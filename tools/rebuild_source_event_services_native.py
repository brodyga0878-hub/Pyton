#!/usr/bin/env python3
"""Compose measured original player handlers, F48 dispatch and F271 messages.

Python only projects shared owners and transports measured callback state. No
expected event/tree, cleanup, ring or clock arithmetic is calculated here.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,json,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_player_events_native as P
import rebuild_source_events_native as E
import rebuild_source_messages_native as M

PROJECT=P.PROJECT;V=PROJECT/'validation/events-messages-2026-11-18'
PROOF=V/'services-native-proof';FIXTURE=PROJECT/'tests/fixtures/source_event_services_native.json'
PROFILE='dos-firstenc-event-services-v1';sha=P.sha
PLAYER_KEYS=['root','bank','event_registers','temporary_event_index_s32','watched_index_u8']
EVENT_KEYS=['root','bank','event_registers','scratch_words','arena','temporary_event_index_s32','tree_root_u32','nodes','next_node_id_u32','task_variables','next_variable_id_u32','definitions']
MESSAGE_KEYS=['root','bank','queue_records','queue_control','fallback_name']
BUFFER_KEYS=['root','bank','event_registers','module_entries','arena','scratch_words','queue_records','queue_control','fallback_name','packet']
OPS=['F349','F350','F351','F352','F271']

def view(value,keys):return {k:copy.deepcopy(value[k])for k in keys}
def merge(state,source,keys):
 out=copy.deepcopy(state)
 for k in keys:out[k]=copy.deepcopy(source[k])
 return out

def baseline():
 state=E.baseline();root=bytearray(16384);struct.pack_into('<II',root,0,0x12345678,0x121cf7);struct.pack_into('<I',root,0xc0,1);root[0xef]=99;root[0xe8]=2;root[0xea]=5;root[0xec]=17;root[0xed]=18;root[0x112]=17
 state.update(root=root.hex(),bank=bytes((i*13+7)&255 for i in range(38986)).hex(),module_entries=bytes(168).hex(),module_count_s32=0,model_resources={'0':json.loads((PROJECT/'data/ffe_object_factory.json').read_text())['models']['0']},queue_records=(b'\xa7'*10380).hex(),queue_control=bytes(36).hex(),fallback_name=bytes(612).hex(),watched_index_u8=9,temporary_event_index_s32=-7)
 return state

def register(state,event,index,count=3):
 out=copy.deepcopy(state);keys=[[event,0,index&0xffffffff,0x414100+i,i+1,0xa000+i]for i in range(count)]
 out['nodes']={str(i+1):E.node(k,0,i+2 if i+1<count else 0)for i,k in enumerate(keys)};out['tree_root_u32']=1 if count else 0;out['next_node_id_u32']=count+1
 return out

def cases():
 rows=[]
 def player(name,op,index,state=None,code=0,policy=None,event_policy=None):
  rows.append({'name':name,'command':{'kind':'player','operation':op,'payload':{'code_u32':code,'body_slot_u32':17,'index_u8':index}},'context_before':state or baseline(),'_player_policy':policy or{},'_event_policy':event_policy or{}});return rows[-1]
 for index in [0,17,127,128,255]:
  state=register(baseline(),22,P.s32(index if index<128 else index-256))
  patches=[E.p32('temporary_event_index_s32',0,123),E.p32('event_registers',88,0xdeadbeef),E.p32('scratch_words',0,0x87654321),E.patch('bank',455,b'original-event'),E.p32('root',4,0x121cf8)]
  player('temporary-dispatch/index-%d'%index,'F61',index,state,event_policy={'event_callback:1':{'patches':patches}})
 player('temporary-dispatch/no-match','F61',255,register(baseline(),22,255))
 player('temporary-dispatch/skipped-code','F61',255,register(baseline(),22,0xffffffff),1)
 player('temporary-dispatch/snapshot-clear','F61',128,register(baseline(),22,0xffffff80),event_policy={'event_callback:1':{'registry_actions':[{'operation':'F50','args':[]}]}})
 for index in [0,17,128,255]:
  state=register(baseline(),1,14);root=bytearray.fromhex(state['root']);root[0xec]=index;root[0xed]=index;root[0x112]=index;state['root']=root.hex();state['watched_index_u8']=(index+1)&255
  player('target-cleanup/dispatch-%d'%index,'F1103',index,state,event_policy={'event_callback:1':{'patches':[E.patch('root',0xed,bytes([(index+1)&255])),E.p32('event_registers',16,0xabcdef12),E.p32('temporary_event_index_s32',0,-3)]}})
 state=register(baseline(),1,14);state['watched_index_u8']=17
 player('watched-cleanup/no-event','F1103',17,state,policy={'F262':[{'owner':0,'offset':0xe8,'hex':'04'},{'owner':0,'offset':4,'hex':'f8bfc099'},{'owner':1,'offset':455,'hex':'61637475616c2d706c61796572'}]})
 message_seeds=M.cases()
 # These authored operands cover the actual whole F271 backend, route gates,
 # source actor binding and callbacks that reread the packet/Root clock.
 selected=[('route-F349',0,'',4),('menu-to-format-F349',0,'menu-format',0),('menu-skips-F349',0,'menu-skip',0),('negative-F350',1,'formatter-clock',4),('actor-F350',1,'wrap-cursor',4),('notify-F351',2,'sound-packet-reread',4),('silent-F351',2,'',44),('immediate-F352',3,'',4),('shared-owner-message-chain',0,'formatter-clock',4)]
 for n,(name,op,policy,mode)in enumerate(selected):
  seed=copy.deepcopy(message_seeds[0]);state=baseline();root=bytearray.fromhex(state['root']);root[0xe8]=mode;state['root']=root.hex();packet=bytearray.fromhex(seed['context_before']['packet']);struct.pack_into('<I',packet,0,0x98c8+n);struct.pack_into('<I',packet,4,0x10203040+n);struct.pack_into('<I',packet,24,0xffffffff if n in [0,3,7,8]else 0);struct.pack_into('<I',packet,28,116+17*338 if n==4 else 0)
  rows.append({'name':'message/'+name,'command':{'kind':'message','operation':OPS[op],'packet':packet.hex(),'display_mode_s32':0 if n==4 else 1},'context_before':state,'_message_policy':policy,'_message_lines':n%5,'carries_previous_native_state':n in [0,8],'packet_witness':{'caller_kind':'equipment','pending':{'kind':'F349','args':[struct.unpack_from('<I',packet,0)[0],struct.unpack_from('<I',packet,4)[0],struct.unpack_from('<I',packet,24)[0]]},'defined_word_offsets_u32':[0,0x18,4]}})
 # Only explicitly defined legacy caller words are bound; every other byte is
 # an opaque, supplied48-byte witness, including words copied by formatter.
 for n in [3,4]:
  row=rows[13+n];packet=bytearray.fromhex(row['command']['packet']);has_count=int(n==4);count=0x12345678
  if has_count:struct.pack_into('<I',packet,0xc,count)
  row['command']['packet']=packet.hex();row['packet_witness']={'caller_kind':'destruction','pending':{'kind':'F349','args':[struct.unpack_from('<I',packet,0)[0],has_count,count,struct.unpack_from('<I',packet,0x18)[0]]},'defined_word_offsets_u32':[0,0x18]+([0xc]if has_count else[])}
 return rows

def player_diff(before,after):
 patches=[]
 for owner,key in enumerate(PLAYER_KEYS):
  a=bytes.fromhex(before[key])if owner<3 else(struct.pack('<i',before[key])if owner==3 else bytes([before[key]]));b=bytes.fromhex(after[key])if owner<3 else(struct.pack('<i',after[key])if owner==3 else bytes([after[key]]))
  if len(a)!=len(b):raise ValueError('Native projected owner length changed')
  at=0
  while at<len(a):
   if a[at]==b[at]:at+=1;continue
   end=at+1
   while end<len(a)and a[end]!=b[end]and end-at<64:end+=1
   patches.append({'owner':owner,'offset':at,'hex':b[at:end].hex()});at=end
 if len(patches)>12:raise ValueError('Measured native reply exceeds reviewed12patch transport')
 return patches

def encode(value,pool):
 if isinstance(value,list):return [encode(x,pool)for x in value]
 if not isinstance(value,dict):return value
 out={}
 for k,v in value.items():
  if k in BUFFER_KEYS and isinstance(v,str):
   raw=bytes.fromhex(v);key=sha(raw);pool.setdefault(key,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});out[k]=key
  elif k=='task_variables':out[k]={}
  else:out[k]=encode(v,pool)
 if 'task_variables'in value:
  for k,v in value['task_variables'].items():
   raw=bytes.fromhex(v);key=sha(raw);pool.setdefault(key,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});out['task_variables'][k]=key
 return out

def hydrate(value,fixture):
 if isinstance(value,list):return [hydrate(x,fixture)for x in value]
 if not isinstance(value,dict):return value
 out={}
 for k,v in value.items():
  if k in BUFFER_KEYS and isinstance(v,str)and v in fixture['buffers']:out[k]=E.hydrate_buffer(fixture,v).hex()
  elif k=='task_variables':out[k]={n:E.hydrate_buffer(fixture,x).hex()for n,x in v.items()}
  else:out[k]=hydrate(v,fixture)
 return out

def hydrate_context(fixture,context):return hydrate(context,fixture)
def raw_row(fixture,row):return hydrate(row,fixture)

def generate(a):
 pm,ps=P.verify();em,es,ek,ec=E.verify();mm,ms=M.verify();rows=cases();records={'player':[],'events':[],'messages':[]};assemblies={};host={'player':P.C,'events':ec,'messages':M.C}
 # Assert actual DOS addresses shared by independently captured components.
 bindings=pm['bindings'];eb=em['source_symbol_addresses'];mb=mm['bindings'];root=bindings['DATA_008804']
 if not(root==mb['DATA_008804'] and bindings['DATA_008560']==0x60bf4c and bindings['DATA_008877']==0x4eed84 and eb['DATA_008550']==0x60bf24 and mb['DATA_008870']==root+0xe8 and mb['DATA_008807']==root+4):raise ValueError('Independent original owner alias proof disagrees')
 with tempfile.TemporaryDirectory(prefix='event-services-native-')as temp:
  folder=Path(temp);binaries={}
  for k in records:(folder/k).mkdir()
  binaries['player'],assemblies['player']=P.build(pm,ps,folder/'player');binaries['events']=E.compile_native(ek,ec,folder/'events');assemblies['events']=ek;binaries['messages'],assemblies['messages']=M.build(mm,ms,folder/'messages')
  def execute(kind,packet):
   replies=[subprocess.run([str(binaries[kind])],input=packet,capture_output=True,timeout=30)for _ in range(3)]
   if any(x.returncode or x.stderr for x in replies):raise ValueError(('Native service call failed',kind,[(x.returncode,x.stderr[:120])for x in replies]))
   if len({x.stdout for x in replies})!=1:raise ValueError('Native service fresh process differs '+kind)
   records[kind].append((packet,replies[0].stdout));return replies[0].stdout
  previous=None
  for row in rows:
   if row.get('carries_previous_native_state'):row['context_before']=copy.deepcopy(previous)
   state=copy.deepcopy(row['context_before']);command=row['command'];event_calls=[];event_packets=[]
   if command['kind']=='player':
    pr={'name':row['name'],'operation':command['operation'],'payload':copy.deepcopy(command['payload']),'context_before':view(state,PLAYER_KEYS),'scripts':[]}
    for _ in range(17):
     raw=execute('player',P.packet(pr));h=struct.unpack_from('<16I',raw)
     if not h[2]:break
     if h[2]!=1 or h[4]<=len(pr['scripts']):raise ValueError('Unexpected native player continuation')
     at=P.BASE+len(pr['scripts'])*P.SNAP;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc];before=P.context(raw[at+40:at+40+P.OWNER]);state=merge(state,before,PLAYER_KEYS)
     if kind==48:
      er={'name':row['name']+'/actual-F48','operation':'F48','args':args,'context_before':view(state,EVENT_KEYS)};scripts=[];seen={}
      for _ in range(257):
       eraw=execute('events',E.packet(er,scripts));decoded=E.decode(eraw,er)
       if not decoded['status']:break
       pending=decoded['pending'];name=pending['kind'];seen[name]=seen.get(name,0)+1;policy=row.get('_event_policy',{}).get(name+':'+str(seen[name]),{});scripts.append({'kind':name,'args':pending['args'],'return_u32':0x12345678,'patches':copy.deepcopy(policy.get('patches',[])),'registry_actions':copy.deepcopy(policy.get('registry_actions',[]))})
      else:raise ValueError('Events service continuation capacity exceeded')
      result=decoded['expected'];state=merge(state,result['context_after'],EVENT_KEYS);observations=copy.deepcopy(decoded['observations'])
      for o,s in zip(observations,scripts):o['registry_actions']=copy.deepcopy(s['registry_actions']);o['authored_patches']=copy.deepcopy(s['patches'])
      event_packets.append({'call_index_u32':len(event_calls),'observations':observations});event_calls.append({k:copy.deepcopy(result[k])for k in ['source_order','captured_callbacks','return_defined']});script={'kind':kind,'args':args,'return_u32':0,'patches':player_diff(before,view(state,PLAYER_KEYS))}
     else:script={'kind':kind,'args':args,'return_u32':0x13570000+kind,'patches':copy.deepcopy(row.get('_player_policy',{}).get('F%d'%kind,[]))}
     pr['scripts'].append(script)
    else:raise ValueError('Player service continuation capacity exceeded')
    result=P.decode(raw,pr);state=merge(state,result['context_after'],PLAYER_KEYS);observations=[o for o in result['observations']if o['kind']!='F48'];expected={k:copy.deepcopy(result[k])for k in ['source_order','return_u32','return_defined']}
   else:
    witness=row['packet_witness'];packet=bytes.fromhex(command['packet']);args=witness['pending']['args']
    if len(packet)!=48 or struct.unpack_from('<I',packet,0)[0]!=args[0]or struct.unpack_from('<I',packet,0x18)[0]!=args[-1]:raise ValueError('Defined source caller packet words differ')
    if witness['caller_kind']=='equipment'and struct.unpack_from('<I',packet,4)[0]!=args[1]:raise ValueError('Equipment source argument differs')
    if witness['caller_kind']=='destruction'and args[1]and struct.unpack_from('<I',packet,0xc)[0]!=args[2]:raise ValueError('Destruction source count differs')
    mr={'name':row['name'],'operation_u32':OPS.index(command['operation']),'display_mode_s32':command['display_mode_s32'],'context_before':view(state,MESSAGE_KEYS)|{'packet':command['packet']},'scripts':[],'policy':row.get('_message_policy',''),'lines':row.get('_message_lines',3)}
    for _ in range(17):
     raw=execute('messages',M.packet(mr));h=struct.unpack_from('<16I',raw)
     if not h[2]:break
     if h[2]!=1 or h[3]<=len(mr['scripts']):raise ValueError('Unexpected native message continuation')
     at=M.BASE+len(mr['scripts'])*M.TRACE;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<7I',raw,at+8))[:argc];mr['scripts'].append(M.provider(mr,kind,args))
    else:raise ValueError('Message service continuation capacity exceeded')
    result=M.decode(raw,mr);state=merge(state,result['context_after'],MESSAGE_KEYS);observations=result['observations'];expected={'source_order':result['source_order'],'return_u32':0}
   row.update(observations=observations,event_packets=event_packets,expected={'kernel_result':expected,'context_after':state,'event_calls':event_calls});previous=copy.deepcopy(state)
  for kind,items in records.items():
   result=subprocess.run([str(binaries[kind])],input=b''.join(p for p,_ in reversed(items)),capture_output=True,timeout=60)
   if result.returncode or result.stderr or result.stdout!=b''.join(o for _,o in reversed(items)):raise ValueError('Native service reverse stream differs '+kind)
 dependencies=['tools/rebuild_source_event_services_native.py','tools/rebuild_source_player_events_native.py','tools/rebuild_source_events_native.py','tools/rebuild_source_messages_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_damage_native.py','data/ffe_object_factory.json']
 for proof in [P.PROOF,E.PROOF,M.PROOF]:dependencies.extend(str(p.relative_to(PROJECT))for p in proof.iterdir()if p.name in ['instruction-proof.json','source-procedures.asm'])
 proof={'schema':'starfrontier-original-event-services-composition-v1','source_executable_sha256':P.N.EXE_SHA,'source_assembly_sha256':P.N.ASM_SHA,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in sorted(dependencies)},'native_calls':{k:len(v)for k,v in records.items()},'fresh_process_runs_each_call':3,'reverse_native_calls_verified':True,'composition_cases':len(rows),'player_cases':sum(r['command']['kind']=='player'for r in rows),'message_cases':sum(r['command']['kind']=='message'for r in rows),'actual_F48_calls':sum(len(r['event_packets'])for r in rows),'actual_F271_calls':sum(r['expected']['kernel_result']['source_order'].count('F271')for r in rows),'negative_F61_index_cases':[r['command']['payload']['index_u8']for r in rows if r['command']['kind']=='player'and r['command']['operation']=='F61'and r['command']['payload']['index_u8']>=128],'shared_owner_steps':sum(bool(r.get('carries_previous_native_state'))for r in rows),'host_assembly_sha256':{k:sha(v.encode())for k,v in assemblies.items()},'host_support_sha256':{k:sha(v.encode())for k,v in host.items()},'actual_DOS_aliases':{'root':hex(root),'Root_clock':hex(mb['DATA_008807']),'Root_screen_E8':hex(mb['DATA_008870']),'watched_index':hex(bindings['DATA_008877']),'temporary_index':hex(bindings['DATA_008560']),'scratch_words':hex(eb['DATA_008550'])},'expected_arithmetic_calculated_in_python':False,'all_native_guards_verified':True,'scope':'Supplemental native composition: actual whole F61/F1101/F1102/F1103 resumes after actual F48 dispatch, and whole F349/F350/F351/F352 routes into actual F271. Shared Root/bank/events/temp owners are projected without duplicate clocks/RNG/flags; D8877 watcher and event scratch are separate verified DOS owners. Formatter, wrap, UI, audio, F1104 gameover and mission VM callbacks remain explicit providers; no Main/APK claim.'}
 pool={};clean=[]
 for row in rows:
  value={k:v for k,v in row.items()if not k.startswith('_')};command=copy.deepcopy(value.pop('command'));packed=encode(value,pool);packed['command']=command;clean.append(packed)
 doc={'schema':'starfrontier-source-event-services-native-v1','profile':PROFILE,'case_count':len(rows),'proof':proof,'buffer_codec':'sha256-zlib-base64-v1','buffers':pool,'cases':clean,'scope':proof['scope']};a.proof_dir.mkdir(parents=True,exist_ok=True)
 for kind,text in assemblies.items():(a.proof_dir/(kind+'-composed-native.s')).write_text(text)
 for kind,text in host.items():(a.proof_dir/(kind+'-support.c')).write_text(text)
 (a.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n');a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'native_calls':proof['native_calls']}))

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=FIXTURE);parser.add_argument('--proof-dir',type=Path,default=PROOF)
 for name in ['exe','asm','data']:parser.add_argument('--'+name,type=Path)
 generate(parser.parse_args())
if __name__=='__main__':main()
