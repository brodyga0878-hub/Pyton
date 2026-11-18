
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define GUARD UINT64_C(0x6d697373696f6e67)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"guards-native:%d\n",__LINE__);exit(97);}}while(0)
#define PROGRAM 65536
#define CAP (32*1024*1024)
struct __attribute__((packed)) GuardedEvents{uint64_t a;uint8_t data[284];uint64_t b;}g_events;
struct __attribute__((packed)) GuardedTask{uint64_t a;uint8_t data[36];uint64_t b;}g_task;
struct __attribute__((packed)) GuardedMetadata{uint64_t a;uint8_t data[1088];uint64_t b;}g_metadata;
static struct{uint64_t a;uint8_t data[PROGRAM];uint64_t b;}program;
uint32_t g_operation,g_registration,g_clause,g_index,g_value,g_entry_ip,g_current_ip,g_args[6],g_trace[8192],g_trace_count,g_source_base,g_program_pointer,g_key_a_kind;
static uint32_t task_block_relocated;
static uint32_t base,length,slot,script_count,used,status,outpos;static uint8_t input[CAP],output[CAP],*cursor,*end;
static jmp_buf env;extern uint32_t call_kernel(void);
static uint32_t get(const void*p){uint32_t x;memcpy(&x,p,4);return x;}static void put(void*p,uint32_t x){memcpy(p,&x,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return (uint32_t)(uintptr_t)p;}
static uint32_t read32(void){CHECK(cursor+4<=end);uint32_t v=get(cursor);cursor+=4;return v;}
static void bytes(void*p,uint32_t n){CHECK(cursor+n<=end);memcpy(p,cursor,n);cursor+=n;}
static void emit32(uint32_t v){CHECK(outpos+4<CAP);put(output+outpos,v);outpos+=4;}
static void emit(const void*p,uint32_t n){CHECK(outpos+n<CAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t source_ref(uint32_t value){return value>=ptr(program.data)&&value<ptr(program.data)+length?base+value-ptr(program.data):value;}
static uint32_t host_ref(uint32_t value){return value>=base&&value<base+length?ptr(program.data)+value-base:value;}
static void import_task(void){uint32_t value=get(g_task.data+8);task_block_relocated=value>=base&&value<base+length;put(g_task.data+8,host_ref(value));}
static void raw_task(uint8_t*task){memcpy(task,g_task.data,36);if(task_block_relocated)put(task+8,source_ref(get(task+8)));}
static void emit_context(void){
 uint32_t current=get((void*)(uintptr_t)g_current_ip);CHECK(current>=ptr(program.data)&&current<=ptr(program.data)+length);
 emit32(current-ptr(program.data));emit(g_events.data,284);uint8_t task[36];raw_task(task);emit(task,36);
}
static uint32_t norm_task(uint32_t value){return value==ptr(g_task.data)?0x60bf50u+slot*36:value;}
uint32_t g_observe(uint32_t kind){
 uint32_t argc=kind==31?1:kind==48?3:6,args[6]={0},result=0;
 if(kind==31){CHECK(g_args[1]==ptr(g_task.data));g_current_ip=g_args[0];args[0]=slot;}
 else{memcpy(args,g_args,argc*4);if(kind==44||kind==45){if(g_key_a_kind==2)args[1]=norm_task(args[1]);args[4]=norm_task(args[4]);}}
 uint32_t row=outpos;emit32(kind);emit32(argc);emit(args,24);emit32(0);emit_context();
 if(used>=script_count){emit_context();used++;status=1;longjmp(env,1);}
 uint32_t wanted=read32(),wanted_argc=read32(),wanted_args[6];bytes(wanted_args,24);result=read32();uint32_t next_ip=read32(),patches=read32();
 CHECK(wanted==kind&&wanted_argc==argc&&!memcmp(wanted_args,args,24)&&patches<=8);
 for(uint32_t i=0;i<patches;i++){uint32_t owner=read32(),offset=read32(),size=read32();uint8_t raw[64];bytes(raw,64);uint32_t count=owner==0?284:36;CHECK(owner<=1&&size<=64&&offset+size<=count);if(owner==0)memcpy(g_events.data+offset,raw,size);else{uint8_t task[36];raw_task(task);memcpy(task+offset,raw,size);memcpy(g_task.data,task,36);import_task();}}
 if(next_ip!=0xffffffffu){CHECK(next_ip<=length);put((void*)(uintptr_t)g_current_ip,ptr(program.data)+next_ip);}
 put(output+row+32,kind==31?result:0);emit_context();used++;return result;
}
int main(void){uint32_t size;
 while(fread(&size,4,1,stdin)==1){CHECK(size<CAP&&fread(input,1,size,stdin)==size);cursor=input;end=input+size;
  g_operation=read32();base=read32();length=read32();uint32_t ip=read32();slot=read32();g_registration=read32();g_clause=read32();g_index=read32();g_value=read32();script_count=read32();
  CHECK(g_operation<4&&length>0&&length<=PROGRAM&&ip<=length&&slot<150&&g_registration<2&&script_count<=256&&g_index<71);
  bytes(g_events.data,284);bytes(g_task.data,36);bytes(program.data,length);bytes(g_metadata.data,1088);import_task();
  g_events.a=g_events.b=g_task.a=g_task.b=g_metadata.a=g_metadata.b=program.a=program.b=GUARD;
  uint8_t program_before[PROGRAM],metadata_before[1088];memcpy(program_before,program.data,length);memcpy(metadata_before,g_metadata.data,1088);
  g_source_base=base;g_program_pointer=ptr(program.data);g_entry_ip=ptr(program.data)+ip;g_current_ip=ptr(&g_entry_ip);used=status=g_trace_count=0;outpos=40;uint32_t result=0;
  if(!setjmp(env)){result=call_kernel();if(g_operation==1)g_current_ip=ptr(&g_entry_ip);CHECK(used==script_count&&cursor==end);}
  CHECK(g_events.a==GUARD&&g_events.b==GUARD&&g_task.a==GUARD&&g_task.b==GUARD&&g_metadata.a==GUARD&&g_metadata.b==GUARD&&program.a==GUARD&&program.b==GUARD&&!memcmp(program_before,program.data,length)&&!memcmp(metadata_before,g_metadata.data,1088));
  uint32_t final_at=outpos;emit_context();uint32_t trace_at=outpos;emit(g_trace,g_trace_count*4);
  put(output,0x32333435);put(output+4,outpos);put(output+8,status);put(output+12,g_operation==3?result:0);put(output+16,used);put(output+20,final_at);put(output+24,trace_at);put(output+28,g_trace_count);put(output+32,g_operation==3);put(output+36,0);
  CHECK(fwrite(output,1,outpos,stdout)==outpos);
 }
 return 0;
}
