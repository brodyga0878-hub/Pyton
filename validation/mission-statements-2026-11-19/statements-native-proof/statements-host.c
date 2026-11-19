
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define CAP (256u*1024u*1024u)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"statement-native:%d\n",__LINE__);exit(97);}}while(0)
#define GUARD UINT64_C(0xa56d697373696f6e)
#define GUARDED(name,N) struct __attribute__((packed)){uint64_t a;uint8_t data[N];uint64_t b;}name __attribute__((aligned(16)))
GUARDED(g_root,22544);GUARDED(g_bank,38986);GUARDED(g_task,36);GUARDED(g_program,65536);GUARDED(g_vectors,324);GUARDED(g_text,65536);
asm(".global s_root,s_bank,s_task,s_program,s_vectors,s_text\ns_root=g_root+8\ns_bank=g_bank+8\ns_task=g_task+8\ns_program=g_program+8\ns_vectors=g_vectors+8\ns_text=g_text+8");
#define s_root g_root.data
#define s_bank g_bank.data
#define s_task g_task.data
#define s_program g_program.data
#define s_vectors g_vectors.data
#define s_text g_text.data
uint32_t s_ip,s_text_pointer,s_args[11],s_frame,s_steps,s_trace_count,s_trace[16384],s_opcodes[256];uint8_t s_seed[156],s_defined[156];
static uint8_t input[16*1024*1024],output[CAP],visible[156],*cursor,*end;static uint32_t base,length,text_length,slot,script_count,used,status,outpos;static jmp_buf env;
extern void call_kernel(void);
static uint32_t get(const void*p){uint32_t v;memcpy(&v,p,4);return v;}static void put(void*p,uint32_t v){memcpy(p,&v,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static uint32_t read32(void){CHECK(cursor+4<=end);uint32_t v=get(cursor);cursor+=4;return v;}
static void bytes(void*p,uint32_t n){CHECK(cursor+n<=end);memcpy(p,cursor,n);cursor+=n;}
static void emit32(uint32_t v){CHECK(outpos+4<CAP);put(output+outpos,v);outpos+=4;}
static void emit(const void*p,uint32_t n){CHECK(outpos+n<CAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t body_host(uint32_t value){if(!value)return 0;CHECK(value>=116&&(value-116)%338==0&&(value-116)/338<=114);return ptr(s_bank)+value;}
static uint32_t body_raw(uint32_t value){if(!value)return 0;CHECK(value>=ptr(s_bank)+116&&value<=ptr(s_bank)+116+114*338&&(value-ptr(s_bank)-116)%338==0);return value-ptr(s_bank);}
static uint32_t source_ref(uint32_t value){return value>=ptr(s_program)&&value<ptr(s_program)+length?base+value-ptr(s_program):value;}
static uint32_t host_ref(uint32_t value){return value>=base&&value<base+length?ptr(s_program)+value-base:value;}
static void import_task(void){for(uint32_t at=8;at<=28;at+=at==16?12:8)put(s_task+at,host_ref(get(s_task+at)));}
static void raw_task(uint8_t*data){memcpy(data,s_task,36);for(uint32_t at=8;at<=28;at+=at==16?12:8)put(data+at,source_ref(get(data+at)));}
static void import_root(void){put(s_root+0xc8,body_host(get(s_root+0xc8)));put(s_root+0xcc,body_host(get(s_root+0xcc)));uint32_t bank=get(s_root+0x580c);CHECK(bank<=1);put(s_root+0x580c,bank?ptr(s_bank):0);}
static void capture(void){
 CHECK(s_ip>=ptr(s_program)&&s_ip<=ptr(s_program)+length);CHECK(s_text_pointer>=ptr(s_text)&&s_text_pointer<=ptr(s_text)+text_length);
 emit32(s_ip-ptr(s_program));emit32(s_text_pointer-ptr(s_text));uint8_t root[22544],task[36];memcpy(root,s_root,22544);put(root+0xc8,body_raw(get(root+0xc8)));put(root+0xcc,body_raw(get(root+0xcc)));uint32_t bank=get(root+0x580c);CHECK(bank==0||bank==ptr(s_bank));put(root+0x580c,bank!=0);emit(root,22544);emit(s_bank,38986);raw_task(task);emit(task,36);emit(s_text,text_length);
}
static void scratch(void){memcpy(visible,s_seed,156);if(s_frame){memcpy(visible,(void*)(uintptr_t)s_frame,68);memcpy(visible+152,(void*)(uintptr_t)(s_frame+152),4);}emit(visible,156);emit(s_defined,156);}
void s_budget_abort(void){status=2;longjmp(env,1);}
void s_strlen_admit(uint32_t pointer){CHECK(pointer>=ptr(s_program)&&pointer<ptr(s_program)+length);CHECK(memchr((void*)(uintptr_t)pointer,0,length-(pointer-ptr(s_program)))!=0);}
static uint32_t output_size(uint32_t kind,uint32_t argc,uint32_t*a,uint8_t**local){
 *local=0;
 if(kind==331){if(a[2]){*local=(uint8_t*)(uintptr_t)a[2];return 48;}return 0;}
 if(kind==345||kind==346||kind==347||kind==349||kind==352||kind==360){*local=(uint8_t*)(uintptr_t)a[0];return 48;}
 if(kind==1344){*local=(uint8_t*)(uintptr_t)a[2];return 20;}
 if(kind==304||kind==305){*local=(uint8_t*)(uintptr_t)a[1];return 4;}
 return 0;
}
uint32_t s_observe(uint32_t kind){
 uint32_t argc=0;switch(kind){
 case 31:argc=1;break;case 37:argc=2;break;case 52:argc=3;break;
 case 342:case 326:case 359:argc=0;break;
 case 331:argc=6;break;case 314:argc=11;break;case 40:argc=9;break;
 case 101:case 98:case 664:case 297:case 290:argc=5;break;
 case 953:case 48:case 236:case 100:case 304:case 305:case 1344:argc=3;break;
 case 99:case 104:case 332:case 665:case 666:case 668:case 942:case 926:case 702:case 291:argc=2;break;
 default:argc=1;break;}
 uint32_t raw[11],a[11]={0};memcpy(raw,s_args,44);memcpy(a,raw,44);uint8_t*local=0;uint32_t local_size=output_size(kind,argc,raw,&local),input_size=local_size;uint8_t known[65536];uint8_t*input_bytes=local;
 if(local_size){CHECK((uintptr_t)local>=s_frame&&(uintptr_t)local+local_size<=s_frame+156);memcpy(known,s_defined+(uintptr_t)local-s_frame,local_size);}
 if(kind==31||kind==37||kind==52){CHECK(raw[0]==ptr(&s_ip)&&raw[1]==ptr(s_task));a[0]=slot;if(kind==37)a[1]=raw[2];if(kind==52){a[1]=raw[2];a[2]=raw[3];}}
 if(kind==331)a[2]=raw[2]?0:0xffffffffu;
 if(kind==345||kind==346||kind==347||kind==349||kind==352||kind==360)a[0]=0;
 if(kind==304||kind==305){a[0]&=255;a[1]=0;}
 if(kind==664)a[2]&=255;
 if(kind==236)a[2]=body_raw(a[2]);
 if(kind==953||kind==942||kind==702||kind==291)a[0]=body_raw(a[0]);
 if(kind==926)a[1]=body_raw(a[1]);
 if(kind==101){CHECK(raw[0]>=ptr(s_program)&&raw[0]<ptr(s_program)+length);a[0]=base+raw[0]-ptr(s_program);input_bytes=(uint8_t*)(uintptr_t)raw[0];uint8_t*last=memchr(input_bytes,0,length-(raw[0]-ptr(s_program)));CHECK(last!=0);input_size=(uint32_t)(last-input_bytes)+1;memset(known,1,input_size);}
 if(kind==314){static uint8_t empty[2]={0};a[9]=0x49aa16;input_bytes=empty;input_size=2;memset(known,1,2);}
 uint32_t destination=0;
 if(kind==1344){destination=raw[0];if(destination>=ptr(s_text)&&destination<=ptr(s_text)+text_length){a[0]=0;a[1]=destination-ptr(s_text);}else{CHECK(destination>=ptr(s_bank)&&destination<ptr(s_bank)+38986);a[0]=1;a[1]=destination-ptr(s_bank);}a[2]=raw[1];}
 for(uint32_t i=argc;i<11;i++)a[i]=0;
 uint32_t row=outpos;emit32(kind);emit32(argc);emit(a,44);emit32(0);emit32(input_size);emit32(0);capture();emit(input_bytes,input_size);emit(known,input_size);
 if(used>=script_count){capture();used++;status=1;longjmp(env,1);}
 uint32_t wanted=read32(),count=read32(),values[11];bytes(values,44);uint32_t result=read32(),patches=read32(),outsize=read32();CHECK(wanted==kind&&count==argc&&!memcmp(values,a,argc*4)&&patches<=64&&outsize<=local_size&&(outsize==0||outsize==local_size));
 for(uint32_t i=0;i<patches;i++){uint32_t owner=read32(),at=read32(),size=read32();uint8_t data[64];bytes(data,64);CHECK(size<=64);uint8_t*dst=0;uint32_t extent=0;if(owner==0){dst=s_root;extent=16384;}else if(owner==1){dst=s_root+16384;extent=6160;}else if(owner==2){dst=s_bank;extent=38986;}else if(owner==3){dst=s_task;extent=36;}else if(owner==4){dst=s_text;extent=text_length;}else{CHECK(owner==5||owner==6);extent=4;dst=owner==5?(uint8_t*)&s_ip:(uint8_t*)&s_text_pointer;}CHECK(at+size<=extent);
  if(owner==0||owner==1){uint8_t normalized[22544];memcpy(normalized,s_root,22544);put(normalized+0xc8,body_raw(get(normalized+0xc8)));put(normalized+0xcc,body_raw(get(normalized+0xcc)));uint32_t bank=get(normalized+0x580c);CHECK(bank==0||bank==ptr(s_bank));put(normalized+0x580c,bank!=0);memcpy(normalized+(owner==1?16384:0)+at,data,size);memcpy(s_root,normalized,22544);import_root();}
  else if(owner==3){uint8_t task[36];raw_task(task);memcpy(task+at,data,size);memcpy(s_task,task,36);import_task();}
  else if(owner==5||owner==6){uint32_t logical=owner==5?s_ip-ptr(s_program):s_text_pointer-ptr(s_text);memcpy((uint8_t*)&logical+at,data,size);CHECK(logical<=(owner==5?length:text_length));if(owner==5){CHECK(kind==31||kind==37||kind==52);s_ip=ptr(s_program)+logical;}else s_text_pointer=ptr(s_text)+logical;}
  else memcpy(dst+at,data,size);
 }
 if(outsize){bytes(local,outsize);bytes(s_defined+(uintptr_t)local-s_frame,outsize);for(uint32_t i=0;i<outsize;i++)CHECK(s_defined[(uintptr_t)local-s_frame+i]<=1);}
 uint32_t returned=0;switch(kind){case 31:case 52:case 101:case 314:case 1344:case 772:case 664:case 665:case 666:case 668:case 297:case 40:case 926:case 291:returned=result;break;default:CHECK(result==0);break;}
 put(output+row+52,returned);put(output+row+60,outsize);capture();if(outsize){emit(local,outsize);emit(s_defined+(uintptr_t)local-s_frame,outsize);}used++;
 if(kind==1344){CHECK(result<=(a[0]==0?text_length+1:38986));return(a[0]==0?ptr(s_text):ptr(s_bank))+result;}
 if(kind==772||kind==664||kind==665||kind==666||kind==668||kind==297||kind==40||kind==926||kind==291)return body_host(result);
 return result;
}
int main(void){uint32_t size;while(fread(&size,4,1,stdin)==1){CHECK(size<=sizeof input&&fread(input,1,size,stdin)==size);cursor=input;end=input+size;base=read32();length=read32();text_length=read32();uint32_t ip=read32(),textcursor=read32();slot=read32();script_count=read32();CHECK(length>0&&length<=65536&&text_length>0&&text_length<=65536&&ip<=length&&textcursor<=text_length&&slot<150&&script_count<=256);bytes(s_root,22544);bytes(s_bank,38986);bytes(s_task,36);bytes(s_program,length);bytes(s_vectors,324);bytes(s_text,text_length);bytes(s_seed,156);bytes(s_defined,156);for(uint32_t i=0;i<156;i++)CHECK(s_defined[i]<=1);import_root();import_task();s_ip=ptr(s_program)+ip;s_text_pointer=ptr(s_text)+textcursor;
 g_root.a=g_root.b=g_bank.a=g_bank.b=g_task.a=g_task.b=g_program.a=g_program.b=g_vectors.a=g_vectors.b=g_text.a=g_text.b=GUARD;uint8_t oldprogram[65536],oldvectors[324];memcpy(oldprogram,s_program,length);memcpy(oldvectors,s_vectors,324);s_trace_count=s_steps=s_frame=used=status=0;memset(s_opcodes,0,sizeof s_opcodes);outpos=40;if(!setjmp(env)){call_kernel();CHECK(used==script_count&&cursor==end);}CHECK(g_root.a==GUARD&&g_root.b==GUARD&&g_bank.a==GUARD&&g_bank.b==GUARD&&g_task.a==GUARD&&g_task.b==GUARD&&g_program.a==GUARD&&g_program.b==GUARD&&g_vectors.a==GUARD&&g_vectors.b==GUARD&&g_text.a==GUARD&&g_text.b==GUARD&&!memcmp(oldprogram,s_program,length)&&!memcmp(oldvectors,s_vectors,324));uint32_t final=outpos;capture();scratch();uint32_t traceat=outpos;emit(s_trace,s_trace_count*4);emit(s_opcodes,sizeof s_opcodes);put(output,0x41ab3257);put(output+4,outpos);put(output+8,status);put(output+12,0);put(output+16,used);put(output+20,final);put(output+24,traceat);put(output+28,s_trace_count);put(output+32,s_steps);put(output+36,0);CHECK(fwrite(output,1,outpos,stdout)==outpos);
 }return 0;}
