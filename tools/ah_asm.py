#!/usr/bin/env python3
# =============================================================================
#  ah_asm.py  -  RV64I mini-assembler (seed of the AH-RISCV toolchain)
#  Copyright (c) 2026 Ali Hussein.  Licensed under GPL-3.0.
#  Part of the AH-RISCV project.  Signature: "AHUSSEIN".
# =============================================================================
import re, sys

OP, OPIMM   = 0b0110011, 0b0010011
OP32, OPI32 = 0b0111011, 0b0011011
LOAD, STORE = 0b0000011, 0b0100011
BRANCH      = 0b1100011
JAL, JALR   = 0b1101111, 0b1100111
LUI, AUIPC  = 0b0110111, 0b0010111
SYSTEM      = 0b1110011
CSRS = {'mstatus':0x300,'mie':0x304,'mtvec':0x305,'mscratch':0x340,
        'mepc':0x341,'mcause':0x342,'mip':0x344,'mhartid':0xF14}
def csr(t):
    t=t.strip()
    return CSRS[t] if t in CSRS else int(t,0)

def reg(t):
    t=t.strip()
    if t=='zero': return 0
    if t=='ra': return 1
    if t=='sp': return 2
    m=re.fullmatch(r'x(\d+)', t)
    if not m: raise ValueError(f"bad register '{t}'")
    return int(m.group(1))

def imm(t): return int(t.strip(), 0)

def r_type(f7,f3,op,rd,rs1,rs2): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def i_type(f3,op,rd,rs1,im):     return ((im&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def i_shift(f6,f3,op,rd,rs1,sh): return (f6<<26)|(sh<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def i_shiftw(f7,f3,op,rd,rs1,sh):return (f7<<25)|(sh<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def s_type(f3,op,rs2,rs1,im):
    im&=0xFFF
    return ((im>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((im&0x1F)<<7)|op
def b_type(f3,op,rs1,rs2,im):
    im&=0x1FFF
    return (((im>>12)&1)<<31)|(((im>>5)&0x3F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(((im>>1)&0xF)<<8)|(((im>>11)&1)<<7)|op
def u_type(op,rd,im): return ((im&0xFFFFF)<<12)|(rd<<7)|op
def j_type(op,rd,im):
    im&=0x1FFFFF
    return (((im>>20)&1)<<31)|(((im>>1)&0x3FF)<<21)|(((im>>11)&1)<<20)|(((im>>12)&0xFF)<<12)|(rd<<7)|op

def split_mem(arg):
    m=re.fullmatch(r'\s*(-?\w+)\s*\(\s*(x\d+|zero|ra|sp)\s*\)\s*', arg)
    if not m: raise ValueError(f"bad mem operand '{arg}'")
    return imm(m.group(1)), reg(m.group(2))

def assemble(lines):
    labels,pc,prog={},0,[]
    for ln in lines:
        ln=ln.split('#')[0].strip()
        if not ln: continue
        if ln.endswith(':'):
            labels[ln[:-1].strip()]=pc; continue
        prog.append((pc,ln)); pc+=4
    out=[]
    for pc,ln in prog:
        p=ln.replace(',',' ').split(); op=p[0]; a=p[1:]
        def L(x): return labels[x]-pc if x in labels else imm(x)
        if   op=='addi':  w=i_type(0,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='slti':  w=i_type(2,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='sltiu': w=i_type(3,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='xori':  w=i_type(4,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='ori':   w=i_type(6,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='andi':  w=i_type(7,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='slli':  w=i_shift(0,1,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='srli':  w=i_shift(0,5,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='srai':  w=i_shift(0x10,5,OPIMM,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='add':   w=r_type(0,0,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='sub':   w=r_type(0x20,0,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='sll':   w=r_type(0,1,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='slt':   w=r_type(0,2,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='sltu':  w=r_type(0,3,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='xor':   w=r_type(0,4,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='srl':   w=r_type(0,5,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='sra':   w=r_type(0x20,5,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='or':    w=r_type(0,6,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='and':   w=r_type(0,7,OP,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='addiw': w=i_type(0,OPI32,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='slliw': w=i_shiftw(0,1,OPI32,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='srliw': w=i_shiftw(0,5,OPI32,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='sraiw': w=i_shiftw(0x20,5,OPI32,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='addw':  w=r_type(0,0,OP32,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='subw':  w=r_type(0x20,0,OP32,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='sllw':  w=r_type(0,1,OP32,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='srlw':  w=r_type(0,5,OP32,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op=='sraw':  w=r_type(0x20,5,OP32,reg(a[0]),reg(a[1]),reg(a[2]))
        elif op in ('lb','lh','lw','ld','lbu','lhu','lwu'):
            f3={'lb':0,'lh':1,'lw':2,'ld':3,'lbu':4,'lhu':5,'lwu':6}[op]
            off,base=split_mem(a[1]); w=i_type(f3,LOAD,reg(a[0]),base,off)
        elif op in ('sb','sh','sw','sd'):
            f3={'sb':0,'sh':1,'sw':2,'sd':3}[op]
            off,base=split_mem(a[1]); w=s_type(f3,STORE,reg(a[0]),base,off)
        elif op in ('beq','bne','blt','bge','bltu','bgeu'):
            f3={'beq':0,'bne':1,'blt':4,'bge':5,'bltu':6,'bgeu':7}[op]
            w=b_type(f3,BRANCH,reg(a[0]),reg(a[1]),L(a[2]))
        elif op=='jal':   w=j_type(JAL,reg(a[0]),L(a[1]))
        elif op=='jalr':  w=i_type(0,JALR,reg(a[0]),reg(a[1]),imm(a[2]))
        elif op=='lui':   w=u_type(LUI,reg(a[0]),imm(a[1]))
        elif op=='auipc': w=u_type(AUIPC,reg(a[0]),imm(a[1]))
        elif op=='ebreak':w=0x00100073
        elif op in ('csrrw','csrrs','csrrc'):
            f3={'csrrw':1,'csrrs':2,'csrrc':3}[op]
            w=i_type(f3,SYSTEM,reg(a[0]),reg(a[2]),csr(a[1]))
        elif op in ('csrrwi','csrrsi','csrrci'):
            f3={'csrrwi':5,'csrrsi':6,'csrrci':7}[op]
            w=i_type(f3,SYSTEM,reg(a[0]),imm(a[2])&0x1F,csr(a[1]))
        elif op=='csrw':   w=i_type(1,SYSTEM,0,reg(a[1]),csr(a[0]))      # csrw csr,rs = csrrw x0
        elif op=='csrr':   w=i_type(2,SYSTEM,reg(a[0]),0,csr(a[1]))      # csrr rd,csr = csrrs rd,csr,x0
        elif op=='csrs':   w=i_type(2,SYSTEM,0,reg(a[1]),csr(a[0]))      # csrs csr,rs
        elif op=='csrc':   w=i_type(3,SYSTEM,0,reg(a[1]),csr(a[0]))
        elif op=='csrwi':  w=i_type(5,SYSTEM,0,imm(a[1])&0x1F,csr(a[0]))
        elif op=='csrsi':  w=i_type(6,SYSTEM,0,imm(a[1])&0x1F,csr(a[0]))
        elif op=='mret':   w=0x30200073
        elif op=='wfi':    w=0x10500073
        elif op=='ecall': w=0x00000073
        elif op=='nop':   w=i_type(0,OPIMM,0,0,0)
        else: raise ValueError(f"unknown instruction '{op}'")
        out.append((w&0xFFFFFFFF, ln))
    return out

PROGRAM = [
    "addi x1, x0, 10",
    "addi x2, x0, 3",
    "add  x3, x1, x2",
    "addi x5, x0, 0",
    "sd   x3, 0(x5)",
    "ld   x4, 0(x5)",
    "addi x6, x0, 0",
    "addi x7, x0, 1",
    "addi x8, x0, 6",
    "loop:",
    "add  x6, x6, x7",
    "addi x7, x7, 1",
    "blt  x7, x8, loop",
    "jal  x9, skip",
    "addi x10, x0, 99",
    "skip:",
    "addi x11, x0, 7",
    "lui  x12, 1",
    "addi x16, x0, 1",
    "slli x16, x16, 32",
    "addiw x17, x16, 5",
    "addw  x18, x16, x16",
    "ebreak",
]

if __name__ == "__main__":
    for w, asm in assemble(PROGRAM):
        print(f"{w:08x}  // {asm}")
