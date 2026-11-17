#!/usr/bin/env python3
"""Supplemental native F606→F1041 continuation controls; main640 bank unchanged."""
from __future__ import annotations
import argparse,copy,hashlib,importlib.util,json,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
PLAYER_PROOF=PROJECT/'validation/player-dispatch-2026-11-17/player-native-proof'
BANK_PROOF=PROJECT/'validation/reference-bank-2026-11-17/native-proof'
DEFAULT=PLAYER_PROOF/'player-frame-chain.json'

def sha(raw):return hashlib.sha256(raw).hexdigest()
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def generate(output):
 P=module('native_chain_player',PROJECT/'tools/rebuild_source_player_dispatch_native.py')
 R=module('native_chain_reference',PROJECT/'tools/rebuild_source_reference_bank_native.py')
 player_source=(PLAYER_PROOF/'source-procedures.s').read_text();player_meta=json.loads((PLAYER_PROOF/'instruction-proof.json').read_text());P.verify_archived(player_meta,player_source)
 player_kernel=P.assembly(player_source);bank_kernel=(BANK_PROOF/'reference-bank-observed-kernel.s').read_bytes()
 bank_meta=json.loads((BANK_PROOF/'instruction-proof.json').read_text())
 if sha(bank_kernel)!=bank_meta['host_assembly_sha256']:raise ValueError('Pinned reference native kernel differs')
 controls=json.loads((PROJECT/'tests/fixtures/source_reference_bank_native.json').read_text())
 cases=[]
 with tempfile.TemporaryDirectory(prefix='native-player-frame-chain-') as directory:
  work=Path(directory)
  for name,body in [('player',player_kernel.encode()),('bank',bank_kernel)]:
   (work/(name+'.s')).write_bytes(body);subprocess.run(['as','--64','-o',str(work/(name+'.o')),str(work/(name+'.s'))],check=True);subprocess.run(['ld','-o',str(work/name),str(work/(name+'.o'))],check=True)
  def player(row):
   runs=[subprocess.run([str(work/'player')],input=P.packet(row),capture_output=True,check=True).stdout for _ in range(3)]
   if len(set(runs))!=1 or len(runs[0])!=P.OUTPUT:raise ValueError('Native player chain unstable')
   return P.decode(runs[0],row),sha(runs[0])
  def bank(row):
   runs=[subprocess.run([str(work/'bank')],input=R.packet(row),capture_output=True,check=True).stdout for _ in range(3)]
   if len(set(runs))!=1 or len(runs[0])!=R.OUTPUT:raise ValueError('Native bank chain unstable')
   raw=runs[0];head=struct.unpack_from('<16I',raw)
   if head[0]!=0x52454642 or head[7] or raw[-64:]!=b'\xa5'*64:raise ValueError('Native reference chain guard')
   native_bank=raw[64+R.OBJECT:64+R.OBJECT+R.BANK]
   objects={index:native_bank[0x74+int(index)*R.OBJECT:0x74+(int(index)+1)*R.OBJECT].hex()for index in row['objects_by_index']}
   expected={'body_hex':raw[64:64+R.OBJECT].hex(),'objects_by_index':objects,'flags_hex':native_bank[:115].hex(),'events':[[11,0]]*head[1]}
   before=bytearray(R.packet(row)[28+R.OBJECT:])
   for index,body in objects.items():
    at=0x74+int(index)*R.OBJECT;before[at:at+R.OBJECT]=bytes.fromhex(body)
   if bytes(before)!=native_bank or row['flags_hex']!=expected['flags_hex']:raise ValueError('Unprovided reference slot changed')
   return expected,sha(raw)
  for reference_name,root_case in [('select_parent/2',False),('select_parent/7',True)]:
   reference=copy.deepcopy(next(row for row in controls['cases']if row['name']==reference_name))
   initial=bytearray.fromhex(reference['body_hex']);initial[0x14d]=0
   own=int(initial[0x86]);parent_index=int(initial[0x56])
   if root_case and parent_index!=0:raise ValueError('Supplemental root case not a root')
   parent_hex=reference['objects_by_index'][str(parent_index)]if parent_index else bytes(P.OBJECT).hex()
   globals_before={'frame_ticks_u32':4971 if root_case else 0,'spin_elapsed_s32':40000001,'player_mode_u8':0,'flight_flags_u8':0,'set_speed_s32':12345,'damping_flags_u8':0,'reference_velocity_s32':[0,0,0],'forward_key_u8':1,'reverse_key_u8':1,'spin_xyz_s32':[123,-456,789],'player_index_u32':own,'player_roll_s16':7,'drift_ticks_low_u32':0,'drift_ticks_high_u32':0}
   row={'name':'root-parent-native-continuation'if root_case else'actual-bank-before-speed-control','operation':'prepare_f1041','body_before_hex':initial.hex(),'parent_hex':parent_hex,'globals_before':globals_before,'frame_response_body_hex':''}
   observer,observer_sha=player(row)
   if not observer['frame_selection_requested']:raise ValueError('Supplemental F606 boundary not reached')
   bank_input=copy.deepcopy(reference);bank_input['body_hex']=observer['frame_boundary_body_hex']
   bank_expected,bank_sha=bank(bank_input)
   row['frame_response_body_hex']=bank_expected['body_hex']
   final,final_sha=player(row)
   late_input=copy.deepcopy(reference);late_input['body_hex']=observer['body_after_hex']
   late,late_sha=bank(late_input)
   late_body=bytes.fromhex(late['body_hex']);final_body=bytes.fromhex(final['body_after_hex'])
   differing=[index for index,(a,b) in enumerate(zip(final_body,late_body))if a!=b]
   if not root_case and not any(index in range(0xf2,0xfe)for index in differing):raise ValueError('Native proof does not distinguish pre/post F607 velocity use')
   cases.append({'name':row['name'],'original_reference_case':reference_name,'source_adapter':{'initial_timer_14d_u8':0,'root_parent_uses_zero_placeholder_parent_record':root_case,'other_initial_body_bytes_changed':False},'bank_input':bank_input,'player_input':row,'player_observer_expected':observer,'bank_expected':bank_expected,'player_expected':final,'wrong_late_order':{'body_hex':late['body_hex'],'body_differs':bool(differing),'different_byte_offsets':differing,'explanation':'Run original F1041 without frame response, then original F606 after F607/F599; this is deliberately the wrong callback order.'},'native_output_sha256':{'player_observer':observer_sha,'bank_middle':bank_sha,'player_with_middle_response':final_sha,'bank_after_player_wrong_order':late_sha},'fresh_runs_each_phase':3})
 pins={name:sha((PROJECT/name).read_bytes())for name in ['tools/rebuild_source_player_dispatch_native.py','tools/rebuild_source_reference_bank_native.py','tools/rebuild_source_player_frame_chain_native.py','tests/fixtures/source_player_dispatch_native.json','tests/fixtures/source_reference_bank_native.json','validation/player-dispatch-2026-11-17/player-native-proof/instruction-proof.json','validation/player-dispatch-2026-11-17/player-native-proof/source-procedures.s','validation/reference-bank-2026-11-17/native-proof/instruction-proof.json','validation/reference-bank-2026-11-17/native-proof/reference-bank-observed-kernel.s']}
 report={'schema':'starfrontier-native-player-frame-chain-v1','profile':'dos-firstenc-player-control-dispatch-v1','source_executable_sha256':P.EXE_SHA,'case_count':len(cases),'cases':cases,'source_pins':pins,'source_kernel_sha256':{'player':sha(player_kernel.encode()),'reference_bank':sha(bank_kernel)},'main640_fixture_changed':False,'supplemental_controls_added_to_main_case_totals':False,'private_original_inputs_needed':False,'expected_arithmetic_calculated_in_python':False,'scope':'Separate actual native composition: original player F1041 observer prefix, whole original F606 on that exact raw prefix/bank, then original F1041 continuation with the actual native F606 output injected at the callback boundary before F607. Wrong late-order composition is independently executed. Both native ABI kernels retain their declared F866-copy and sound/event observer limits. No F1019 admission, full F570, world scheduler, live Main or Android claim.'}
 output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'case_count':len(cases),'output':str(output),'sha256':sha(output.read_bytes()),'wrong_order_body_differs':[c['wrong_late_order']['body_differs']for c in cases]},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=DEFAULT);a=p.parse_args();generate(a.output)
if __name__=='__main__':main()
