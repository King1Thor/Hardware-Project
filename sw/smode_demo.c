/* S-mode bring-up: M-mode drops to S via mret; S-mode ecall is delegated to the
   S-mode handler; sret returns. Output proves the whole privilege cycle. */
__attribute__((naked,aligned(4))) void s_trap(void){
  asm volatile(
    "addi sp,sp,-16\n sd t0,0(sp)\n sd t1,8(sp)\n"
    "li t0,0x10000000\n"
    "1: lbu t1,8(t0)\n andi t1,t1,1\n beqz t1,1b\n li t1,84\n sb t1,0(t0)\n"  /* 'T' */
    "csrr t0,sepc\n addi t0,t0,4\n csrw sepc,t0\n"                            /* skip ecall */
    "ld t0,0(sp)\n ld t1,8(sp)\n addi sp,sp,16\n sret\n");
}
__attribute__((naked,aligned(4))) void smode_entry(void){
  asm volatile(
    "li t0,0x10000000\n"
    "1: lbu t1,8(t0)\n andi t1,t1,1\n beqz t1,1b\n li t1,83\n sb t1,0(t0)\n"  /* 'S' */
    "ecall\n"                                                                /* delegated -> s_trap */
    "2: lbu t1,8(t0)\n andi t1,t1,1\n beqz t1,2b\n li t1,66\n sb t1,0(t0)\n"  /* 'B' back */
    "3: lbu t1,8(t0)\n andi t1,t1,1\n beqz t1,3b\n li t1,35\n sb t1,0(t0)\n"  /* '#' done */
    "4: j 4b\n");
}
static void uputc(char c){ volatile unsigned char*s=(void*)0x10000008,*d=(void*)0x10000000;
    while(!(*s&1)){} *d=(unsigned char)c; }
int main(void){
    uputc('M');
    asm volatile(
        "li t0, (1<<9)\n csrw medeleg, t0\n"          /* delegate ecall-from-S */
        "la t0, s_trap\n csrw stvec, t0\n"
        "la t0, smode_entry\n csrw mepc, t0\n"
        "csrr t0, mstatus\n li t1, ~(3<<11)\n and t0,t0,t1\n"
        "li t1, (1<<11)\n or t0,t0,t1\n csrw mstatus, t0\n"   /* MPP = S(01) */
        "mret\n" ::: "t0","t1");
    for(;;){}
}
