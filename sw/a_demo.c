#define STATUS (*(volatile unsigned char *)0x10000008u)
#define TXDATA (*(volatile unsigned char *)0x10000000u)
static void uputc(char c){ while(!(STATUS&1u)){} TXDATA=(unsigned char)c; }
static void uputd(unsigned long n){char b[24];int i=0; if(!n){uputc('0');uputc(' ');return;}
    while(n){b[i++]='0'+(char)(n%10u);n/=10u;} while(i)uputc(b[--i]); uputc(' ');}
#define AMO(op,p,v) ({ long _o; asm volatile(op " %0,%2,(%1)":"=r"(_o):"r"(p),"r"(v):"memory"); _o; })
static long x;
int main(void){
    x=100;
    uputd(AMO("amoadd.d",&x,5L));     /* 100 */
    uputd(AMO("amoswap.d",&x,42L));   /* 105 */
    uputd(AMO("amoor.d",&x,0x0FL));   /* 42  */
    uputd(AMO("amoand.d",&x,0x3CL));  /* 47  */
    uputd(AMO("amoxor.d",&x,0xFFL));  /* 44  */
    uputd(AMO("amomaxu.d",&x,50L));   /* 211 */
    uputd(AMO("amominu.d",&x,50L));   /* 211 */
    long t,r; do{ asm volatile("lr.d %0,(%1)":"=r"(t):"r"(&x):"memory"); t++;
                  asm volatile("sc.d %0,%2,(%1)":"=r"(r):"r"(&x),"r"(t):"memory"); }while(r);
    uputd((unsigned long)x);          /* 51 after lr/sc increment of 50 */
    uputd((unsigned long)AMO("amoadd.w",&x,1000L)); /* 51, word variant */
    uputc('#');
    for(;;){}
}
