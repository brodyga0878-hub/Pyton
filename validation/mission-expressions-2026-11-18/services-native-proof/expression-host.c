
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define ROOT 16384
#define TAIL 6160
#define BANK 38986
#define REGS 284
#define GLOBALS 40
#define VARS 1024
#define PROGRAM 65536
#define OWNER (ROOT+TAIL+BANK+REGS+GLOBALS+VARS+PROGRAM+12)
#define BASE (64+OWNER+512*4)
#define RECORD (64+OWNER*2+4096)
#define MAX 16
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,pad;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,outlen,patches,pad[5];struct Patch patch[12];uint8_t output[4096];};
struct __attribute__((packed)) Input{uint32_t h[16];uint8_t owner[OWNER];struct Script scripts[MAX];};
struct GuardRoot{uint8_t left[64],data[ROOT+TAIL],right[64];} g_root;
struct GuardBank{uint8_t left[64],data[BANK],right[64];} g_bank;
struct GuardRegs{uint8_t left[64],data[REGS],right[64];} g_events;
struct GuardGlobals{uint8_t left[64],data[GLOBALS],right[64];} g_globals;
struct GuardVars{uint8_t left[64],data[VARS],right[64];} g_vars;
struct GuardProgram{uint8_t left[64],data[PROGRAM],right[64];} g_program;
/* External names bind the original instruction operands to these exact owners. */
asm(".global e_root,e_bank,e_events,e_globals,e_vars,e_program\ne_root=g_root+64\ne_bank=g_bank+64\ne_events=g_events+64\ne_globals=g_globals+64\ne_vars=g_vars+64\ne_program=g_program+64");
#define e_root g_root.data
#define e_bank g_bank.data
#define e_events g_events.data
#define e_globals g_globals.data
#define e_vars g_vars.data
#define e_program g_program.data
uint8_t e_task[36],e_descriptor[32],e_market[308];uint32_t e_ip,e_global_base;int32_t e_temporary;uint32_t e_trace[512],e_trace_count;
extern uintptr_t e_extra3,e_extra4;
extern uint32_t call_kernel(uint32_t,uint32_t,uint32_t);
static struct Input input;static uint8_t output[BASE+MAX*RECORD],logical[OWNER];static uint32_t used,status;static jmp_buf e_jump;
static const uint32_t sizes[10]={ROOT,TAIL,BANK,REGS,GLOBALS,VARS,PROGRAM,4,4,4};
static const uint32_t offsets[10]={0,ROOT,ROOT+TAIL,ROOT+TAIL+BANK,ROOT+TAIL+BANK+REGS,ROOT+TAIL+BANK+REGS+GLOBALS,ROOT+TAIL+BANK+REGS+GLOBALS+VARS,OWNER-12,OWNER-8,OWNER-4};
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static uint32_t body_to_host(uint32_t n){if(!n)return 0;if(n<116||(n-116)%338||(n-116)/338>114)exit(90);return(uint32_t)(uintptr_t)(e_bank+n);}
static uint32_t body_to_logical(uint32_t n){if(!n)return 0;uintptr_t b=(uintptr_t)e_bank;if(n<b+116||n>b+116+114*338||(n-b-116)%338)exit(91);return n-(uint32_t)b;}
static void capture(uint8_t*p){memcpy(p,e_root,ROOT+TAIL);put(p+0xc8,body_to_logical(get(e_root+0xc8)));put(p+0xcc,body_to_logical(get(e_root+0xcc)));if(get(e_root+0x580c)!=(uint32_t)(uintptr_t)e_bank)exit(92);put(p+0x580c,1);memcpy(p+offsets[2],e_bank,BANK);memcpy(p+offsets[3],e_events,REGS);memcpy(p+offsets[4],e_globals,GLOBALS);memcpy(p+offsets[5],e_vars,VARS);memcpy(p+offsets[6],e_program,PROGRAM);put(p+offsets[7],e_ip-(uint32_t)(uintptr_t)e_program);put(p+offsets[8],e_global_base);put(p+offsets[9],(uint32_t)e_temporary);}
static void load(const uint8_t*p){memcpy(e_root,p,ROOT+TAIL);put(e_root+0xc8,body_to_host(get(p+0xc8)));put(e_root+0xcc,body_to_host(get(p+0xcc)));if(get(p+0x580c)!=1)exit(93);put(e_root+0x580c,(uint32_t)(uintptr_t)e_bank);memcpy(e_bank,p+offsets[2],BANK);memcpy(e_events,p+offsets[3],REGS);memcpy(e_globals,p+offsets[4],GLOBALS);memcpy(e_vars,p+offsets[5],VARS);memcpy(e_program,p+offsets[6],PROGRAM);e_ip=(uint32_t)(uintptr_t)e_program+get(p+offsets[7]);e_global_base=get(p+offsets[8]);e_temporary=(int32_t)get(p+offsets[9]);memset(e_task,0xa5,36);memset(e_descriptor,0xa5,32);put(e_descriptor+0x14,e_global_base==0xffffffff?0:(uint32_t)(uintptr_t)(e_globals+e_global_base));put(e_task+0x1c,(uint32_t)(uintptr_t)e_descriptor);put(e_task+0x20,(uint32_t)(uintptr_t)e_vars);}
static void setguards(void){memset(g_root.left,0x6d,64);memset(g_root.right,0x7b,64);memset(g_bank.left,0x6d,64);memset(g_bank.right,0x7b,64);memset(g_events.left,0x6d,64);memset(g_events.right,0x7b,64);memset(g_globals.left,0x6d,64);memset(g_globals.right,0x7b,64);memset(g_vars.left,0x6d,64);memset(g_vars.right,0x7b,64);memset(g_program.left,0x6d,64);memset(g_program.right,0x7b,64);}
static void guards(void){uint8_t*left[]={g_root.left,g_bank.left,g_events.left,g_globals.left,g_vars.left,g_program.left};uint8_t*right[]={g_root.right,g_bank.right,g_events.right,g_globals.right,g_vars.right,g_program.right};for(int i=0;i<6;i++)for(int j=0;j<64;j++)if(left[i][j]!=0x6d||right[i][j]!=0x7b)exit(94);if(memcmp(e_program,input.owner+offsets[6],PROGRAM))exit(95);}
uint32_t e_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c,uintptr_t out1,uintptr_t out2){uint32_t argc=kind==48||kind==96?3:kind==85||kind==392||kind==857||kind==909?2:kind==1476?0:1;uint32_t args[6]={a,b,c,0,0,0};if(kind==392)args[0]=body_to_logical(a);if(argc<3)args[2]=0;if(argc<2)args[1]=0;if(!argc)args[0]=0;
 if(used>=MAX)exit(96);uint8_t*row=output+BASE+used*RECORD;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+64);
 if(used>=input.h[5]){status=1;put(row+32,0);capture(row+64+OWNER);used++;longjmp(e_jump,1);return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24))exit(98);
 capture(logical);for(uint32_t i=0;i<s->patches;i++){struct Patch*p=&s->patch[i];if(p->owner>=10||p->owner==6||p->owner==7||p->owner==8||p->size>64||p->offset+p->size>sizes[p->owner])exit(99);if(p->owner==5&&p->offset+p->size>input.h[4])exit(100);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}load(logical);
 uint32_t want=kind==461?4096:kind==649?(s->result?308:0):kind==658?2:kind==870?16:kind==871?8:0;if(s->outlen!=want)exit(101);put(row+32,s->result);put(row+36,s->outlen);memcpy(row+64+2*OWNER,s->output,s->outlen);
 if(kind==461||kind==658)memcpy((void*)out1,s->output,s->outlen);
 if(kind==649&&s->result)memcpy(e_market,s->output,308);
 if(kind==870){memcpy((void*)out1,s->output,4);memcpy((void*)out2,s->output+4,4);memcpy((void*)e_extra3,s->output+8,4);memcpy((void*)e_extra4,s->output+12,4);}
 if(kind==871){memcpy((void*)out1,s->output,4);memcpy((void*)out2,s->output+4,4);}
 capture(row+64+OWNER);used++;return kind==649?(s->result?(uint32_t)(uintptr_t)e_market:0):s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){if(input.h[0]>16||input.h[3]>PROGRAM||input.h[4]>VARS||input.h[5]>MAX)return 81;setguards();load(input.owner);memset(output,0,sizeof output);used=status=e_trace_count=0;volatile uint32_t result=0;if(setjmp(e_jump)==0)result=call_kernel(input.h[0],input.h[1],input.h[2]);guards();put(output,0x31e02055);put(output+4,BASE+used*RECORD);put(output+8,status);put(output+12,result);put(output+16,used);put(output+20,e_trace_count);put(output+24,input.h[0]!=2&&input.h[0]!=13&&input.h[0]!=16);capture(output+64);memcpy(output+64+OWNER,e_trace,e_trace_count*4);if(fwrite(output,1,BASE+used*RECORD,stdout)!=BASE+used*RECORD)return 82;}return 0;}
