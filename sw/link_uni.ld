/* AH-RISCV unified-memory layout: code + data in one RAM at 0x80000000. */
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 256K }
SECTIONS {
  . = 0x80000000;
  .text   : { *(.text.init) *(.text*) }            > RAM
  .rodata : { *(.rodata*) *(.srodata*) }            > RAM
  .data   : { *(.data*) *(.sdata*) }                > RAM
  .bss    : { *(.bss*) *(.sbss*) *(COMMON) }        > RAM
  . = ALIGN(8);
  _end = .;
}
