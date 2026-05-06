/-! Minimal RISC-V freestanding "kernel" exercising the
    `freestanding_program` lake build path.

    Defines one trivial Lean function that the boot stub doesn't need to
    actually call — the goal of this fixture is to verify that:
      1. `lean --target=riscv64-unknown-none-elf --bc=...` produces bitcode
         for a Lean module under the freestanding runtime,
      2. `leanc --target=riscv64-unknown-none-elf` links that bitcode with
         a `.S` boot stub and a linker script into a valid ELF,
      3. the validator catches non-ELF output. -/

@[export lean_kernel_main_io]
def kernelMain : BaseIO UInt64 := pure 0x77
