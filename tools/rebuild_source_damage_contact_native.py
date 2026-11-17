#!/usr/bin/env python3
"""Actual native F575/F578 damage orchestration through original whole F953.

Python transports native continuations and authored external boundary replies;
it never calculates expected collision, shield, hull or RNG arithmetic.
"""
from __future__ import annotations
import argparse,copy,json,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_contact_classifier_native as C
import rebuild_source_collision_contact_native as Chain
import rebuild_source_damage_native as H

PROJECT=C.PROJECT
PROOF=PROJECT/'validation/damage-core-2026-11-17/contact-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_damage_contact_native.json'
PROFILE='dos-firstenc-actual-damage-contact-composition-v1'
INPUT=8192;EXTRA=2048;REPLY=680
sha=H.sha

def classifier_assembly(source):
    text=C.assembly(source)
    for marker in ['mov edx,2048','cmp r8d,2048','input: .zero 2048']:
        if text.count(marker)!=1:raise ValueError('Classifier packet framing changed')
        text=text.replace(marker,marker.replace('2048',str(INPUT)))
    marker='FUNC_000953_parent_skip:\nmov rdx,QWORD PTR [active_record]'
    if text.count(marker)!=1:raise ValueError('F953 observation continuation changed')
    # Only the previously explicit F953 boundary acquires full raw return
    # records. Every original F575/F577/F578 instruction remains unchanged.
    adapter='''FUNC_000953_parent_skip:
mov eax,DWORD PTR [obs_count]
imul esi,eax,680
add esi,OFFSET FLAT:input+2048
test DWORD PTR [esi],1
jz contact_no_body
push rsi
add esi,4
mov edi,OFFSET FLAT:object
mov ecx,338
rep movsb
pop rsi
contact_no_body:
test DWORD PTR [esi],2
jz contact_no_collider
add esi,342
mov edi,OFFSET FLAT:parent
mov ecx,338
rep movsb
contact_no_collider:
mov rdx,QWORD PTR [active_record]'''
    return text.replace(marker,adapter)

def classifier_packet(row,models):
    out=bytearray(C.packet(row,models))+bytearray(INPUT-C.INPUT)
    for index,script in enumerate(row['scripts']):
        at=EXTRA+index*REPLY;flags=0
        if 'body_after_hex'in script:flags|=1;out[at+4:at+342]=bytes.fromhex(script['body_after_hex'])
        if 'collider_after_hex'in script:flags|=2;out[at+342:at+680]=bytes.fromhex(script['collider_after_hex'])
        struct.pack_into('<I',out,at,flags)
    return bytes(out)

def cases(models):
    # Raw source-space flight operands were already independently exercised by
    # the original classifier corpus. Health/equipment and contact identities
    # below are explicit caller inputs, not inferred expected physics.
    seeds=C.cases(models);context=H.build_rows()[0]['context_before'];rows=[]
    for index in range(40):
        seed=copy.deepcopy(seeds[180+(index%7)]);body=bytearray.fromhex(seed['body_before_hex']);other=bytearray.fromhex(seed['collider_before_hex'])
        policy=index%8;body[0x56]=0;other[0x56]=0;body[0x87]=3 if index%5 else 11;other[0x87]=3
        for raw in [body,other]:
            raw[0x118]=0;raw[0x14e]=0x75;raw[0x151]=0xaa;raw[0x88]=[0,127,128,255][index%4]
            struct.pack_into('<H',raw,0xe0,40 if policy==1 else 0);struct.pack_into('<H',raw,0xe4,65535)
        globals=seed['globals_before'];globals.update(player_index_u32=[17,9,114][index%3],collision_enabled_u8=1)
        if globals['player_index_u32']==17:body[0x118]=255
        if globals['player_index_u32']==9:other[0x118]=255
        # The final eight controls select the real F577/F575 player/NPC
        # response instead of the independent F578 pair branch.
        if index>=32:
            body[0x56]=9;other[0x87]=1;body[0x87]=3 if index%2==0 else 11
            globals['player_index_u32']=17 if index%2==0 else 114
            struct.pack_into('<H',body,0x9e,0)
            seed['relative_before_hex']=struct.pack('<3q',0,100+(index%7)*250,0).hex()
        dc=copy.deepcopy(context)
        dc['model_descriptors_hex']={str(k):dc['model_descriptors_hex'][str(k)]for k in [15,24,38,81,96]}
        root=bytearray.fromhex(dc['root_hex']);struct.pack_into('<I',root,0xc0,globals['player_index_u32']);struct.pack_into('<2I',root,0x24,0x12345678+index,0x87654321-index);dc['root_hex']=root.hex()
        entries=bytearray.fromhex(dc['module_entries_hex']);dc['module_count_s32']=18 if policy in [4,5] else 0
        for module in [3,11,17]:entries[module*8]=6 if policy in [4,5] else 0
        dc['module_entries_hex']=entries.hex()
        policies={'F48:3':[H.p32('event_registers',48,-7 if policy==2 else 1)]}
        if policy==3:policies['F1907:1']=[H.p16('body',0xe4,1000),H.p8('body',0x151,0x80)]
        if policy==4:policies['F144_handler:1']=[H.p32('module_count_s32',0,0)]
        if policy==5:policies['F144_handler:1']=[H.p8('module_entries',11*8,0)]
        if policy==6:policies['F1907:1']=[H.p32('root',0x24,0xffffffff),H.p32('root',0x28,0)]
        if policy==7:policies['F1907:1']=[H.p32('root',0xc0,114)]
        rows.append({'name':'native-damage-contact/%02d'%index,'body_hex':body.hex(),'collider_hex':other.hex(),'relative_hex':seed['relative_before_hex'],'globals_before':globals,'damage_context_before':dc,'policy':policies,'seed_classifier_case':seed['name'],'authored_scope':'Original native classifier source-space operands with explicit healthy damage fields and identity. External replies are authored mutations; all intermediate physics and owner outputs are measured.'})
    return rows

def boundary_context(value):
    return {'body':value['body_hex'],'collider':value['collider_hex'],'relative':value['relative_hex'],'globals':value['globals']}

def serialize(rows,pool):
    def context(raw,body):return H.encode_snapshot({'body_hex':body,'context':raw},pool)['context']
    def observations(items):
        return [{**{k:v for k,v in item.items()if k not in ['before','after']},'before':H.encode_snapshot(item['before'],pool),'after':H.encode_snapshot(item['after'],pool)}for item in items]
    result=[]
    for row in rows:
        packed=copy.deepcopy(row);packed['damage_context_before']=context(row['damage_context_before'],row['body_hex']);packed['damage_context_after']=context(row['damage_context_after'],row['expected']['body_after_hex'])
        for call in packed['damage_calls']:
            initial=H.encode_snapshot({'body_hex':call['input'].pop('body_before_hex'),'context':call['input'].pop('context_before')},pool)
            call['input'].update(body_before=initial['body'],context_before=initial['context'])
            final=H.encode_snapshot({'body_hex':call['expected'].pop('body_after_hex'),'context':call['expected'].pop('context_after')},pool)
            call['expected'].update(body_after=final['body'],context_after=final['context'])
            call['observations']=observations(call['observations'])
        packed['damage_packets']=[{'call_index_u32':call['call_index_u32'],'observations':call['observations']}for call in packed['damage_calls']]
        result.append(packed)
    return result

def generate(a):
    cm=json.loads((C.PROOF/'instruction-proof.json').read_text());cs=(C.PROOF/'source-procedures.asm').read_text();C.verify_archived(cm,cs)
    hm,hs,hkernel=H.verify(H.PROOF);assemblies={'classifier':classifier_assembly(cs),'damage':hkernel};records={k:[]for k in assemblies};rows=cases(cm['models']);pool={}
    for row in rows:
        for key,descriptor in row['damage_context_before']['model_descriptors_hex'].items():
            if descriptor!=cm['models'][key]['descriptor_hex']:raise ValueError('Original model descriptor differs across native kernels')
    with tempfile.TemporaryDirectory(prefix='damage-contact-native-')as d:
        folder=Path(d);binaries={k:Chain.compile_native(folder,k,v)for k,v in assemblies.items()}
        def execute(kind,packet):
            runs=[subprocess.run([str(binaries[kind])],input=packet,capture_output=True,timeout=30)for _ in range(3)]
            if any(x.returncode or x.stderr for x in runs):raise ValueError('Native '+kind+' exit/stderr differs '+str([(x.returncode,x.stderr.decode())for x in runs]))
            if len({x.stdout for x in runs})!=1:raise ValueError('Fresh process repeat differs '+kind)
            records[kind].append((packet,runs[0].stdout));return runs[0].stdout
        for row in rows:
            classifier={'name':row['name'],'body_before_hex':row['body_hex'],'collider_before_hex':row['collider_hex'],'relative_before_hex':row['relative_hex'],'globals_before':row['globals_before'],'scripts':[{'return_u32':0,'globals':{}}for _ in range(C.MAXOBS)]}
            dc=copy.deepcopy(row['damage_context_before']);damage_calls=[]
            for step in range(C.MAXOBS+1):
                final=C.decode(execute('classifier',classifier_packet(classifier,cm['models'])),classifier)
                observations=final['observations']
                if any(o['kind']!='F953'for o in observations):raise ValueError('Composition only permits actual sphere/pair damage paths')
                if len(damage_calls)==len(observations):break
                if len(damage_calls)>len(observations):raise ValueError('Native damage continuation erased an earlier call')
                observation=observations[len(damage_calls)];target,amount,attacker=observation['args'];before=observation['before']
                key='body_hex'if target==bytes.fromhex(before['body_hex'])[0x86]else'collider_hex'
                if target!=bytes.fromhex(before[key])[0x86]:raise ValueError('Native target not in the supplied pair')
                if struct.unpack_from('<I',bytes.fromhex(dc['root_hex']),0xc0)[0]!=before['globals']['player_index_u32']:raise ValueError('Shared Root player-index alias drifted before native damage')
                rawrow={'name':row['name']+'/F953-%d'%len(damage_calls),'operation':'damage','body_before_hex':before[key],'context_before':copy.deepcopy(dc),'damage_s32':amount,'attacker_u32':attacker,'bound_s32':0}
                scripts=[];occurrences={k:0 for k in H.BOUNDARIES}
                for reply_index in range(H.MAX_SCRIPTS+1):
                    decoded=H.decode(execute('damage',H.packet(rawrow,scripts)),rawrow)
                    if not decoded['status']:break
                    pending=decoded['pending'];kind=pending['kind'];occurrences[kind]+=1
                    patches=row['policy'].get(kind+':'+str(occurrences[kind]),[])
                    scripts.append({'kind':kind,'args':pending['args'],'return_u32':{'F48':0x13579bdf,'F144_handler':0x2468ace0,'F1907':0x99aabbcc,'F942':0x87654321,'F952':0xfedcba98}[kind],'patches':patches})
                else:raise ValueError('Damage callback discovery did not terminate')
                dc=copy.deepcopy(decoded['expected']['context_after']);after=copy.deepcopy(before);after[key]=decoded['expected']['body_after_hex'];after['globals']['player_index_u32']=struct.unpack_from('<I',bytes.fromhex(dc['root_hex']),0xc0)[0]
                index=len(damage_calls);classifier['scripts'][index]={'return_u32':decoded['expected']['return_u32'],'globals':after['globals'],'body_after_hex':after['body_hex'],'collider_after_hex':after['collider_hex']}
                damage_calls.append({'call_index_u32':index,'target_role':key.removesuffix('_hex'),'input':rawrow,'expected':decoded['expected'],'observations':decoded['observations'],'authored_scripts':scripts})
            else:raise ValueError('Native F575 continuation capacity exceeded')
            if not damage_calls:raise ValueError('Authored contact did not execute F953 '+row['name'])
            for o,call in zip(final['observations'],damage_calls):
                expected=call['expected'];role=call['target_role']+'_hex'
                if o['after'][role]!=expected['body_after_hex']or o['return_u32']!=expected['return_u32']:raise ValueError('Actual damage result was not resumed inside F575')
            row.update(expected=final,damage_context_after=dc,damage_calls=damage_calls,observations=[],damage_packets=[{'call_index_u32':call['call_index_u32'],'observations':call['observations']}for call in damage_calls])
            row.pop('policy')
        for kind,items in records.items():
            result=subprocess.run([str(binaries[kind])],input=b''.join(p for p,_ in reversed(items)),capture_output=True,check=True,timeout=90)
            if result.stderr or result.stdout!=b''.join(o for _,o in reversed(items)):raise ValueError('Native reverse process order differs '+kind)
    paths=['tools/rebuild_source_damage_contact_native.py','tools/rebuild_source_damage_native.py','tools/rebuild_source_contact_classifier_native.py','tools/rebuild_source_collision_contact_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_spherical_contact_native.py','tools/rebuild_source_frame_dispatch_native.py','recovered-history/ground_harness/tools/native_reference.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','data/ffe_collision_programs.json','tests/fixtures/source_object_factory_native.json']
    for directory in [C.PROOF,H.PROOF]:paths.extend(str(p.relative_to(PROJECT))for p in directory.iterdir()if p.name in ['instruction-proof.json','source-procedures.asm','damage-native.s','dos-disassembly.txt'])
    proof={'schema':'starfrontier-original-damage-contact-composition-v1','source_executable_sha256':H.N.EXE_SHA,'source_assembly_sha256':H.N.ASM_SHA,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in sorted(set(paths))},'host_assembly_sha256':{k:sha(v.encode())for k,v in assemblies.items()},'native_calls':{k:len(v)for k,v in records.items()},'fresh_process_runs_each_call':3,'reverse_repeat_native_calls':{k:len(v)for k,v in records.items()},'native_input_sha256':{k:sha(b''.join(p for p,_ in v))for k,v in records.items()},'native_output_sha256':{k:sha(b''.join(o for _,o in v))for k,v in records.items()},'expected_arithmetic_calculated_in_python':False,'all_raw_native_canaries_verified':True,'Root_player_index_binding':'Root+C0 exactly aliases classifier Frame13 player_index_u32. Actual native damage context is carried across calls, including all RNG/event/module words. Frame12 words are not altered by these supplied providers.','scope':'Original F575/F577/F578 invokes whole original F953/F34/F35/F144/F148/F1530/F1538 and resumes after each measured reply. Exact pair/body/caller/global outputs and sequential shared context are compared. External handlers/event/audio/equipment/fatal callbacks remain typed authored replies; this is not a full world, Main or Android build.'}
    proof['actual_F953_calls']=sum(len(r['damage_calls'])for r in rows);proof['pair_two_damage_cases']=sum(len(r['damage_calls'])==2 for r in rows);proof['actual_F1530_calls']=sum(c['expected']['source_order'].count('F1530')for r in rows for c in r['damage_calls'])
    a.proof_dir.mkdir(parents=True,exist_ok=True)
    for name,text in assemblies.items():(a.proof_dir/(name+'-composed-native.s')).write_text(text)
    (a.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
    packed_rows=serialize(rows,pool)
    fixture={'schema':'starfrontier-source-damage-contact-native-v1','profile':PROFILE,'case_count':len(rows),'proof':proof,'buffer_codec':'sha256-keyed zlib_base64; decoded byte_count and SHA256 must match','buffers':pool,'cases':packed_rows,'scope':proof['scope']}
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n')
    print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'actual_F953_calls':proof['actual_F953_calls'],'pair_two_damage_cases':proof['pair_two_damage_cases'],'actual_F1530_calls':proof['actual_F1530_calls']}))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF)
    for flag in ['exe','asm','data']:p.add_argument('--'+flag,type=Path)
    generate(p.parse_args())
if __name__=='__main__':main()
