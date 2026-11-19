
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define ROOT 16384
#define TAIL 6160
#define BANK 38986
#define OWNER (ROOT+TAIL+BANK)
#define MAX 8
#define TRACE 64
#define BASE (64+OWNER+TRACE*4)
#define RECORD (64+OWNER*2+4)
#define GUARD UINT64_C(0xa5a5a5a5a5a5a5a5)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"spawn-native-check:%d\n",__LINE__);exit(97);}}while(0)
struct __attribute__((packed)){uint64_t a;uint8_t data[ROOT+TAIL];uint64_t b;}p_root_store;
struct __attribute__((packed)){uint64_t a;uint8_t data[BANK];uint64_t b;}p_bank_store;
#define p_root p_root_store.data
#define p_bank p_bank_store.data
uint32_t p_trace[TRACE],p_trace_count;
#pragma pack(push,1)
struct Patch{uint32_t owner,offset,size,unused;uint8_t data[64];};
struct Script{uint32_t h[16];struct Patch patch[12];uint8_t output[4];};
struct Input{uint32_t h[16];uint8_t owner[OWNER];struct Script scripts[MAX];};
#pragma pack(pop)
static struct Input input;static uint8_t output[BASE+MAX*RECORD],logical[OWNER];
static uint32_t used,status;static jmp_buf jump;
extern uint32_t call_kernel(uint32_t,uint32_t*);
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}
static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static int body_ref(uint32_t n){return n==0||(n>=116&&(n-116)%338==0&&(n-116)/338<=114);}
static uint32_t to_host(uint32_t n){CHECK(body_ref(n));return n?ptr(p_bank)+n:0;}
static uint32_t to_ref(uint32_t n){CHECK(n==0||(n>=ptr(p_bank)+116&&n<=ptr(p_bank)+116+114*338&&(n-ptr(p_bank)-116)%338==0));return n?n-ptr(p_bank):0;}
static void capture(uint8_t*p){memcpy(p,p_root,ROOT+TAIL);put(p+0xc8,to_ref(get(p_root+0xc8)));put(p+0xcc,to_ref(get(p_root+0xcc)));CHECK(get(p_root+0x580c)==ptr(p_bank));put(p+0x580c,1);memcpy(p+ROOT+TAIL,p_bank,BANK);}
static void load(const uint8_t*p){memcpy(p_root,p,ROOT+TAIL);put(p_root+0xc8,to_host(get(p+0xc8)));put(p_root+0xcc,to_host(get(p+0xcc)));CHECK(get(p+0x580c)==1);put(p_root+0x580c,ptr(p_bank));memcpy(p_bank,p+ROOT+TAIL,BANK);}
static void canaries(void){CHECK(p_root_store.a==GUARD&&p_root_store.b==GUARD&&p_bank_store.a==GUARD&&p_bank_store.b==GUARD);}
uint32_t p_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c,uint32_t d,uintptr_t outlocal){
 uint32_t args[6]={0};
 if(kind==927){CHECK(a==ptr(p_bank));args[0]=1;args[1]=to_ref(b);args[2]=c;args[3]=d;}
 else{CHECK(kind==1507);args[0]=to_ref(a);args[1]=b;args[2]=c;args[3]=d;}
 CHECK(used<MAX);uint8_t*row=output+BASE+used*RECORD;put(row,kind);put(row+4,4);memcpy(row+8,args,24);capture(row+64);
 if(used>=input.h[10]){status=1;capture(row+64+OWNER);used++;longjmp(jump,1);return 0;}
 struct Script*s=&input.scripts[used];CHECK(s->h[0]==kind&&s->h[1]==4&&!memcmp(s->h+2,args,24));uint32_t returned=s->h[8],patches=s->h[9],outlen=s->h[10];CHECK(patches<=12);
 capture(logical);
 uint32_t sizes[3]={ROOT,TAIL,BANK},offsets[3]={0,ROOT,ROOT+TAIL};
 for(uint32_t i=0;i<patches;i++){struct Patch*p=&s->patch[i];CHECK(p->owner<3&&p->size<=64&&p->offset<=sizes[p->owner]&&p->size<=sizes[p->owner]-p->offset);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}
 load(logical);
 if(kind==927){CHECK(body_ref(returned)&&(outlen==0||outlen==4));if(outlen){CHECK(outlocal!=0);memcpy((void*)outlocal,s->output,4);memcpy(row+64+OWNER*2,(void*)outlocal,4);}}
 else CHECK(returned==0&&outlen==0);
 put(row+32,returned);put(row+36,outlen);capture(row+64+OWNER);used++;return kind==927?to_host(returned):0;
}
int main(void){
 while(fread(&input,1,sizeof input,stdin)==sizeof input){
  CHECK(input.h[0]<2&&input.h[10]<=MAX);if(input.h[0]==1)CHECK(input.h[2]<=114);
  p_root_store.a=p_root_store.b=p_bank_store.a=p_bank_store.b=GUARD;load(input.owner);memset(output,0,sizeof output);used=status=p_trace_count=0;volatile uint32_t returned=0;
  if(!setjmp(jump))returned=call_kernel(input.h[0],input.h+1);
  if(!status)CHECK(used==input.h[10]);canaries();put(output,0x40fa1739);put(output+4,BASE+used*RECORD);put(output+8,status);put(output+12,status?0:input.h[0]==0?returned:to_ref(returned));put(output+16,used);put(output+20,p_trace_count);put(output+24,input.h[0]==0);put(output+28,input.h[0]==1);capture(output+64);memcpy(output+64+OWNER,p_trace,p_trace_count*4);
  CHECK(fwrite(output,1,BASE+used*RECORD,stdout)==BASE+used*RECORD);
 }
 return 0;
}
