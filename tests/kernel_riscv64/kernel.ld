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

  ASSERT(. <= 0x80300000, "kernel image overlaps page-table arena")
  . = 0x80300000;
  .kernel_pt : ALIGN(4K) {
    __kernel_pt_start = .;
    . += 0x3000;
    __kernel_pt_end = .;
  }

  . = ALIGN(16);
  __lean_heap_start = .;
  . += 0x80000;
  __lean_heap_end = .;

  . = ALIGN(16);
  __stack_bottom = .;
  . += 0x10000;
  __stack_top = .;

  . = 0x80600000;
  .user : ALIGN(4K) {
    KEEP(*(.user.text))
  }
}
