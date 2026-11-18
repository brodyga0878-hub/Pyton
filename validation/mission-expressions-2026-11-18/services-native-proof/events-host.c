
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define CAP 512
#define OUTCAP (512u*1024u*1024u)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"events-native-check:%d\n",__LINE__);exit(97);}}while(0)
#define GUARD UINT64_C(0xa5a5a5a5a5a5a5a5)
#define GUARDED(name,N) struct __attribute__((packed)){uint64_t guard_a;uint8_t data[N];uint64_t guard_b;} name __attribute__((aligned(16)))
GUARDED(g_root,16384);GUARDED(g_bank,38986);GUARDED(g_events,284);GUARDED(g_arena,5400);GUARDED(g_scratch,32);
#define s_root g_root.data
#define s_bank g_bank.data
#define s_events g_events.data
#define s_arena g_arena.data
#define s_scratch_words g_scratch.data
uint32_t s_registry_root,s_module_table[256];
static uint8_t node_pool[CAP][32],snapshot_pool[CAP][16],variable_pool[CAP][1024];
static uint8_t node_live[CAP],snapshot_live[CAP],variable_live[CAP],definition_live[256];
static uint32_t variable_length[CAP],definitions[256][32],definition_original[256][32],cleanup_words[256],cleanup_original[256],definition_refs[256];
static uint32_t next_node,next_variable,snapshot_count,temporary_index,scheduler_steps;
static uint8_t input[4*1024*1024],output[OUTCAP];static uint32_t input_size,outpos;
static uint32_t operation,args[12],trace_words[65536],trace_count,script_count,script_used,status,result_word,allocated_slot,allocated_handle;
static uint32_t captured[CAP][3],captured_count,records_count,pending_kind,pending_argc,pending_args[4];
static uint8_t *script_cursor,*input_end;static jmp_buf case_env;
extern void run_low(void);extern uint32_t invoke_original(void*,uint32_t,uint32_t*);
extern void FUNC_000042(void),FUNC_000043(void),FUNC_000044(void),FUNC_000045(void),FUNC_000046(void),FUNC_000048(void),FUNC_000050(void),FUNC_000051(void),FUNC_000054(void),FUNC_000055(void),FUNC_000056(void);
static uint32_t word(const void*p){uint32_t x;memcpy(&x,p,4);return x;}
static void setword(void*p,uint32_t x){memcpy(p,&x,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static uint32_t read32(uint8_t**p){CHECK(*p+4<=input_end);uint32_t x=word(*p);*p+=4;return x;}
static void copyin(uint8_t**p,void*d,uint32_t n){CHECK(*p+n<=input_end);memcpy(d,*p,n);*p+=n;}
static void put32(uint32_t x){CHECK(outpos+4<=OUTCAP);setword(output+outpos,x);outpos+=4;}
static void putbytes(const void*p,uint32_t n){CHECK(outpos+n<=OUTCAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t nodeptr(uint32_t id){CHECK(id<=CAP);return id?ptr(node_pool[id-1]):0;}
static uint32_t nodeid(uint32_t address){if(!address)return 0;CHECK(address>=ptr(node_pool)&&address<ptr(node_pool)+sizeof node_pool);uint32_t n=address-ptr(node_pool);CHECK(n%32==0);return n/32+1;}
static uint32_t variableid(uint32_t address){if(!address)return 0;if(address>=ptr(variable_pool)&&address<ptr(variable_pool)+sizeof variable_pool){uint32_t n=address-ptr(variable_pool);CHECK(n%1024==0);return n/1024+1;}return address;}
static uint32_t variableptr(uint32_t id){return id>0&&id<next_variable?ptr(variable_pool[id-1]):id;}
static uint32_t descriptor_token(uint32_t address){for(uint32_t i=0;i<256;i++)if(definition_live[i]&&address==ptr(definitions[i]))return definition_refs[i];return address;}
static uint32_t descriptor_pointer(uint32_t token){for(uint32_t i=0;i<256;i++)if(definition_live[i]&&token==definition_refs[i])return ptr(definitions[i]);return token;}
static void import_arena(void){for(uint32_t i=0;i<150;i++){uint8_t*p=s_arena+i*36;uint32_t v=word(p+32);if(v>0&&v<next_variable)setword(p+32,variableptr(v));setword(p+28,descriptor_pointer(word(p+28)));}}
static void emit_context(void){
 uint32_t start=outpos;put32(0);put32(next_node);put32(nodeid(s_registry_root));put32(next_variable);put32(temporary_index);
 putbytes(s_root,sizeof s_root);putbytes(s_bank,sizeof s_bank);putbytes(s_events,sizeof s_events);
 uint8_t arena[5400];memcpy(arena,s_arena,sizeof arena);for(uint32_t i=0;i<150;i++){uint8_t*p=arena+i*36;setword(p+32,variableid(word(p+32)));setword(p+28,descriptor_token(word(p+28)));}putbytes(arena,sizeof arena);putbytes(s_scratch_words,32);
 uint32_t count=0;for(uint32_t i=0;i<CAP;i++)if(node_live[i])count++;put32(count);
 for(uint32_t i=0;i<CAP;i++)if(node_live[i]){put32(i+1);put32(nodeid(word(node_pool[i])));put32(nodeid(word(node_pool[i]+4)));put32(1);putbytes(node_pool[i]+8,24);}
 count=0;for(uint32_t i=0;i<CAP;i++)if(variable_live[i])count++;put32(count);
 for(uint32_t i=0;i<CAP;i++)if(variable_live[i]){put32(i+1);put32(variable_length[i]);putbytes(variable_pool[i],variable_length[i]);}
 setword(output+start,outpos-start);
}
void c_scheduler_guard(void){CHECK(++scheduler_steps<=1024);}
void c_trace(uint32_t id){CHECK(trace_count<65536);trace_words[trace_count++]=id;}
uint32_t c_alloc_node(uint32_t n){CHECK(n==32&&next_node<=CAP);uint32_t id=next_node++;node_live[id-1]=1;memset(node_pool[id-1],0xa5,32);return nodeptr(id);}
uint32_t c_alloc_snapshot(uint32_t n){CHECK(n==16&&snapshot_count<CAP);uint32_t id=snapshot_count++;snapshot_live[id]=1;memset(snapshot_pool[id],0xa5,16);return ptr(snapshot_pool[id]);}
uint32_t c_alloc_variables(uint32_t n){CHECK(n>=8&&n<=1024&&n%4==0&&next_variable<=CAP);uint32_t id=next_variable++;variable_live[id-1]=1;variable_length[id-1]=n;memset(variable_pool[id-1],0xa5,n);return ptr(variable_pool[id-1]);}
void c_free(uint32_t address){
 if(!address)return;
 if(address>=ptr(node_pool)&&address<ptr(node_pool)+sizeof node_pool){uint32_t id=nodeid(address);CHECK(node_live[id-1]);node_live[id-1]=0;return;}
 if(address>=ptr(snapshot_pool)&&address<ptr(snapshot_pool)+sizeof snapshot_pool){uint32_t n=address-ptr(snapshot_pool);CHECK(n%16==0&&snapshot_live[n/16]);snapshot_live[n/16]=0;return;}
 uint32_t id=variableid(address);CHECK(id>0&&id<next_variable&&id<=CAP&&variable_live[id-1]);variable_live[id-1]=0;
}
static void validate_definitions(void){
 CHECK(g_root.guard_a==GUARD&&g_root.guard_b==GUARD&&g_bank.guard_a==GUARD&&g_bank.guard_b==GUARD&&g_events.guard_a==GUARD&&g_events.guard_b==GUARD&&g_arena.guard_a==GUARD&&g_arena.guard_b==GUARD&&g_scratch.guard_a==GUARD&&g_scratch.guard_b==GUARD);
 for(uint32_t i=0;i<256;i++)if(definition_live[i]){CHECK(s_module_table[i]==ptr(definitions[i]));CHECK(memcmp(definitions[i],definition_original[i],128)==0);CHECK(cleanup_words[i]==cleanup_original[i]);}
}
static void action(uint32_t op,uint32_t argc,uint32_t*a){
 if(op==44){CHECK(argc==6);invoke_original(FUNC_000044,6,a);}
 else if(op==45){CHECK(argc==6);invoke_original(FUNC_000045,6,a);}
 else{CHECK(op==50&&argc==0);invoke_original(FUNC_000050,0,a);}
}
static uint32_t external(uint32_t kind,uint32_t argc,uint32_t*a){
 c_trace(kind);CHECK(argc<=4);
 if(script_used>=script_count){status=1;pending_kind=kind;pending_argc=argc;memcpy(pending_args,a,argc*4);longjmp(case_env,1);}
 uint8_t*p=script_cursor;CHECK(read32(&p)==kind);CHECK(read32(&p)==argc);for(uint32_t i=0;i<argc;i++)CHECK(read32(&p)==a[i]);uint32_t ret=read32(&p);
 put32(1);put32(kind);put32(argc);for(uint32_t i=0;i<argc;i++)put32(a[i]);put32(ret);emit_context();
 uint32_t patches=read32(&p);CHECK(patches<=32);
 for(uint32_t i=0;i<patches;i++){
  uint32_t owner=read32(&p),ref=read32(&p),off=read32(&p),len=read32(&p);uint8_t*dst=0;uint32_t size=0;
  if(owner==0){dst=s_root;size=sizeof s_root;}else if(owner==1){dst=s_bank;size=sizeof s_bank;}else if(owner==2){dst=s_events;size=sizeof s_events;}else if(owner==3){dst=s_arena;size=sizeof s_arena;}else if(owner==4){dst=(uint8_t*)&temporary_index;size=4;}else if(owner==5){dst=s_scratch_words;size=32;}else{CHECK(owner==6&&ref>0&&ref<next_variable&&variable_live[ref-1]);dst=variable_pool[ref-1];size=variable_length[ref-1];}
  CHECK(len<=64&&off<=size&&len<=size-off);copyin(&p,dst+off,len);
 }
 import_arena();uint32_t actions=read32(&p);CHECK(actions<=64);
 for(uint32_t i=0;i<actions;i++){uint32_t op=read32(&p),n=read32(&p),values[6];CHECK(n<=6);for(uint32_t j=0;j<n;j++)values[j]=read32(&p);action(op,n,values);}
 script_cursor=p;script_used++;emit_context();records_count++;return ret;
}
uint32_t c_event_callback(uint32_t code,uint32_t a,uint32_t b){CHECK(code!=0&&captured_count<CAP);captured[captured_count][0]=code;captured[captured_count][1]=a;captured[captured_count++][2]=b;uint32_t v[3]={code,a,b};return external(48000,3,v);}
uint32_t c_f53(uint32_t task){CHECK(task>=ptr(s_arena)&&task<ptr(s_arena)+sizeof s_arena&&(task-ptr(s_arena))%36==0);uint32_t slot=(task-ptr(s_arena))/36;uint32_t a[2]={slot,word(s_arena+slot*36+4)};return external(53,2,a);}
uint32_t c_f41(uint32_t instruction_pointer,uint32_t task){CHECK(task>=ptr(s_arena)&&task<ptr(s_arena)+sizeof s_arena&&(task-ptr(s_arena))%36==0);uint32_t a[2]={(task-ptr(s_arena))/36,word((void*)(uintptr_t)instruction_pointer)};return external(41,2,a);}
uint32_t c_f52(uint32_t a,uint32_t b,uint32_t c,uint32_t d){uint32_t values[4]={a,b,c,d};return external(52,4,values);}
static void load_case(uint8_t*p){
 g_root.guard_a=g_root.guard_b=g_bank.guard_a=g_bank.guard_b=g_events.guard_a=g_events.guard_b=g_arena.guard_a=g_arena.guard_b=g_scratch.guard_a=g_scratch.guard_b=GUARD;
 operation=read32(&p);CHECK(operation<11);for(uint32_t i=0;i<12;i++)args[i]=read32(&p);
 next_node=read32(&p);uint32_t root_id=read32(&p);next_variable=read32(&p);temporary_index=read32(&p);CHECK(next_node>=1&&next_node<=513&&next_variable>=1&&next_variable<=513);
 copyin(&p,s_root,sizeof s_root);copyin(&p,s_bank,sizeof s_bank);copyin(&p,s_events,sizeof s_events);copyin(&p,s_arena,sizeof s_arena);copyin(&p,s_scratch_words,32);
 memset(node_live,0,sizeof node_live);memset(snapshot_live,0,sizeof snapshot_live);memset(variable_live,0,sizeof variable_live);memset(definition_live,0,sizeof definition_live);memset(s_module_table,0,sizeof s_module_table);memset(node_pool,0xa5,sizeof node_pool);memset(variable_pool,0xa5,sizeof variable_pool);
 uint32_t count=read32(&p);CHECK(count<=CAP);
 for(uint32_t i=0;i<count;i++){uint32_t id=read32(&p),left=read32(&p),right=read32(&p),generation=read32(&p);CHECK(id>0&&id<next_node&&generation==1);node_live[id-1]=1;setword(node_pool[id-1],nodeptr(left));setword(node_pool[id-1]+4,nodeptr(right));copyin(&p,node_pool[id-1]+8,24);}
 s_registry_root=nodeptr(root_id);count=read32(&p);CHECK(count<=CAP);
 for(uint32_t i=0;i<count;i++){uint32_t id=read32(&p),len=read32(&p);CHECK(id>0&&id<next_variable&&len>=8&&len<=1024&&len%4==0);variable_live[id-1]=1;variable_length[id-1]=len;copyin(&p,variable_pool[id-1],len);}
 count=read32(&p);CHECK(count<=256);
 for(uint32_t i=0;i<count;i++){uint32_t id=read32(&p),ref=read32(&p),cleanup=read32(&p),words=read32(&p);CHECK(id<256&&words>=2&&words<=256);definition_live[id]=1;definition_refs[id]=ref;memset(definitions[id],0xa5,sizeof definitions[id]);definitions[id][3]=0;definitions[id][4]=words;cleanup_words[id]=cleanup;definitions[id][7]=ptr(cleanup_words+id);s_module_table[id]=ptr(definitions[id]);memcpy(definition_original[id],definitions[id],128);cleanup_original[id]=cleanup;}
 import_arena();script_count=read32(&p);CHECK(script_count<=256);script_cursor=p;
}
void c_run_case(void){
 trace_count=script_used=snapshot_count=status=records_count=captured_count=scheduler_steps=0;result_word=0;allocated_slot=0xffffffffu;allocated_handle=0;pending_kind=pending_argc=0;outpos=24;
 if(setjmp(case_env)==0){
  uint32_t returned=0;
  if(operation<=1){uint32_t a[2]={ptr(args),ptr(args+6)};returned=invoke_original(operation==0?FUNC_000042:FUNC_000043,2,a);result_word=returned;}
  else if(operation==2)invoke_original(FUNC_000044,6,args);
  else if(operation==3)invoke_original(FUNC_000045,6,args);
  else if(operation==4){uint32_t first=0,tail=ptr(&first),a[3]={ptr(&tail),s_registry_root,ptr(args)};invoke_original(FUNC_000046,3,a);uint32_t cursor=first;while(cursor){CHECK(captured_count<CAP);memcpy(captured[captured_count++],(void*)(uintptr_t)(cursor+4),12);uint32_t next=word((void*)(uintptr_t)cursor);c_free(cursor);cursor=next;}}
  else if(operation==5)invoke_original(FUNC_000048,3,args);
  else if(operation==6)invoke_original(FUNC_000050,0,args);
  else if(operation==7){uint32_t free_slot=0;for(uint32_t i=0;i<150;i++)if(word(s_arena+i*36)==0)free_slot=1;if(free_slot)CHECK(args[0]<256&&definition_live[args[0]]);returned=invoke_original(FUNC_000051,2,args);if(returned){CHECK(returned>=ptr(s_arena)&&returned<ptr(s_arena)+sizeof s_arena);allocated_slot=(returned-ptr(s_arena))/36;allocated_handle=word((void*)(uintptr_t)(returned+4));}}
  else if(operation==8)invoke_original(FUNC_000054,0,args);
  else if(operation==9)invoke_original(FUNC_000055,0,args);
  else invoke_original(FUNC_000056,0,args);
 }
 CHECK(script_used==script_count);validate_definitions();
 put32(2);put32(trace_count);for(uint32_t i=0;i<trace_count;i++)put32(trace_words[i]);emit_context();put32(captured_count);for(uint32_t i=0;i<captured_count;i++)putbytes(captured[i],12);
 if(status){put32(3);put32(pending_kind);put32(pending_argc);for(uint32_t i=0;i<pending_argc;i++)put32(pending_args[i]);}
 setword(output,0x45564e54);setword(output+4,outpos);setword(output+8,status);setword(output+12,result_word);setword(output+16,allocated_slot);setword(output+20,allocated_handle);
}
int main(void){while(fread(&input_size,4,1,stdin)==1){CHECK(input_size>=4&&input_size<=sizeof input);CHECK(fread(input,input_size-4,1,stdin)==1);input_end=input+input_size-4;load_case(input);run_low();CHECK(fwrite(output,outpos,1,stdout)==1);}return 0;}
