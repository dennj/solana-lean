#!/usr/bin/env sh

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/linux" >&2
  exit 2
fi

LINUX=$1
LIB="$LINUX/lib"
ORIG="$LIB/nlattr.c"
BACKUP="$LIB/nlattr_c_original.c"
MAKEFILE="$LIB/Makefile"
SCRIPT_DIR=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(unset CDPATH; cd -- "$SCRIPT_DIR/../.." && pwd)
EXPORTS="$SCRIPT_DIR/nlattr_exports.c"
HOOK="$SCRIPT_DIR/lean_nlattr_hook.c"
LEAN_SRC="$SCRIPT_DIR/NlAttrCore.lean"
LEAN_MEMORY_SRC="$SCRIPT_DIR/NlAttrMemory.lean"
RAW_SRC="$SCRIPT_DIR/nlattr_raw.c"
KBUILD_FRAGMENT="$SCRIPT_DIR/lean_nlattr_kbuild.mk"
FREESTANDING="$ROOT/src/runtime/freestanding"
RUNTIME="$FREESTANDING/runtime.c"
RUNTIME_HEADER="$FREESTANDING/lean_freestanding.h"
LEAN_CORE_DIR="$LIB/lean_nlattr_core"

remove_exact_line() {
  line=$1
  file=$2

  if grep -Fxq "$line" "$file"; then
    tmp=$(mktemp)
    grep -Fxv "$line" "$file" > "$tmp"
    mv "$tmp" "$file"
  fi
}

remove_prefix_lines() {
  prefix=$1
  file=$2

  if grep -Fq "$prefix" "$file"; then
    tmp=$(mktemp)
    awk -v prefix="$prefix" 'index($0, prefix) != 1 { print }' "$file" > "$tmp"
    mv "$tmp" "$file"
  fi
}

saved_original_is_not_upstream() {
  file=$1

  grep -Eq 'lean_public___nla_validate|lean_nlattr_core|Lean nlattr replacement' "$file"
}

restore_original_from_git() {
  if command -v git >/dev/null 2>&1 &&
     git -C "$LINUX" cat-file -e HEAD:lib/nlattr.c 2>/dev/null; then
    git -C "$LINUX" show HEAD:lib/nlattr.c > "$BACKUP"
    return 0
  fi

  echo "cannot recover upstream lib/nlattr.c" >&2
  exit 1
}

if [ ! -d "$LIB" ] || [ ! -f "$LINUX/Makefile" ]; then
  echo "$LINUX does not look like a Linux source tree" >&2
  exit 1
fi

if [ ! -f "$ORIG" ] && [ ! -f "$BACKUP" ]; then
  echo "missing $ORIG" >&2
  exit 1
fi

for file in "$EXPORTS" "$HOOK" "$LEAN_SRC" "$LEAN_MEMORY_SRC" "$RAW_SRC" "$KBUILD_FRAGMENT" \
            "$RUNTIME" "$RUNTIME_HEADER"; do
  if [ ! -f "$file" ]; then
    echo "missing replacement source $file" >&2
    exit 1
  fi
done

if [ ! -f "$BACKUP" ]; then
  if saved_original_is_not_upstream "$ORIG"; then
    restore_original_from_git
  else
    cp "$ORIG" "$BACKUP"
  fi
elif saved_original_is_not_upstream "$BACKUP"; then
  restore_original_from_git
fi

cp "$EXPORTS" "$ORIG"
cp "$HOOK" "$LIB/lean_nlattr_hook.c"
mkdir -p "$LEAN_CORE_DIR"
cp "$LEAN_SRC" "$LEAN_CORE_DIR/NlAttrCore.lean"
cp "$LEAN_MEMORY_SRC" "$LEAN_CORE_DIR/NlAttrMemory.lean"
cp "$RAW_SRC" "$LEAN_CORE_DIR/nlattr_raw.c"
cp "$RUNTIME" "$LEAN_CORE_DIR/runtime.c"
cp "$RUNTIME_HEADER" "$LEAN_CORE_DIR/lean_freestanding.h"
cp "$KBUILD_FRAGMENT" "$LIB/lean_nlattr_kbuild.mk"

rm -f "$LIB/lean_nlattr_selftest.c" "$LIB/lean_nlattr_selftest.o" \
      "$LIB/.lean_nlattr_selftest.o.cmd"
rm -f "$LIB/lean_nlattr_benchmark.c" "$LIB/lean_nlattr_benchmark_original.c" \
      "$LIB/lean_nlattr_benchmark.o" "$LIB/.lean_nlattr_benchmark.o.cmd"

MAKE_DOLLAR='$'
OBJ_LINE="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_hook.o lean_nlattr_core.o"
KBUILD_INCLUDE="include ${MAKE_DOLLAR}(srctree)/lib/lean_nlattr_kbuild.mk"
HOOK_CFLAGS_LINE="CFLAGS_lean_nlattr_hook.o += -DLEAN_NLATTR_TRACE_COVERAGE -DLEAN_NLATTR_ENABLE_RUNTIME_HOOKS -DLEAN_NLATTR_HEAP_BYTES=${MAKE_DOLLAR}(LEAN_NLATTR_HEAP_BYTES)"
SELFTEST_OBJ_LINE="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_selftest.o"
BENCHMARK_OBJ_LINE="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_benchmark.o"
BENCHMARK_HOOK_CFLAGS_LINE='CFLAGS_lean_nlattr_hook.o += -DLEAN_NLATTR_TRACE_COUNTS'
BENCHMARK_ITERS_CFLAGS_PREFIX='CFLAGS_lean_nlattr_benchmark.o += -DLEAN_NLATTR_BENCH_ITERS='
BENCHMARK_ROUNDS_CFLAGS_PREFIX='CFLAGS_lean_nlattr_benchmark.o += -DLEAN_NLATTR_BENCH_ROUNDS='

remove_exact_line "$OBJ_LINE" "$MAKEFILE"
remove_exact_line "$KBUILD_INCLUDE" "$MAKEFILE"
remove_exact_line "$HOOK_CFLAGS_LINE" "$MAKEFILE"
remove_exact_line "$SELFTEST_OBJ_LINE" "$MAKEFILE"
remove_exact_line "$BENCHMARK_OBJ_LINE" "$MAKEFILE"
remove_exact_line "$BENCHMARK_HOOK_CFLAGS_LINE" "$MAKEFILE"
remove_prefix_lines "$BENCHMARK_ITERS_CFLAGS_PREFIX" "$MAKEFILE"
remove_prefix_lines "$BENCHMARK_ROUNDS_CFLAGS_PREFIX" "$MAKEFILE"

{
  printf '\n%s\n' "$KBUILD_INCLUDE"
  printf '%s\n' "$OBJ_LINE"
  printf '%s\n' "$HOOK_CFLAGS_LINE"
} >> "$MAKEFILE"

echo "installed Lean nlattr replacement in $LINUX"
echo "  original: $BACKUP"
echo "  exports:  $ORIG"
echo "  hook:     $LIB/lean_nlattr_hook.c"
echo "  lean:     $LEAN_CORE_DIR/NlAttrCore.lean"
