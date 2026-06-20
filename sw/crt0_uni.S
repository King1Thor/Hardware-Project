# AH-RISCV unified-memory startup. (c) 2026 Ali Hussein. GPL-3.0.
.section .text.init
.global _start
_start:
    li   sp, 0x80040000          # top of the 256 KB RAM
    call main
1:  j 1b
