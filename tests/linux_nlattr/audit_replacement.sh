#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 /path/to/linux objects|linked" >&2
  exit 2
fi

LINUX="$1"
MODE="$2"
LLVM_NM="${LLVM_NM:-llvm-nm}"
LLVM_OBJDUMP="${LLVM_OBJDUMP:-llvm-objdump}"

case "$MODE" in
  objects|linked) ;;
  *)
    echo "unknown audit mode: $MODE" >&2
    exit 2
    ;;
esac

if [[ ! -d "$LINUX/lib" || ! -f "$LINUX/Makefile" ]]; then
  echo "$LINUX does not look like a Linux source tree" >&2
  exit 1
fi

for tool in "$LLVM_NM" "$LLVM_OBJDUMP"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

NLATTR_OBJ="$LINUX/lib/nlattr.o"
LEAN_CORE_OBJ="$LINUX/lib/lean_nlattr_core.o"
VMLINUX="$LINUX/vmlinux"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REQUIRED_PUBLIC_SYMBOLS=(
  __nla_validate
  __nla_parse
  nla_policy_len
  nla_find
  nla_strscpy
  nla_strdup
  nla_memcpy
  nla_memcmp
  nla_strcmp
  __nla_reserve
  __nla_reserve_64bit
  __nla_reserve_nohdr
  nla_reserve
  nla_reserve_64bit
  nla_reserve_nohdr
  __nla_put
  __nla_put_64bit
  __nla_put_nohdr
  nla_put
  nla_put_64bit
  nla_put_nohdr
  nla_append
)

REQUIRED_IMPL_SYMBOLS=(
  nla_get_range_unsigned
  nla_get_range_signed
)

REQUIRED_OBJECT_REFS=(
  __nla_validate
  __nla_parse
  nla_strdup
  nla_policy_len
  nla_find
  nla_strscpy
  nla_memcpy
  nla_memcmp
  nla_strcmp
  __nla_reserve
  __nla_reserve_64bit
  __nla_reserve_nohdr
  nla_reserve
  nla_reserve_64bit
  nla_reserve_nohdr
  __nla_put
  __nla_put_64bit
  __nla_put_nohdr
  nla_put
  nla_put_64bit
  nla_put_nohdr
  nla_append
)

REQUIRED_LINKED_SYMBOLS=("${REQUIRED_PUBLIC_SYMBOLS[@]}")
REQUIRED_LINKED_SYMBOLS+=("${REQUIRED_IMPL_SYMBOLS[@]}")

if [[ -f "$LINUX/lib/nlattr_c_original.c" ]]; then
  grep -oE 'EXPORT_SYMBOL(_GPL)?\([A-Za-z0-9_]+\)' "$LINUX/lib/nlattr_c_original.c" |
    sed -E 's/EXPORT_SYMBOL(_GPL)?\(([^)]+)\)/\2/' |
    sort -u > "$WORK/original.exports"
  printf '%s\n' "${REQUIRED_PUBLIC_SYMBOLS[@]}" | sort -u > "$WORK/expected.exports"
  if ! diff -u "$WORK/expected.exports" "$WORK/original.exports" > "$WORK/export.diff"; then
    echo "saved original lib/nlattr.c export surface differs from the replacement audit list" >&2
    cat "$WORK/export.diff" >&2
    exit 1
  fi
fi

if [[ ! -f "$NLATTR_OBJ" ]]; then
  echo "missing nlattr object: $NLATTR_OBJ" >&2
  exit 1
fi

if "$LLVM_NM" -a "$NLATTR_OBJ" | grep -q 'lean_original'; then
  echo "lib/nlattr.o contains comparison-only symbols" >&2
  exit 1
fi

if "$LLVM_OBJDUMP" -r "$NLATTR_OBJ" | grep -q 'lean_original'; then
  echo "lib/nlattr.o relocates to comparison-only symbols" >&2
  exit 1
fi

if [[ "$MODE" == "objects" ]]; then
  if "$LLVM_NM" --defined-only --extern-only --format=posix "$NLATTR_OBJ" |
      awk '$1 ~ /^lean_public_/ { print; bad = 1 } END { exit bad ? 0 : 1 }'; then
    echo "lib/nlattr.o defines Lean public symbols; expected undefined references" >&2
    exit 1
  fi

  if [[ ! -f "$LEAN_CORE_OBJ" ]]; then
    echo "missing Lean core object: $LEAN_CORE_OBJ" >&2
    exit 1
  fi

  if "$LLVM_NM" --defined-only --extern-only --format=posix "$LEAN_CORE_OBJ" |
      awk '$1 ~ /^lean_public_/ { print; bad = 1 } END { exit bad ? 0 : 1 }'; then
    echo "lib/lean_nlattr_core.o exposes internal Lean ABI symbols" >&2
    exit 1
  fi

  "$LLVM_NM" -u "$NLATTR_OBJ" | awk '{ print $NF }' | sort -u > "$WORK/nlattr.undefined"
  for sym in "${REQUIRED_OBJECT_REFS[@]}"; do
    if ! grep -Fxq "$sym" "$WORK/nlattr.undefined"; then
      echo "lib/nlattr.o does not have required replacement reference: $sym" >&2
      exit 1
    fi
  done
fi

if [[ "$MODE" == "linked" ]]; then
  if [[ ! -f "$VMLINUX" ]]; then
    echo "missing linked kernel image: $VMLINUX" >&2
    exit 1
  fi

  if "$LLVM_NM" -a "$VMLINUX" | grep -q 'lean_original'; then
    echo "vmlinux contains comparison-only symbols" >&2
    exit 1
  fi

  if "$LLVM_NM" --defined-only --extern-only --format=posix "$VMLINUX" |
      awk '$1 ~ /^lean_public_/ { print; bad = 1 } END { exit bad ? 0 : 1 }'; then
    echo "vmlinux exposes internal Lean ABI symbols" >&2
    exit 1
  fi

  "$LLVM_NM" --defined-only --extern-only --format=posix "$VMLINUX" > "$WORK/vmlinux.defined"
  for sym in "${REQUIRED_LINKED_SYMBOLS[@]}"; do
    type="$(awk -v sym="$sym" '$1 == sym { print $2; found = 1; exit } END { if (!found) exit 1 }' "$WORK/vmlinux.defined")" || {
      echo "vmlinux does not define required replacement symbol: $sym" >&2
      exit 1
    }
    case "$type" in
      W|w|V|v|U)
        echo "vmlinux defines $sym as weak/undefined type $type" >&2
        exit 1
        ;;
    esac
  done
fi

echo "PASS: Lean nlattr replacement audit ($MODE)"
