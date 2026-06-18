#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/linux" >&2
  exit 2
fi

LINUX="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${ARCH:-riscv}"
LLVM="${LLVM:-1}"
MAKE_JOBS="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
LLVM_SIZE="${LLVM_SIZE:-llvm-size}"
LLVM_NM="${LLVM_NM:-llvm-nm}"
LLVM_OBJDUMP="${LLVM_OBJDUMP:-llvm-objdump}"

if [[ ! -d "$LINUX/lib" || ! -f "$LINUX/Makefile" ]]; then
  echo "$LINUX does not look like a Linux source tree" >&2
  exit 1
fi

for tool in "$LLVM_SIZE" "$LLVM_NM" "$LLVM_OBJDUMP"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" olddefconfig

source_is_not_upstream() {
  grep -Eq 'lean_public___nla_validate|lean_nlattr_core|Lean nlattr replacement' "$1"
}

recover_original_source() {
  if git -C "$LINUX" cat-file -e HEAD:lib/nlattr.c 2>/dev/null; then
    git -C "$LINUX" show HEAD:lib/nlattr.c > "$ORIGINAL_SOURCE"
    return 0
  fi

  echo "cannot recover upstream lib/nlattr.c for size report" >&2
  exit 1
}

ORIGINAL_SOURCE="$LINUX/lib/nlattr_c_original.c"
if [[ ! -f "$ORIGINAL_SOURCE" ]]; then
  if source_is_not_upstream "$LINUX/lib/nlattr.c"; then
    recover_original_source
  else
    cp "$LINUX/lib/nlattr.c" "$ORIGINAL_SOURCE"
  fi
elif source_is_not_upstream "$ORIGINAL_SOURCE"; then
  recover_original_source
fi

cp "$ORIGINAL_SOURCE" "$LINUX/lib/nlattr.c"
rm -f "$LINUX/lib/nlattr.o" "$LINUX/lib/.nlattr.o.cmd"
make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" -j"$MAKE_JOBS" lib/nlattr.o >/dev/null
cp "$LINUX/lib/nlattr.o" "$WORK/nlattr_c_original.o"

"$SCRIPT_DIR/install_replacement.sh" "$LINUX" >/dev/null
rm -f "$LINUX/lib/nlattr.o" "$LINUX/lib/.nlattr.o.cmd" \
      "$LINUX/lib/lean_nlattr_hook.o" "$LINUX/lib/.lean_nlattr_hook.o.cmd" \
      "$LINUX/lib/lean_nlattr_core.o" "$LINUX/lib/.lean_nlattr_core.o.cmd"
make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" -j"$MAKE_JOBS" \
  lib/nlattr.o lib/lean_nlattr_hook.o lib/lean_nlattr_core.o >/dev/null

if "$LLVM_NM" -a "$LINUX/lib/nlattr.o" | grep -q 'lean_original'; then
  echo "lib/nlattr.o contains comparison-only symbols" >&2
  exit 1
fi

if "$LLVM_OBJDUMP" -r "$LINUX/lib/nlattr.o" | grep -q 'lean_original'; then
  echo "lib/nlattr.o relocates to comparison-only symbols" >&2
  exit 1
fi

cp "$LINUX/lib/nlattr.o" "$WORK/nlattr_lean_exports.o"
cp "$LINUX/lib/lean_nlattr_hook.o" "$WORK/lean_nlattr_hook.o"
cp "$LINUX/lib/lean_nlattr_core.o" "$WORK/lean_nlattr_core.o"

file_bytes() {
  wc -c < "$1" | tr -d '[:space:]'
}

text_symbols() {
  "$LLVM_NM" --defined-only --format=posix "$1" |
    awk '$2 ~ /^[Tt]$/ { c++ } END { print c + 0 }'
}

instruction_count() {
  "$LLVM_OBJDUMP" -d "$1" |
    awk '/^[[:space:]]*[0-9a-fA-F]+:[[:space:]]/ { c++ } END { print c + 0 }'
}

size_row() {
  local label="$1" file="$2"
  local text data bss dec hex file_size symbols insns

  read -r text data bss dec hex < <("$LLVM_SIZE" "$file" |
    awk 'NR == 2 { print $1, $2, $3, $4, $5 }')
  file_size="$(file_bytes "$file")"
  symbols="$(text_symbols "$file")"
  insns="$(instruction_count "$file")"
  printf '%-24s %10s %10s %10s %10s %10s %12s %10s %10s\n' \
    "$label" "$text" "$data" "$bss" "$dec" "$hex" "$file_size" "$symbols" "$insns"
}

size_values() {
  "$LLVM_SIZE" "$1" | awk 'NR == 2 { print $1, $2, $3, $4 }'
}

read -r c_text c_data _c_bss c_dec < <(size_values "$WORK/nlattr_c_original.o")
read -r w_text w_data w_bss w_dec < <(size_values "$WORK/nlattr_lean_exports.o")
read -r h_text h_data h_bss h_dec < <(size_values "$WORK/lean_nlattr_hook.o")
read -r l_text l_data l_bss l_dec < <(size_values "$WORK/lean_nlattr_core.o")

lean_text=$((w_text + h_text + l_text))
lean_data=$((w_data + h_data + l_data))
lean_bss=$((w_bss + h_bss + l_bss))
lean_dec=$((w_dec + h_dec + l_dec))
c_file="$(file_bytes "$WORK/nlattr_c_original.o")"
w_file="$(file_bytes "$WORK/nlattr_lean_exports.o")"
h_file="$(file_bytes "$WORK/lean_nlattr_hook.o")"
l_file="$(file_bytes "$WORK/lean_nlattr_core.o")"
lean_file=$((c_file - c_file + w_file + h_file + l_file))
lean_text_pct=$((lean_text * 100 / c_text))
lean_dec_pct=$((lean_dec * 100 / c_dec))
lean_text_data=$((lean_text + lean_data))
c_text_data=$((c_text + c_data))
lean_text_data_pct=$((lean_text_data * 100 / c_text_data))

REPORT="${LEAN_NLATTR_SIZE_REPORT:-}"
if [[ -n "$REPORT" ]]; then
  exec > >(tee "$REPORT")
fi

echo "Lean nlattr size report"
echo "mode=replacement arch=$ARCH llvm=$LLVM linux=$LINUX"
echo
printf '%-24s %10s %10s %10s %10s %10s %12s %10s %10s\n' \
  "object" "text" "data" "bss" "dec" "hex" "file-bytes" "text-syms" "insns"
size_row "original-c:nlattr.o" "$WORK/nlattr_c_original.o"
size_row "lean:exports/thunks" "$WORK/nlattr_lean_exports.o"
size_row "lean:hook" "$WORK/lean_nlattr_hook.o"
size_row "lean:core" "$WORK/lean_nlattr_core.o"
printf '%-24s %10d %10d %10d %10d %10x %12d %10s %10s\n' \
  "lean:total" "$lean_text" "$lean_data" "$lean_bss" "$lean_dec" "$lean_dec" \
  "$lean_file" "-" "-"
echo
echo "Lean replacement text is ${lean_text_pct}% of original C nlattr.o text."
echo "Lean replacement text+data, excluding BSS, is ${lean_text_data_pct}% of original C nlattr.o text+data."
echo "Lean replacement total allocatable sections are ${lean_dec_pct}% of original C nlattr.o."
echo "If LEAN_NLATTR_ENABLE_RUNTIME_HOOKS is enabled, hook BSS includes the freestanding runtime heap; default LEAN_NLATTR_HEAP_BYTES is 65536."
echo "PASS: size-report nlattr size report"
