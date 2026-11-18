
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define OWNER 66446
#define BASE (64+OWNER+2048)
#define TRACE (48+2*OWNER+2048)
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,reserved;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[7],result,patch_count,text_size,pad[4];uint8_t text[1024];struct Patch patches[12];uint8_t unused[2048];};
struct __attribute__((packed)) Input{uint32_t header[16];uint8_t owners[OWNER],text[1024];struct Script scripts[16];};
uint8_t m_store[OWNER+16],m_text[1024];uint32_t m_order[512],m_order_count,m_actor_mode;
extern void call_kernel(uint32_t,uint32_t,uint32_t);
static struct Input input,saved_input;static uint8_t output[BASE+16*TRACE];static uint32_t used,status,actor_bound;
static const uint32_t sizes[6]={16384,38986,48,10380,36,612},offsets[6]={0,16384,55370,55418,65798,65834};
#define ROOT (m_store+8)
#define BANK (m_store+8+16384)
#define PACKET (m_store+8+55370)
#define FALLBACK (m_store+8+65834)
static uint32_t get(const void*p){uint32_t v;memcpy(&v,p,4);return v;}static void put(void*p,uint32_t v){memcpy(p,&v,4);}
static void bind(void){uint32_t v=get(PACKET+28);actor_bound=v>=116&&v+338<=38986&&(v-116)%338==0;if(actor_bound)put(PACKET+28,(uint32_t)(uintptr_t)(BANK+v));}
static void capture(uint8_t*out){memcpy(out,m_store+8,OWNER);if(actor_bound)put(out+55370+28,get(PACKET+28)-(uint32_t)(uintptr_t)BANK);}
static uint32_t cstring(uint8_t*to,const uint8_t*from){for(uint32_t i=0;i<1024;i++){to[i]=from[i];if(!from[i])return i+1;}exit(94);}
uint32_t m_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){
 uint32_t args[7]={0},argc=0,in_size=0;uint8_t input_text[1024]={0};uint32_t dest=0;
 if(m_order_count>=512)exit(95);m_order[m_order_count++]=kind;
 if(kind==217)argc=0;
 else if(kind==1906){argc=1;args[0]=a;}
 else if(kind==1344){argc=7;dest=a;args[0]=b;memcpy(args+1,(void*)(uintptr_t)c,20);if(m_actor_mode==0){uintptr_t ptr=args[5];if(ptr==(uintptr_t)FALLBACK){args[5]=0;args[6]=2;}else if(ptr>=(uintptr_t)BANK+116+0x124&&ptr<(uintptr_t)BANK+38986&&(ptr-(uintptr_t)BANK-116-0x124)%338==0){args[5]=ptr-(uintptr_t)BANK;args[6]=1;}else exit(96);}}
 else if(kind==1398){argc=1;args[0]=b;dest=a;in_size=cstring(input_text,(void*)(uintptr_t)a);}
 else exit(97);
 if(used>=16)exit(98);uint8_t*row=output+BASE+used*TRACE;put(row,kind);put(row+4,argc);memcpy(row+8,args,28);put(row+40,in_size);memcpy(row+48+2*OWNER,input_text,in_size);capture(row+48);
 uint32_t result=0,out_size=0;
 if(used>=input.header[2]){status=1;if(kind==1344||kind==1398){((uint8_t*)(uintptr_t)dest)[0]=0;out_size=1;}}
 else{struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,28))exit(99);uint8_t logical[OWNER];capture(logical);for(uint32_t i=0;i<s->patch_count;i++){struct Patch*p=&s->patches[i];if(p->owner>=6||p->size>64||p->offset+p->size>sizes[p->owner])exit(100);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}memcpy(m_store+8,logical,OWNER);bind();result=s->result;if(kind==1344||kind==1398){if(!s->text_size||s->text_size>1024||s->text[s->text_size-1]||memchr(s->text,0,s->text_size-1))exit(101);memcpy((void*)(uintptr_t)dest,s->text,s->text_size);out_size=s->text_size;}else if(s->text_size)exit(102);}
 put(row+36,result);put(row+44,out_size);capture(row+48+OWNER);if(out_size)memcpy(row+48+2*OWNER+1024,(void*)(uintptr_t)dest,out_size);used++;return result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){memcpy(&saved_input,&input,sizeof input);memset(m_store,0xa5,sizeof m_store);memcpy(m_store+8,input.owners,OWNER);memcpy(m_text,input.text,1024);bind();used=status=m_order_count=0;memset(output,0,sizeof output);call_kernel(input.header[0],input.header[1],input.header[3]);if(memcmp(&input,&saved_input,sizeof input))status=2;uint8_t guard[8];memset(guard,0xa5,8);if(memcmp(m_store,guard,8)||memcmp(m_store+8+OWNER,guard,8))status=3;put(output,0x349271aa);put(output+4,BASE+used*TRACE);put(output+8,status);put(output+12,used);put(output+16,m_order_count);capture(output+64);memcpy(output+64+OWNER,m_order,m_order_count*4);if(fwrite(output,1,BASE+used*TRACE,stdout)!=BASE+used*TRACE)return 103;}return 0;}
