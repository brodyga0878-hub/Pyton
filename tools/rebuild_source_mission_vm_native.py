#!/usr/bin/env python3
"""Native composition of actual F41 and the sealed mission kernels over Core21.

The router transports measured native owners and explicit authored world replies.
It never evaluates game arithmetic. Original statement frames execute in native
kernels; F41 is never an external world provider.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,json,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_mission_runtime_native as R
import rebuild_source_mission_statements_native as Q
import rebuild_source_mission_spawn_native as P
PROJECT=R.PROJECT
PROOF=PROJECT/'validation/mission-statements-2026-11-19/vm-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_vm_native.json'
SPEC=PROJECT/'validation/mission-statements-2026-11-19/native-vm-spec.json'
PROFILE='dos-firstenc-composed-mission-vm-v1';MASK=R.MASK
KEYS=R.KEYS+['text_buffer','text_cursor_u32','vectors']
BYTE_KEYS=R.BYTE_KEYS+['text_buffer','vectors']
WORLD_KEYS=['kind','args','task_slot_s32','ip_before_u32','ip_after_u32','before','after','return_u32','input_hex','output_hex','input_defined_hex','output_defined_hex']
sha=R.sha;word=R.word;pword=R.pword
def scratch(fill=0xa7,defined=0):return {'seed_hex':(bytes([fill])*156).hex(),'defined_hex':(bytes([defined])*156).hex()}
def command(kind='statements',op='F41',args=(),slot=7,ip=128,frames=None):return R.command(kind,op,args,slot,ip)|{'statement_frames':copy.deepcopy(frames if frames is not None else[scratch()]if kind=='statements'else[])}
class Native(R.Native):
 def __init__(self,folder,proof):
  super().__init__(folder,proof)
  for kind,module in [('statements',Q),('spawn',P)]:
   work=Path(folder)/kind;work.mkdir();meta,source=module.verify(module.PROOF);binary,asm=module.build(meta,source,work);self.binaries[kind]=binary
   (proof/(kind+'-composition-native.s')).write_text(asm)
   (proof/(kind+'-composition-host.c')).write_text(Q.HOST_C if kind=='statements'else P.C)
 def run(self,kind,row):
  if kind not in ['statements','spawn']:return super().run(kind,row)
  module=Q if kind=='statements'else P;packet=module.packet(row);done=subprocess.run([str(self.binaries[kind])],input=packet,capture_output=True,timeout=30)
  self.measurements.append({'kind':kind,'name':row['name'],'input_sha256':sha(packet),'output_sha256':sha(done.stdout),'exit_code':done.returncode})
  if done.returncode or done.stderr:raise ValueError(('Native VM child failed',kind,row['name'],done.returncode,done.stderr[:300]))
  result=module.decode(done.stdout,row);result['_raw_sha256']=sha(done.stdout);result['_input_sha256']=sha(packet)
  return result
class Session(R.Session):
 def __init__(self,native,core,frames,policy=None):
  super().__init__(native,core,policy);self.seeds=copy.deepcopy(frames);self.seed_used=0;self.frames_after=[];self.retired={}
 def view(self,kind,slot,ip,frame):
  c=self.core
  if kind=='spawn':return {key:c[key]for key in P.KEYS}
  if kind=='statements':
   a=bytes.fromhex(c['arena'])
   return {key:c[key]for key in ['root','root_tail','bank','program','program_base_u32','vectors','text_buffer','text_cursor_u32']}|{'ip_u32':ip,'task_record':a[slot*36:slot*36+36].hex(),'task_slot_u32':slot}
  if kind not in ['expression','store']:return super().view(kind,slot,ip,frame)
  a=bytes.fromhex(c['arena']);program=bytes.fromhex(c['program']);descriptor=word(a,slot*36+28);at=descriptor-c['program_base_u32'];identifier=str(word(a,slot*36+32));reference=word(program,at+20);offset=MASK if reference==0 else reference-0x60bde0
  live=identifier in c['task_variables']
  if live:variables=c['task_variables'][identifier];frame['retired_variables']=variables
  elif identifier in self.retired:variables=self.retired[identifier]
  elif 'retired_variables'in frame:variables=frame['retired_variables']
  else:raise ValueError('Native VM selected allocation unavailable outside transport profile')
  frame['variable_live']=live;frame['variable_id']=identifier
  result={key:c[key]for key in R.SHARED}|{'task_variables':variables,'ip_u32':ip,'module_global_offset_u32':offset}
  if kind=='store':result.update(task_slot_u32=slot,descriptor_ref_u32=descriptor,market_buffer=c['market_records'].get(frame['market_key'],bytes(308).hex()))
  return result
 def merge(self,kind,view,slot,frame):
  if kind=='spawn':
   for key in P.KEYS:self.core[key]=view[key]
  elif kind=='statements':
   for key in ['root','root_tail','bank','text_buffer','text_cursor_u32']:self.core[key]=view[key]
   a=bytearray.fromhex(self.core['arena']);a[slot*36:slot*36+36]=bytes.fromhex(view['task_record']);self.core['arena']=a.hex()
  elif kind in ['expression','store']:
   for key in R.SHARED:self.core[key]=view[key]
   identifier=str(word(bytes.fromhex(self.core['arena']),slot*36+32))
   if identifier in self.core['task_variables']:self.core['task_variables'][identifier]=view['task_variables']
   if kind=='store'and frame['market_key']is not None:self.core['market_records'][frame['market_key']]=view['market_buffer']
  else:super().merge(kind,view,slot,frame)
 def world_call(self,name,args,slot,ip,parent,frame):
  if name=='F41':raise ValueError('Native VM cannot fabricate an F41 world reply')
  index=self.counts.get(name,0);self.counts[name]=index+1;policy=self.policy.get(name+':'+str(index),self.policy.get(name,{}));packet=frame.get('packet',{})
  before=copy.deepcopy(self.core);after=copy.deepcopy(before);returned=policy.get('return_u32',0);out=policy.get('output_hex','');outmask=policy.get('output_defined_hex','01'*(len(out)//2));actions=copy.deepcopy(policy.get('registry_actions',[]))
  for patch in policy.get('patches',[]):
   data=bytearray.fromhex(after[patch['owner']]);raw=bytes.fromhex(patch['hex']);data[patch['offset']:patch['offset']+len(raw)]=raw;after[patch['owner']]=data.hex()
  for key,value in policy.get('market_records',{}).items():after['market_records'][key]=value
  if policy.get('free_selected'):
   identifier=str(word(bytes.fromhex(after['arena']),slot*36+32));self.retired[identifier]=after['task_variables'].pop(identifier)
  if 'format_hex'in policy:
   data=bytes.fromhex(policy['format_hex']);key='text_buffer'if args[0]==0 else'bank';owner=bytearray.fromhex(after[key]);owner[args[1]:args[1]+len(data)]=data;after[key]=owner.hex();returned=args[1]+len(data)
  if policy.get('write_packet_tail'):
   data=bytearray.fromhex(packet['input_hex']);known=bytearray.fromhex(packet['input_defined_hex']);pword(data,len(data)-4,0x77889900);known[-4:]=bytes([1])*4;out=data.hex();outmask=known.hex()
  self.core=after;order=[name]
  for action in actions:
   outcome=self.invoke('events',action['operation'],action['args'],slot,ip);order+=outcome['source_order']
  after=copy.deepcopy(self.core)
  if name=='F649'and parent=='store':frame['market_key']=str(args[0])if returned else None
  row={'kind':name,'args':copy.deepcopy(args),'task_slot_s32':slot,'ip_before_u32':ip,'ip_after_u32':ip,'before':before,'after':after,'return_u32':returned,'input_hex':packet.get('input_hex',''),'output_hex':out,'input_defined_hex':packet.get('input_defined_hex',''),'output_defined_hex':outmask}
  if actions:row['registry_actions']=actions
  self.world.append(row);self.journal+=copy.deepcopy(actions)
  return {'return_u32':returned,'return_defined':True,'cursor_after_u32':ip,'source_order':order,'input_hex':row['input_hex'],'output_hex':out,'input_defined_hex':row['input_defined_hex'],'output_defined_hex':outmask}
 def close(self,parent,pending,slot,ip,frame):
  frame.pop('packet',None);name=pending['kind'];args=pending['args']
  if parent=='statements':
   if name=='F31':return self.nested('expression','F31',[],slot,ip)
   if name=='F37':return self.nested('store','F37',[args[1]],slot,ip)
   if name=='F52':return self.nested('tasks','F52',[slot,args[1],args[2]],slot,ip)
   if name=='F38':return self.nested('tasks','F38',args,slot,ip)
   if name=='F48':return self.nested('events','F48',args,slot,ip)
   if name in ['F39','F40']:
    value=self.nested('spawn',name,args,slot,ip)
    if name=='F39':value['return_u32']=0;value['return_defined']=False
    return value
   frame['packet']=pending;return self.world_call(name,args,slot,ip,parent,frame)
  if name=='F41':
   if parent=='tasks':return self.nested('statements','F41',[],args[0],pending['cursor_before_u32'])
   if parent=='events':return self.nested('statements','F41',[],args[0],args[1]-self.core['program_base_u32'])
   raise ValueError('Unrecognized actual F41 native callsite')
  return super().close(parent,pending,slot,ip,frame)
 def script(self,kind,pending,after,closed,journal):
  if kind=='spawn':return {'kind':int(pending['kind'][1:]),'args':pending['args'],'return_u32':closed['return_u32'],'patches':R.fixed_patches(pending['before'],after,P.KEYS),'output_hex':closed.get('output_hex','')}
  if kind=='statements':
   keys=['root','root_tail','bank','task_record','text_buffer','ip_u32','text_cursor_u32']
   return {'kind':int(pending['kind'][1:]),'args':pending['args'],'return_u32':closed['return_u32'],'patches':R.fixed_patches(pending['before'],after,keys),'output_hex':closed.get('output_hex',''),'output_defined_hex':closed.get('output_defined_hex','')}
  if kind in ['expression','store']:
   if len(pending['before']['task_variables'])!=len(after['task_variables'])or pending['before']['module_global_offset_u32']!=after['module_global_offset_u32']:raise ValueError('Native VM excludes dynamic selected extent/global changes within a suspended old helper')
  return super().script(kind,pending,after,closed,journal)
 def invoke(self,kind,op,args,slot,ip):
  if kind=='model':return super().invoke(kind,op,args,slot,ip)
  frame={'market_key':None}
  if kind=='statements':
   if self.seed_used>=len(self.seeds):raise ValueError('Native VM invocation scratch seed missing')
   frame['scratch']=self.seeds[self.seed_used];frame['ordinal']=self.seed_used;self.seed_used+=1
  initial=self.view(kind,slot,ip,frame);scripts=[];children=[];cursor=ip
  for attempt in range(256):
   row={'name':'native-vm-'+kind+'-'+op,'operation':op,'args':args,'context_before':initial,'scripts':scripts}
   if kind=='store':row['value_u32']=args[0]
   if kind=='statements':row['scratch']=frame['scratch']
   result=self.native.run(kind,row)
   if result['status']==2:raise ValueError('Native statement budget outside composition corpus')
   if not result['status']:
    self.merge(kind,result['context_after'],slot,frame)
    if kind in ['expression','store','guards','statements']:cursor=result['context_after']['ip_u32']
    elif kind=='tasks':cursor=result['context_after']['caller_ip_u32']
    if kind=='events'and op in ['F44','F45','F50','F56']:self.journal.append({'operation':'F50'if op=='F56'else op,'args':[]if op=='F56'else copy.deepcopy(args)})
    expanded=[]
    for index,name in enumerate(result['source_order']):
     expanded.append(name)
     for child in children:
      if child['at']==index:
       order=child['order'];expanded+=order[1:]if order and order[0]==name else order
    output={'cursor_after_u32':cursor,'return_u32':result.get('return_u32',0),'return_defined':result.get('return_defined',False),'source_order':expanded}
    if 'allocated_slot_s32'in result:output['allocated_slot_s32']=result['allocated_slot_s32']
    if kind=='statements':self.frames_after.append({'ordinal_u32':frame['ordinal'],'task_slot_u32':slot,'scratch_after_hex':result['scratch_after_hex'],'scratch_defined_hex':result['scratch_defined_hex']})
    self.measurements.append({'kind':kind,'operation':op,'input_sha256':result['_input_sha256'],'output_sha256':result['_raw_sha256']});return output
   pending=result['pending'];self.merge(kind,pending['before'],slot,frame)
   if kind in ['expression','store','guards','statements']:cursor=pending['before']['ip_u32']
   start=len(self.journal);closed=self.close(kind,pending,slot,cursor,frame);new_ip=closed['cursor_after_u32']if kind in ['expression','store','guards','statements']else ip
   if kind=='tasks':new_ip=closed['cursor_after_u32']if pending['cursor_kind']=='caller'else pending['before']['caller_ip_u32']
   after=self.view(kind,slot,new_ip,frame);scripts.append(self.script(kind,pending,after,closed,self.journal[start:]));children.append({'at':len(result['source_order'])-1,'order':closed['source_order']})
  raise ValueError('Native VM continuation bound')

def put(core,at,payload):
 data=bytearray.fromhex(core['program']);data[at:at+len(payload)]=payload;core['program']=data.hex();return core
def base_core():
 core=R.base_core();data=bytearray.fromhex(core['program']);data.extend(bytes(2048-len(data)));pword(data,0x300,core['program_base_u32']+640);core['program']=data.hex();resource=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());core.update(text_buffer=bytes(256).hex(),text_cursor_u32=0,vectors=resource['regions']['vectors']['hex']);variables=bytearray.fromhex(core['task_variables']['1']);pword(variables,0,word(bytes.fromhex(core['arena']),7*36+4));core['task_variables']['1']=variables.hex();return put(core,640,b'\0')
def authored(code,values=None,variant=None):return Q.authored(code,values,variant)[0]
def cases():
 rows=[]
 def add(name,payload=b'\0',core=None,cmd=None,policy=None,frames=None,carry=False):
  c=copy.deepcopy(core or base_core());put(c,128,payload);rows.append({'name':name,'context_before':c,'command':cmd or command(frames=frames),'policy':policy or {},'carries_previous_native_state':carry});return rows[-1]
 add('F41-stop')
 add('F41-out-of-table-bytes',bytes([255,61,0]))
 for code in [4,6,3]:
  payload=bytes([7])+R.E.immediate(0x12345678)+bytes([code])+struct.pack('<I',2)+b'\0'
  add('F41-real-store-selector%d'%code,payload)
 add('F41-real-add-overflow',bytes([7,13])+R.E.immediate(MASK)+R.E.immediate(2)+b'\4'+struct.pack('<I',2)+b'\0')
 add('F41-real-F39-identity',authored(20,[0xdeadbeef]))
 add('F41-UI-private-packet-chain',authored(23,[5])[:-1]+authored(24,[6]),policy={'F345':{'write_packet_tail':True}})
 add('F41-two-formatter-parameters',authored(35,[70])[:-1]+authored(36,[71,42]),policy={'F1344:0':{'format_hex':'4f4b00'},'F1344:1':{'format_hex':'5a00'}})
 add('F41-body-name-alias',authored(26,[17,70]),policy={'F1344':{'format_hex':'414c49415300'}})
 for variant in [None,'utf8']:
  add('F41-inline-NUL-'+str(variant),authored(10,[11,22,33,44],variant),policy={'F101':{'return_u32':33}})
 for value in [0,116+17*338]:
  add('F41-real-spawn-'+str(value),authored(50,[38,1,0x12345678,0x154000,0x8000,MASK,0xffff8000,255,0xffff8001]),policy={'F927':{'return_u32':value,'output_hex':'11000000','patches':[{'owner':'bank','offset':116+17*338+0x86,'hex':'7e'}]if value else[]},'F1507':{'patches':[{'owner':'root','offset':0x200,'hex':'11223344'}]}})
 add('F41-real-F52-allocator-callee-stores',authored(1),frames=[scratch(0x11)])
 add('F54-real-child-F53-F41-continuation',cmd=command('events','F54',[],-1,MASK,[scratch(0x22)]),carry=True)
 add('F55-real-boot-F53-F41',core=base_core(),cmd=command('events','F55',[],-1,MASK,[scratch(0x33)]))
 c=base_core();put(c,640,bytes([8,6])+struct.pack('<I',0)+b'\0')
 add('F55-generation-self-cancel-free',core=c,cmd=command('events','F55',[],-1,MASK,[scratch(0x44)]))
 c=base_core();p=bytearray.fromhex(c['program']);pword(p,0x10c,0);c['program']=p.hex();c['definitions']['0']['cleanup_instruction_u32']=c['program_base_u32']+640
 add('F41-cleanup-self-halt',bytes([8,6])+struct.pack('<I',0)+authored(18,[3]),core=c)
 add('F41-generation-change-continues',bytes([8])+R.E.immediate(0x30007)+authored(18,[3]),policy={'F105':{'patches':[{'owner':'root','offset':0x200,'hex':'01000000'}]}})
 c=base_core();p=bytearray.fromhex(c['program']);pword(p,0x304,1);p[0x50:0x55]=b'\4'+struct.pack('<I',0);p[0x55:0x55+len(authored(18,[3]))]=authored(18,[3]);c['program']=p.hex();a=bytearray.fromhex(c['arena']);a[8*36:9*36]=a[7*36:8*36];pword(a,8*36+4,0x10008);pword(a,8*36+32,2);c['arena']=a.hex();c['task_variables']['2']=bytes(16).hex();c['next_variable_id_u32']=3;regs=bytearray.fromhex(c['event_registers']);pword(regs,0,1);c['event_registers']=regs.hex();key=[4,0x60bf50+7*36,2,0x413ff4,0x60bf50+8*36,0];c['nodes']={'1':R.V.node(key)};c['tree_root_u32']=1;c['next_node_id_u32']=2
 add('F41-real-event-recursive-two-frames',bytes([7])+R.E.immediate(9)+b'\6'+struct.pack('<I',2)+b'\0',core=c,frames=[scratch(0x11),scratch(0x22)],policy={'F105':{'patches':[{'owner':'root','offset':0x200,'hex':'01000000'}]}})
 add('F41-freed-after-last-variable-read',bytes([7,45])+R.E.immediate(9)+b'\4'+struct.pack('<I',2)+b'\0',policy={'F106':{'free_selected':True,'return_u32':11}})
 c=base_core();p=bytearray.fromhex(c['program']);pword(p,0x140+20,0x60bde4);c['program']=p.hex()
 payload=authored(18,[5])[:-1]+bytes([7,5])+struct.pack('<I',0)+b'\4'+struct.pack('<I',2)+b'\0'
 add('F41-descriptor-reread-between-expressions',payload,core=c,policy={'F105':{'patches':[{'owner':'arena','offset':7*36+28,'hex':struct.pack('<I',c['program_base_u32']+0x140).hex()},{'owner':'module_globals','offset':4,'hex':struct.pack('<I',41).hex()}]}})
 add('F41-eleven-argument-service',authored(37),policy={'F314':{'return_u32':7}})
 add('F41-zero-argument-world',bytes([34,0]))
 add('F41-zero-selected-velocity',authored(57,[17]))
 add('F41-private-four-byte-outlocal-provenance',authored(53,[1,0xabcdef98,42])[:-1]+authored(53,[2,0x12345680,43]),policy={'F305':{'output_hex':'78563412','output_defined_hex':'01000001'},'F304':{'output_hex':'21436587','output_defined_hex':'00010100'}})
 c=R.original_core(2);resource=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());c.update(text_buffer=bytes(256).hex(),text_cursor_u32=0,vectors=resource['regions']['vectors']['hex']);rows.append({'name':'original-module2-real-F53-F41-resource-graph','context_before':c,'command':command('tasks','F53',[7],7,MASK,[scratch(0x66)]),'policy':{'F1476':{'return_u32':0x12345678}},'carries_previous_native_state':False})
 c=base_core();market=bytes([0x31])*308;c['market_records']={'9':market.hex()}
 streams=[bytes([7])+R.E.immediate(11)+b'\6'+struct.pack('<I',2)+b'\0',bytes([7])+R.E.immediate(22)+b'\4'+struct.pack('<I',2)+b'\0',bytes([7])+R.E.immediate(33)+b'\x1f'+R.E.immediate(2)+b'\0',bytes([7])+R.E.immediate(44)+b'\x38'+R.E.immediate(17)+b'\0',bytes([7])+R.E.immediate(55)+b'\x42'+R.E.immediate(9)+R.E.immediate(1002)+b'\0',authored(35,[70])]
 for i,payload in enumerate(streams):put(c,1100+i*32,payload)
 for i in range(len(streams)):
  add('shared-Core21-transition-%02d'%i,core=c,cmd=command(ip=1100+i*32),policy={'F649':{'return_u32':1},'F1344':{'format_hex':'d0a0d0a300'}},carry=i>0)
 return rows

def pool_context(context,pool):
 result=copy.deepcopy(context)
 for key in BYTE_KEYS:
  raw=bytes.fromhex(result[key]);name=sha(raw);pool.setdefault(name,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});result[key]={'buffer_sha256':name}
 for owner in ['task_variables','market_records']:
  for key,content in result[owner].items():
   raw=bytes.fromhex(content);name=sha(raw);pool.setdefault(name,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});result[owner][key]={'buffer_sha256':name}
 return result
def execute(native,row):
 session=Session(native,row['context_before'],row['command']['statement_frames'],row['policy']);cmd=row['command'];result=session.invoke(cmd['kind'],cmd['operation'],cmd['args'],cmd['task_slot_s32'],cmd['ip_u32'])
 if session.seed_used!=len(session.seeds):raise ValueError(('Unused native statement seed',row['name'],session.seed_used,len(session.seeds)))
 result.update(context_after=copy.deepcopy(session.core),dependency_calls=copy.deepcopy(session.calls),world_observations_used=len(session.world),statement_frames_used=session.seed_used,statement_frames_after=session.frames_after)
 return result,session.world,session.measurements
def generate(a):
 a.proof_dir.mkdir(parents=True,exist_ok=True);rows=cases();pool={};serialized=[];previous=None;all_measurements=[]
 with tempfile.TemporaryDirectory(prefix='mission-vm-native-')as folder:
  native=Native(folder,a.proof_dir)
  for row in rows:
   if row['carries_previous_native_state']:row['context_before']=copy.deepcopy(previous['context_after'])
   results=[execute(native,row)for _ in range(3)]
   if results[0]!=results[1]or results[0]!=results[2]:raise ValueError('Native VM fresh cohorts differ '+row['name'])
   expected,world,measurements=results[0];previous=expected;all_measurements+=measurements
   observations=[]
   for raw in world:
    item=copy.deepcopy(raw);item['before']=pool_context(item['before'],pool);item['after']=pool_context(item['after'],pool);observations.append(item)
   stored=copy.deepcopy(expected);stored['context_after']=pool_context(stored['context_after'],pool)
   serialized.append({'name':row['name'],'command':row['command'],'context_before':pool_context(row['context_before'],pool),'observations':observations,'expected':stored,'carries_previous_native_state':row['carries_previous_native_state'],'native_measurements':measurements})
   print(row['name'],len(expected['dependency_calls']),len(world),session_frame_summary(expected),flush=True)
  for row,wanted in zip(reversed(rows),reversed(serialized)):
   value,world,measurements=execute(native,row);target=copy.deepcopy(wanted['expected']);target['context_after']=hydrate_context({'buffer_pool':pool},target['context_after'])
   if value!=target:raise ValueError('Reverse native VM cohort differs '+row['name'])
 modules=[R.E,R.S,R.G,R.T,R.V,R.M,P,Q]
 dependencies=['tools/rebuild_source_mission_vm_native.py','tools/rebuild_source_mission_runtime_native.py','tools/rebuild_source_mission_statements_native.py','tools/rebuild_source_mission_spawn_native.py','data/ffe_mission_programs.json','data/ffe_mission_models.json']
 for module in [R.E,R.S,R.G,R.T,R.V,R.M]:
  for path in json.loads(module.FIXTURE.read_text()).get('source_dependencies_sha256',{}):
   if path not in dependencies:dependencies.append(path)
 proofs={str(path.relative_to(PROJECT)):sha(path.read_bytes())for module in modules for path in [module.PROOF/'instruction-proof.json',module.PROOF/'source-procedures.asm']}
 generated=[path for path in a.proof_dir.iterdir()if path.name in ['events-callback-heap-overlay.c','model-composition-native.s','statements-composition-native.s','statements-composition-host.c','spawn-composition-native.s','spawn-composition-host.c']]
 proofs.update({str((PROOF/path.name).relative_to(PROJECT)):sha(path.read_bytes())for path in generated})
 doc={'schema':'starfrontier-mission-vm-native-v1','profile':PROFILE,'case_count':len(serialized),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'source_executable_sha256':R.E.N.EXE_SHA,'source_assembly_sha256':R.E.N.ASM_SHA,'source_dependencies_sha256':{path:sha((PROJECT/path).read_bytes())for path in dependencies},'proofs_sha256':proofs,'buffer_codec':'sha256-zlib-base64-v1','buffer_pool':pool,'native_measurement_count':len(all_measurements),'native_measurements_sha256':sha(json.dumps(all_measurements,sort_keys=True,separators=(',',':')).encode()),'native_F41_is_closed':True,'F41_world_callbacks':0,'statement_invocations':sum(row['expected']['statement_frames_used']for row in serialized),'consecutive_shared_state_edges':sum(row['carries_previous_native_state']for row in rows),'expected_arithmetic_calculated_in_python':False,'native_transport_restrictions':['Selected allocation byte length and module-global base cannot change inside a suspended old expression/store adapter.','Freed selected bytes are private retired projection transport and are never reinserted; a later freed-memory read/write is outside positive native corpus, not an asserted CPU fault.','The inherited callback heap overlay admits consecutive surviving new IDs; transient allocator gaps remain outside its native transport.'],'cases':serialized,'Main_integrated':False,'full_original_port_complete':False,'scope':'Native composition of actual F41 with real expression/store/guard/task/event/spawn/model kernels over Core21; formatting and unclosed world services remain explicit authored observations.'}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n')
 contract={'schema':'starfrontier-mission-vm-contract-v1','profile':PROFILE,'context_keys':KEYS,'command_keys':['kind','operation','args','task_slot_s32','ip_u32','statement_frames'],'world_keys':WORLD_KEYS,'world_optional_keys':['registry_actions'],'fixture_sha256':sha(a.output.read_bytes()),'case_count':len(rows),'F41_world_boundary_forbidden':True}
 (a.proof_dir/'vm-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
 print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size,'native_measurements':len(all_measurements)},indent=2))
def session_frame_summary(expected):return 'frames='+str(expected['statement_frames_used'])
def hydrate_context(doc,value):
 result=copy.deepcopy(value)
 for key in BYTE_KEYS:
  ref=result[key]['buffer_sha256'];row=doc['buffer_pool'][ref];raw=zlib.decompress(base64.b64decode(row['zlib_base64']));assert sha(raw)==ref and len(raw)==row['byte_count'];result[key]=raw.hex()
 for owner in ['task_variables','market_records']:
  for key,value in result[owner].items():
   ref=value['buffer_sha256'];row=doc['buffer_pool'][ref];raw=zlib.decompress(base64.b64decode(row['zlib_base64']));assert sha(raw)==ref and len(raw)==row['byte_count'];result[owner][key]=raw.hex()
 return result
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE)
 for name in ['exe','asm','data']:p.add_argument('--'+name,type=Path,default=None)
 generate(p.parse_args())
if __name__=='__main__':main()
