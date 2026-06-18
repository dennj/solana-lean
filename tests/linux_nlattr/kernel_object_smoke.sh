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
LLVM_NM="${LLVM_NM:-llvm-nm}"
MAKE_JOBS="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

if [[ ! -d "$LINUX/lib" || ! -f "$LINUX/Makefile" ]]; then
  echo "$LINUX does not look like a Linux source tree" >&2
  exit 1
fi

"$SCRIPT_DIR/install_replacement.sh" "$LINUX"

if [[ ! -f "$LINUX/.config" ]]; then
  make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" defconfig
fi

make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" olddefconfig
make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" -j"$MAKE_JOBS" \
  lib/nlattr.o lib/lean_nlattr_hook.o lib/lean_nlattr_core.o

bash "$SCRIPT_DIR/audit_replacement.sh" "$LINUX" objects

required_core_defs=(
  __nla_validate
  __nla_parse
  nla_get_range_unsigned
  nla_get_range_signed
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

"$LLVM_NM" --defined-only --extern-only --format=posix \
  "$LINUX/lib/lean_nlattr_core.o" > "$LINUX/lib/.lean_nlattr_core.defined"

for sym in "${required_core_defs[@]}"; do
  if ! awk -v sym="$sym" '$1 == sym { found = 1 } END { exit found ? 0 : 1 }' \
      "$LINUX/lib/.lean_nlattr_core.defined"; then
    echo "Lean core does not define required symbol: $sym" >&2
    exit 1
  fi
done

if awk '$1 ~ /^lean_public_/ { print; bad = 1 } END { exit bad ? 0 : 1 }' \
    "$LINUX/lib/.lean_nlattr_core.defined"; then
  echo "Lean core exposes internal ABI symbols" >&2
  exit 1
fi

MAKE_DOLLAR='$'
KBUILD_INCLUDE="include ${MAKE_DOLLAR}(srctree)/lib/lean_nlattr_kbuild.mk"
if ! grep -Fq "$KBUILD_INCLUDE" "$LINUX/lib/Makefile"; then
  echo "lib/Makefile does not include the Lean nlattr Kbuild fragment" >&2
  exit 1
fi

echo "PASS: Lean nlattr replacement objects build"
