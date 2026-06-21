# AH-RISCV board demo: x4 = 13, x6 = 1+2+3+4+5 = 15, then halt (ebreak).
# (c) 2026 Ali Hussein. GPL-3.0.
    .section .text
    .globl _start
_start:
    li   x4, 13            # "loaded value"
    li   x6, 0             # running sum
    li   x5, 1             # i = 1
1:  add  x6, x6, x5        # sum += i
    addi x5, x5, 1         # i++
    li   x7, 6
    blt  x5, x7, 1b        # while (i < 6)  -> sum = 15
    ebreak                 # halt
