
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
#define MARKET 308
#define OWNER (ROOT+TAIL+BANK+REGS+GLOBALS+VARS+PROGRAM+12+8+MARKET)
#define BASE (64+OWNER+1024*4)
#define RECORD (64+OWNER*2)
#define MAX 64
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,pad;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,patches,pad[6];struct Patch patch[12];};
struct __attribute__((packed)) Input{uint32_t h[16];uint8_t owner[OWNER];struct Script scripts[MAX];};
struct GuardRoot{uint8_t left[64],data[ROOT+TAIL],right[64];} g_root;
struct GuardBank{uint8_t left[64],data[BANK],right[64];} g_bank;
struct GuardRegs{uint8_t left[64],data[REGS],right[64];} g_events;
struct GuardGlobals{uint8_t left[64],data[GLOBALS],right[64];} g_globals;
struct GuardVars{uint8_t left[64],data[VARS],right[64];} g_vars;
struct GuardProgram{uint8_t left[64],data[PROGRAM],right[64];} g_program;
struct GuardMarket{uint8_t left[64],data[MARKET],right[64];} g_market;
asm(".global s_root,s_bank,s_events,s_globals,s_vars,s_program,s_market\ns_root=g_root+64\ns_bank=g_bank+64\ns_events=g_events+64\ns_globals=g_globals+64\ns_vars=g_vars+64\ns_program=g_program+64\ns_market=g_market+64");
#define s_root g_root.data
#define s_bank g_bank.data
#define s_events g_events.data
#define s_globals g_globals.data
#define s_vars g_vars.data
#define s_program g_program.data
#define s_market g_market.data
uint8_t s_task[36],s_descriptor[32];uint32_t s_ip,s_global_base,s_slot,s_descriptor_ref;int32_t s_temporary;uint32_t s_trace[1024],s_trace_count;
extern uint32_t call_kernel(uint32_t);
static struct Input input;static uint8_t output[BASE+MAX*RECORD],logical[OWNER];static uint32_t used,status;static jmp_buf jump;
static const uint32_t sizes[13]={ROOT,TAIL,BANK,REGS,GLOBALS,VARS,PROGRAM,4,4,4,4,4,MARKET};
static const uint32_t offsets[13]={0,ROOT,ROOT+TAIL,ROOT+TAIL+BANK,ROOT+TAIL+BANK+REGS,ROOT+TAIL+BANK+REGS+GLOBALS,ROOT+TAIL+BANK+REGS+GLOBALS+VARS,OWNER-12-8-MARKET,OWNER-8-8-MARKET,OWNER-4-8-MARKET,OWNER-8-MARKET,OWNER-4-MARKET,OWNER-MARKET};
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static uint32_t body_to_host(uint32_t n){if(!n)return 0;if(n<116||(n-116)%338||(n-116)/338>114)exit(90);return(uint32_t)(uintptr_t)(s_bank+n);}
static uint32_t body_to_logical(uint32_t n){if(!n)return 0;uintptr_t b=(uintptr_t)s_bank;if(n<b+116||n>b+116+114*338||(n-b-116)%338)exit(91);return n-(uint32_t)b;}
static uint32_t body_slot(uint32_t n){uint32_t off=body_to_logical(n);if(off<116)exit(92);return(off-116)/338;}
static void capture(uint8_t*p){memcpy(p,s_root,ROOT+TAIL);put(p+0xc8,body_to_logical(get(s_root+0xc8)));put(p+0xcc,body_to_logical(get(s_root+0xcc)));if(get(s_root+0x580c)!=(uint32_t)(uintptr_t)s_bank)exit(93);put(p+0x580c,1);memcpy(p+offsets[2],s_bank,BANK);memcpy(p+offsets[3],s_events,REGS);memcpy(p+offsets[4],s_globals,GLOBALS);memcpy(p+offsets[5],s_vars,VARS);memcpy(p+offsets[6],s_program,PROGRAM);put(p+offsets[7],s_ip-(uint32_t)(uintptr_t)s_program);put(p+offsets[8],s_global_base);put(p+offsets[9],(uint32_t)s_temporary);put(p+offsets[10],s_slot);put(p+offsets[11],s_descriptor_ref);memcpy(p+offsets[12],s_market,MARKET);}
static void load(const uint8_t*p){memcpy(s_root,p,ROOT+TAIL);put(s_root+0xc8,body_to_host(get(p+0xc8)));put(s_root+0xcc,body_to_host(get(p+0xcc)));if(get(p+0x580c)!=1)exit(94);put(s_root+0x580c,(uint32_t)(uintptr_t)s_bank);memcpy(s_bank,p+offsets[2],BANK);memcpy(s_events,p+offsets[3],REGS);memcpy(s_globals,p+offsets[4],GLOBALS);memcpy(s_vars,p+offsets[5],VARS);memcpy(s_program,p+offsets[6],PROGRAM);s_ip=(uint32_t)(uintptr_t)s_program+get(p+offsets[7]);s_global_base=get(p+offsets[8]);s_temporary=(int32_t)get(p+offsets[9]);s_slot=get(p+offsets[10]);s_descriptor_ref=get(p+offsets[11]);memcpy(s_market,p+offsets[12],MARKET);memset(s_task,0xa5,36);memset(s_descriptor,0xa5,32);put(s_descriptor+0x14,s_global_base==0xffffffff?0:(uint32_t)(uintptr_t)(s_globals+s_global_base));put(s_task+0x1c,(uint32_t)(uintptr_t)s_descriptor);put(s_task+0x20,(uint32_t)(uintptr_t)s_vars);}
static void setguards(void){memset(g_root.left,0x6d,64);memset(g_root.right,0x7b,64);memset(g_bank.left,0x6d,64);memset(g_bank.right,0x7b,64);memset(g_events.left,0x6d,64);memset(g_events.right,0x7b,64);memset(g_globals.left,0x6d,64);memset(g_globals.right,0x7b,64);memset(g_vars.left,0x6d,64);memset(g_vars.right,0x7b,64);memset(g_program.left,0x6d,64);memset(g_program.right,0x7b,64);memset(g_market.left,0x6d,64);memset(g_market.right,0x7b,64);}
static void guards(void){uint8_t*left[]={g_root.left,g_bank.left,g_events.left,g_globals.left,g_vars.left,g_program.left,g_market.left};uint8_t*right[]={g_root.right,g_bank.right,g_events.right,g_globals.right,g_vars.right,g_program.right,g_market.right};for(int i=0;i<7;i++)for(int j=0;j<64;j++)if(left[i][j]!=0x6d||right[i][j]!=0x7b)exit(95);if(memcmp(s_program,input.owner+offsets[6],PROGRAM))exit(96);if(memcmp(s_vars+input.h[2],input.owner+offsets[5]+input.h[2],VARS-input.h[2]))exit(107);if(get(s_task+28)!=(uint32_t)(uintptr_t)s_descriptor||get(s_task+32)!=(uint32_t)(uintptr_t)s_vars||get(s_descriptor+20)!=(s_global_base==0xffffffff?0:(uint32_t)(uintptr_t)(s_globals+s_global_base)))exit(108);}
uint32_t s_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){uint32_t argc=kind==48||kind==441?3:kind==31||kind==649?1:2,args[6]={a,b,c,0,0,0};
 if(kind==31){if(a!=(uint32_t)(uintptr_t)&s_ip||b!=(uint32_t)(uintptr_t)s_task)exit(97);args[0]=s_slot;args[1]=0;}
 if(kind==36||kind==390||kind==391||kind==392||kind==441)args[0]=body_slot(a);
 if(kind==48&&a==3){if(b!=(uint32_t)(uintptr_t)s_descriptor)exit(98);args[1]=s_descriptor_ref;}
 if(kind==48&&a==4){if(b!=(uint32_t)(uintptr_t)s_task)exit(99);args[1]=0x60bf50+s_slot*36;}
 if(argc<3)args[2]=0;if(argc<2)args[1]=0;
 if(used>=MAX)exit(100);uint8_t*row=output+BASE+used*RECORD;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+64);
 if(used>=input.h[3]){status=1;capture(row+64+OWNER);used++;longjmp(jump,1);return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24))exit(101);
 capture(logical);for(uint32_t i=0;i<s->patches;i++){struct Patch*p=&s->patch[i];if(p->owner>=13||p->owner==6||p->owner==8||p->owner==10||p->owner==11||p->size>64||p->offset+p->size>sizes[p->owner])exit(102);if(p->owner==7&&kind!=31)exit(103);if(p->owner==5&&p->offset+p->size>input.h[2])exit(104);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}load(logical);
 if((kind==22||kind==34||kind==36||kind==48||kind==441)&&s->result)exit(105);if(kind==649&&s->result>1)exit(106);
 put(row+32,s->result);capture(row+64+OWNER);used++;return kind==649?(s->result?(uint32_t)(uintptr_t)s_market:0):s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){if(input.h[1]>PROGRAM||input.h[2]>VARS||input.h[3]>MAX)return 81;setguards();load(input.owner);memset(output,0,sizeof output);used=status=s_trace_count=0;if(setjmp(jump)==0)call_kernel(input.h[0]);guards();put(output,0x37f02056);put(output+4,BASE+used*RECORD);put(output+8,status);put(output+12,0);put(output+16,used);put(output+20,s_trace_count);capture(output+64);memcpy(output+64+OWNER,s_trace,s_trace_count*4);if(fwrite(output,1,BASE+used*RECORD,stdout)!=BASE+used*RECORD)return 82;}return 0;}
