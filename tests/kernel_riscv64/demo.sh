#!/usr/bin/env bash
# Visual kernel boot demo: build the freestanding RISC-V kernel from
# the Lean sources here, then boot it under QEMU with serial I/O wired
# to the terminal so the audience watches the kernel print live.
#
# Exit QEMU with Ctrl-A then X.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# Local Lean toolchain (the patched one with the SBF-friendly runtime)
LEAN_BIN="$(cd ../../build/release/stage1/bin && pwd)"
export PATH="$LEAN_BIN:$PATH"

# ld.lld lookup (matches run_test.sh fallbacks)
if [[ -z "${LEAN_RISCV64_LD:-}" ]]; then
  for cand in /opt/homebrew/bin/ld.lld /opt/homebrew/opt/llvm@19/bin/ld.lld /usr/local/opt/llvm/bin/ld.lld; do
    [[ -x "$cand" ]] && export LEAN_RISCV64_LD="$cand" && break
  done
fi

QEMU=${LEAN_RISCV64_QEMU:-$(command -v qemu-system-riscv64)}
if [[ -z "$QEMU" ]]; then
  echo "qemu-system-riscv64 not found. brew install qemu (or set LEAN_RISCV64_QEMU)."
  exit 1
fi

cyan()  { printf '\033[36m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cyan "==> Cross-compile each Lean module to SBF-/RISC-V bitcode"
mkdir -p "$WORK/Kernel"
export LEAN_PATH="$WORK${LEAN_PATH:+:$LEAN_PATH}"
for m in Kernel/Sv39 Kernel/Memory Kernel/Core Kernel/Hardware Main; do
  echo "    lean --target=riscv64-unknown-none-elf $m.lean"
  lean --target=riscv64-unknown-none-elf --root=. \
    --bc="$WORK/$m.bc" -o "$WORK/$m.olean" "$m.lean"
done

cyan "==> Link with boot.S, kernel.c, and kernel.ld → kernel.elf"
leanc --target=riscv64-unknown-none-elf \
  "$WORK/Main.bc" \
  "$WORK/Kernel/Core.bc" "$WORK/Kernel/Memory.bc" \
  "$WORK/Kernel/Sv39.bc" "$WORK/Kernel/Hardware.bc" \
  boot.S kernel.c \
  -I "$LEAN_BIN/../../../../src/runtime/freestanding" \
  -T kernel.ld -Wl,-e,_start \
  -o "$WORK/kernel.elf"

green "    built $WORK/kernel.elf ($(wc -c < "$WORK/kernel.elf") bytes)"
echo

cyan "==> Boot in QEMU.  Exit with Ctrl-A then X."
green "------------------------ kernel output ------------------------"
exec "$QEMU" \
  -machine virt \
  -m 128M \
  -smp 1 \
  -bios default \
  -kernel "$WORK/kernel.elf" \
  -display none \
  -serial stdio \
  -monitor none
