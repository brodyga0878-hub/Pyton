
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define ROOT 16384
#define BANK 38986
#define EVENTS 284
#define OWNER (ROOT+BANK+EVENTS+5)
#define BASE (64+OWNER+512)
#define SNAP (40+2*OWNER)
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,pad;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,patches,pad[6];struct Patch patch[12];};
struct __attribute__((packed)) Input{uint32_t h[16];uint8_t root[ROOT],bank[BANK],events[EVENTS];int32_t temporary;uint8_t watched;struct Script scripts[16];};
uint8_t p_root[ROOT],p_bank[BANK],p_events[EVENTS],p_payload[16],p_watched;int32_t p_temporary;uint32_t p_trace[128],p_trace_count;
extern uint32_t call_kernel(uint32_t,uint32_t,uint32_t);
static struct Input input;static uint8_t output[BASE+16*SNAP];static uint32_t used,status;
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static void capture(uint8_t*p){memcpy(p,p_root,ROOT);memcpy(p+ROOT,p_bank,BANK);memcpy(p+ROOT+BANK,p_events,EVENTS);memcpy(p+ROOT+BANK+EVENTS,&p_temporary,4);p[ROOT+BANK+EVENTS+4]=p_watched;}
uint32_t p_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){uint32_t argc=kind==48?3:(kind==262||kind==1097)?2:kind==1104?1:0,args[6]={a,b,c,0,0,0};if(!argc)memset(args,0,sizeof args);else if(argc<3)args[2]=0;if(argc<2)args[1]=0;
 if(used>=16)exit(94);uint8_t*row=output+BASE+used*SNAP;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+40);
 if(used>=input.h[4]){status=1;put(row+32,0);capture(row+40+OWNER);used++;return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24))exit(95);
 for(uint32_t i=0;i<s->patches;i++){struct Patch*p=&s->patch[i];uint8_t*dest=p->owner==0?p_root:p->owner==1?p_bank:p->owner==2?p_events:p->owner==3?(uint8_t*)&p_temporary:p->owner==4?&p_watched:0;uint32_t size=p->owner==0?ROOT:p->owner==1?BANK:p->owner==2?EVENTS:p->owner==3?4:1;if(!dest||p->size>64||p->offset+p->size>size)exit(96);memcpy(dest+p->offset,p->data,p->size);}
 put(row+32,s->result);capture(row+40+OWNER);used++;return s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){if(input.h[0]>2||input.h[2]>114||input.h[3]>255||input.h[4]>16)return 91;memcpy(p_root,input.root,ROOT);memcpy(p_bank,input.bank,BANK);memcpy(p_events,input.events,EVENTS);p_temporary=input.temporary;p_watched=input.watched;memset(output,0,sizeof output);memset(p_payload,0xa5,16);put(p_payload,input.h[1]);put(p_payload+4,(uint32_t)(uintptr_t)(p_bank+116+input.h[2]*338));p_payload[8]=input.h[3];uint8_t payload_before[16];memcpy(payload_before,p_payload,16);used=status=p_trace_count=0;uint32_t result=call_kernel(input.h[0],input.h[3]|0xa5a50000,input.h[1]);if(memcmp(payload_before,p_payload,16))return 92;uint32_t defined=!(input.h[0]==2&&input.h[1]!=0);put(output,0x110261aa);put(output+4,BASE+used*SNAP);put(output+8,status);put(output+12,defined?result:0);put(output+16,used);put(output+20,p_trace_count);put(output+24,defined);capture(output+64);memcpy(output+64+OWNER,p_trace,p_trace_count*4);if(fwrite(output,1,BASE+used*SNAP,stdout)!=BASE+used*SNAP)return 93;}return 0;}
