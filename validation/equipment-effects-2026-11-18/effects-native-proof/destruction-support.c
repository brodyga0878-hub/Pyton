
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define BANK 38986
#define ROOT 16384
#define OWNER (ROOT+BANK+168+4)
#define BASE (64+OWNER+2048)
#define SNAP (40+2*OWNER)
struct __attribute__((packed)) Model{uint32_t index;uint8_t descriptor[68],physical[24];uint32_t collision_present,collision_first,physical_present;};
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,reserved;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,patch_count,pad[6];struct Patch patches[12];};
struct __attribute__((packed)) Input{uint32_t header[16];uint8_t root[ROOT],bank[BANK],modules[168];int32_t count;struct Model models[156];struct Script scripts[64];};
struct __attribute__((packed)){uint8_t before[8],data[ROOT],after[8];}d_root_store;
struct __attribute__((packed)){uint8_t before[8],data[BANK],after[8];}d_bank_store;
struct __attribute__((packed)){uint8_t before[8],data[168],after[8];}d_module_store;
struct __attribute__((packed)){uint8_t before[8];int32_t data;uint8_t after[8];}d_count_store;
#define d_root (d_root_store.data)
#define d_bank (d_bank_store.data)
#define d_modules (d_module_store.data)
#define d_module_count (d_count_store.data)
uint32_t d_trace[512],d_trace_count,d_module;
uint8_t descriptors[256][68],physical[256][24],collision[256];
extern uint32_t DATA_004681[256];extern uint32_t call_kernel(uint32_t,uint32_t);
static struct Input input,saved_input;static uint8_t output[BASE+64*SNAP];static uint32_t used,status;static int pointer_bound;
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static void capture(uint8_t*out){memcpy(out,d_root,ROOT);uint32_t p=get(out+0xc8);uintptr_t first=(uintptr_t)d_bank+116,last=first+115*338;if(pointer_bound&&p>=first&&p<last&&(p-first)%338==0)put(out+0xc8,(p-first)/338);memcpy(out+ROOT,d_bank,BANK);memcpy(out+ROOT+BANK,d_modules,168);memcpy(out+ROOT+BANK+168,&d_module_count,4);}
static void bind_root(void){uint32_t n=get(d_root+0xc8);pointer_bound=n>=1&&n<=114;if(pointer_bound)put(d_root+0xc8,(uint32_t)(uintptr_t)(d_bank+116+n*338));}
static uint32_t body_offset(uint32_t p){uintptr_t first=(uintptr_t)d_bank+116;if(p<first||p>=first+115*338||(p-first)%338){status=2;return 0xffffffff;}return p-(uint32_t)(uintptr_t)d_bank;}
uint32_t d_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){
 if(d_trace_count>=512)exit(98);d_trace[d_trace_count++]=kind;
 uint32_t argc=0,args[6]={0};
 if(kind==349){uint8_t*p=(uint8_t*)(uintptr_t)a;argc=4;args[0]=get(p);args[1]=args[0]==0x8635;args[2]=args[1]?get(p+12):0;args[3]=get(p+24);}
 else if(kind==1907){argc=2;args[0]=a;args[1]=b;}
 else if(kind==1344){argc=2;uintptr_t first=(uintptr_t)d_bank+116+0x124;if(a<first||a>=first+115*338||(a-first)%338){status=3;return 0;}args[0]=a-(uint32_t)(uintptr_t)d_bank;args[1]=b;}
 else if(kind==14400){kind=144;argc=6;uint8_t*p=(uint8_t*)(uintptr_t)a;args[0]=d_module;args[1]=11;args[2]=get(p);args[3]=body_offset(get(p+4));args[4]=p[8];args[5]=p[9];}
 else{status=4;return 0;}
 if(used>=64){status=5;exit(95);}uint8_t*row=output+BASE+used*SNAP;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+40);
 if(used>=input.header[3]){status=1;put(row+32,0);capture(row+40+OWNER);used++;return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24)){status=6;exit(96);}
 uint8_t logical[OWNER];capture(logical);
 for(uint32_t i=0;i<s->patch_count;i++){struct Patch*p=&s->patches[i];uint8_t*base=0;uint32_t size=0;if(p->owner==0){base=logical;size=ROOT;}else if(p->owner==1){base=d_bank;size=BANK;}else if(p->owner==2){base=d_modules;size=168;}else if(p->owner==3){base=(uint8_t*)&d_module_count;size=4;}if(!base||p->size>64||p->offset+p->size>size){status=7;exit(97);}memcpy(base+p->offset,p->data,p->size);}
 memcpy(d_root,logical,ROOT);bind_root();put(row+32,s->result);capture(row+40+OWNER);used++;return s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){
 memcpy(&saved_input,&input,sizeof input);memset(&d_root_store,0xa5,sizeof d_root_store);memset(&d_bank_store,0xa5,sizeof d_bank_store);memset(&d_module_store,0xa5,sizeof d_module_store);memset(&d_count_store,0xa5,sizeof d_count_store);
 memset(output,0,sizeof output);memcpy(d_root,input.root,ROOT);memcpy(d_bank,input.bank,BANK);memcpy(d_modules,input.modules,168);d_module_count=input.count;bind_root();memset(DATA_004681,0,1024);memset(descriptors,0,sizeof descriptors);memset(physical,0,sizeof physical);memset(collision,0,sizeof collision);
 for(uint32_t i=0;i<input.header[4];i++){struct Model*m=&input.models[i];if(m->index>=256)return 91;memcpy(descriptors[m->index],m->descriptor,68);memcpy(physical[m->index],m->physical,24);collision[m->index]=m->collision_first;put(descriptors[m->index]+0x34,m->collision_present?(uint32_t)(uintptr_t)&collision[m->index]:0);put(descriptors[m->index]+0x38,m->physical_present?(uint32_t)(uintptr_t)physical[m->index]:0);DATA_004681[m->index]=(uint32_t)(uintptr_t)descriptors[m->index];}
 used=status=d_trace_count=0;uint32_t result=call_kernel(input.header[1],input.header[2]);
 uint8_t guard[8];memset(guard,0xa5,8);if(memcmp(guard,d_root_store.before,8)||memcmp(guard,d_root_store.after,8)||memcmp(guard,d_bank_store.before,8)||memcmp(guard,d_bank_store.after,8)||memcmp(guard,d_module_store.before,8)||memcmp(guard,d_module_store.after,8)||memcmp(guard,d_count_store.before,8)||memcmp(guard,d_count_store.after,8))status=8;
 if(memcmp(&input,&saved_input,sizeof input))status=9;
 for(uint32_t i=0;i<input.header[4];i++){struct Model*m=&input.models[i];uint8_t expected[68];memcpy(expected,m->descriptor,68);put(expected+0x34,m->collision_present?(uint32_t)(uintptr_t)&collision[m->index]:0);put(expected+0x38,m->physical_present?(uint32_t)(uintptr_t)physical[m->index]:0);if(memcmp(expected,descriptors[m->index],68)||memcmp(m->physical,physical[m->index],24)||collision[m->index]!=(uint8_t)m->collision_first)status=10;}
 put(output,0x942926aa);put(output+4,BASE+used*SNAP);put(output+8,status);put(output+12,result);put(output+16,used);put(output+20,d_trace_count);capture(output+64);memcpy(output+64+OWNER,d_trace,d_trace_count*4);if(fwrite(output,1,BASE+used*SNAP,stdout)!=BASE+used*SNAP)return 92;
 }return 0;}
