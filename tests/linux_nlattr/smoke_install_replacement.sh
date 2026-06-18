#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
MAKE_DOLLAR='$'

seed_linux_tree() {
  tree=$1

  mkdir -p "$tree/lib"
  printf '%s\n' 'int original_nlattr_marker;' > "$tree/lib/nlattr.c"
  {
    printf '%s\n' "obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += nlattr.o"
    printf '%s\n' "include ${MAKE_DOLLAR}(srctree)/lib/lean_nlattr_kbuild.mk"
    printf '%s\n' "obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_hook.o lean_nlattr_core.o"
    printf '%s\n' "obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_selftest.o"
    printf '%s\n' "obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_benchmark.o"
    printf '%s\n' 'CFLAGS_lean_nlattr_hook.o += -DLEAN_NLATTR_TRACE_COUNTS'
  } > "$tree/lib/Makefile"
  printf '%s\n' 'int fixture_selftest_marker;' > "$tree/lib/lean_nlattr_selftest.c"
  printf '%s\n' 'int fixture_benchmark_marker;' > "$tree/lib/lean_nlattr_benchmark.c"
  printf '%s\n' 'int fixture_benchmark_original_marker;' > "$tree/lib/lean_nlattr_benchmark_original.c"
  printf '%s\n' 'all:' > "$tree/Makefile"
}

seed_linux_tree "$WORK/linux"
kbuild_include="include ${MAKE_DOLLAR}(srctree)/lib/lean_nlattr_kbuild.mk"
replacement_obj_line="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_hook.o lean_nlattr_core.o"
selftest_obj_line="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_selftest.o"
benchmark_obj_line="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_benchmark.o"
hook_cflags="CFLAGS_lean_nlattr_hook.o += -DLEAN_NLATTR_TRACE_COVERAGE -DLEAN_NLATTR_ENABLE_RUNTIME_HOOKS -DLEAN_NLATTR_HEAP_BYTES=${MAKE_DOLLAR}(LEAN_NLATTR_HEAP_BYTES)"

"$SCRIPT_DIR/install_replacement.sh" "$WORK/linux" >/dev/null
"$SCRIPT_DIR/install_replacement.sh" "$WORK/linux" >/dev/null

test -f "$WORK/linux/lib/nlattr_c_original.c"
test -f "$WORK/linux/lib/lean_nlattr_hook.c"
test -f "$WORK/linux/lib/lean_nlattr_core/NlAttrCore.lean"
test -f "$WORK/linux/lib/lean_nlattr_core/NlAttrMemory.lean"
test -f "$WORK/linux/lib/lean_nlattr_core/nlattr_raw.c"
test -f "$WORK/linux/lib/lean_nlattr_core/runtime.c"
test -f "$WORK/linux/lib/lean_nlattr_core/lean_freestanding.h"
test -f "$WORK/linux/lib/lean_nlattr_kbuild.mk"
test ! -e "$WORK/linux/lib/lean_nlattr_selftest.c"
test ! -e "$WORK/linux/lib/lean_nlattr_benchmark.c"
test ! -e "$WORK/linux/lib/lean_nlattr_benchmark_original.c"
test "$(grep -Fxc "$kbuild_include" "$WORK/linux/lib/Makefile")" -eq 1
test "$(grep -Fxc "$replacement_obj_line" "$WORK/linux/lib/Makefile")" -eq 1
test "$(grep -Fxc "$hook_cflags" "$WORK/linux/lib/Makefile")" -eq 1
test "$(grep -Fxc "$selftest_obj_line" "$WORK/linux/lib/Makefile")" -eq 0
test "$(grep -Fxc "$benchmark_obj_line" "$WORK/linux/lib/Makefile")" -eq 0
test "$(grep -Fxc 'CFLAGS_lean_nlattr_hook.o += -DLEAN_NLATTR_TRACE_COUNTS' "$WORK/linux/lib/Makefile")" -eq 0

grep -q 'Lean nlattr replacement export metadata' "$WORK/linux/lib/nlattr.c"
if grep -q 'lean_public___nla_validate' "$WORK/linux/lib/nlattr.c"; then
  echo "replacement export metadata exposes internal Lean symbol" >&2
  exit 1
fi
grep -q 'lean_nlattr_public_roots' "$WORK/linux/lib/lean_nlattr_kbuild.mk"

echo "PASS: Lean nlattr replacement install"
