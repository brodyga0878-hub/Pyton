#!/usr/bin/env python3
"""Real F575/F576/F582/F581/F1876 composition on original natural programs.

All expected arithmetic executes captured original native kernels. Python
only transports raw measured replies. F953 remains an explicit identity
observation; terrain results and persistent query words are never invented.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_collision_contact_native as Chain
import rebuild_source_collision_terrain_native as H

C=Chain.C;G=Chain.G;V=Chain.V;P=Chain.P;T=Chain.T
PROJECT=C.PROJECT
PROOF=PROJECT/'validation/terrain-height-2026-11-17/surface-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_collision_surface_native.json'
CATALOG='data/ffe_collision_programs.json'
NATURAL_SEEDS='tests/fixtures/source_natural_contact_native.json'
PROFILE='dos-firstenc-actual-terrain-contact-composition-v1'
def sha(raw):return hashlib.sha256(raw).hexdigest()

def initial_cases():
    seeds=json.loads((PROJECT/NATURAL_SEEDS).read_text());rows=[]
    for index,mid in enumerate(range(117,149)):
        own=[24,15,38][index%3]
        old=next(r for r in seeds['cases']if r['parent_model']==mid and r['player_model']==own and r['selection']=='shell_mid'and r['expected']['terrain_query_calls']>0)
        body=bytearray.fromhex(old['player_object_hex']);parent=bytearray.fromhex(old['parent_object_hex'])
        body[0x86]=114;parent[0x86]=37;body[0x56]=37;parent[0x56]=0
        body[0x87]=3;parent[0x87]=1
        body[0x3e:0x56]=bytes.fromhex(old['relative_before_hex'])
        struct.pack_into('<3q',parent,0x3e,0,0,0)
        struct.pack_into('<3i',body,0x8c,0,0,0)
        struct.pack_into('<H',body,0x9e,0xffff)
        globals={name:0 for name,_,_ in C.FIELDS}
        # These are the original fixture's explicit raw source words; its
        # measured height is not reused as an expected result in this chain.
        for name,_,_ in G.FIELDS:
            if name in old['context']['initial_globals']:globals[name]=old['context']['initial_globals'][name]
        globals.update(player_index_u32=114,collider_ref_u32=37,collider_index_u8=0,collision_enabled_u8=0 if index%2 else 1)
        prior=old['context']['initial_globals']
        state={'graphics_level_u32':old['context']['graphics_level'],'recorded_intersection_raw_s32':prior['recorded_intersection_raw'],'pending_query_flag_u32':prior['pending_query_flag']}
        rows.append({'name':'actual-terrain-contact/model%d/ship%d'%(mid,own),'body_hex':body.hex(),'collider_hex':parent.hex(),'relative_hex':old['relative_before_hex'],'globals_before':globals,'terrain_state_before':state,'own_model_u32':own,'collider_model_u32':mid,'seed_native_case':old['name'],'seed_scope':'Exact raw records and queried-band vector from prior independent native F576 controls; distinct IDs, selected-parent position and healthy stationary pose are explicit authored source inputs.'})
    for ordinal,seed_index in enumerate([0,1,12,31]):
        flat=copy.deepcopy(rows[seed_index]);flat['name']='actual-flat-contact/model%d'%flat['collider_model_u32']
        flat['relative_hex']=bytes(24).hex();body=bytearray.fromhex(flat['body_hex']);body[0x3e:0x56]=bytes(24);flat['body_hex']=body.hex()
        flat['terrain_state_before']={'graphics_level_u32':[0xffffffff,0x80000000,0,15][ordinal],'recorded_intersection_raw_s32':[-0x80000000,0x7fffffff,-1,123456][ordinal],'pending_query_flag_u32':[0xffffffff,0x80000000,1,0][ordinal]}
        flat['is_flat_auxiliary_guard']=True;flat['seed_scope']+=' Explicit zero source-space pose exercises the real inner gate; query words and full graphics must remain unchanged.'
        rows.append(flat)
    return rows

def compile_terrain(folder,kernel,adapter):
    for name,text in [('terrain',kernel),('terrain-adapter',adapter)]:
        (folder/(name+'.s')).write_text(text)
        subprocess.run(['as','--64','-o',str(folder/(name+'.o')),str(folder/(name+'.s'))],capture_output=True,check=True)
    target=folder/'terrain'
    subprocess.run(['ld','-o',str(target),str(folder/'terrain.o'),str(folder/'terrain-adapter.o')],capture_output=True,check=True)
    return target

def generate(a):
    catalog_raw=(PROJECT/CATALOG).read_bytes();models=json.loads(catalog_raw)['models']
    cm=json.loads((C.PROOF/'instruction-proof.json').read_text());cs=(C.PROOF/'source-procedures.asm').read_text();C.verify_archived(cm,cs)
    gm=json.loads((G.PROOF/'instruction-proof.json').read_text());gs=(G.PROOF/'source-procedures.asm').read_text();G.verify_archived(gm,gs)
    vm,vs=V.verify(V.PROOF);pm,ps=P.verify(P.PROOF);tm,ts=T.verify(T.PROOF)
    hm,hs,terrain_kernel,terrain_adapter=H.verify(H.PROOF)
    assemblies={'classifier':C.assembly(cs),'geometry':G.assembly(gs),'program':V.assembly(vs,ps,ts),'terrain':terrain_kernel,'terrain-adapter':terrain_adapter}
    records={k:[]for k in ['classifier','geometry','program','terrain']};rows=initial_cases()
    with tempfile.TemporaryDirectory(prefix='native-terrain-contact-')as directory:
        folder=Path(directory)
        binaries={k:Chain.compile_native(folder,k,assemblies[k])for k in ['classifier','geometry','program']}
        binaries['terrain']=compile_terrain(folder,terrain_kernel,terrain_adapter)
        def execute(kind,packet,size):
            runs=[subprocess.run([str(binaries[kind])],input=packet,capture_output=True,check=True,timeout=120).stdout for _ in range(3)]
            if len(set(runs))!=1 or len(runs[0])!=size:raise ValueError('Native repeat/length differs '+kind)
            records[kind].append((packet,runs[0]));return runs[0]
        for row in rows:
            own=row['own_model_u32'];parent=row['collider_model_u32'];nested=Chain.closure(models,parent)
            for mid in [own,parent]:
                if models[str(mid)]['descriptor_hex']!=cm['models'][str(mid)]['descriptor_hex']:raise ValueError('Descriptor identity differs across native kernels')
            classifier={'name':row['name'],'body_before_hex':row['body_hex'],'collider_before_hex':row['collider_hex'],'relative_before_hex':row['relative_hex'],'globals_before':row['globals_before'],'scripts':[{'return_u32':0,'globals':{}}for _ in range(C.MAXOBS)]}
            first=C.decode(execute('classifier',C.packet(classifier,cm['models']),C.OUTPUT),classifier)
            boundaries=[(i,o)for i,o in enumerate(first['observations'])if o['kind']=='F576']
            if len(boundaries)!=1:raise ValueError('Authored source input did not reach F576 '+row['name'])
            boundary_index,boundary=boundaries[0];before=boundary['before']
            front={'name':row['name']+'/F576','body_hex':before['body_hex'],'collider_hex':before['collider_hex'],'relative_hex':before['relative_hex'],'globals_before':{name:before['globals'][name]for name,_,_ in G.FIELDS},'resources':{str(own):copy.deepcopy(models[str(own)]),str(parent):copy.deepcopy(models[str(parent)])},'scripts':[]}
            program_calls=[];aux=copy.deepcopy(row['terrain_state_before'])
            for iteration in range(G.MAXCALLS+1):
                front_result=G.decode(execute('geometry',G.packet(front),G.OUTPUT),front)
                if len(front['scripts'])==len(front_result['calls']):break
                if len(front['scripts'])>len(front_result['calls']):raise ValueError('F576 replay erased preceding callbacks')
                prepared=front_result['calls'][len(front['scripts'])];resource=models[str(parent)]
                context={k:prepared[k]for k in ['point_xyz_s32','mesh_zoom_s32','vector_scale_s32']}
                context.update(normals_hex=resource['normals_hex'],vertices_hex=resource['vertices_hex'],normal_origin_u32=resource['normals_origin_u32'],vertex_origin_u32=resource['vertices_origin_u32'])
                program={'name':row['name']+'/F582-%02d'%len(front['scripts']),'body_before_hex':front['collider_hex'],'program_hex':resource['collision_program_hex'],'context':context,'threshold_s32':prepared['threshold_s32'],'globals_before':prepared['globals_before'],'primitive_u8_before':0,'resources':nested,'terrain_scripts':[]}
                terrain_calls=[];aux_before=copy.deepcopy(aux)
                for terrain_index in range(9):
                    actual=V.decode(execute('program',V.packet(program),V.OUTPUT),program)
                    if len(program['terrain_scripts'])==len(actual['observations']):break
                    if len(program['terrain_scripts'])>len(actual['observations']):raise ValueError('F582 replay erased preceding F581 calls')
                    observed=actual['observations'][len(program['terrain_scripts'])]
                    terrain_before=observed['before']
                    terrain={'name':program['name']+'/F581-%d'%len(program['terrain_scripts']),'body_before_hex':terrain_before['body_hex'],'program_hex':terrain_before['program_hex'],'offset_u32':int(observed['args'][0]),'context':copy.deepcopy(terrain_before['context']),'threshold_s32':int(observed['args'][1]),'globals_before':copy.deepcopy(terrain_before['globals']),'terrain_state_before':copy.deepcopy(aux)}
                    computed=H.decode(execute('terrain',H.packet(terrain),H.OUTPUT),terrain)
                    program['terrain_scripts'].append({'return_s32':computed['hit_s32'],'next_offset_u32':computed['next_offset_u32'],'globals_after':computed['globals_after']})
                    terrain_calls.append({'input':terrain,'expected':computed});aux=copy.deepcopy(computed['terrain_state_after'])
                else:raise ValueError('Native F581 observation transport exhausted')
                for observed,terrain_call in zip(actual['observations'],terrain_calls):
                    computed=terrain_call['expected']
                    if observed['return_s32']!=computed['hit_s32']or observed['next_offset_u32']!=computed['next_offset_u32']or observed['after']['globals']!=computed['globals_after']:raise ValueError('Actual F581 result was not resumed exactly inside F582')
                front['scripts'].append({'return_s32':actual['return_s8'],'primitive_u8':actual['primitive_u8'],'globals_after':actual['globals_after']})
                program_calls.append({'input':program,'expected':actual,'terrain_state_before':aux_before,'terrain_state_after':copy.deepcopy(aux),'terrain_calls':terrain_calls})
            else:raise ValueError('Native F576 observation transport exhausted')
            for front_call,program_call in zip(front_result['calls'],program_calls):
                actual=program_call['expected']
                if front_call['return_s32']!=actual['return_s8']or front_call['primitive_u8']!=actual['primitive_u8']or front_call['globals_after']!=actual['globals_after']:raise ValueError('Actual program result was not resumed inside F576')
            after=dict(front_result['globals_after']);after['player_index_u32']=before['globals']['player_index_u32']
            classifier['scripts'][boundary_index]={'return_u32':front_result['return_s32']&0xffffffff,'globals':after}
            final=C.decode(execute('classifier',C.packet(classifier,cm['models']),C.OUTPUT),classifier)
            resumed=next(o for o in final['observations']if o['kind']=='F576')
            if resumed['after']['globals']!=after or resumed['return_u32']!=(front_result['return_s32']&0xffffffff):raise ValueError('Actual F576 result was not resumed inside F575')
            if row.get('is_flat_auxiliary_guard'):
                if aux!=row['terrain_state_before']or any(t['expected']['query_count_u32']for p in program_calls for t in p['terrain_calls']):raise ValueError('Actual flat gate changed persistent query words or entered F1876')
            row.update(observations=Chain.observations(final),geometry_observations=[],expected=final,terrain_state_after=copy.deepcopy(aux),geometry_expected=front_result,program_calls=program_calls)
        for kind,items in records.items():
            reverse=subprocess.run([str(binaries[kind])],input=b''.join(packet for packet,_ in reversed(items)),capture_output=True,check=True,timeout=120).stdout
            if reverse!=b''.join(output for _,output in reversed(items)):raise ValueError('Native reverse order contamination '+kind)
    paths=['tools/rebuild_source_collision_surface_native.py','tools/rebuild_source_collision_contact_native.py','tools/rebuild_source_collision_terrain_native.py','tools/rebuild_source_contact_classifier_native.py','tools/rebuild_source_collision_geometry_native.py','tools/rebuild_source_collision_program_native.py','tools/rebuild_source_collision_planes_native.py','tools/rebuild_source_collision_transform_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_spherical_contact_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_frame_dispatch_native.py','recovered-history/ground_harness/tools/native_reference.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py',CATALOG,NATURAL_SEEDS]
    for directory in [C.PROOF,G.PROOF,V.PROOF,P.PROOF,T.PROOF,H.PROOF]:
        paths.extend(str(p.relative_to(PROJECT))for p in directory.iterdir()if p.name in ['instruction-proof.json','source-procedures.asm','source-procedures.s','terrain-native.s','terrain-adapter.s'])
    terrain_calls=[t for row in rows for p in row['program_calls']for t in p['terrain_calls']]
    proof={'schema':'starfrontier-original-terrain-contact-composition-v1','source_executable_sha256':C.C.EXE_SHA,'source_assembly_sha256':C.C.ASM_SHA,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in sorted(set(paths))},'collision_resource_sha256':sha(catalog_raw),'host_assembly_sha256':{k:sha(v.encode())for k,v in assemblies.items()},'fresh_process_runs_each_call':3,'reverse_repeat_native_calls':{k:len(v)for k,v in records.items()},'native_calls':{k:len(v)for k,v in records.items()},'native_input_sha256':{k:sha(b''.join(p for p,_ in v))for k,v in records.items()},'native_output_sha256':{k:sha(b''.join(o for _,o in v))for k,v in records.items()},'actual_F581_calls':len(terrain_calls),'actual_F1876_queries':sum(t['expected']['query_count_u32']for t in terrain_calls),'persistent_aux_words_measured':True,'expected_arithmetic_calculated_in_python':False,'all_raw_canaries_verified':True,'F953_policy':'Explicit matched identity observations only; authoritative damage, allocation and world effects remain outside this oracle.','scope':'Whole original F575 resumes actual F576/F579, actual collision programs F582 and real F581/F1876 queries. Original natural model programs117..148 and native raw seed-band records are used; persistent graphics/query words are transported from measured native results. F953 remains matched identity observation. No live Main, Android, full damage engine or all37terrainrecord composition claim.'}
    proof['actual_flat_F581_calls']=sum(1 for t in terrain_calls if t['expected']['query_count_u32']==0)
    proof['flat_auxiliary_guard_cases']=sum(bool(row.get('is_flat_auxiliary_guard'))for row in rows)
    proof['multi_child_cases']=sum(len(row['program_calls'])>1 for row in rows)
    proof['matched_F953_identity_observations']=sum(len(row['observations'])for row in rows)
    a.proof_dir.mkdir(parents=True,exist_ok=True)
    for name,text in assemblies.items():(a.proof_dir/(name+'-composed-native.s')).write_text(text)
    (a.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
    fixture={'schema':'starfrontier-source-collision-surface-native-v1','profile':PROFILE,'case_count':len(rows),'natural_models':list(range(117,149)),'proof':proof,'cases':rows,'scope':proof['scope']}
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n')
    print(json.dumps({'case_count':len(rows),'actual_F581_calls':proof['actual_F581_calls'],'actual_F1876_queries':proof['actual_F1876_queries'],'native_calls':proof['native_calls'],'fixture_sha256':sha(a.output.read_bytes())},indent=2))
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=FIXTURE);parser.add_argument('--proof-dir',type=Path,default=PROOF)
    for name in ['exe','asm','data']:parser.add_argument('--'+name,type=Path)
    generate(parser.parse_args())
if __name__=='__main__':main()
