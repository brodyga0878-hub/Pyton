
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define CAP (64*1024*1024)
#define PROGRAM 65536
#define GUARD UINT64_C(0x7461736b6e617469)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"task-native:%d\n",__LINE__);exit(97);}}while(0)
struct __attribute__((packed)){uint64_t a;uint8_t data[5400];uint64_t b;}t_arena;
static struct{uint64_t a;uint8_t data[PROGRAM];uint64_t b;}program __attribute__((section(".task_program_owner")));
uint32_t t_operation,t_command[4],t_base,t_program_ptr,t_caller_ip,t_module_table[256],t_args[4],t_length;
static uint32_t refs[256],length,script_count,used,status,outpos,trace_count,steps;
static uint32_t trace_words[16384],field_raw[150][3],field_host[150][3];static uint8_t field_kind[150][3];
static uint8_t input[CAP],output[CAP],*cursor,*end;static jmp_buf env;
extern uint32_t call_kernel(void);
static uint32_t get(const void*p){uint32_t x;memcpy(&x,p,4);return x;}
static void put(void*p,uint32_t x){memcpy(p,&x,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static uint32_t read32(void){CHECK(cursor+4<=end);uint32_t x=get(cursor);cursor+=4;return x;}
static void bytes(void*p,uint32_t n){CHECK(cursor+n<=end);memcpy(p,cursor,n);cursor+=n;}
static void emit32(uint32_t x){CHECK(outpos+4<CAP);put(output+outpos,x);outpos+=4;}
static void emit(const void*p,uint32_t n){CHECK(outpos+n<CAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t is_source(uint32_t p){return p>=t_base&&p<=t_base+length;}
static uint32_t is_host(uint32_t p){return p>=t_program_ptr&&p<=t_program_ptr+length;}
static uint32_t tohost(uint32_t p){return is_source(p)?t_program_ptr+p-t_base:p;}
static uint32_t source(uint32_t p){return is_host(p)?t_base+p-t_program_ptr:p;}
static const uint32_t fields[3]={8,16,28};
static void import_arena(void){for(uint32_t i=0;i<150;i++)for(uint32_t j=0;j<3;j++){uint8_t*p=t_arena.data+i*36+fields[j];uint32_t v=get(p);field_raw[i][j]=v;field_kind[i][j]=is_source(v);field_host[i][j]=tohost(v);put(p,field_host[i][j]);}}
static void raw_arena(uint8_t*out){memcpy(out,t_arena.data,5400);for(uint32_t i=0;i<150;i++)for(uint32_t j=0;j<3;j++){uint8_t*p=out+i*36+fields[j];uint32_t v=get(p);if(is_host(v)&&(field_kind[i][j]||v!=field_host[i][j]))put(p,source(v));}}
static uint32_t offset(uint32_t p){if(!p)return 0xffffffffu;CHECK(p>=t_program_ptr&&p<=t_program_ptr+length);return p-t_program_ptr;}
static void emit_context(void){emit32(offset(t_caller_ip));uint8_t arena[5400];raw_arena(arena);emit(arena,5400);}
static uint32_t slot(uint32_t p){if(!p)return 0xffffffffu;CHECK(p>=ptr(t_arena.data)&&p<ptr(t_arena.data)+5400&&(p-ptr(t_arena.data))%36==0);return(p-ptr(t_arena.data))/36;}
void t_trace(uint32_t n){CHECK(trace_count<16384);if(n==53000){CHECK(++steps<=1024);return;}trace_words[trace_count++]=n;}
uint32_t t_observe(uint32_t kind){
 uint32_t argc=kind==37||kind==51||kind==33?2:1,args[4]={0},cursor_kind=0,ip_pointer=0;
 if(kind==31||kind==41){args[0]=slot(t_args[1]);ip_pointer=t_args[0];cursor_kind=kind==31&&t_operation==2?1:3;}
 else if(kind==37){args[0]=slot(t_args[1]);args[1]=t_args[2];ip_pointer=t_args[0];cursor_kind=2;}
 else if(kind==51){args[0]=t_args[0];args[1]=t_args[1];}
 else{CHECK(kind==33);args[0]=slot(t_args[0]);args[1]=t_args[1];}
 uint32_t before=cursor_kind?offset(get((void*)(uintptr_t)ip_pointer)):0xffffffffu;
 uint32_t row=outpos;emit32(kind);emit32(argc);emit(args,16);emit32(0);emit32(cursor_kind);emit32(before);emit32(before);emit_context();
 if(used>=script_count){emit_context();used++;status=1;longjmp(env,1);}
 uint32_t wanted=read32(),wanted_argc=read32(),wanted_args[4];bytes(wanted_args,16);uint32_t result=read32(),wanted_cursor=read32(),after=read32(),patches=read32();
 CHECK(kind==wanted&&argc==wanted_argc&&!memcmp(args,wanted_args,16)&&cursor_kind==wanted_cursor&&patches<=32);
 for(uint32_t i=0;i<patches;i++){uint32_t at=read32(),size=read32();uint8_t data[64];bytes(data,64);CHECK(size<=64&&at+size<=5400);uint8_t arena[5400];raw_arena(arena);memcpy(arena+at,data,size);memcpy(t_arena.data,arena,5400);import_arena();}
 if(cursor_kind){CHECK(after<=length);put((void*)(uintptr_t)ip_pointer,t_program_ptr+after);}else CHECK(after==0xffffffffu);
 put(output+row+24,kind==31||kind==51?result:0);put(output+row+36,after);emit_context();used++;
 if(kind==51){if(result==0xffffffffu)return 0;CHECK(result<150);return ptr(t_arena.data)+result*36;}
 return result;
}
int main(void){uint32_t size;
 while(fread(&size,4,1,stdin)==1){CHECK(size<CAP&&fread(input,1,size,stdin)==size);cursor=input;end=input+size;
  t_operation=read32();bytes(t_command,16);t_base=read32();length=read32();t_length=length;uint32_t caller=read32(),count=read32();CHECK(t_operation<4&&length>0&&length<=PROGRAM&&t_base+length>t_base&&count<=256);
  memset(refs,0,sizeof refs);memset(t_module_table,0,sizeof t_module_table);for(uint32_t i=0;i<count;i++){uint32_t id=read32(),ref=read32();CHECK(id<256);refs[id]=ref;}
  bytes(t_arena.data,5400);bytes(program.data,length);t_program_ptr=ptr(program.data);for(uint32_t i=0;i<256;i++)if(refs[i]){CHECK(is_source(refs[i]));t_module_table[i]=tohost(refs[i]);}
  import_arena();t_caller_ip=caller==0xffffffffu?0:t_program_ptr+caller;CHECK(caller==0xffffffffu||caller<=length);script_count=read32();CHECK(script_count<=256);
  t_arena.a=t_arena.b=program.a=program.b=GUARD;uint8_t before_program[PROGRAM];memcpy(before_program,program.data,length);
  trace_count=used=status=steps=0;outpos=40;uint32_t result=0;
  if(!setjmp(env)){result=call_kernel();CHECK(used==script_count&&cursor==end);}
  CHECK(t_arena.a==GUARD&&t_arena.b==GUARD&&program.a==GUARD&&program.b==GUARD&&!memcmp(before_program,program.data,length));
  uint32_t final=outpos;emit_context();uint32_t trace_at=outpos;emit(trace_words,trace_count*4);
  put(output,0x38475253);put(output+4,outpos);put(output+8,status);put(output+12,t_operation==2?result:0);put(output+16,used);put(output+20,final);put(output+24,trace_at);put(output+28,trace_count);put(output+32,t_operation==2);put(output+36,0);
  CHECK(fwrite(output,1,outpos,stdout)==outpos);
 }
 return 0;
}
