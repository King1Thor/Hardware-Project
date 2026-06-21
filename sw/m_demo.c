#define STATUS (*(volatile unsigned char *)0x10000008u)
#define TXDATA (*(volatile unsigned char *)0x10000000u)
static void uputc(char c){ while(!(STATUS&1u)){} TXDATA=(unsigned char)c; }
static void uputs(const char*s){ while(*s) uputc(*s++); }
static void uputd(unsigned long n){ char b[24];int i=0; if(!n){uputc('0');return;}
    while(n){b[i++]='0'+(char)(n%10u);n/=10u;} while(i)uputc(b[--i]); }
static void uputsd(long n){ if(n<0){uputc('-');n=-n;} uputd((unsigned long)n); }
int main(void){
    unsigned long a=123456u, b=789u;
    uputs("mul=");  uputd(a*b);        uputs("\r\n");   /* 97406784 */
    uputs("div=");  uputd(a/b);        uputs("\r\n");   /* 156 */
    uputs("rem=");  uputd(a%b);        uputs("\r\n");   /* 372 */
    long x=-1000, y=7;
    uputs("sdiv="); uputsd(x/y);       uputs("\r\n");   /* -142 */
    uputs("srem="); uputsd(x%y);       uputs("\r\n");   /* -6 */
    uputs("sq=");   uputd(40000u*40000u); uputs("\r\n");/* 1600000000 */
    for(;;){}
}
