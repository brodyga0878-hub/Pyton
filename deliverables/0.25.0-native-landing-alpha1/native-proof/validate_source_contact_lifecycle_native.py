#!/usr/bin/env python3
"""Validate immutable native lifecycle witnesses; optional archived replay."""
from __future__ import annotations
import argparse,collections,hashlib,importlib.util,json,struct,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('lifecycle_replay',HERE/'rebuild_source_contact_lifecycle_native.py');L=importlib.util.module_from_spec(spec);spec.loader.exec_module(L)
def sha(b):return hashlib.sha256(b).hexdigest()
def word(b,at):return struct.unpack_from('<H',b,at)[0]
def dword(b,at):return struct.unpack_from('<I',b,at)[0]
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--replay',action='store_true');args=parser.parse_args()
 path=ROOT/'tests/fixtures/source_contact_lifecycle_native.json';raw=path.read_bytes();f=json.loads(raw);checks=0
 def check(ok,why):
  nonlocal checks
  checks+=1
  if not ok:raise ValueError(why)
 check(f['generator_sha256']==sha((HERE/'rebuild_source_contact_lifecycle_native.py').read_bytes()),'Generator pin')
 check(f['observed_assembly_sha256']==sha((HERE/'lifecycle-observed-kernel.s').read_bytes()),'Assembly pin')
 check(f['excluded_assembly_sha256']==sha((HERE/'excluded-native.s').read_bytes()),'Adapter pin')
 check(f['original_instruction_proofs_sha256']==sha((HERE/'instruction-proofs.json').read_bytes()),'Instruction proof pin')
 proof=json.load(open(HERE/'instruction-proofs.json'));check(proof['procedure_count']==19 and proof['instruction_count']==1409 and proof['byte_length']==4202,'Full DOS instruction coverage')
 check(all(r['all_instructions_equal']for r in proof['procedures'].values()),'Original procedure equivalence')
 for name,digest in f['old_fixture_sha256'].items():check(sha((ROOT/name).read_bytes())==digest,'Old immutable proof '+name)
 for model,(outer,inner)in {24:(10400,5200),38:(36000,9600),15:(4800,1920)}.items():
  b=bytes.fromhex(f['initialized_record_hex'][str(model)]);check(struct.unpack_from('<2q',b,0x138)==(outer,inner),'Original F1533 ship radii')
 stats=collections.Counter();models=set();ships=set()
 for bank in ['actor_cases','corrected_requery_cases','parked_tick_cases','launch_entry_cases']:
  for r in f[bank]:
   e=r['expected'];c=e['canonical'];p=e['natural_continuation'];before=bytes.fromhex(r['player_object_hex']);after=bytes.fromhex(c['player_hex']);post575=bytes.fromhex(e['body_after_f575_hex']);rootbefore=bytes.fromhex(p['game_root_before_hex']);rootafter=bytes.fromhex(p['game_root_hex']);g=c['globals'];initial=r['context']['initial_globals']
   check(len(before)==len(after)==len(post575)==338,'Raw body extent '+r['id']);check(c['parent_hex']==r['parent_object_hex'],'Parent immutable '+r['id'])
   check(p['source_flags_8860_before_u8']==r['park_context']['source_flags_8860_u8']==p['source_flags_8860_after_u8'],'Raw source sound flag '+r['id'])
   check(p['source_8918_before_s32']==r['park_context']['input_8918_s32'],'Raw source control input '+r['id'])
   check(p['body_pointer_u32']>0 and p['parent_pointer_u32']>0 and p['body_pointer_u32']!=p['parent_pointer_u32'],'Observed independent native pointers '+r['id'])
   if bank=='actor_cases':models.add(r['parent_model']);ships.add(r['player_model'])
   if r['mode']=='f1047_entry_prefix_only':
    check(after==before==post575,'Original F1047 prefix preserves all338bodybytes '+r['id']);check(c['globals']==initial,'No classification/history mutation in bounded launch prefix '+r['id']);check(not c['f574_called']and not c['f575_called']and c['f576_return_s32']is None and c['terrain_query_calls']==0,'No contact or response in launch entry prefix '+r['id']);check(p['state_before_u8']==0x32 and p['state_after_u8']==0x34,'Actual original launch request state32→34 '+r['id']);check(dword(rootafter,0xf0)==1 and rootafter[0xf8]==255,'Actual original launch request words '+r['id']);check(p['f1047_entry_prefix_executed']and not p['actual_f1030_parked_update_executed']and p['ui_f148_requests']==[[14,0]],'Actual original bounded UI148 request '+r['id']);check(not p['ui_f48_requests']and not p['sound_f1910_requests']and p['source_8918_before_s32']==p['source_8918_after_s32'],'F1049 reset and later UI unexecuted '+r['id']);stats['bounded_f1047_entry_prefixes']+=1;continue
   if r['mode']=='f1030_tick_only':
    check(after==before==post575,'Original F1030 preserves all338bodybytes '+r['id']);check(c['globals']==initial,'Original F1030 preserves exact history/globalbytes '+r['id']);check(rootbefore==rootafter,'Original F1030 preserves restored raw root '+r['id']);check(p['actual_f1030_parked_update_executed']and not p['executed'],'Only original parked update '+r['id']);check(not c['f575_called']and c['f576_return_s32']is None and c['terrain_query_calls']==0,'No contact requery while parked '+r['id']);check(p['state_before_u8']==p['state_after_u8']==0x32,'Actual natural parked32 state '+r['id']);check(p['source_8918_after_s32']==p['source_8918_before_s32']and not p['ui_f48_requests']and not p['sound_f1910_requests'],'No reset/callback during RET '+r['id']);stats['cold_f1030_ticks']+=1;continue
   check(c['f575_called'],'Full original F575 actually called '+r['id']);check(g['collision_enabled_u8']==0,'F574 disabled-response query wrapper '+r['id'])
   check(c['f574_return_flags_u8']==g['collision_flags_u8'],'Original source return lowbyte '+r['id'])
   if c['f576_return_s32']in [-1,None]:check(post575==before,'No-hit source does not mutate body '+r['id']);stats['noncontacts']+=1
   if c['f576_return_s32']==0:stats['contacts']+=1
   if e['selected_child_index']>0:stats['selected_child_hits']+=1
   if c['f576_return_s32']is None:
    check(not e['volume_trace'] and c['terrain_query_calls']==0,'Broadphase skip no F576 '+r['id']);stats['broadphase_skips']+=1
   if p['executed']:
    check(c['f576_return_s32']==0 and c['f574_return_flags_u8']&0x40 and not(c['f574_return_flags_u8']&0x20),'Actual accepted original natural source flags '+r['id'])
    check(p['state_before_u8']==0 and p['state_after_u8']==0x32 and rootafter[0xf8]==255,'Actual source park transition '+r['id'])
    check(rootafter[0xc5]==bytes.fromhex(r['parent_object_hex'])[0x86]and dword(rootafter,0xcc)==p['parent_pointer_u32'],'Actual original parent reference '+r['id'])
    check(p['ui_f48_requests']==[[1,0,13],[1,0,14]],'Actual original UI request args '+r['id'])
    check(p['actual_f1030_parked_update_executed'],'Original parked RET tick reached '+r['id'])
    for at in [0x8c,0x90,0x94]:check(dword(after,at)==0,'F1042 integer velocity clear '+r['id'])
    for at in [0xb0,0xb2,0xb6,0xb8,0xba]:check(word(post575,at)==word(before,at)!=0 and word(after,at)==0,'F1042 nonzero rate/target reset '+r['id'])
    check(after[0xec:0xf2]==post575[0xec:0xf2]==before[0xec:0xf2]==bytes.fromhex('34127856bc9a'),'F575/F1042 preserve actual nonzero raw velocity fractions '+r['id'])
    check(p['source_8918_after_s32']==0 and p['source_8918_before_s32']!=0,'Actual source global control reset '+r['id'])
    expected_sound=[[3,1,300,p['body_pointer_u32']]]if p['source_flags_8860_before_u8']&128 else[];check(p['sound_f1910_requests']==expected_sound,'Actual observed sound request args '+r['id']);stats['natural_park_transitions']+=1
   else:
    check(after==post575,'No F1042 outside accepted continuation '+r['id']);check(p['source_8918_after_s32']==p['source_8918_before_s32'],'No source control reset outside continuation '+r['id']);check(not p['ui_f48_requests']and not p['sound_f1910_requests'],'No callbacks outside continuation '+r['id'])
   for t in e['volume_trace']:
    stats['visited_volumes']+=1
    if t['terrain_query_calls']:stats['native_queries']+=1
    if t['query']['fresh_altitude_written']:stats['fresh_query_altitudes']+=1
    if t['branch']=='outside_outer':stats['outside_coarse_gates']+=1
   if not c['terrain_query_calls']:
    check(g['altitude_low_u32']==0xffffffff and g['altitude_high_s32']==initial['altitude_high_s32'],'F574 low-only altitude reset '+r['id']);check(g['previous_altitude_low_u32']==initial['previous_altitude_low_u32']and g['previous_altitude_high_s32']==initial['previous_altitude_high_s32'],'No-query inherited previous altitude '+r['id'])
 check(models==set(range(117,134))and ships=={15,24,38},'17solids/3actualships coverage')
 check(len(f['actor_cases'])==247 and len(f['corrected_requery_cases'])==len(f['parked_tick_cases'])==76,'Bounded final case counts')
 if args.replay:
  work=Path(tempfile.mkdtemp(prefix='contact-lifecycle-validate-'));L.build(work)
  for bank,key in [('actor_cases','actor_output_sha256'),('corrected_requery_cases','requery_output_sha256'),('parked_tick_cases','parked_tick_output_sha256'),('launch_entry_cases','launch_entry_output_sha256')]:
   rows=f[bank];native=L.execute(work/'lifecycle',rows);check(sha(native)==f[key],'Native ordered output digest '+bank)
   for i,row in enumerate(rows):check(L.decode(native[i*L.OUTPUT:(i+1)*L.OUTPUT],row)==row['expected'],'Exact original-native replay '+row['id'])
  stats['native_replayed_cases']=f['case_count']
 report={'schema':1,'checks':checks,'failures':0,'fixture_sha256':sha(raw),'counts':dict(sorted(stats.items())),'scope':'Independent original-instruction observations; full contact query/response and separately accepted natural park fragment plus RET-only state update. Explicit host restore and direct requery controls do not prove original saves, complete F1009 dispatch, full F1021 flight, F1047 launch beyond the explicitly intercepted entry prefix or Android lifecycle.'}
 (HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
