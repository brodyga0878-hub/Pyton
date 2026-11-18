#!/usr/bin/env python3
"""Measured composition of the original expression, guard and registry kernels.

Python only projects shared owners and transports native-measured byte patches.
It does not calculate the expected expression/guard/registry arithmetic.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_mission_expression_native as X
import rebuild_source_mission_guards_native as G
import rebuild_source_events_native as E
PROJECT=X.PROJECT
PROOF=PROJECT/'validation/mission-expressions-2026-11-18/services-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_services_native.json'
PROFILE='dos-firstenc-mission-services-v1'
EVENT_KEYS=['root','bank','event_registers','scratch_words','arena','temporary_event_index_s32','tree_root_u32','nodes','next_node_id_u32','task_variables','next_variable_id_u32','definitions']
SHARED_EXPR=['root','root_tail','bank','event_registers','module_globals','program','ip_u32','module_global_offset_u32']
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def raw(value):return bytes.fromhex(value)
def put(buffer,offset,value):struct.pack_into('<I',buffer,offset,value&0xffffffff)
def get(buffer,offset):return struct.unpack_from('<I',buffer,offset)[0]
def selected_id(core):return str(get(raw(core['arena']),core['task_slot_u32']*36+32))
def view_expression(core):
 result={k:copy.deepcopy(core[k])for k in SHARED_EXPR};result['temporary_event_index_s32']=core['temporary_event_index_s32'];result['task_variables']=core['task_variables'][selected_id(core)];return result
def view_events(core):return {k:copy.deepcopy(core[k])for k in EVENT_KEYS}
def view_guards(core):
 result={k:copy.deepcopy(core[k])for k in ['event_registers','program','program_base_u32','ip_u32','task_slot_u32','metadata']};at=core['task_slot_u32']*36;result['task_record']=raw(core['arena'])[at:at+36].hex();return result
def merge_expression(core,view):
 result=copy.deepcopy(core)
 for k in SHARED_EXPR+['temporary_event_index_s32']:result[k]=copy.deepcopy(view[k])
 result['task_variables'][selected_id(core)]=view['task_variables'];return result
def merge_events(core,view):
 result=copy.deepcopy(core)
 for k in EVENT_KEYS:result[k]=copy.deepcopy(view[k])
 return result
def merge_guards(core,view):
 result=copy.deepcopy(core)
 for k in ['event_registers','program','program_base_u32','ip_u32','task_slot_u32','metadata']:result[k]=copy.deepcopy(view[k])
 at=result['task_slot_u32']*36;arena=bytearray(raw(result['arena']));arena[at:at+36]=raw(view['task_record']);result['arena']=arena.hex();return result
def differences(first,second,owner):
 a=raw(first);b=raw(second)
 if len(a)!=len(b):raise ValueError('Native shared owner resized')
 out=[];i=0
 while i<len(a):
  if a[i]==b[i]:i+=1;continue
  start=i
  while i<len(a)and a[i]!=b[i]and i-start<64:i+=1
  out.append({'owner':owner,'offset':start,'hex':b[start:i].hex()})
 return out
def expression_decode(data,row):
 h=struct.unpack_from('<16I',data);base=64+X.OWNER+X.MAX_TRACE*4;stride=64+X.OWNER*2+4096
 if h[0]!=0x31e02055 or h[1]!=len(data)or h[2]not in [0,1]or len(data)!=base+h[4]*stride:raise ValueError('Native expression transport differs')
 observations=[]
 for i in range(h[4]):
  at=base+i*stride;kind,argc=struct.unpack_from('<2I',data,at);outlen=struct.unpack_from('<I',data,at+36)[0]
  observations.append({'kind':'F%d'%kind,'args':list(struct.unpack_from('<6I',data,at+8))[:argc],'before':X.context(data[at+64:at+64+X.OWNER],row),'after':X.context(data[at+64+X.OWNER:at+64+X.OWNER*2],row),'return_u32':struct.unpack_from('<I',data,at+32)[0],'input_hex':'','output_hex':data[at+64+X.OWNER*2:at+64+X.OWNER*2+outlen].hex()})
 return {'status':h[2],'context_after':X.context(data[64:64+X.OWNER],row),'source_order':['F%d'%n for n in struct.unpack_from('<%dI'%h[5],data,64+X.OWNER)],'return_defined':bool(h[6]),'return_u32':h[3]if h[6]else 0,'observations':observations}

class Runner:
 def __init__(self,binaries):self.binaries=binaries;self.log={k:[]for k in binaries};self.counts={k:0 for k in binaries}
 def call(self,kind,row):
  packet=X.packet(row)if kind=='expression'else G.packet(row)if kind=='guards'else E.packet(row)
  baseline=None
  for _ in range(3):
   p=subprocess.run([str(self.binaries[kind])],input=packet,capture_output=True,timeout=30)
   if p.returncode or p.stderr:raise ValueError(('Native composition failed',kind,row['name'],p.returncode,p.stderr.decode(errors='replace')))
   if baseline is not None and p.stdout!=baseline:raise ValueError('Fresh native composition call differs')
   baseline=p.stdout;self.counts[kind]+=1
  self.log[kind].append((packet,baseline))
  return expression_decode(baseline,row)if kind=='expression'else G.decode(baseline,row)if kind=='guards'else E.decode(baseline,row)
 def reverse(self):
  for kind,rows in self.log.items():
   p=subprocess.run([str(self.binaries[kind])],input=b''.join(packet for packet,_ in reversed(rows)),capture_output=True,timeout=120)
   if p.returncode or p.stderr or p.stdout!=b''.join(data for _,data in reversed(rows)):raise ValueError('Reverse composed native cohort differs: '+kind)
   self.counts[kind]+=len(rows)
 def events(self,core,operation,args,policy):
  row={'name':'nested-'+operation,'operation':operation,'args':args,'context_before':view_events(core),'_scripts':[]}
  for _ in range(257):
   value=self.call('events',row)
   if value['status']==0:return merge_events(core,value['expected']['context_after']),value['expected'],value['observations']
   pending=value['pending']
   if pending['kind']!='event_callback':raise ValueError('Unexpected VM boundary in bounded composition')
   patches=[]
   if policy=='shared_F47_mutation':patches=[E.p32('root',0x30,0xdeadbeef),E.patch('task_variables',4,E.u32(0x11223344),variable_id=1)]
   row['_scripts'].append({'kind':pending['kind'],'args':pending['args'],'return_u32':0,'patches':patches})
  raise ValueError('Composed event provider limit')
 def expression(self,core,operation,args,policy):
  row={'name':'outer-'+operation,'operation':operation,'args':args,'context_before':view_expression(core),'scripts':[]};state=copy.deepcopy(core);calls=[];packets=[]
  for _ in range(17):
   value=self.call('expression',row)
   if value['status']==0:return merge_expression(state,value['context_after']),value,calls,packets
   pending=value['observations'][-1];state=merge_expression(state,pending['before'])
   if pending['kind']!='F48':raise ValueError('An unauthored expression world provider was requested')
   state,invoked,observations=self.events(state,'F48',pending['args'],policy)
   if observations:packets.append({'call_index_u32':len(calls),'observations':observations})
   calls.append({'kind':'F48','result':summary(invoked)})
   after=view_expression(state);patches=[]
   for index,key in enumerate(X.CONTEXT_KEYS[:6]):patches+=differences(pending['before'][key],after[key],index)
   if pending['before']['temporary_event_index_s32']!=after['temporary_event_index_s32']:patches.append({'owner':9,'offset':0,'hex':struct.pack('<i',after['temporary_event_index_s32']).hex()})
   if len(patches)>12:raise ValueError('Expression native patch budget exceeded')
   row['scripts'].append({'kind':48,'args':pending['args'],'return_u32':0,'patches':patches,'output_hex':''})
  raise ValueError('Composed expression provider limit')
 def guards(self,core,operation,args,policy):
  row={'name':'outer-'+operation,'operation':operation,'args':args,'context_before':view_guards(core),'scripts':[]};state=copy.deepcopy(core);calls=[];packets=[]
  for _ in range(257):
   value=self.call('guards',row)
   if value['status']==0:return merge_guards(state,value['context_after']),value,calls,packets
   pending=value['observations'][-1];state=merge_guards(state,pending['before'])
   if pending['kind']=='F31':
    state,invoked,nested_calls,nested_packets=self.expression(state,'F31',[],policy)
    if nested_calls or nested_packets:raise ValueError('Authored guard child unexpectedly nested another service')
    observations=invoked['observations']
   else:state,invoked,observations=self.events(state,pending['kind'],pending['args'],policy)
   if observations:packets.append({'call_index_u32':len(calls),'observations':observations})
   calls.append({'kind':pending['kind'],'result':summary(invoked)})
   after=view_guards(state);patches=differences(pending['before']['event_registers'],after['event_registers'],0)+differences(pending['before']['task_record'],after['task_record'],1)
   if len(patches)>8:raise ValueError('Guard native patch budget exceeded')
   row['scripts'].append({'kind':int(pending['kind'][1:]),'args':pending['args'],'return_u32':invoked.get('return_u32',0)if pending['kind']=='F31'else 0,'ip_after_u32':after['ip_u32'],'patches':patches})
  raise ValueError('Composed guard provider limit')
 def execute(self,case):
  core=case['context_before'];command=case['command'];policy=case.get('provider_policy','none')
  return self.expression(core,command['operation'],command['args'],policy)if command['kind']=='expression'else self.guards(core,command['operation'],command['args'],policy)

def summary(value):
 out={'source_order':value['source_order'],'return_defined':value.get('return_defined',False)}
 if value.get('return_defined',False):out['return_u32']=value['return_u32']
 return out

def baseline(resources,program=b'\x02\x00\x00\x00\x00',full=False,module_index=26):
 module=resources['modules'][module_index];base=resources['regions']['mission']['original_va_u32'];root=bytearray(16384);put(root,0x24,0x12345678);put(root,0x28,0x89abcdef)
 tail=bytearray(6160);put(tail,0x180c,1);event=bytearray(284);put(event,70*4,0x55667788);globals_=bytearray(40);put(globals_,20,0x0badcafe)
 variables=bytearray([0xa5]*(module['variable_words_u32']*4));put(variables,0,0x37);put(variables,4,0x89abcdef)
 slot=17;arena=bytearray(5400);at=slot*36;put(arena,at+4,0xffff0011);put(arena,at+24,module_index);put(arena,at+28,base+module['descriptor_offset_u32']);put(arena,at+32,1)
 definitions={}
 for definition in resources['modules']if full else[module]:
  cleanup=definition['cleanup_block_index_s32'];instruction=0
  if cleanup>=0:instruction=base+resources['blocks'][str(definition['block_offsets_u32'][cleanup])]['initialization_offset_u32']
  definitions[str(definition['module_index_u32'])]={'descriptor_ref_u32':base+definition['descriptor_offset_u32'],'cleanup_instruction_u32':instruction,'variable_words_u32':definition['variable_words_u32']}
 return {'root':root.hex(),'root_tail':tail.hex(),'bank':bytes(38986).hex(),'event_registers':event.hex(),'module_globals':globals_.hex(),'program':program.hex(),'ip_u32':0,'module_global_offset_u32':module['global_owner_offset_u32'],'temporary_event_index_s32':-17,'scratch_words':bytes(range(32)).hex(),'arena':arena.hex(),'tree_root_u32':0,'nodes':{},'next_node_id_u32':1,'task_variables':{'1':variables.hex()},'next_variable_id_u32':2,'definitions':definitions,'task_slot_u32':slot,'program_base_u32':base,'metadata':resources['regions']['expression_metadata']['hex']}
def immediate(value):return b'\x02'+struct.pack('<I',value&0xffffffff)
def variable(selector,index):return bytes([selector])+struct.pack('<I',index)
def build_cases(resources):
 rows=[]
 def add(name,kind,operation,args,program=None,context=None,policy='none',carry=False):
  c=copy.deepcopy(context)if context is not None else baseline(resources,program or immediate(7));rows.append({'name':name,'context_before':c,'command':{'kind':kind,'operation':operation,'args':args},'provider_policy':policy,'carry_previous':carry})
 add('guard-store-real-dispatch','guards','F34',[70,0x12345678]);add('guard-read-event-word','guards','F35',[70])
 for token,index in [(3,12),(4,70),(5,0),(6,1)]:add('guard-register-source-key-%d'%token,'guards','F32',['F44',token],variable(token,index))
 for token,children,registration in [(31,[7],'F44'),(32,[0xffffffff,0x80000000],'F44'),(37,[17,19],'F45')]:add('guard-evaluate-real-F31-%d'%token,'guards','F32',[registration,token],bytes([token])+b''.join(immediate(v)for v in children))
 base=resources['regions']['mission']['original_va_u32'];program=bytearray(160);put(program,4,2);put(program,8,base+64);put(program,12,base+96);program[64:69]=variable(3,12);program[96:102]=bytes([31])+immediate(7)
 core=baseline(resources,program);arena=bytearray(raw(core['arena']));put(arena,core['task_slot_u32']*36+8,base);core['arena']=arena.hex();core['ip_u32']=15;add('block-multiple-guard-routes','guards','F33',['F44'],context=core)
 negative=copy.deepcopy(core);p=bytearray(raw(negative['program']));put(p,4,0xffffffff);negative['program']=p.hex();add('block-signed-negative-count','guards','F33',['F44'],context=negative)
 for selector,value in [(1,0xffffffff),(12,0xffffffff),(21,7)]:add('global-store-real-F48-%d'%selector,'expression','F22',[selector,value])
 for selector,index in [(4,70),(5,0),(6,1)]:add('expression-shared-source-read-%d'%selector,'expression','F31',[],variable(selector,index))
 add('expression-real-shared-RNG','expression','F922',[3])
 shared_program=bytearray(160);put(shared_program,4,1);put(shared_program,8,base+64);shared_program[64:69]=variable(4,70);shared_program[16:21]=variable(6,1)
 start=baseline(resources,shared_program);start['ip_u32']=16;arena=bytearray(raw(start['arena']));put(arena,start['task_slot_u32']*36+8,base);start['arena']=arena.hex()
 add('shared-owner-0-register','guards','F33',['F44'],context=start)
 add('shared-owner-1-dispatch-F47-provider','guards','F34',[70,0x22334455],policy='shared_F47_mutation',carry=True)
 add('shared-owner-2-read-modified-local','expression','F31',[],carry=True)
 add('shared-owner-3-remove','guards','F33',['F45'],carry=True)
 add('shared-owner-4-dispatch-miss','guards','F34',[70,0x66778899],carry=True)
 for index,row in enumerate(rows[-5:]):row['shared_owner_sequence_index_u32']=index
 # Real reachable leaf expressions retain the complete unmodified DOS image,
 # all105 definitions and exact module26 descriptor/global/local projections.
 original=raw(resources['regions']['mission']['hex']);leaves=[];max_variables=[4]
 def walk(at,depth=0):
  if depth>64 or at<0 or at>=len(original):raise ValueError('Original expression span')
  token=original[at];start=at;at+=1
  if token>=68:raise ValueError('Original metadata selector')
  count=resources['expression_metadata_rows'][token]['child_expression_count_s32']
  if count>0:
   for _ in range(count):at=walk(at,depth+1)
  else:
   if at+4>len(original):raise ValueError('Original immediate span')
   value=get(original,at)
   if token==2 or token==6 and value<max_variables[0]:leaves.append((start,token))
   at+=4
  return at
 for module_index in [26,32]:
  leaves.clear();max_variables[0]=resources['modules'][module_index]['variable_words_u32']
  for offset in resources['modules'][module_index]['block_offsets_u32']:
   for clause in resources['blocks'][str(offset)]['clause_offsets_u32']:walk(clause)
  chosen={}
  for offset,token in leaves:
   if token not in chosen:chosen[token]=offset
  for token,offset in sorted(chosen.items()):
   if module_index==32 and token!=6:continue
   core=baseline(resources,original,full=True,module_index=module_index);core['ip_u32']=offset;add('original-image-module%d-leaf-%d'%(module_index,token),'expression','F31',[],context=core)
 return rows

def generate(a):
 resources=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());xm,xs=X.verify();gm,gs=G.verify();em,es,ek,ec=E.verify();kernels={'expression-composed.s':X.assembly(xs,xm),'expression-host.c':X.C,'guards-composed.s':G.assembly(gs),'guards-host.c':G.HOST_C,'events-composed.s':ek,'events-host.c':ec}
 if a.proof_dir.exists():
  for name,text in kernels.items():
   if (a.proof_dir/name).exists()and(a.proof_dir/name).read_text()!=text:raise ValueError('Composed native capture changed: '+name)
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 for name,text in kernels.items():(a.proof_dir/name).write_text(text)
 with tempfile.TemporaryDirectory(prefix='mission-services-native-')as directory:
  root=Path(directory);bins={}
  for kind,(s,c)in {'expression':('expression-composed.s','expression-host.c'),'guards':('guards-composed.s','guards-host.c'),'events':('events-composed.s','events-host.c')}.items():
   d=root/kind;d.mkdir();(d/'native.s').write_text(kernels[s]);(d/'host.c').write_text(kernels[c]);binary=d/'native';cmd=['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector']
   if kind=='guards':cmd+=['-Wl,-Ttext-segment=0x20000000']
   p=subprocess.run(cmd+['-o',str(binary),str(d/'native.s'),str(d/'host.c')],capture_output=True,text=True)
   if p.returncode:raise ValueError(p.stderr)
   bins[kind]=binary
  runner=Runner(bins);records=[];previous=None
  for case in build_cases(resources):
   if case['carry_previous']:
    if previous is None:raise ValueError('Missing measured shared predecessor')
    case['context_before']=copy.deepcopy(previous)
   after,result,calls,packets=runner.execute(case);previous=copy.deepcopy(after)
   expected={'context_after':after,'source_order':result['source_order'],'return_defined':result.get('return_defined',False),'return_u32':result.get('return_u32',0)if result.get('return_defined',False)else 0,'dependency_calls':calls,'original_resource_projection_verified':len(raw(case['context_before']['program']))==resources['regions']['mission']['bytes']}
   record={k:case[k]for k in ['name','context_before','command']}|{'observations':[],'dependency_packets':packets,'expected':expected,'carries_previous_native_state':case['carry_previous']}
   if 'shared_owner_sequence_index_u32'in case:record['shared_owner_sequence_index_u32']=case['shared_owner_sequence_index_u32']
   records.append(record)
  runner.reverse()
  source_pins={str(p.relative_to(PROJECT)):sha(p.read_bytes())for p in [Path(__file__),PROJECT/'tools/rebuild_source_mission_expression_native.py',PROJECT/'tools/rebuild_source_mission_guards_native.py',PROJECT/'tools/rebuild_source_events_native.py',PROJECT/'data/ffe_mission_programs.json']}
  for directory in [X.PROOF,G.PROOF,E.PROOF]:
   for name in ['instruction-proof.json','source-procedures.asm']:
    p=directory/name;source_pins[p.relative_to(PROJECT).as_posix()]=sha(p.read_bytes())
  proof={'schema':'starfrontier-mission-services-composition-proof-v1','source_dependencies_sha256':source_pins,'fresh_process_runs_each_call':3,'reverse_native_calls_verified':True,'expected_arithmetic_calculated_in_python':False,'native_invocations_including_fresh_and_reverse':runner.counts,'shared_owner_steps':5,'shared_owner_continuations':4,'shared_sequence_program_rebound':False,'original_full_image_cases':sum(r['expected']['original_resource_projection_verified']for r in records),'guard_F31_actual_expression_calls':sum(c['kind']=='F31'for r in records for c in r['expected']['dependency_calls']),'actual_registry_service_calls':sum(c['kind']in ['F44','F45','F48']for r in records for c in r['expected']['dependency_calls']),'F47_body_executed':False,'full_mission_VM_executed':False,'Main_integrated':False,'scope':'Measured shared-owner composition of existing independently proven native kernels. F47 remains an explicit event callback provider. Transport patches are measured byte differences; expected arithmetic is never calculated by Python.'}
  for kind in ['F31','F44','F45','F48']:proof['actual_'+kind+'_calls']=sum(c['kind']==kind for r in records for c in r['expected']['dependency_calls'])
  (a.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
  doc={'schema':'starfrontier-mission-services-native-v1','profile':PROFILE,'case_count':len(records),'source_pins':source_pins,'proof':proof,'cases':records}
  a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');print(json.dumps({'case_count':len(records),'fixture_sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size,'proof':proof},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE)
 for option in ['exe','asm','data']:p.add_argument('--'+option,type=Path)
 generate(p.parse_args())
