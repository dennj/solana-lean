/* Minimal linker script for the cross_freestanding lake fixture.
 * Lays out a tiny RISC-V kernel image starting at the QEMU virt machine's
 * default kernel load address. Only verifies the link succeeds — we don't
 * actually run this under an emulator. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80200000;

  .text : ALIGN(4K) {
    *(.text.boot)
    *(.text .text.*)
  }

  .rodata : ALIGN(4K) {
    *(.rodata .rodata.*)
  }

  .data : ALIGN(4K) {
    *(.sdata .sdata.*)
    *(.data .data.*)
  }

  .bss : ALIGN(4K) {
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
  }
}
