/* Minimal RISC-V boot stub for the cross_freestanding lake fixture.
 * Defines _start as the linker entry point. The body just spins so the
 * kernel never returns; we never run it under QEMU here, we only verify
 * leanc + ld.lld produce a valid ELF. */
.section .text.boot, "ax", @progbits
.global _start
_start:
1:
    j 1b
