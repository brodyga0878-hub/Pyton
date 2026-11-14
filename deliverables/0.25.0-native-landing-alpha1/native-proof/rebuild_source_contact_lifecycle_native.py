#!/usr/bin/env python3
"""Bounded original F574/F575 contact response and natural parked continuation.
All expected contact/height/correction values come from native instructions.
"""
from __future__ import annotations
import argparse,hashlib,inspect,json,re,struct,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[3];PROOF=Path(__file__).resolve().parent
sys.path.insert(0,str(PROJECT/'tools'))
import rebuild_source_natural_contact_native as N
F=N.load('lifecycle_footprint',PROJECT/'validation/footprint-2026-11-14/native-proof/rebuild_source_footprint_native.py')
INPUT=1088;OUTPUT=3072
ADDITIONAL=[571,574,575,1030,1042,1332,1333,1335,1501,1503,1504,1519,1520,1522,1552,1664]
STATIC=[1021,1047]
def sha(b):return hashlib.sha256(b).hexdigest()
def once(s,a,b):
 if s.count(a)!=1:raise ValueError('Anchor '+repr(a)+' count '+str(s.count(a)))
 return s.replace(a,b,1)
def adapt(source,numbers):
 source=re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',source)
 source=re.sub(r'\+0x(f[0-9a-f]{7})',lambda m:'-0x%x'%(0x100000000-int(m[1],16)),source)
 source=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 lines,_=N.Q.procedures(source,numbers);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'(,\s*)(DATA_\d+|FUNC_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 return re.sub(r'call QWORD PTR \[([^\]]+)\]',lambda m:'mov eax,DWORD PTR ['+m[1]+']\ncall rax',text)
def build(work,source=None,data=None):
 # Reproduction needs only archived assembly and old archived data/BSS adapter.
 if source is None:
  text=(PROOF/'lifecycle-observed-kernel.s').read_text();excluded=(PROOF/'excluded-native.s').read_text()
 else:
  text=(F.PROOF/'footprint-observed-kernel.s').read_text()
  text=once(text,'DATA_008804: .long 0\nDATA_008807: .long 0','.set DATA_008804,lc_game_root\n.set DATA_008807,lc_game_root+4\n.set DATA_008812,lc_game_root+0x10\n.set DATA_008857,lc_game_root+0xc0\n.set DATA_008860,lc_game_root+0xc6\n.set DATA_008861,lc_game_root+0xc8\n.set DATA_008870,lc_game_root+0xe8\n.set DATA_008878,lc_game_root+0xf0\n.set DATA_008880,lc_game_root+0xf8\n.set DATA_008918,lc_game_root+0x1b8')
  existing=set(map(int,re.findall(r'^FUNC_(\d{6}):',text,re.M)))
  missing=[n for n in ADDITIONAL if n not in existing]
  text+='\n.section .text\n'+adapt(source,missing)+'\n.section .data\nDATA_007719: .long FUNC_001520\nDATA_007737: .long FUNC_001522\n'
  for number in [7635,7636]:
   resource=N.Q.byte_block(N.Q.data_block(data,number))
   if resource!=bytes(4):raise ValueError('Original signed64 zero constant changed')
   text+=f'DATA_{number:06d}: .byte '+','.join(map(str,resource))+'\n'
  text=once(text,'output_full: .zero 2048','output_full: .zero 3072')
  text=once(text,'input_full: .zero 800','input_full: .zero 1088')
  text=once(text,'mov edx,800','mov edx,1088')
  text=once(text,'cmp r8d,800','cmp r8d,1088')
  text=once(text,'mov ecx,512\n rep stosd','mov ecx,768\n rep stosd')
  text=once(text,'mov edx,2048\n syscall','mov edx,3072\n syscall')
  text=once(text,'classify_full:\n test DWORD PTR [input_full],2\n jnz fp_direct_query\n push OFFSET FLAT:relative\n push OFFSET FLAT:parent\n push OFFSET FLAT:player\n call FUNC_000576\n add rsp,24\n jmp capture_full',r'''classify_full:
 movzx eax,BYTE PTR [player+0x86]
 mov DWORD PTR [DATA_008857],eax
 mov DWORD PTR [output_full+2960],OFFSET FLAT:player
 mov DWORD PTR [output_full+2964],OFFSET FLAT:parent
 mov esi,OFFSET FLAT:input_full+800
 mov edi,OFFSET FLAT:lc_game_root
 mov ecx,256
 rep movsb
 cmp DWORD PTR [input_full+776],0
 je lc_no_parent_binding
 mov DWORD PTR [lc_game_root+0xcc],OFFSET FLAT:parent
lc_no_parent_binding:
 mov DWORD PTR [lc_game_root+0xc8],OFFSET FLAT:player
 mov eax,DWORD PTR [input_full+4]
 mov DWORD PTR [DATA_008812],eax
 movzx eax,BYTE PTR [input_full+768]
 mov BYTE PTR [DATA_008860],al
 mov DWORD PTR [output_full+2944],eax
 mov eax,DWORD PTR [input_full+772]
 mov DWORD PTR [DATA_008918],eax
 mov DWORD PTR [output_full+2952],eax
 mov esi,OFFSET FLAT:lc_game_root
 mov edi,OFFSET FLAT:output_full+2688
 mov ecx,256
 rep movsb
 movzx eax,BYTE PTR [lc_game_root+0xe8]
 mov DWORD PTR [output_full+2008],eax
 test DWORD PTR [input_full],16
 jnz lc_launch_prefix_only
 test DWORD PTR [input_full],8
 jnz lc_tick_only
 mov DWORD PTR [lc_height],0x12345678
 mov DWORD PTR [output_full+1992],0x7fffffff
 mov DWORD PTR [output_full+1996],0
 mov DWORD PTR [output_full+2000],0x7fffffff
 mov DWORD PTR [output_full+2004],0
 push OFFSET FLAT:parent
 push OFFSET FLAT:player
 push OFFSET FLAT:relative
 push OFFSET FLAT:lc_height
 call FUNC_000574
 add rsp,32
 mov eax,DWORD PTR [lc_height]
 mov DWORD PTR [output_full+1988],eax
 # Save real post-F575 state before the separately bounded flight continuation.
 mov esi,OFFSET FLAT:player
 mov edi,OFFSET FLAT:output_full+2048
 mov ecx,338
 rep movsb
 # Mode4 is the actual F1021 accepted-natural branch, not full F1021 flight.
 test DWORD PTR [input_full],4
 jz lc_skip_park
 mov al,BYTE PTR [DATA_008696]
 push OFFSET FLAT:parent
 push OFFSET FLAT:player
 call LifecycleAcceptedF1021Fragment
 add rsp,16
lc_skip_park:
 jmp lc_capture_state
lc_tick_only:
 mov esi,OFFSET FLAT:player
 mov edi,OFFSET FLAT:output_full+2048
 mov ecx,338
 rep movsb
 push OFFSET FLAT:player
 call FUNC_001030
 pop rcx
 mov DWORD PTR [output_full+2024],1
 jmp lc_capture_state
lc_launch_prefix_only:
 mov esi,OFFSET FLAT:player
 mov edi,OFFSET FLAT:output_full+2048
 mov ecx,338
 rep movsb
 call LifecycleF1047EntryPrefix
lc_capture_state:
 movzx eax,BYTE PTR [DATA_008860]
 mov DWORD PTR [output_full+2948],eax
 mov eax,DWORD PTR [DATA_008918]
 mov DWORD PTR [output_full+2956],eax
 movzx eax,BYTE PTR [lc_game_root+0xe8]
 mov DWORD PTR [output_full+2012],eax
 mov esi,OFFSET FLAT:lc_game_root
 mov edi,OFFSET FLAT:output_full+2400
 mov ecx,256
 rep movsb
 movzx eax,BYTE PTR [DATA_008696]
 jmp capture_full''')
  # Preserve real F576/F575 returns before callers consume them.
  text=once(text,'FUNC_000576:','LifecycleOriginalF576:')
  text=once(text,'FUNC_000575:','LifecycleOriginalF575:')
  wrappers='\n.section .text\n'
  for number,at,count in [(576,1992,3),(575,2000,3)]:
   wrappers+=f'FUNC_{number:06d}:\npush rbp\nmov rbp,rsp\n'+''.join(f'push QWORD PTR [rbp+{a}]\n'for a in range(16+8*(count-1),15,-8))+f'call LifecycleOriginalF{number}\nlea rsp,[rsp+{8*count}]\nmov DWORD PTR [output_full+{at}],eax\nmov DWORD PTR [output_full+{at+4}],1\npop rbp\nret\n'
  # The exact accepted branch is extracted; unsupported continuation branches
  # are deliberately not substituted with host flight behavior.
  fragment=N.G.block(source,1021);fragment=fragment[fragment.index('JUMP_004228:'):fragment.index('JUMP_004229:')]
  fragment=fragment.replace('jz JUMP_004229','jz LifecycleParkDone').replace('jmp short JUMP_004231','jmp LifecycleParkDone')
  pseudo='FUNC_099991:\n'+fragment+'\nFUNC_099992:\nret\n'
  frag=adapt(pseudo,[99991]);frag=once(frag,'FUNC_099991:','LifecycleAcceptedSourceFragment:')
  wrappers+=r'''LifecycleAcceptedF1021Fragment:
 push rbp
 mov rbp,rsp
 sub rsp,16
 push rbx
 push rsi
 mov ebx,DWORD PTR [rbp+16]
 mov edx,DWORD PTR [rbp+24]
 mov DWORD PTR [rbp-4],edx
 mov esi,OFFSET FLAT:lc_game_root
 jmp LifecycleAcceptedSourceFragment
'''+frag+r'''
LifecycleParkDone:
 cmp BYTE PTR [lc_game_root+0xe8],0x32
 jne LifecycleParkReturn
 mov DWORD PTR [output_full+2016],1
 # Actual source parked-state update: no body or history mutation.
 push rbx
 call FUNC_001030
 pop rcx
 mov DWORD PTR [output_full+2024],1
LifecycleParkReturn:
 pop rsi
 pop rbx
 mov rsp,rbp
 pop rbp
 ret
FUNC_001910:
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 mov eax,DWORD PTR [rbp+16]
 mov DWORD PTR [output_full+3008],eax
 mov eax,DWORD PTR [rbp+24]
 mov DWORD PTR [output_full+3012],eax
 mov eax,DWORD PTR [rbp+32]
 mov DWORD PTR [output_full+3016],eax
 mov eax,DWORD PTR [rbp+40]
 mov DWORD PTR [output_full+3020],eax
 inc DWORD PTR [output_full+3024]
 pop rax
 popfq
 pop rbp
 ret
FUNC_000048:
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 push rcx
 mov eax,DWORD PTR [output_full+2020]
 imul eax,12
 mov ecx,DWORD PTR [rbp+16]
 mov DWORD PTR [output_full+2976+eax],ecx
 mov ecx,DWORD PTR [rbp+24]
 mov DWORD PTR [output_full+2980+eax],ecx
 mov ecx,DWORD PTR [rbp+32]
 mov DWORD PTR [output_full+2984+eax],ecx
 inc DWORD PTR [output_full+2020]
 pop rcx
 pop rax
 popfq
 pop rbp
 ret
'''
  prefix=N.G.block(source,1047);prefix=prefix[:prefix.index('call FUNC_001119')]
  prefix=re.sub(r'FUNC_001047:', 'FUNC_099993:',prefix)+'\nFUNC_099994:\nret\n'
  entry=adapt(prefix,[99993]).replace('FUNC_099993:','LifecycleF1047EntryPrefix:')
  wrappers+=entry+'\nmov DWORD PTR [output_full+3028],1\npop rbp\nret\nFUNC_000148:\npush rbp\nmov rbp,rsp\npushfq\npush rax\nmov eax,DWORD PTR [rbp+16]\nmov DWORD PTR [output_full+3036],eax\nmov eax,DWORD PTR [rbp+24]\nmov DWORD PTR [output_full+3040],eax\ninc DWORD PTR [output_full+3032]\npop rax\npopfq\npop rbp\nret\n'
  text+=wrappers+'\n.section .bss\nlc_height: .zero 4\nlc_game_root: .zero 512\n'
  (work/'lifecycle.s').write_text(text)
  subprocess.run(['as','--64',str(work/'lifecycle.s'),'-o',str(work/'lifecycle.o')],check=True)
  undefined=subprocess.run(['nm','-u',str(work/'lifecycle.o')],check=True,capture_output=True,text=True).stdout
  excluded,meta=N.Q.unresolved_adapter(undefined,data)
  excluded=once(excluded,'_abs:\nmov eax,60\nmov edi,97\nsyscall','_abs:\npush rbp\nmov rbp,rsp\nmov eax,DWORD PTR [rbp+16]\ncdq\nxor eax,edx\nsub eax,edx\npop rbp\nret')
  (PROOF/'adapter-scope.json').write_text(json.dumps(meta,indent=2)+'\n')
  (PROOF/'lifecycle-observed-kernel.s').write_text(text);(PROOF/'excluded-native.s').write_text(excluded)
 for stem,body in [('lifecycle',text),('excluded',excluded)]:
  (work/(stem+'.s')).write_text(body);subprocess.run(['as','--64',str(work/(stem+'.s')),'-o',str(work/(stem+'.o'))],check=True)
 subprocess.run(['ld','-m','elf_x86_64',str(work/'lifecycle.o'),str(work/'excluded.o'),'-o',str(work/'lifecycle')],check=True)
 return text,excluded

def packet(row):
 raw=bytearray(INPUT);raw[:800]=N.packet(row,initialize=row.get('mode')=='initialize_f1533')
 struct.pack_into('<I',raw,60,int(row['context']['initial_globals'].get('collider_parent_selected',False)))
 context=row.get('park_context',{});root=bytearray.fromhex(context.get('game_root_before_hex',bytes(256).hex()))
 if len(root)!=256:raise ValueError('Expected raw256byte gameRoot')
 raw[800:1056]=root
 struct.pack_into('<III',raw,768,int(context.get('source_flags_8860_u8',0)),int(context.get('input_8918_s32',0))&0xffffffff,int(context.get('selected_parent_pointer_binding',False)))
 if row.get('mode')=='f1030_tick_only':struct.pack_into('<I',raw,0,8)
 if row.get('mode')=='f1047_entry_prefix_only':struct.pack_into('<I',raw,0,16)
 if row.get('mode')=='f574_then_natural_park':struct.pack_into('<I',raw,0,4)
 return bytes(raw)
def execute(binary,rows,repeat=True):
 ordered=rows+list(reversed(rows))if repeat else rows;payload=b''.join(map(packet,ordered));runs=[]
 for _ in range(3 if repeat else 1):
  r=subprocess.run([str(binary)],input=payload,capture_output=True,timeout=120)
  if r.returncode:raise ValueError('Native exit%d after%drecords err%s'%(r.returncode,len(r.stdout)//OUTPUT,r.stderr))
  if len(r.stdout)!=len(ordered)*OUTPUT:raise ValueError('Native short output')
  runs.append(r.stdout)
 if any(raw!=runs[0]for raw in runs):raise ValueError('Fresh repeat mismatch')
 if repeat:
  for i,row in enumerate(rows):
   if runs[0][i*OUTPUT:(i+1)*OUTPUT]!=runs[0][(len(ordered)-1-i)*OUTPUT:(len(ordered)-i)*OUTPUT]:raise ValueError('Reverse mismatch '+row['id'])
 return runs[0]
def decode(raw,row):
 c=N.decode(raw[:1024]);frow=dict(row,player_object_hex=c['player_hex'],parent_object_hex=c['parent_hex'],relative_before_hex=c['relative_after_hex'])
 if struct.unpack_from('<I',raw,1984)[0]:trace=F.decode(raw[:2048],frow)
 else:trace={'volume_trace':[],'selected_child_index':-1,'visited_volume_count':0,'native_termination':'parked_F1030_no_classification'if row.get('mode')=='f1030_tick_only'else'F1047_entry_prefix_stopped_before_F1119'if row.get('mode')=='f1047_entry_prefix_only'else'F575_outer_broadphase_skip'}
 old=c.pop('f576_return_s32');c['f574_called']=row.get('mode')not in ['f1030_tick_only','f1047_entry_prefix_only'];c['f574_return_flags_u8']=old&255 if c['f574_called']else None;c['f574_height_output_s32']=struct.unpack_from('<i',raw,1988)[0]if c['f574_called']else None
 c['f576_return_s32']=struct.unpack_from('<i',raw,1992)[0]if struct.unpack_from('<I',raw,1996)[0]else None
 c['f575_called']=bool(struct.unpack_from('<I',raw,2004)[0]);c['f575_return_eax_s32']=struct.unpack_from('<i',raw,2000)[0]if c['f575_called']else None
 post=raw[2048:2386].hex();state=struct.unpack_from('<I',raw,2012)[0]
 return {'canonical':c,'volume_trace':trace['volume_trace'],'selected_child_index':trace['selected_child_index'],'native_termination':trace['native_termination'],'body_after_f575_hex':post,'natural_continuation':{'executed':bool(struct.unpack_from('<I',raw,2016)[0]),'state_before_u8':struct.unpack_from('<I',raw,2008)[0],'state_after_u8':state,'selected_parent_index_u8':raw[2400+0xc5],'selected_parent_pointer_present':struct.unpack_from('<I',raw,2400+0xcc)[0]!=0,'source_f8_u8':raw[2400+0xf8],'ui_f48_request_count':struct.unpack_from('<I',raw,2020)[0],'actual_f1030_parked_update_executed':bool(struct.unpack_from('<I',raw,2024)[0]),'reference_policy':'native-captured-pointer-word-v1','body_pointer_u32':struct.unpack_from('<I',raw,2960)[0],'parent_pointer_u32':struct.unpack_from('<I',raw,2964)[0],'game_root_before_hex':raw[2688:2944].hex(),'game_root_hex':raw[2400:2656].hex(),'source_flags_8860_before_u8':struct.unpack_from('<I',raw,2944)[0],'source_flags_8860_after_u8':struct.unpack_from('<I',raw,2948)[0],'source_8918_before_s32':struct.unpack_from('<i',raw,2952)[0],'source_8918_after_s32':struct.unpack_from('<i',raw,2956)[0],'f1047_entry_prefix_executed':bool(struct.unpack_from('<I',raw,3028)[0]),'f1047_interception':'before_F1119; F1049_and_later_calls_unexecuted'if struct.unpack_from('<I',raw,3028)[0]else None,'ui_f148_requests':[list(struct.unpack_from('<2i',raw,3036))]if struct.unpack_from('<I',raw,3032)[0]else[],'sound_f1910_requests':[list(struct.unpack_from('<4I',raw,3008))]if struct.unpack_from('<I',raw,3024)[0]else[],'ui_f48_requests':[list(struct.unpack_from('<3i',raw,2976+i*12))for i in range(struct.unpack_from('<I',raw,2020)[0])]}}

def initial_records(binary):
 rows=N.initial_rows();rows=[dict(row,id='initialize/'+str(i),mode='initialize_f1533')for i,row in enumerate(rows)]
 raw=execute(binary,rows)
 return {struct.unpack_from('<I',bytes.fromhex(row['player_object_hex']),0x82)[0]:N.decode(raw[i*OUTPUT:i*OUTPUT+1024])['player_hex']for i,row in enumerate(rows)}
def controls(initialized):
 field=json.load(open(PROJECT/'tests/fixtures/source_contact_field_native.json'));rows=[]
 for a in field['anchors']:
  if a['anchor']!='repro':continue
  mid=a['model_index'];parent=bytearray.fromhex(initialized[mid]);parent[0x86]=1
  struct.pack_into('<I',parent,0xa0,int.from_bytes(bytes.fromhex(a['source_record_hex'])[4:8],'little'))
  for ship in [24,38,15]:
   for offset in [-500,0,{24:5200,38:9600,15:1920}[ship],16000]:
    body=bytearray.fromhex(initialized[ship]);struct.pack_into('<9i',body,0,*a['bodyorientation_q31']);body[0x56]=1;body[0x57]=1;body[0x86]=2;struct.pack_into('<H',body,0x9e,65535)
    # Nonzero raw rates/fractions distinguish F1042 from F575 reset. Inputs only.
    struct.pack_into('<HH',body,0xb0,17,29);struct.pack_into('<HHH',body,0xb6,31,37,41);struct.pack_into('<HHH',body,0xec,0x1234,0x5678,0x9abc)
    radius=a['final_ray_radius_raw']+offset;point=struct.pack('<3q',*((q*radius)>>31 for q in a['radial_q31']));body[0x3e:0x56]=point
    g={name:0 for name,_,_ in N.GLOBAL_FIELDS};g.update(altitude_low_u32=0x89abcdef,altitude_high_s32=-1234567,previous_altitude_low_u32=0x76543210,previous_altitude_high_s32=-2345678,collision_active_u8=77,collision_enabled_u8=255,recorded_intersection_raw=-91,pending_query_flag=17)
    rows.append({'id':f'model{mid}/ship{ship}/root_plus_{offset}','mode':'f574_then_natural_park','player_model':ship,'parent_model':mid,'source_anchor_id':a['id'],'source_record_hex':a['source_record_hex'],'radial_q31':a['radial_q31'],'root_radius_raw':a['final_ray_radius_raw'],'input_offset_raw':offset,'park_context':{'game_root_before_hex':(bytes(0xc0)+struct.pack('<I',2)+bytes(0x34)+bytes([0x7b])+bytes(7)).hex(),'source_flags_8860_u8':0,'input_8918_s32':0x13579bdf,'selected_parent_pointer_binding':False},'input_domain':'actual_F1533_radii; source_root_anchor; zero_velocity; gear_FFFF; actual_F574_disabled_damage; accepted_natural_F1021_fragment_only','player_object_hex':body.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':point.hex(),'context':{'graphics_level':1,'initial_globals':g}})
 # Nonzero sound gate captures an original request, not original audio engine.
 sound=json.loads(json.dumps(next(r for r in rows if r['parent_model']==120 and r['player_model']==38 and r['input_offset_raw']==-500)));sound['id']+='/source_sound_flag80';sound['park_context']['source_flags_8860_u8']=128;rows.append(sound)
 # Canonical outer-band probes deliberately exercise source caps/coarse gates.
 base=list(rows)
 for mid in range(117,134):
  r=json.loads(json.dumps(next(v for v in base if v['parent_model']==mid and v['player_model']==24 and v['input_offset_raw']==0)))
  outer=struct.unpack_from('<q',bytes.fromhex(r['parent_object_hex']),0x138)[0]
  for extra in [-1000,100000]:
   row=json.loads(json.dumps(r));radius=outer+extra;point=struct.pack('<3q',*((q*radius)>>31 for q in row['radial_q31']));body=bytearray.fromhex(row['player_object_hex']);body[0x3e:0x56]=point;row.update(id=f'model{mid}/ship24/canonical_outer_plus_{extra}',mode='f574_only',relative_before_hex=point.hex(),player_object_hex=body.hex(),input_offset_raw=None,input_domain='canonical_original_bounds_outer_band; actual_F574_only');rows.append(row)
 # Source F575 broadphase skip with raw history still present.
 for mid in [117,120]:
  for ship in [24,38,15]:
   row=json.loads(json.dumps(next(r for r in base if r['parent_model']==mid and r['player_model']==ship and r['input_offset_raw']==0)))
   radius=struct.unpack_from('<q',bytes.fromhex(row['parent_object_hex']),0x138)[0]*4;point=struct.pack('<3q',*((q*radius)>>31 for q in row['radial_q31']));body=bytearray.fromhex(row['player_object_hex']);body[0x3e:0x56]=point;row.update(id=f'model{mid}/ship{ship}/F575_far_broadphase_skip',mode='f574_only',relative_before_hex=point.hex(),player_object_hex=body.hex(),input_offset_raw=None,input_domain='actual_F575_broadphase_skip; original_F574_reset_and_preserved_history');rows.append(row)
 # Actual published modern-source child hits, never substituted zero-radius probes.
 old=json.load(open(PROJECT/'tests/fixtures/source_footprint_native.json'))['actor_cases']
 for key in ['118_cobra_roll_plus_3.0','118_shuttle_pitch_minus_0.5']:
  actor=next((v for v in old if v['id']==key),None)
  if actor is None:continue
  row={k:v for k,v in actor.items()if k not in ['expected','visible_ground_points']};body=bytearray.fromhex(initialized[row['player_model']]);sourcebody=bytes.fromhex(row['player_object_hex']);body[:36]=sourcebody[:36];body[0x56:0x58]=sourcebody[0x56:0x58];body[0x86]=sourcebody[0x86];body[0x3e:0x56]=bytes.fromhex(row['relative_before_hex']);struct.pack_into('<H',body,0x9e,65535);struct.pack_into('<HH',body,0xb0,17,29);struct.pack_into('<HHH',body,0xb6,31,37,41);struct.pack_into('<HHH',body,0xec,0x1234,0x5678,0x9abc);row.update(id='full_chain_child/'+key,mode='f574_then_natural_park',player_object_hex=body.hex(),park_context=base[0]['park_context']);rows.append(row)
 return rows

def source_proof(source,data,exe_path):
 exe=exe_path.read_bytes()
 if sha(exe)!=N.EXE_SHA:raise ValueError('Wrong uploaded DOS executable')
 # JJFFE changes elsewhere invalidate large Pos deltas. These two additional
 # entries use unique original opcode prefixes, then EVERY instruction is compared.
 prefixes={1021:'558bec83c4f853568b5d08be3c21640053e8660d00005953e82f10000059f6',1042:'558bec8b450833d289908c00000033d2899090000000'}
 image=N.G.Image(exe);anchors={}
 for number,prefix in prefixes.items():
  needle=bytes.fromhex(prefix);at=exe.find(needle)
  if at<0 or exe.find(needle,at+1)>=0:raise ValueError('Ambiguous original prefix')
  va=next(image.base+section_va+at-file_at for _,section_va,size,file_at in image.sections if file_at<=at<file_at+size)
  anchors[number]={'virtual_address':va,'file_offset':at,'unique_prefix_hex':prefix}
 text=inspect.getsource(N.proof)
 additions=''.join('\n bind(%r,%d)'%('FUNC_%06d'%number,anchor['virtual_address'])for number,anchor in anchors.items())
 text=once(text,"bind('FUNC_000576',0x427e78)","bind('FUNC_000576',0x427e78)"+additions)
 namespace=dict(N.__dict__);exec(text,namespace)
 _,records,_,callbacks=namespace['proof'](source,data,exe,exe_path,sorted(set([576]+ADDITIONAL+STATIC)))
 record={'scope':'Full listed procedures compare instruction-for-instruction with original DOS. Full F1021 and F1047 are statically proved; only the exact accepted F1021 JUMP4228 branch and intercepted F1047 entry prefix execute separately. Adapted helper list does not assert every branch/function is dynamically reached. F1910 and F48 are request observers only.','source_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'procedure_count':len(records),'instruction_count':sum(r['instruction_count']for r in records.values()),'byte_length':sum(r['byte_length']for r in records.values()),'adapted_new_procedure_numbers':ADDITIONAL,'full_procedures_with_only_selected_prefix_or_branch_executed':STATIC,'additional_unique_opcode_entry_anchors':anchors,'procedures':records,'callback_words':callbacks}
 (PROOF/'instruction-proofs.json').write_text(json.dumps(record,indent=2)+'\n')

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--original-source',type=Path);p.add_argument('--data-source',type=Path);p.add_argument('--executable',type=Path);p.add_argument('--work',type=Path);args=p.parse_args();work=args.work or Path(tempfile.mkdtemp(prefix='contact-lifecycle-native-'));work.mkdir(parents=True,exist_ok=True)
 source=args.original_source.read_text()if args.original_source else None;data=args.data_source.read_text()if args.data_source else None
 if source is not None:
  if sha(args.original_source.read_bytes())!=N.ASM_SHA:raise ValueError('Wrong original source assembly')
  if args.executable is None or data is None:raise ValueError('Original source regeneration also requires --data-source and --executable')
  if sha(args.data_source.read_bytes())!='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850':raise ValueError('Wrong original data source')
  source_proof(source,data,args.executable)
 assembly,excluded=build(work,source,data)
 initialized=initial_records(work/'lifecycle');rows=controls(initialized);raw=execute(work/'lifecycle',rows)
 for i,row in enumerate(rows):row['expected']=decode(raw[i*OUTPUT:(i+1)*OUTPUT],row)
 # Repeat contact at the actual native corrected body, retaining actual history;
 # this is a direct F574 requery control, not the state's RET-only parked tick.
 repeats=[]
 for row in rows:
  if not row['expected']['natural_continuation']['executed']:continue
  r={k:v for k,v in row.items()if k!='expected'};r.update(id=row['id']+'/explicit_requery_corrected_body',mode='f574_only',player_object_hex=row['expected']['canonical']['player_hex'],relative_before_hex=bytes.fromhex(row['expected']['canonical']['player_hex'])[0x3e:0x56].hex(),context={'graphics_level':1,'initial_globals':row['expected']['canonical']['globals']},input_domain='explicit_F574_requery_at_actual_native_corrected_body_and_history; not_parked_state_update');repeats.append(r)
 repeated=execute(work/'lifecycle',repeats)
 for i,row in enumerate(repeats):row['expected']=decode(repeated[i*OUTPUT:(i+1)*OUTPUT],row)
 ticks=[]
 for actor in rows:
  e=actor['expected'];park=e['natural_continuation']
  if not park['executed']:continue
  r={k:v for k,v in actor.items()if k!='expected'};root=bytearray.fromhex(park['game_root_hex']);root[0xcc:0xd0]=bytes(4)
  r.update(id=actor['id']+'/cold_restored_f1030_tick',mode='f1030_tick_only',player_object_hex=e['canonical']['player_hex'],relative_before_hex=bytes.fromhex(e['canonical']['player_hex'])[0x3e:0x56].hex(),context={'graphics_level':1,'initial_globals':e['canonical']['globals']},park_context={'game_root_before_hex':root.hex(),'source_flags_8860_u8':park['source_flags_8860_after_u8'],'input_8918_s32':park['source_8918_after_s32'],'selected_parent_pointer_binding':True},input_domain='explicit_host_byte_restore_plus_original_F1030_RET_only; not_original_savefile_or_full_F1009_tick');ticks.append(r)
 tickraw=execute(work/'lifecycle',ticks)
 for i,row in enumerate(ticks):row['expected']=decode(tickraw[i*OUTPUT:(i+1)*OUTPUT],row)
 launches=[]
 for ship in [24,38,15]:
  row=json.loads(json.dumps(next(r for r in ticks if r['parent_model']==120 and r['player_model']==ship and r.get('input_offset_raw')==-500 and not r['park_context']['source_flags_8860_u8'])));row.pop('expected');row.update(id=f'model120/ship{ship}/F1047_launch_entry_prefix',mode='f1047_entry_prefix_only',input_domain='original_F1047_entry_prefix_only; UI148_observed; stopped_before_F1119; no_full_launch_or_F1049');launches.append(row)
 launchraw=execute(work/'lifecycle',launches)
 for i,row in enumerate(launches):row['expected']=decode(launchraw[i*OUTPUT:(i+1)*OUTPUT],row)
 oldpaths=['tests/fixtures/source_natural_contact_native.json','tests/fixtures/source_contact_field_native.json','tests/fixtures/source_footprint_native.json','tests/fixtures/source_contact_frame_native.json']
 report={'schema':1,'revision':'original-native-natural-contact-lifecycle-v1','scope':'Full original F574→F575→F576→F579→bounded natural F582/F581→native F1876, actual F1533 initialized positive three-ship radii. Separate exact accepted F1021 branch/F1042 reset/F1030 RET-only parked update with observed UI callbacks. Explicit corrected-body F574 repeat is not parked-state dispatch. Three separate actual F1047 entry-prefix witnesses stop before F1119/F1049. Damage-enabled F575, full F1021 integration, complete launch, cold save format and Android lifecycle remain unproved.','source_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_commit':N.COMMIT,'native_expected_arithmetic':'none; native source instructions only','old_fixture_sha256':{path:sha((PROJECT/path).read_bytes())for path in oldpaths},'generator_sha256':sha(Path(__file__).read_bytes()),'original_instruction_proofs_sha256':sha((PROOF/'instruction-proofs.json').read_bytes()),'original_instruction_procedure_count':19,'original_instruction_count':1409,'original_instruction_byte_length':4202,'original_F574_policy':'Query wrapper forces collision_enabled=0; clears flags/low-altitude but preserves altitude-high/previous/raw caller history. These are not enabled-FF manual flight inputs.','natural_park_policy':'Actual accepted F1021 JUMP4228 path, caller precondition state!=2C and flags20 clear; full F1021 integration is not executed. F1042 resets integer velocities/rates/targets and DATA8918 while EC..F0 raw fractions remain. State32 F1030 RET is executed, separate from full F1009 clock/gear update.','root_alias_policy':'Original DATA8804base aliases DATA8807+4,8812+10hex,8857+C0hex,8860+C6hex,8861+C8hex,8870+E8hex,8878+F0hex,8880+F8hex,8918+1B8hex; native input overlays observed globals/pointers before snapshot. First256rootbytes exposed plus separate8918control.','cold_restore_policy':'Explicit host restoration of captured raw body/root/history with isolated low-address native parent pointer rebinding; original savegame format and Android process restore are not proved.','observed_assembly_sha256':sha(assembly.encode()),'excluded_assembly_sha256':sha(excluded.encode()),'native_fresh_process_runs_per_bank':3,'reverse_repeats_per_case':1,'actor_case_count':len(rows),'explicit_corrected_requery_case_count':len(repeats),'parked_cold_tick_case_count':len(ticks),'launch_entry_prefix_case_count':len(launches),'case_count':len(rows)+len(repeats)+len(ticks)+len(launches),'actor_output_sha256':sha(raw),'requery_output_sha256':sha(repeated),'parked_tick_output_sha256':sha(tickraw),'launch_entry_output_sha256':sha(launchraw),'initialized_record_hex':{str(k):v for k,v in initialized.items()},'actor_cases':rows,'corrected_requery_cases':repeats,'parked_tick_cases':ticks,'launch_entry_cases':launches}
 out=PROJECT/'tests/fixtures/source_contact_lifecycle_native.json';out.write_text(json.dumps(report,separators=(',',':'))+'\n');(PROOF/'summary.json').write_text(json.dumps({k:v for k,v in report.items()if k not in ['actor_cases','corrected_requery_cases','parked_tick_cases','launch_entry_cases','initialized_record_hex']},indent=2)+'\n')
 print('SOURCE LIFECYCLE NATIVE',len(rows),'actors',len(repeats),'actual corrected repeats',len(ticks),'cold RETticks',len(launches),'bounded launch entry',sha(out.read_bytes()),'work',work)
if __name__=='__main__':main()
