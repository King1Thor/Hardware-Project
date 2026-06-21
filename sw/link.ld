/* AH-RISCV linker: code in instruction memory, data in the 64 KB data BRAM. */
ENTRY(_start)
MEMORY {
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  DMEM (rw)  : ORIGIN = 0x40000000, LENGTH = 64K
}
SECTIONS {
  .text   : { *(.text.init) *(.text*) }                  > IMEM
  .rodata : { *(.rodata*) *(.srodata*) }                 > DMEM
  .data   : { *(.data*) *(.sdata*) }                     > DMEM
  .bss    : { *(.bss*) *(.sbss*) *(COMMON) }             > DMEM
  . = ALIGN(8);
  _end = .;
}
