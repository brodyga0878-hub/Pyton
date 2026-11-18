#!/usr/bin/env python3
"""Original F953 resumed with measured original F952 and full-bank F942.

Python routes native continuations. It never calculates expected shields,
equipment, cargo, allocations, rewards, positions or random arithmetic.
"""
from __future__ import annotations
import argparse,base64,copy,json,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_damage_native as H
import rebuild_source_equipment_native as E
import rebuild_source_destruction_native as D

PROJECT=H.PROJECT;PROOF=PROJECT/'validation/equipment-effects-2026-11-18/effects-native-proof';FIXTURE=PROJECT/'tests/fixtures/source_damage_effects_native.json'
PROFILE='dos-firstenc-actual-f953-equipment-destruction-composition-v1'
INPUT=H.INPUT+H.MAX_SCRIPTS*H.OWNER_SIZE
sha=H.sha

def damage_assembly(kernel):
    for marker in ['mov edx,65536','cmp r8d,65536','s_input: .zero 65536']:
        if kernel.count(marker)!=1:raise ValueError('Native damage framing changed')
        kernel=kernel.replace(marker,marker.replace('65536',str(INPUT)))
    marker='s_patch_done:\ncmp DWORD PTR [rbx+36],0'
    if kernel.count(marker)!=1:raise ValueError('Native external reply seam changed')
    lines=['s_patch_done:','cmp DWORD PTR [rbx+48],0','je effects_replacement_done','cmp DWORD PTR [rbx+48],1','jne s_bad','mov eax,DWORD PTR [s_used]',f'imul esi,eax,{H.OWNER_SIZE}',f'add esi,OFFSET FLAT:s_input+{H.INPUT}']
    for name,size in zip(H.OWNER_KEYS,H.OWNER_SIZES):lines.extend(['mov edi,OFFSET FLAT:s_'+name,'mov ecx,%d'%size,'rep movsb'])
    lines.extend(['effects_replacement_done:','cmp DWORD PTR [rbx+36],0'])
    return kernel.replace(marker,'\n'.join(lines))

def packed_owner(state):
    raw=bytes.fromhex(state['body_hex']);ctx=state['context']
    for name in H.OWNER_KEYS[1:]:raw+=struct.pack('<i',ctx[name])if name=='module_count_s32'else bytes.fromhex(ctx[name+'_hex'])
    if len(raw)!=H.OWNER_SIZE:raise ValueError('Full native owner reply differs')
    return raw

def damage_packet(row,scripts):
    raw=bytearray(H.packet(row,scripts))+bytearray(INPUT-H.INPUT)
    for index,script in enumerate(scripts):
        struct.pack_into('<I',raw,H.SCRIPT_AT+index*H.SCRIPT_SIZE+48,int('full_after'in script))
        if 'full_after'not in script:continue
        raw[H.INPUT+index*H.OWNER_SIZE:H.INPUT+(index+1)*H.OWNER_SIZE]=packed_owner(script['full_after'])
    return bytes(raw)

def effect_context_from_damage(base,slot,snapshot):
    value=copy.deepcopy(base);ctx=snapshot['context'];bank=bytearray.fromhex(value['bank']);bank[:115]=bytes.fromhex(ctx['flags_hex']);at=116+slot*338;bank[at:at+338]=bytes.fromhex(snapshot['body_hex']);value['bank']=bank.hex()
    for name in ['root','event_registers','module_entries']:value[name]=ctx[name+'_hex']
    value['module_count_s32']=ctx['module_count_s32'];return value

def damage_context(value,equipment=False):
    models={k:r['descriptor_hex']for k,r in value['model_resources'].items()if int(k)<149}
    ctx={name+'_hex':value[name]for name in ['root','event_registers','module_entries']};ctx['flags_hex']=bytes.fromhex(value['bank'])[:115].hex();ctx['module_count_s32']=value['module_count_s32'];ctx['model_descriptors_hex']=models
    if equipment:ctx['physical_specs_hex']={k:r['physical_spec_hex']for k,r in value['model_resources'].items()if int(k)<149 and r['physical_spec_hex']}
    return ctx

def body(value,slot):return bytes.fromhex(value['bank'])[116+slot*338:116+(slot+1)*338].hex()
def set_body(value,slot,raw):
    b=bytearray.fromhex(value['bank']);at=116+slot*338;b[at:at+338]=bytes.fromhex(raw);value['bank']=b.hex()

def cases():
    old=json.loads((PROJECT/'data/ffe_object_factory.json').read_text())['models'];extra=json.loads((PROJECT/'data/ffe_effect_factory.json').read_text())['models'];rows=[]
    equipment=[r for r in E.build_rows()if r['operation']=='F952']
    for index,seed_index in enumerate([0,1,2,7,8,9,12,17,20,21,30,31,40,41,100,101]):
        seed=copy.deepcopy(equipment[seed_index]);ctx=seed['context_before'];record=bytearray.fromhex(seed['body_before_hex']);slot=record[0x86];record[0x87]=3;struct.pack_into('<H',record,0xe0,0);struct.pack_into('<H',record,0xe4,30)
        bank=bytearray(bytes.fromhex(ctx['flags_hex'])+b'\xa7'+bytes(338)*115)
        for i in range(115):bank[116+i*338+0x86]=i
        bank[116+slot*338:116+(slot+1)*338]=record
        resources={k:copy.deepcopy(old[k])for k in ctx['model_descriptors_hex']}
        for k in resources:
            resources[k]['descriptor_hex']=ctx['model_descriptors_hex'][k];resources[k]['physical_spec_hex']=ctx['physical_specs_hex'].get(k,'')
        resources.update(copy.deepcopy(extra))
        value={'root':ctx['root_hex'],'bank':bank.hex(),'event_registers':ctx['event_registers_hex'],'module_entries':ctx['module_entries_hex'],'module_count_s32':20,'model_resources':resources}
        if index>=8:
            modules=bytearray.fromhex(value['module_entries'])
            for module in [2,3,20]:modules[module*8]=2
            value['module_entries']=modules.hex()
        rows.append({'name':'equipment-effects/%02d'%index,'family':'equipment','target_slot_u32':slot,'damage_s32':10,'attacker_u32':7,'context_before':value,'equipment_seed':seed['name'],'damage_policy':{},'equipment_policy':{'F349:1':[E.p8('body',0x118,0)]}if index==9 else{},'equipment_payload_policy':{'F144_handler:1':[0xdeadbeef,0x87654321]}if index==11 else{}})
    destruction=D.cases()
    for index,seed_index in enumerate([0,1,2,3,4,5,10,11,14,15,25,34,38,50,53,58]):
        seed=copy.deepcopy(destruction[seed_index]);value=seed['context_before'];slot=seed['body_slot_u32'];record=bytearray.fromhex(body(value,slot));record[0x87]=3;struct.pack_into('<H',record,0xe0,0);struct.pack_into('<H',record,0xe4,30);set_body(value,slot,record.hex());value['event_registers']=bytes(284).hex()
        if index in [10,11]:
            bank=bytearray.fromhex(value['bank'])
            for free_slot in [109,110,111,112,113]:bank[free_slot]=0
            value['bank']=bank.hex()
        rows.append({'name':'fatal-effects/%02d'%index,'family':'fatal','target_slot_u32':slot,'damage_s32':30,'attacker_u32':seed['attacker_u32'],'context_before':value,'destruction_seed':seed['name'],'damage_policy':{},'equipment_policy':{},'equipment_payload_policy':{}})
    for index in range(4):
        row=copy.deepcopy(rows[index]);row.update(name='no-effect/%02d'%index,family='shield');record=bytearray.fromhex(body(row['context_before'],row['target_slot_u32']));struct.pack_into('<H',record,0xe0,100);record[0x118]=0;set_body(row['context_before'],row['target_slot_u32'],record.hex());row['damage_policy']={'F48:3':[H.p32('event_registers',48,-1)]}if index==3 else{};rows.append(row)
    return rows

def compile_asm(folder,name,text):
    source=folder/(name+'.s');source.write_text(text);obj=folder/(name+'.o');binary=folder/name;subprocess.run(['as','--64','-o',str(obj),str(source)],check=True);subprocess.run(['ld','-o',str(binary),str(obj)],check=True);return binary

def run_destruction(binary,row,execute):
    for _ in range(65):
        raw=execute('destruction',D.packet(row));h=struct.unpack_from('<16I',raw)
        if h[2]==0:return D.decode(raw,row)
        if h[2]!=1 or h[4]<=len(row['scripts']):raise ValueError('Unexpected native destruction pending')
        at=D.BASE+len(row['scripts'])*D.SNAP;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc]
        row['scripts'].append({'kind':kind,'args':args,'return_u32':0,'patches':[]})
    raise ValueError('Destruction callbacks did not converge')

def serialize(rows,pool):
    def intern(raw):
        key=sha(raw)
        if key not in pool:pool[key]={'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}
        return key
    def ctx(value):
        result=copy.deepcopy(value)
        for key in ['root','bank','event_registers','module_entries']:
            if key in result:result[key]=intern(bytes.fromhex(result[key]))
        return result
    def obs(items,kind):
        result=[]
        for item in items:
            o={k:copy.deepcopy(v)for k,v in item.items()if k not in ['before','after']}
            for side in ['before','after']:o[side]=ctx(item[side])if kind=='destruction'else(E.encode_snapshot(item[side],pool)if kind=='equipment'else H.encode_snapshot(item[side],pool))
            result.append(o)
        return result
    output=[]
    for row in rows:
        packed={k:copy.deepcopy(v)for k,v in row.items()if k not in ['damage_policy','equipment_policy','equipment_payload_policy']};packed['context_before']=ctx(row['context_before']);packed['expected']['context_after']=ctx(row['expected']['context_after']);packed['observations']=obs(row['observations'],'damage')
        for field,kind in [('equipment_packets','equipment'),('destruction_packets','destruction')]:packed[field]=[{'call_index_u32':p['call_index_u32'],'observations':obs(p['observations'],kind)}for p in row[field]]
        output.append(packed)
    return output

def hydrate_effect_context(fixture,value):
    result=copy.deepcopy(value)
    for key in ['root','bank','event_registers','module_entries']:
        if key in result:result[key]=H.hydrate_buffer(fixture,result[key]).hex()
    return result

def hydrate_observations(fixture,items,kind):
    result=[]
    for item in items:
        row={k:copy.deepcopy(v)for k,v in item.items()if k not in ['before','after']}
        for side in ['before','after']:
            if kind=='destruction':row[side]=hydrate_effect_context(fixture,item[side])
            else:row[side]={'body_hex':H.hydrate_buffer(fixture,item[side]['body']).hex(),'context':E.hydrate_context(fixture,item[side]['context'])if kind=='equipment'else H.hydrate_context(fixture,item[side]['context'])}
        result.append(row)
    return result

def raw_row(fixture,row):
    result=copy.deepcopy(row);result['context_before']=hydrate_effect_context(fixture,row['context_before']);result['expected']['context_after']=hydrate_effect_context(fixture,row['expected']['context_after']);result['observations']=hydrate_observations(fixture,row['observations'],'damage')
    for field,kind in [('equipment_packets','equipment'),('destruction_packets','destruction')]:result[field]=[{'call_index_u32':r['call_index_u32'],'observations':hydrate_observations(fixture,r['observations'],kind)}for r in row[field]]
    return result

def generate(a):
    hm,hs,hkernel=H.verify();em,es,ekernel,er=E.verify();dm,ds=D.verify();assemblies={'damage':damage_assembly(hkernel),'equipment':ekernel};records={'damage':[],'equipment':[],'destruction':[]};rows=cases()
    with tempfile.TemporaryDirectory(prefix='damage-effects-native-')as temp:
        folder=Path(temp);binaries={k:compile_asm(folder,k,v)for k,v in assemblies.items()}
        (folder/'destruction-build').mkdir();binaries['destruction'],dkernel=D.build(dm,ds,folder/'destruction-build');assemblies['destruction']=dkernel
        def execute(kind,packet):
            done=[subprocess.run([str(binaries[kind])],input=packet,capture_output=True,timeout=60)for _ in range(3)]
            if any(r.returncode or r.stderr for r in done):raise ValueError(('Native kernel exit/stderr',kind,[(x.returncode,x.stderr[:80])for x in done]))
            if len({r.stdout for r in done})!=1:raise ValueError('Fresh native process differs '+kind)
            records[kind].append((packet,done[0].stdout));return done[0].stdout
        for row in rows:
            state=copy.deepcopy(row['context_before']);slot=row['target_slot_u32'];hr={'name':row['name'],'operation':'damage','damage_s32':row['damage_s32'],'attacker_u32':row['attacker_u32'],'bound_s32':0,'body_before_hex':body(state,slot),'context_before':damage_context(state)};scripts=[];calls=[];equipment_packets=[];destruction_packets=[];occurrences={}
            for _ in range(65):
                decoded=H.decode(execute('damage',damage_packet(hr,scripts)),hr)
                if not decoded['status']:break
                pending=decoded['pending'];kind=pending['kind'];occurrences[kind]=occurrences.get(kind,0)+1
                state=effect_context_from_damage(state,slot,pending['before'])
                if kind=='F952':
                    erow={'name':row['name']+'/equipment','operation':'F952','args':[],'body_before_hex':body(state,slot),'context_before':damage_context(state,True)};escripts=[];seen={}
                    for _ in range(65):
                        eq=E.decode(execute('equipment',E.packet(erow,escripts)),erow)
                        if not eq['status']:break
                        ep=eq['pending'];name=ep['kind'];seen[name]=seen.get(name,0)+1;tag=name+':'+str(seen[name]);script={'kind':name,'args':ep['args'],'return_u32':0,'patches':row['equipment_policy'].get(tag,[])}
                        if tag in row['equipment_payload_policy']:script['payload_after_u32']=row['equipment_payload_policy'][tag]
                        escripts.append(script)
                    else:raise ValueError('Equipment callback limit exceeded')
                    result=eq['expected'];state=effect_context_from_damage(state,slot,{'body_hex':result['body_after_hex'],'context':result['context_after']});equipment_packets.append({'call_index_u32':len(equipment_packets),'observations':eq['observations']});calls.append({'kind':'F952','source_order':result['source_order']})
                elif kind=='F942':
                    dc={k:copy.deepcopy(state[k])for k in ['root','bank','module_entries','module_count_s32','model_resources']};drow={'name':row['name']+'/destruction','body_slot_u32':slot,'attacker_u32':row['attacker_u32'],'context_before':dc,'scripts':[]};result=run_destruction(binaries['destruction'],drow,execute)
                    for key in ['root','bank','module_entries','module_count_s32']:state[key]=copy.deepcopy(result['context_after'][key])
                    destruction_packets.append({'call_index_u32':len(destruction_packets),'observations':result['observations']});calls.append({'kind':'F942','source_order':result['source_order']})
                else:
                    scripts.append({'kind':kind,'args':pending['args'],'return_u32':0,'patches':row['damage_policy'].get(kind+':'+str(occurrences[kind]),[])});continue
                scripts.append({'kind':kind,'args':pending['args'],'return_u32':result['return_u32'],'patches':[],'full_after':{'body_hex':body(state,slot),'context':damage_context(state)}})
            else:raise ValueError('Damage effect callback limit exceeded')
            final=decoded['expected'];state=effect_context_from_damage(state,slot,{'body_hex':final['body_after_hex'],'context':final['context_after']});order=[];cursor=0
            for entry in final['source_order']:
                if entry in ['F952','F942']:order.extend(calls[cursor]['source_order']);cursor+=1
                else:order.append(entry)
            if row['family']=='equipment'and not equipment_packets:raise ValueError('Equipment case did not invoke real F952')
            if row['family']=='fatal'and not destruction_packets:raise ValueError('Fatal case did not invoke real F942')
            if row['family']=='shield'and calls:raise ValueError('Shield case unexpectedly invoked an effect kernel')
            row.update(expected={'context_after':state,'return_u32':final['return_u32'],'return_s32':final['return_s32'],'source_order':order,'equipment_calls_u32':len(equipment_packets),'destruction_calls_u32':len(destruction_packets)},observations=[o for o in decoded['observations']if o['kind']not in ['F952','F942']],equipment_packets=equipment_packets,destruction_packets=destruction_packets,effect_calls=calls)
        for kind,items in records.items():
            # Destruction's C adapter streams packets; pure assembly adapters do too.
            raw=subprocess.run([str(binaries[kind])],input=b''.join(p for p,_ in reversed(items)),capture_output=True,check=True,timeout=120)
            if raw.stderr or raw.stdout!=b''.join(o for _,o in reversed(items)):raise ValueError('Reverse native stream differs '+kind)
    dependencies=['tools/rebuild_source_damage_effects_native.py','tools/rebuild_source_damage_native.py','tools/rebuild_source_equipment_native.py','tools/rebuild_source_destruction_native.py','tools/rebuild_source_effect_factory_native.py','tools/rebuild_source_natural_contact_native.py','data/ffe_object_factory.json','data/ffe_effect_factory.json','data/ffe_ground_coordinates.json']
    for proof in [H.PROOF,E.PROOF,D.PROOF]:dependencies.extend(str(p.relative_to(PROJECT))for p in proof.iterdir()if p.name in ['instruction-proof.json','source-procedures.asm','original-resources.json'])
    all_orders=[c['source_order']for r in rows for c in r['effect_calls']]
    active_cargo=sum(any(bytes.fromhex(r['expected']['context_after']['bank'])[i]and struct.unpack_from('<I',bytes.fromhex(r['expected']['context_after']['bank']),116+i*338+0x82)[0]==153 for i in range(1,115))for r in rows)
    proof={'schema':'starfrontier-original-damage-effects-composition-v1','source_executable_sha256':H.N.EXE_SHA,'source_assembly_sha256':H.N.ASM_SHA,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in sorted(set(dependencies))},'host_assembly_sha256':{k:sha(v.encode())for k,v in assemblies.items()},'host_support_sha256':{'destruction':sha(D.C.encode())},'native_calls':{k:len(v)for k,v in records.items()},'fresh_process_runs_each_call':3,'reverse_native_calls_verified':True,'equipment_cases':sum(bool(r['equipment_packets'])for r in rows),'destruction_cases':sum(bool(r['destruction_packets'])for r in rows),'no_effect_cases':sum(not r['effect_calls']for r in rows),'actual_cargo_selection_F951_calls':sum(o.count('F951')for o in all_orders),'actual_displacement_F1514_calls':sum(o.count('F1514')for o in all_orders),'cases_with_active_native_created_cargo153':active_cargo,'complete_native_owner_bytes_per_effect_reply':H.OWNER_SIZE,'expected_arithmetic_calculated_in_python':False,'all_native_canaries_verified':True,'scope':'Whole original F953 receives measured whole F952 equipment or F942/F926/F927 destruction outputs, with complete bank/root/event/module ownership carried. Source targets are original0..148 ship models; newly created153/155 records are real outputs but later damage to those effect objects is outside this bounded F953 profile. Handler/VM/UI/string bodies remain typed explicit external providers; no Main or Android claim.'}
    if proof['actual_cargo_selection_F951_calls']<2 or proof['actual_displacement_F1514_calls']<1 or active_cargo<1:raise ValueError('Composite cases did not execute actual cargo selection and creation')
    pool={};encoded=serialize(rows,pool);doc={'schema':'starfrontier-source-damage-effects-native-v1','profile':PROFILE,'case_count':len(rows),'proof':proof,'buffer_codec':'sha256-zlib-base64-v1','buffers':pool,'cases':encoded,'scope':proof['scope']}
    a.proof_dir.mkdir(parents=True,exist_ok=True)
    for kind,text in assemblies.items():(a.proof_dir/(kind+'-composed-native.s')).write_text(text)
    (a.proof_dir/'destruction-support.c').write_text(D.C)
    (a.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n');a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'native_calls':proof['native_calls']}))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF)
    for name in ['exe','asm','data']:p.add_argument('--'+name,type=Path)
    generate(p.parse_args())
if __name__=='__main__':main()
