set -e

LEAN_FEATURES=$(lean --features 2>/dev/null || true)
if ! echo "$LEAN_FEATURES" | grep -q LLVM; then
  echo "SKIP: lean was built without -DLLVM=ON; riscv64 kernel emit unavailable"
  exit 0
fi

find_tool() {
  local env_name="$1"
  local tool="$2"
  local value="${!env_name:-}"
  if [[ -n "$value" && -x "$value" ]]; then
    echo "$value"
    return 0
  fi
  for d in /opt/homebrew/opt/llvm@19 /opt/homebrew/opt/llvm /usr/local/opt/llvm /usr/lib/llvm-19 /usr/lib/llvm-18; do
    if [[ -x "$d/bin/$tool" ]]; then
      echo "$d/bin/$tool"
      return 0
    fi
  done
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi
  return 1
}

CLANG=$(find_tool LEAN_RISCV64_CLANG clang || true)
LD_LLD=$(find_tool LEAN_RISCV64_LD ld.lld || true)
LLVM_READELF=$(find_tool LLVM_READELF llvm-readelf || true)
QEMU=$(find_tool LEAN_RISCV64_QEMU qemu-system-riscv64 || true)

if [[ -z "$CLANG" ]]; then
  echo "SKIP: riscv64 clang not found (set LEAN_RISCV64_CLANG=<path>)"
  exit 0
fi
if [[ -z "$LD_LLD" ]]; then
  echo "SKIP: ld.lld not found (set LEAN_RISCV64_LD=<path>)"
  exit 0
fi
if [[ -z "$LLVM_READELF" ]]; then
  echo "SKIP: llvm-readelf not found (set LLVM_READELF=<path>)"
  exit 0
fi

export LEAN_RISCV64_CLANG="$CLANG"
export LEAN_RISCV64_LD="$LD_LLD"

fail() { echo "TEST FAILED: $*"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SRCDIR=$PWD
mkdir -p "$WORK/Kernel"
export LEAN_PATH="$WORK${LEAN_PATH:+:$LEAN_PATH}"

kernel_lean() {
  lake env env "LEAN_PATH=$LEAN_PATH" lean "$@"
}

kernel_leanc() {
  leanc "$@"
}

kernel_lean --target=riscv64-unknown-none-elf --root=. \
  --bc="$WORK/Kernel/Sv39.bc" -o "$WORK/Kernel/Sv39.olean" Kernel/Sv39.lean
[[ -s "$WORK/Kernel/Sv39.bc" ]] || fail "no bitcode emitted for Kernel.Sv39"
kernel_lean --target=riscv64-unknown-none-elf --root=. \
  --bc="$WORK/Kernel/Memory.bc" -o "$WORK/Kernel/Memory.olean" Kernel/Memory.lean
[[ -s "$WORK/Kernel/Memory.bc" ]] || fail "no bitcode emitted for Kernel.Memory"
kernel_lean --target=riscv64-unknown-none-elf --root=. \
  --bc="$WORK/Kernel/Core.bc" -o "$WORK/Kernel/Core.olean" Kernel/Core.lean
[[ -s "$WORK/Kernel/Core.bc" ]] || fail "no bitcode emitted for Kernel.Core"
kernel_lean --target=riscv64-unknown-none-elf --root=. \
  --bc="$WORK/Kernel/Hardware.bc" -o "$WORK/Kernel/Hardware.olean" Kernel/Hardware.lean
[[ -s "$WORK/Kernel/Hardware.bc" ]] || fail "no bitcode emitted for Kernel.Hardware"
kernel_lean --target=riscv64-unknown-none-elf --root=. \
  --bc="$WORK/Main.bc" -o "$WORK/Main.olean" Main.lean
[[ -s "$WORK/Main.bc" ]] || fail "no bitcode emitted for riscv64 kernel target"

cd "$WORK"

kernel_leanc --target=riscv64-unknown-none-elf \
  Main.bc Kernel/Core.bc Kernel/Memory.bc Kernel/Sv39.bc Kernel/Hardware.bc \
  "$SRCDIR/boot.S" "$SRCDIR/kernel.c" \
  -I "$SRCDIR/../../src/runtime/freestanding" \
  -T "$SRCDIR/kernel.ld" -Wl,-e,_start \
  -o kernel.elf 2>leanc.err \
  || { echo "leanc failed:"; cat leanc.err; fail "kernel ELF link failed"; }

[[ -s kernel.elf ]] || fail "empty kernel.elf"

"$LLVM_READELF" -h kernel.elf > header.txt
grep -q 'Machine:.*RISC-V' header.txt \
  || fail "kernel.elf is not a RISC-V ELF:\n$(cat header.txt)"

"$LLVM_READELF" -s kernel.elf > symbols.txt
grep -q '_start' symbols.txt \
  || fail "missing _start symbol"
grep -q 'lean_kernel_invoke_entry' symbols.txt \
  || fail "missing lean_kernel_invoke_entry symbol"
grep -q 'lean_kernel_trap_entry_io' symbols.txt \
  || fail "missing lean_kernel_trap_entry_io symbol"
grep -q 'kernel_trap_vector' symbols.txt \
  || fail "missing kernel_trap_vector symbol"
grep -q 'kernel_user_entry' symbols.txt \
  || fail "missing kernel_user_entry symbol"
grep -q 'initialize_Kernel_Core' symbols.txt \
  || fail "missing initialize_Kernel_Core symbol"
grep -q 'initialize_Kernel_Memory' symbols.txt \
  || fail "missing initialize_Kernel_Memory symbol"
grep -q 'initialize_Kernel_Sv39' symbols.txt \
  || fail "missing initialize_Kernel_Sv39 symbol"
grep -q '__lean_heap_start' symbols.txt \
  || fail "missing __lean_heap_start linker symbol"
grep -q '__lean_heap_end' symbols.txt \
  || fail "missing __lean_heap_end linker symbol"
grep -q '__kernel_pt_start' symbols.txt \
  || fail "missing __kernel_pt_start linker symbol"
grep -q '__kernel_pt_end' symbols.txt \
  || fail "missing __kernel_pt_end linker symbol"
grep -q 'kernel_store8' symbols.txt \
  || fail "missing kernel_store8 symbol"
grep -q 'kernel_store8_u64' symbols.txt \
  || fail "missing kernel_store8_u64 symbol"
grep -q 'kernel_store64' symbols.txt \
  || fail "missing kernel_store64 symbol"
grep -q 'kernel_trap_vector_addr' symbols.txt \
  || fail "missing kernel_trap_vector_addr symbol"
grep -q 'kernel_write_stvec' symbols.txt \
  || fail "missing kernel_write_stvec symbol"
grep -q 'kernel_write_satp' symbols.txt \
  || fail "missing kernel_write_satp symbol"
grep -q 'kernel_write_sepc' symbols.txt \
  || fail "missing kernel_write_sepc symbol"
grep -q 'kernel_set_timer' symbols.txt \
  || fail "missing kernel_set_timer symbol"
grep -q 'kernel_enter_user' symbols.txt \
  || fail "missing kernel_enter_user symbol"
grep -q 'kernel_sfence_vma' symbols.txt \
  || fail "missing kernel_sfence_vma symbol"
grep -q 'kernel_probe_breakpoint_trap' symbols.txt \
  || fail "missing kernel_probe_breakpoint_trap symbol"
grep -q 'kernel_set_state_boots' symbols.txt \
  || fail "missing kernel_set_state_boots symbol"
grep -q 'kernel_deny_bad_page_table_action' symbols.txt \
  || fail "missing kernel_deny_bad_page_table_action symbol"
grep -q 'kernel_deny_unhandled_trap' symbols.txt \
  || fail "missing kernel_deny_unhandled_trap symbol"

if [[ -z "$QEMU" ]]; then
  echo "PASS: riscv64 Lean kernel-shaped ELF (boot skipped: qemu-system-riscv64 not found)"
  exit 0
fi

"$QEMU" \
  -machine virt \
  -m 128M \
  -smp 1 \
  -bios default \
  -kernel kernel.elf \
  -display none \
  -serial stdio \
  -monitor none \
  > qemu.out 2>&1 &
QEMU_PID=$!

cleanup_qemu() {
  if kill -0 "$QEMU_PID" >/dev/null 2>&1; then
    kill "$QEMU_PID" >/dev/null 2>&1 || true
    wait "$QEMU_PID" >/dev/null 2>&1 || true
  fi
}
trap 'cleanup_qemu; rm -rf "$WORK"' EXIT

for _ in {1..100}; do
  if grep -q 'Lean theorem: user writeByte syscall authorized' qemu.out; then
    cleanup_qemu
    echo "PASS: riscv64 Lean kernel booted under QEMU and ran Lean entry"
    exit 0
  fi
  if ! kill -0 "$QEMU_PID" >/dev/null 2>&1; then
    cat qemu.out
    fail "QEMU exited before Lean kernel log"
  fi
  sleep 0.1
done

cat qemu.out
fail "QEMU did not print Lean kernel log"
