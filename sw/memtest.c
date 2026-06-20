/* AH-RISCV memory-upgrade demo. (c) 2026 Ali Hussein, GPL-3.0.
 * Uses every feature the old Harvard core could not: string literals (.rodata),
 * an initialised global array (.data), a zero-init global (.bss), recursion
 * (stack), and a heap allocator. */
#define TXDATA (*(volatile unsigned char *)0x10000000u)
#define STATUS (*(volatile unsigned char *)0x10000008u)
static void uputc(char c){ while(!(STATUS & 1u)){} TXDATA=(unsigned char)c; }
static void uputs(const char *s){ while(*s) uputc(*s++); }
static void uputd(unsigned long n){            /* decimal, no hw divide needed below 10^10 */
    char b[24]; int i=0;
    if(!n){ uputc('0'); return; }
    while(n){ b[i++]='0'+(char)(n%10u); n/=10u; }
    while(i) uputc(b[--i]);
}

const char *msg = "strings work now!";     /* .rodata string + .data pointer */
int  table[5]   = {10,20,30,40,50};         /* .data initialised array        */
int  sum;                                   /* .bss zero-initialised global    */

static unsigned long fib(unsigned long n){ return n<2 ? n : fib(n-1)+fib(n-2); }

extern char _end;                           /* start of free heap (from linker)*/
static char *hp = &_end;
static void *halloc(unsigned long sz){ void *p = hp; hp += (sz+7)&~7u; return p; }

int main(void){
    uputs(msg); uputs("\r\n");
    sum = 0; for(int i=0;i<5;i++) sum += table[i];
    uputs("sum="); uputd((unsigned)sum); uputs("\r\n");
    uputs("fib(10)="); uputd(fib(10)); uputs("\r\n");
    int *a = (int*)halloc(3*sizeof(int)); a[0]=7; a[1]=8; a[2]=9;
    uputs("heap="); uputd((unsigned)(a[0]+a[1]+a[2])); uputs("\r\n");
    for(;;){}
    return 0;
}
