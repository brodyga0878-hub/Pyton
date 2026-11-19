#!/usr/bin/env python3
"""Compose independently proved DOS mission kernels over one persistent owner set.

Python routes typed continuations and transports bytes; every game result is
measured by an original instruction kernel. The only unclosed statement worker
is the explicitly authored F41 provider. No expected game arithmetic is in Python.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,json,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_mission_expression_native as E
import rebuild_source_mission_store_native as S
import rebuild_source_mission_guards_native as G
import rebuild_source_mission_task_native as T
import rebuild_source_events_native as V
import rebuild_source_model_replace_native as M

PROJECT=E.PROJECT
PROOF=PROJECT/'validation/mission-tasks-2026-11-19/runtime-native-proof'
SPEC=PROJECT/'validation/mission-tasks-2026-11-19/native-runtime-spec.json'
FIXTURE=PROJECT/'tests/fixtures/source_mission_runtime_native.json'
PROFILE='dos-firstenc-composed-mission-runtime-v1';MASK=0xffffffff
KEYS=['root','root_tail','bank','event_registers','module_globals','program','program_base_u32','metadata','temporary_event_index_s32','scratch_words','arena','tree_root_u32','nodes','next_node_id_u32','task_variables','next_variable_id_u32','definitions','market_records']
EVENT_KEYS=['root','bank','event_registers','scratch_words','arena','temporary_event_index_s32','tree_root_u32','nodes','next_node_id_u32','task_variables','next_variable_id_u32','definitions']
SHARED=['root','root_tail','bank','event_registers','module_globals','program','temporary_event_index_s32']
BYTE_KEYS=['root','root_tail','bank','event_registers','module_globals','program','metadata','scratch_words','arena']
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def word(raw,at=0):return struct.unpack_from('<I',raw,at)[0]
def pword(raw,at,value):struct.pack_into('<I',raw,at,value&MASK)
def command(kind,op,args=(),slot=-1,ip=MASK):return {'kind':kind,'operation':op,'args':list(args),'task_slot_s32':slot,'ip_u32':ip}

def event_overlay(host):
 """New callback transport only: import measured allocator deltas, not trees."""
 old='else{CHECK(owner==6&&ref>0&&ref<next_variable&&variable_live[ref-1]);dst=variable_pool[ref-1];size=variable_length[ref-1];}'
 new='''else if(owner==7){CHECK(ref==next_variable&&ref<=CAP&&!variable_live[ref-1]&&off==0&&len>=8&&len<=1024&&len%4==0);variable_live[ref-1]=1;variable_length[ref-1]=len;next_variable++;copyin(&p,variable_pool[ref-1],len);continue;}
  else if(owner==8){CHECK(ref>0&&ref<next_variable&&ref<=CAP&&variable_live[ref-1]&&off==0&&len==0);variable_live[ref-1]=0;continue;}
  else{CHECK(owner==6&&ref>0&&ref<next_variable&&variable_live[ref-1]);dst=variable_pool[ref-1];size=variable_length[ref-1];}'''
 if host.count(old)!=1:raise ValueError('Event callback heap overlay site differs')
 host=host.replace(old,new).replace('CHECK(patches<=32);','CHECK(patches<=256);')
 marker='uint32_t patches=read32(&p);CHECK(patches<=256);'
 if host.count(marker)!=1:raise ValueError('Event callback arena normalization site differs')
 host=host.replace(marker,'''for(uint32_t slot=0;slot<150;slot++){uint8_t*task=s_arena+slot*36;setword(task+32,variableid(word(task+32)));setword(task+28,descriptor_token(word(task+28)));}
 '''+marker)
 # Registry journal replay is transport, not a second source invocation in the
 # composed order. Original tree instructions still execute without alteration.
 host=host.replace('static uint32_t next_node,','static uint32_t overlay_replay;\nstatic uint32_t next_node,')
 host=host.replace('void c_trace(uint32_t id){CHECK','void c_trace(uint32_t id){if(overlay_replay)return;CHECK')
 marker='for(uint32_t i=0;i<actions;i++){uint32_t op=read32(&p),n=read32(&p),values[6];CHECK(n<=6);for(uint32_t j=0;j<n;j++)values[j]=read32(&p);action(op,n,values);}'
 if host.count(marker)!=1:raise ValueError('Event callback registry overlay site differs')
 host=host.replace(marker,'overlay_replay=1;'+marker+'overlay_replay=0;')
 return host

def changed_chunks(before,after,limit=64):
 if len(before)!=len(after):raise ValueError('A projected owner changed extent')
 result=[];at=0
 while at<len(before):
  if before[at]==after[at]:at+=1;continue
  start=at;at=min(len(before),start+limit)
  result.append((start,after[start:at]))
 return result

def fixed_patches(before,after,keys,exclude=()):
 out=[]
 for owner,key in enumerate(keys):
  if key in exclude:continue
  a=struct.pack('<I',before[key]&MASK)if isinstance(before[key],int)else bytes.fromhex(before[key])
  b=struct.pack('<I',after[key]&MASK)if isinstance(after[key],int)else bytes.fromhex(after[key])
  for offset,data in changed_chunks(a,b):out.append({'owner':owner,'offset':offset,'hex':data.hex()})
 return out

def event_packet(row):
 # The frozen Events source adapter packet gains two transport owner numbers:
 # 7 imports a measured new logical allocation, 8 imports a measured free.
 args=row['args'];flat=sum(args,[])if row['operation']in['F42','F43']else args
 raw=V.words([V.OPERATIONS.index(row['operation']),*(flat+[0]*12)[:12]])+V.context_packet(row['context_before'])+V.u32(len(row.get('scripts',[])))
 for script in row.get('scripts',[]):
  raw+=V.words([V.KIND_IDS[script['kind']],len(script['args']),*script['args'],script['return_u32']]);patches=script['patches'];raw+=V.u32(len(patches))
  for patch in patches:
   data=bytes.fromhex(patch['hex']);raw+=V.words([patch['owner'],patch.get('ref',0),patch['offset'],len(data)])+data
  actions=script.get('registry_actions',[]);raw+=V.u32(len(actions))
  for action in actions:raw+=V.words([int(action['operation'][1:]),len(action['args']),*action['args']])
 return V.u32(len(raw)+4)+raw

def model_assembly(source):
 # The old replacement oracle returns338 body bytes. This new transport also
 # records actual entries in an output trailer that was previously a canary.
 text=M.assembly(source)
 for number in M.NUMBERS:
  marker='FUNC_%06d:\n'%number
  if text.count(marker)!=1:raise ValueError('Model entry trace site differs')
  code='pushfq\npush rax\nmov eax,DWORD PTR [runtime_model_count]\nmov DWORD PTR [runtime_model_trace+rax*4],%d\ninc DWORD PTR [runtime_model_count]\npop rax\npopfq\n'%number
  text=text.replace(marker,marker+code,1)
 text=text.replace('mov DWORD PTR [lookup_calls],0','mov DWORD PTR [lookup_calls],0\nmov DWORD PTR [runtime_model_count],0')
 marker=' mov esi,OFFSET FLAT:output\n'
 if text.count(marker)!=1:raise ValueError('Model trace output site differs')
 text=text.replace(marker,' mov ecx,DWORD PTR [runtime_model_count]\n mov DWORD PTR [output+816],ecx\n mov esi,OFFSET FLAT:runtime_model_trace\n mov edi,OFFSET FLAT:output+784\n mov ecx,8\n rep movsd\n'+marker)
 text+='\n.section .bss\n.balign 4\nruntime_model_trace: .zero 32\nruntime_model_count: .zero 4\n'
 return text

class Native:
 def __init__(self,folder,proof):
  self.binaries={};self.measurements=[];self.proof=proof
  for kind,module in [('expression',E),('store',S),('guards',G),('tasks',T),('events',V),('model',M)]:
   work=Path(folder)/kind;work.mkdir();meta,source,*_=module.verify(module.PROOF)
   if kind in['expression','store']:binary=module.build(meta,source,work)[0]
   elif kind=='guards':binary=G.build(meta,source,work)
   elif kind=='tasks':binary=T.build(source,work)[0]
   elif kind=='events':
    kernel=V.adapt(source);host=event_overlay(V.HOST_C);binary=V.compile_native(kernel,host,work)
    (proof/'events-callback-heap-overlay.c').write_text(host)
    self.events_assembly_sha=sha(kernel.encode());self.events_before_sha=sha(V.HOST_C.encode());self.events_overlay_sha=sha(host.encode())
   else:
    asm=model_assembly(source);(proof/'model-composition-native.s').write_text(asm);(work/'native.s').write_text(asm);subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],check=True);subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],check=True);binary=work/'native'
   self.binaries[kind]=binary
  self.models=json.loads(M.RESOURCE.read_text())
 def run(self,kind,row):
  if kind=='events':packet=event_packet(row)
  elif kind=='model':packet=M.packet(row)
  else:packet={'expression':E,'store':S,'guards':G,'tasks':T}[kind].packet(row)
  process=subprocess.run([str(self.binaries[kind])],input=packet,capture_output=True,timeout=30)
  self.measurements.append({'kind':kind,'name':row['name'],'input_sha256':sha(packet),'output_sha256':sha(process.stdout),'exit_code':process.returncode})
  if process.returncode or process.stderr:raise ValueError(('Native composition child failed',kind,row['name'],process.returncode,process.stderr[:300]))
  raw=process.stdout
  if kind=='events':
   value=V.decode(raw,row);result=value['expected'];result['status']=value['status'];result['observations']=value['observations'];result['pending']=value['pending']
   result.setdefault('return_u32',0)
   if row['operation']=='F51':result['return_u32']=result['allocated_slot_s32']&MASK;result['return_defined']=True
  elif kind in['expression','store']:
   module=E if kind=='expression'else S;h=struct.unpack_from('<16I',raw);status=h[2];copyraw=bytearray(raw);pword(copyraw,8,0);decode_row=copy.deepcopy(row);decode_row['scripts']=[None]*h[4];result=module.decoded_output(bytes(copyraw),decode_row);result['status']=status
   result['pending']=result['observations'][-1]if status else None
  else:
   result={'guards':G,'tasks':T}[kind].decode(raw,row);result['pending']=result['observations'][-1]if result['status']else None
  result['_raw_sha256']=sha(raw);result['_input_sha256']=sha(packet)
  return result

class Session:
 def __init__(self,native,core,policy=None):
  self.native=native;self.core=copy.deepcopy(core);self.world=[];self.calls=[];self.journal=[];self.policy=policy or {};self.counts={};self.measurements=[]
 def view(self,kind,slot,ip,frame):
  c=self.core
  if kind=='events':return {key:copy.deepcopy(c[key])for key in EVENT_KEYS}
  if kind=='tasks':return {'arena':c['arena'],'program':c['program'],'program_base_u32':c['program_base_u32'],'module_refs':{key:value['descriptor_ref_u32']for key,value in c['definitions'].items()},'caller_ip_u32':ip}
  a=bytes.fromhex(c['arena']);p=bytes.fromhex(c['program']);descriptor=word(a,slot*36+28);at=descriptor-c['program_base_u32']
  if kind=='guards':return {'event_registers':c['event_registers'],'program':c['program'],'program_base_u32':c['program_base_u32'],'ip_u32':ip,'task_record':a[slot*36:slot*36+36].hex(),'task_slot_u32':slot,'metadata':c['metadata']}
  identifier=str(word(a,slot*36+32));global_ref=word(p,at+20);global_offset=MASK if global_ref==0 else global_ref-0x60bde0
  result={key:c[key]for key in SHARED};result.update(task_variables=c['task_variables'][identifier],ip_u32=ip,module_global_offset_u32=global_offset)
  if kind=='store':result.update(task_slot_u32=slot,descriptor_ref_u32=descriptor,market_buffer=c['market_records'].get(frame['market_key'],bytes(308).hex()))
  return result
 def merge(self,kind,view,slot,frame):
  c=self.core
  if kind=='events':
   for key in EVENT_KEYS:c[key]=copy.deepcopy(view[key])
  elif kind=='tasks':c['arena']=view['arena']
  elif kind=='guards':
   c['event_registers']=view['event_registers'];a=bytearray.fromhex(c['arena']);a[slot*36:slot*36+36]=bytes.fromhex(view['task_record']);c['arena']=a.hex()
  else:
   identifier=str(word(bytes.fromhex(c['arena']),slot*36+32))
   for key in SHARED:c[key]=view[key]
   c['task_variables'][identifier]=view['task_variables']
   if kind=='store'and frame['market_key']is not None:c['market_records'][frame['market_key']]=view['market_buffer']
 def nested(self,kind,op,args,slot,ip):
  row=command(kind,op,args,slot,ip);index=len(self.calls);self.calls.append(copy.deepcopy(row));result=self.invoke(kind,op,args,slot,ip)
  self.calls[index].update(return_u32=result['return_u32'],return_defined=result['return_defined'],cursor_after_u32=result['cursor_after_u32']);return result
 def world_call(self,name,args,slot,ip,parent,frame):
  index=self.counts.get(name,0);self.counts[name]=index+1;policy=self.policy.get(name+':'+str(index),self.policy.get(name,{}))
  before=copy.deepcopy(self.core);after=copy.deepcopy(before);ret=policy.get('return_u32',0);new_ip=policy.get('ip_after_u32',ip);output=policy.get('output_hex','');actions=copy.deepcopy(policy.get('registry_actions',[]))
  for patch in policy.get('patches',[]):
   key=patch['owner'];value=bytearray.fromhex(after[key]);data=bytes.fromhex(patch['hex']);value[patch['offset']:patch['offset']+len(data)]=data;after[key]=value.hex()
  for key,value in policy.get('market_records',{}).items():after['market_records'][key]=value
  self.core=after;order=[name]
  for action in actions:
   outcome=self.invoke('events',action['operation'],action['args'],slot,ip);order+=outcome['source_order']
  after=copy.deepcopy(self.core)
  if name=='F649'and parent=='store':frame['market_key']=str(args[0])if ret else None
  row={'kind':name,'args':copy.deepcopy(args),'task_slot_s32':slot,'ip_before_u32':ip,'ip_after_u32':new_ip,'before':before,'after':after,'return_u32':ret,'input_hex':'','output_hex':output}
  if actions:row['registry_actions']=actions
  self.world.append(row)
  return {'return_u32':ret,'return_defined':True,'cursor_after_u32':new_ip,'source_order':order,'output_hex':output}
 def close(self,parent,pending,slot,ip,frame):
  name=pending['kind'];args=pending['args']
  if parent in['expression','store','guards']:
   routes={'F31':('expression','F31',[]),'F22':('expression','F22',args),'F34':('guards','F34',args),'F36':('model','F36',args),'F44':('events','F44',args),'F45':('events','F45',args),'F48':('events','F48',args)}
   if name in routes:
    kind,op,childargs=routes[name];return self.nested(kind,op,childargs,slot,ip)
  elif parent=='tasks':
   target=args[0];cursor=pending['cursor_before_u32']
   if name=='F31':return self.nested('expression','F31',[],target,cursor)
   if name=='F37':return self.nested('store','F37',[args[1]],target,cursor)
   if name=='F33':return self.nested('guards','F33',['F44'if args[1]==44 else'F45'],target,0)
   if name=='F51':
    outcome=self.nested('events','F51',args,slot,MASK);outcome['return_u32']=outcome['allocated_slot_s32']&MASK;return outcome
   if name=='F41':return self.world_call(name,args,target,cursor,parent,frame)
  elif parent=='events':
   if name=='event_callback'and args[0]==0x413ff4:
    target=(args[1]-0x60bf50)//36;return self.nested('tasks','F47',[target,args[2]],target,MASK)
   if name=='F53':return self.nested('tasks','F53',[args[0]],args[0],MASK)
   if name=='F52':return self.nested('tasks','F52',[-1,0,0],-1,MASK)
   if name=='F41':return self.world_call(name,[args[0]],args[0],args[1]-self.core['program_base_u32'],parent,frame)
  return self.world_call(name,args,slot,ip,parent,frame)
 def script(self,kind,pending,after,closed,journal):
  before=pending['before'];ret=closed['return_u32'];base={'kind':0 if kind=='events'else int(pending['kind'][1:]),'args':pending['args'],'return_u32':ret}
  if kind=='tasks':
   patches=[{'offset':at,'hex':data.hex()}for at,data in changed_chunks(bytes.fromhex(before['arena']),bytes.fromhex(after['arena']))]
   return base|{'cursor_kind':pending['cursor_kind'],'cursor_after_u32':MASK if pending['cursor_kind']=='none'else closed['cursor_after_u32'],'patches':patches}
  if kind=='guards':return base|{'ip_after_u32':after['ip_u32'],'patches':fixed_patches(before,after,['event_registers','task_record'])}
  if kind in['expression','store']:
   keys=E.CONTEXT_KEYS if kind=='expression'else S.CONTEXT_KEYS
   patches=fixed_patches(before,after,keys,exclude=['program','module_global_offset_u32','task_slot_u32','descriptor_ref_u32'])
   if len(patches)>12:raise ValueError(('Native fixed patch capacity',kind,len(patches)))
   return base|{'patches':patches,'output_hex':closed.get('output_hex','')}
  patches=[]
  added=sorted(int(key)for key in after['task_variables']if key not in before['task_variables'])
  if added!=list(range(before['next_variable_id_u32'],after['next_variable_id_u32'])):raise ValueError('Native callback transport excludes transient allocation gaps')
  for key,value in after['task_variables'].items():
   if key not in before['task_variables']:patches.append({'owner':7,'ref':int(key),'offset':0,'hex':value})
  for key in before['task_variables']:
   if key not in after['task_variables']:patches.append({'owner':8,'ref':int(key),'offset':0,'hex':''})
  for owner,key in enumerate(V.OWNER_KEYS):
   a=struct.pack('<I',before[key]&MASK)if isinstance(before[key],int)else bytes.fromhex(before[key]);b=struct.pack('<I',after[key]&MASK)if isinstance(after[key],int)else bytes.fromhex(after[key])
   for at,data in changed_chunks(a,b):patches.append({'owner':owner,'offset':at,'hex':data.hex()})
  for key,value in after['task_variables'].items():
   if key in before['task_variables']:
    for at,data in changed_chunks(bytes.fromhex(before['task_variables'][key]),bytes.fromhex(value)):patches.append({'owner':6,'ref':int(key),'offset':at,'hex':data.hex()})
  return {'kind':pending['kind'],'args':pending['args'],'return_u32':ret,'patches':patches,'registry_actions':copy.deepcopy(journal)}
 def invoke(self,kind,op,args,slot,ip):
  if kind=='model':
   index,model=args;bank=bytearray.fromhex(self.core['bank']);at=116+index*338;row={'name':'composed-model','operation':'F36','model_index_u32':model,'resource':M.model_resource(self.native.models,model),'before_body_hex':bank[at:at+338].hex(),'unused_source_hex':bytes(338).hex()};raw=M.run(self.native.binaries['model'],M.packet(row));resource=row['resource'];header=struct.unpack_from('<4I',raw)
   if header[:3]!=(0x1533fac7,0,1)or raw[820:]!=b'\xa5'*28 or raw[354:692].hex()!=row['unused_source_hex']or raw[692:760].hex()!=resource['descriptor_hex']or raw[760:784]!=bytes.fromhex(resource['physical_spec_hex']).ljust(24,b'\0'):raise ValueError('Native model composition transport/canary differs')
   bank[at:at+338]=raw[16:354];self.core['bank']=bank.hex()
   self.measurements.append({'kind':'model','input_sha256':sha(M.packet(row)),'output_sha256':sha(raw)})
   count=word(raw,816)
   if count<1 or count>8 or word(raw,784)!=36:raise ValueError('Model native entry trace differs')
   return {'cursor_after_u32':ip,'return_u32':0,'return_defined':False,'source_order':['F%d'%word(raw,784+index*4)for index in range(count)]}
  frame={'market_key':None};initial=self.view(kind,slot,ip,frame);scripts=[];children=[];cursor=ip
  for attempt in range(256):
   row={'name':'composed-'+kind+'-'+op,'operation':op,'args':args,'context_before':initial,'scripts':scripts}
   if kind=='store':row['value_u32']=args[0]
   result=self.native.run(kind,row)
   if not result['status']:
    self.merge(kind,result['context_after'],slot,frame)
    if kind in['expression','store','guards']:cursor=result['context_after']['ip_u32']
    elif kind=='tasks':cursor=result['context_after']['caller_ip_u32']
    if kind=='events'and op in['F44','F45','F50','F56']:self.journal.append({'operation':'F50'if op=='F56'else op,'args':[]if op=='F56'else copy.deepcopy(args)})
    expanded=[]
    for index,name in enumerate(result['source_order']):
     expanded.append(name)
     for child in children:
      if child['at']==index:
       order=child['order'];expanded+=order[1:]if order and order[0]==name else order
    output={'cursor_after_u32':cursor,'return_u32':result.get('return_u32',0),'return_defined':result.get('return_defined',False),'source_order':expanded}
    if 'allocated_slot_s32'in result:output['allocated_slot_s32']=result['allocated_slot_s32']
    self.measurements.append({'kind':kind,'operation':op,'input_sha256':result['_input_sha256'],'output_sha256':result['_raw_sha256']})
    return output
   pending=result['pending'];self.merge(kind,pending['before'],slot,frame)
   if kind in['expression','store','guards']:cursor=pending['before']['ip_u32']
   start=len(self.journal);closed=self.close(kind,pending,slot,cursor,frame);new_ip=closed['cursor_after_u32']if kind in['expression','store','guards']else ip
   if kind=='tasks':new_ip=closed['cursor_after_u32']if pending['cursor_kind']=='caller'else pending['before']['caller_ip_u32']
   after=self.view(kind,slot,new_ip,frame);scripts.append(self.script(kind,pending,after,closed,self.journal[start:]));children.append({'at':len(result['source_order'])-1,'order':closed['source_order']})
  raise ValueError('Native composition bounded continuation limit')

def base_core():
 task=T.synthetic_context(slot=7,state=1,generation=3,cleanup=-1,count=0,argc=0,caller=32);expr=E.base_context(bytes.fromhex(task['program']));events=V.baseline();resource=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());c={key:expr[key]for key in SHARED};c.update({key:events[key]for key in EVENT_KEYS if key not in c});c.update(program_base_u32=task['program_base_u32'],metadata=resource['regions']['expression_metadata']['hex'],arena=task['arena'],market_records={})
 c['definitions']={str(index):{'descriptor_ref_u32':ref,'cleanup_instruction_u32':0,'variable_words_u32':4}for index,ref in enumerate(task['module_refs'].values())}
 c['task_variables']={'1':struct.pack('<4I',7,0,0x11223344,0x55667788).hex()};c['next_variable_id_u32']=2
 p=bytearray.fromhex(c['program']);a=bytearray.fromhex(c['arena']);pword(a,7*36+32,1)
 # All frame descriptors have a real logical globals binding; argc0 by default.
 for module in range(4):pword(p,0x100+module*64+20,0x60bde0)
 c['program']=p.hex();c['arena']=a.hex();return c

def cases():
 rows=[]
 def add(name,kind,op,args=(),slot=-1,ip=MASK,c=None,policy=None,carry=False):
  rows.append({'name':name,'context_before':copy.deepcopy(c or base_core()),'command':command(kind,op,args,slot,ip),'policy':policy or {},'carries_previous_native_state':carry});return rows[-1]
 # Real F51 allocation, argument F31 caller, and F37 callee cursor composition.
 for argc in[0,1,2,4]:
  c=base_core();p=bytearray.fromhex(c['program']);pword(p,0x108,argc)
  for index in range(argc):p[32+index*5:37+index*5]=E.immediate(0x10000101+index)
  c['program']=p.hex();add('F52-real-allocation-argc%d'%argc,'tasks','F52',[7,0,0x12345678],7,32,c)
 c=base_core();a=bytearray.fromhex(c['arena']);a[:36]=T.task_bytes(0,0,0xffff);c['arena']=a.hex();add('F52-valid-zero-handle-after-wrap','tasks','F52',[-1,0,0],-1,MASK,c)
 # Direct original DOS F47 no-count variant and real predicate reads.
 for count,index,value in[(0,0,0),(0,0,1),(1,2,1),(2,1,MASK)]:
  c=base_core();p=bytearray.fromhex(c['program']);pword(p,0x304,count);at=0x50+index*8;p[at:at+5]=E.immediate(value);c['program']=p.hex();add('F47-count%d-index%d-value%x'%(count,index,value),'tasks','F47',[7,index],7,MASK,c,{'F41':{'ip_after_u32':at+6}})
 # Actual Guard/F31/registry cleanup and generation, not typed F33 stubs.
 for cleanup in[-1,0]:
  c=base_core();p=bytearray.fromhex(c['program']);pword(p,0x10c,cleanup);c['program']=p.hex();c['definitions']['0']['cleanup_instruction_u32']=c['program_base_u32']+0x10 if cleanup==0 else 0
  add('F38-real-unregister-cleanup%d'%cleanup,'tasks','F38',[(3<<16)|7],7,MASK,c)
 # Initial F41 remains typed; all predicate/register/heap work is real native.
 for count in[0,1,2]:
  c=base_core();p=bytearray.fromhex(c['program']);pword(p,0x304,count)
  for index in range(count):p[0x50+index*8:0x55+index*8]=E.immediate(0)
  c['program']=p.hex();add('F53-real-false-predicates-%d'%count,'tasks','F53',[7],7,MASK,c)
 # Store -> real model replacement -> real dispatch.
 for model in[38,117,155]:
  c=base_core();p=bytearray.fromhex(c['program']);stream=S.authored_program(61,[17]);p[0x20:0x20+len(stream)]=stream;c['program']=p.hex();add('F37-real-model-%d'%model,'store','F37',[model],7,32,c)
 # Event callback snapshot -> actual F47/F31 -> one explicit statement worker.
 c=base_core();p=bytearray.fromhex(c['program']);p[0x50:0x55]=E.immediate(1);c['program']=p.hex();key=[3,c['program_base_u32']+0x100,2,0x413ff4,0x60bf50+7*36,0];c['nodes']={'1':V.node(key)};c['tree_root_u32']=1;c['next_node_id_u32']=2;add('F48-snapshot-actual-task-F47','events','F48',key[:3],7,MASK,c)
 c=copy.deepcopy(c);c['task_variables']['2']=struct.pack('<4I',7,0,33,44).hex();c['next_variable_id_u32']=3
 add('F48-live-descriptor-and-variable-retarget','events','F48',key[:3],7,MASK,c,{'F41':{'patches':[{'owner':'arena','offset':7*36+28,'hex':struct.pack('<2I',c['program_base_u32']+0x140,2).hex()}]}})
 # Real F55 clears scratch, boots F52/F51, then schedules F53. The unchanged F41
 # provider leaves state3; original F53 final registration completes startup.
 c=base_core();add('F55-real-boot-allocation','events','F55',[], -1,MASK,c)
 # Dependent market writes retain one keyed308-byte owner across commands.
 for index,value in enumerate([0x10203040,0xffffffff,0x12345678,0x80000000,0]):
  c=base_core();p=bytearray.fromhex(c['program']);stream=S.authored_program(66,[9,1002]);p[0x20:0x20+len(stream)]=stream;c['program']=p.hex();market=struct.pack('<77I',*(0x44550000+i for i in range(77))).hex();c['market_records']={'9':market};add('market-key9-dependent-%d'%index,'store','F37',[value],7,32,c,{'F649':{'return_u32':1}},index>0)
 # Cancellation then actual scheduler frees variable owner and clears task.
 c=base_core();a=bytearray.fromhex(c['arena']);pword(a,7*36,6);c['arena']=a.hex();add('F54-real-final-free','events','F54',[],7,MASK,c)
 # Full unchanged original resource graph with all105 descriptor bindings.
 c=original_core();add('original-module0-F52-real-allocation','tasks','F52',[-1,0,0],-1,MASK,c)
 c=original_core(1);add('original-module1-F53-real-initialization','tasks','F53',[7],7,MASK,c)
 c=original_core(2);registers=bytearray.fromhex(c['event_registers']);pword(registers,40*4,0x12345678);c['event_registers']=registers.hex();add('original-module2-clause1-real-expression','expression','F31',[],7,13171,c)
 c=original_core();a=bytearray.fromhex(c['arena']);a[7*36:7*36+36]=bytes(36);c['arena']=a.hex();c['task_variables']={};c['next_variable_id_u32']=1
 add('original-F55-real-boot-and-free','events','F55',[],-1,MASK,c,{'F41':{'patches':[{'owner':'arena','offset':0,'hex':struct.pack('<I',6).hex()}]}})
 c=full_arena_core();add('F51-full-arena-NULL-physical-pointer','events','F51',[0,0],-1,MASK,c)
 return rows

def original_core(module=0):
 c=base_core();doc=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());c['program']=doc['regions']['mission']['hex'];c['program_base_u32']=doc['regions']['mission']['original_va_u32'];c['module_globals']=doc['module_globals_initialization']['initial_hex'];p=bytes.fromhex(c['program']);base=c['program_base_u32'];c['definitions']={}
 for row in doc['modules']:
  index=row['module_index_u32'];at=row['descriptor_offset_u32'];cleanup=row['cleanup_block_index_s32'];instruction=0
  if cleanup>=0:instruction=word(p,word(p,at+28+cleanup*4)-base)
  c['definitions'][str(index)]={'descriptor_ref_u32':base+at,'cleanup_instruction_u32':instruction,'variable_words_u32':row['variable_words_u32']}
 d=c['definitions'][str(module)];at=d['descriptor_ref_u32']-base;block=word(p,at+28);a=bytearray(5400);a[7*36:7*36+36]=T.task_bytes(7,4,3,module,d['descriptor_ref_u32'],block);pword(a,7*36+8,0);pword(a,7*36+32,1);c['arena']=a.hex();c['task_variables']={'1':(struct.pack('<2I',(3<<16)|7,0)+bytes([0xa5])*(d['variable_words_u32']*4-8)).hex()};return c

def full_arena_core():
 c=base_core();a=bytearray.fromhex(c['arena'])
 for slot in range(150):a[slot*36:slot*36+36]=T.task_bytes(slot,1,3,0,c['program_base_u32']+0x100,c['program_base_u32']+0x300)
 c['arena']=a.hex();return c

def fault_domains(native):
 core=full_arena_core();session=Session(native,core);allocator=session.invoke('events','F51',[0,0],-1,MASK)
 if allocator['return_u32']!=MASK:raise ValueError('Full actual native arena unexpectedly allocates')
 row={'name':'F52-full-arena-null-original-fault','operation':'F52','args':[-1,0,0],'context_before':session.view('tasks',-1,MASK,{}),'scripts':[{'kind':51,'args':[0,0],'return_u32':MASK,'cursor_kind':'none','cursor_after_u32':MASK,'patches':[]}]};results=[T.run(native.binaries['tasks'],row)for _ in range(3)]
 if any(result.returncode!=-11 or result.stdout for result in results):raise ValueError('Actual original F52 null dereference fault differs')
 return [{'name':row['name'],'context_before':core,'command':command('tasks','F52',[-1,0,0],-1,MASK),'observations':[],'source_signal':'SIGSEGV','native_returncode':-11,'actual_native_process_returncode':-11,'fresh_native_processes':3,'fresh_native_process_runs':3,'actual_allocator_return_u32':MASK,'allocator_measurements':session.measurements,'failing_task_input_sha256':sha(T.packet(row)),'after_state_claimed':False,'expected_complete_native_context_after_available':False,'normal_case_count_includes_fault':False}]

def pool_context(context,pool):
 result=copy.deepcopy(context)
 def encode(raw):
  data=bytes.fromhex(raw);key=sha(data)
  if key not in pool:pool[key]={'byte_count':len(data),'zlib_base64':base64.b64encode(zlib.compress(data,9)).decode()}
  return key
 for key in BYTE_KEYS:result[key]=encode(result[key])
 for owner in['task_variables','market_records']:
  result[owner]={key:encode(value)for key,value in result[owner].items()}
 return result
def hydrate_context(document,context):
 result=copy.deepcopy(context)
 def decode(key):
  row=document['buffer_pool'][key];raw=zlib.decompress(base64.b64decode(row['zlib_base64']))
  if len(raw)!=row['byte_count']or sha(raw)!=key:raise ValueError('Composed pooled bytes differ')
  return raw.hex()
 for key in BYTE_KEYS:result[key]=decode(result[key])
 for owner in['task_variables','market_records']:result[owner]={key:decode(value)for key,value in result[owner].items()}
 return result

def generate(a):
 a.proof_dir.mkdir(parents=True,exist_ok=True);rows=cases();pool={};serialized=[];previous=None;all_measurements=[]
 with tempfile.TemporaryDirectory(prefix='mission-runtime-native-')as directory:
  native=Native(directory,a.proof_dir)
  for row in rows:
   if row['carries_previous_native_state']:row['context_before']=copy.deepcopy(previous['context_after'])
   results=[]
   for cohort in range(3):
    session=Session(native,row['context_before'],row['policy']);cmd=row['command'];result=session.invoke(cmd['kind'],cmd['operation'],cmd['args'],cmd['task_slot_s32'],cmd['ip_u32']);result.update(context_after=copy.deepcopy(session.core),dependency_calls=copy.deepcopy(session.calls),world_observations_used=len(session.world));results.append((result,session.world,session.measurements))
   if results[0]!=results[1]or results[0]!=results[2]:raise ValueError('Fresh composition cohorts differ '+row['name'])
   expected,world,measurements=results[0];previous=expected;all_measurements+=measurements
   obs=[]
   for observation in world:
    value=copy.deepcopy(observation);value['before']=pool_context(value['before'],pool);value['after']=pool_context(value['after'],pool);obs.append(value)
   stored=copy.deepcopy(expected);stored['context_after']=pool_context(stored['context_after'],pool)
   serialized.append({'name':row['name'],'command':row['command'],'context_before':pool_context(row['context_before'],pool),'observations':obs,'expected':stored,'carries_previous_native_state':row['carries_previous_native_state'],'native_measurements':measurements})
   print(row['name'],len(expected['dependency_calls']),len(world),flush=True)
  # Reverse cohort independently recomposes all original before contexts. The
  # child binaries each execute a fresh process; this also detects router state.
  for row,wanted in zip(reversed(rows),reversed(serialized)):
   session=Session(native,row['context_before'],row['policy']);cmd=row['command'];value=session.invoke(cmd['kind'],cmd['operation'],cmd['args'],cmd['task_slot_s32'],cmd['ip_u32']);value.update(context_after=copy.deepcopy(session.core),dependency_calls=copy.deepcopy(session.calls),world_observations_used=len(session.world));target=copy.deepcopy(wanted['expected']);target['context_after']=hydrate_context({'buffer_pool':pool},target['context_after'])
   if value!=target:raise ValueError('Reverse composition cohort differs '+row['name'])
  faults=fault_domains(native)
  for fault in faults:fault['context_before']=pool_context(fault['context_before'],pool)
  overlay={'schema':'starfrontier-mission-runtime-native-overlay-v1','source_event_host_sha256':native.events_before_sha,'overlay_event_host_sha256':native.events_overlay_sha,'source_event_assembly_unchanged_sha256':native.events_assembly_sha,'new_owner7':'Consecutive surviving monotonic allocations with exact bytes measured by child original F51; imports liveness, length and advances next ID.','new_owner8':'Logical free measured by child original allocator worker; imports liveness only, preserving stale allocation addresses.','allocation_profile_restriction':'Transient allocated-and-freed IDs and gaps in new surviving logical variable IDs are explicitly rejected by this native transport; no fake objects or bytes are synthesized.','arena_pointer_roundtrip':'Normalize arena descriptor+28/variable+32 pointer fields before partial byte deltas, then import after all measured allocator deltas.','registry_replay':'Calls actual original F44/F45/F50 in the same native process; existing snapshot and tree pointers are retained. Replay trace is suppressed to avoid counting child instructions twice.','model_entry_trace':'New transport preserves EAX and flags while recording actual F36/F1538/F1495/F1341 entries in a32-byte output trailer; remaining28-byte canary and readonly resources remain checked. Source model arithmetic instructions are unchanged.','game_instructions_modified':False,'expected_arithmetic_calculated_in_python':False}
  (a.proof_dir/'overlay-proof.json').write_text(json.dumps(overlay,indent=2)+'\n')
 dependencies=['tools/rebuild_source_mission_runtime_native.py','tools/rebuild_source_mission_expression_native.py','tools/rebuild_source_mission_store_native.py','tools/rebuild_source_mission_guards_native.py','tools/rebuild_source_mission_task_native.py','tools/rebuild_source_events_native.py','tools/rebuild_source_model_replace_native.py','data/ffe_mission_programs.json','data/ffe_mission_models.json']
 for module in[E,S,G,T,V,M]:
  captured=json.loads(module.FIXTURE.read_text())
  for path in captured['source_dependencies_sha256']:
   if path not in dependencies:dependencies.append(path)
 proofs={str(path.relative_to(PROJECT)):sha(path.read_bytes())for module in[E,S,G,T,V,M]for path in[module.PROOF/'instruction-proof.json',module.PROOF/'source-procedures.asm']}
 proofs.update({str((PROOF/path.name).relative_to(PROJECT)):sha(path.read_bytes())for path in[a.proof_dir/'events-callback-heap-overlay.c',a.proof_dir/'overlay-proof.json',a.proof_dir/'model-composition-native.s']})
 document={'schema':'starfrontier-mission-runtime-native-v1','profile':PROFILE,'case_count':len(serialized),'fresh_process_runs':3,'reverse_repeat_cases':len(serialized),'consecutive_shared_state_steps':sum(row['carries_previous_native_state']for row in rows),'source_executable_sha256':E.N.EXE_SHA,'source_assembly_sha256':E.N.ASM_SHA,'source_dependencies_sha256':{path:sha((PROJECT/path).read_bytes())for path in dependencies},'proofs_sha256':proofs,'buffer_codec':'sha256-zlib-base64-v1','buffer_pool':pool,'native_measurement_count':len(all_measurements),'native_measurements_sha256':sha(json.dumps(all_measurements,sort_keys=True,separators=(',',':')).encode()),'whole_executable_constituent_procedures':42,'whole_executable_constituent_instructions':2690,'additional_readonly_anchor_procedures':1,'additional_readonly_anchor_instructions':10,'explicit_world_boundary_count':sum(len(row['observations'])for row in serialized),'expected_arithmetic_calculated_in_python':False,'actual_allocator_callback_overlay':True,'native_fault_domains_separate':faults,'native_transport_restrictions':['Only consecutive net surviving allocator additions; transient allocation gaps rejected.'],'full_F41_VM_executed':False,'Main_integrated':False,'cases':serialized,'scope':'Native composition of proved expression/store/guard/task/events/model kernels over Core18; F41 and remaining world workers are explicit flat observations.'}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(document,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'native_measurements':len(all_measurements),'bytes':a.output.stat().st_size},indent=2))
 spec={'schema':'starfrontier-mission-runtime-native-spec-v1','profile':PROFILE,'context_keys':KEYS,'command_keys':['kind','operation','args','task_slot_s32','ip_u32'],'world_keys':['kind','args','task_slot_s32','ip_before_u32','ip_after_u32','before','after','return_u32','input_hex','output_hex'],'world_optional_keys':['registry_actions'],'fixture_sha256':sha(a.output.read_bytes()),'case_count':len(rows),'F41_remains_explicit':True,'Main_integrated':False}
 (a.proof_dir/'runtime-contract.json').write_text(json.dumps(spec,indent=2)+'\n')

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE)
 # The frozen verifier passes deliberately absent originals. Composition reads
 # the independently sealed constituent captures, never these optional paths.
 for name in['exe','asm','data']:p.add_argument('--'+name,type=Path,default=None)
 a=p.parse_args();generate(a)
if __name__=='__main__':main()
