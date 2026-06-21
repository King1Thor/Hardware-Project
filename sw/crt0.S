# AH-RISCV bare-metal startup. (c) 2026 Ali Hussein, GPL-3.0.
    .section .text.init,"ax"
    .global _start
_start:
    li   sp, 0x40010000     # top of the 64 KB data memory
    jal  ra, main
1:  j    1b
