#!/usr/bin/env python3
"""Native F830 names and F860 system headers from original sector records.

Source code/data are pinned independently. Standard sprintf formatting is
marshalled to host snprintf, and scalar sqrt uses x87 FSQRT; these ABI adapters
do not supply system-generation decisions or expected GDScript results.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, re, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
NUMBERS=[827,830,833,852,860,868,869,871,2095]
PACKET=8
OUTPUT=4+64+128+4

def sha(raw):return hashlib.sha256(raw).hexdigest()
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def strings_resource(source,original,names):
    blocks={}
    for match in re.finditer(r'^DATA_(\d+):[^\n]*\n(.*?)(?=^DATA_\d+:|\Z)',source,re.M|re.S):
        number=int(match[1])
        if number not in [6796,6823,7097,7098] and not 6830<=number<=7096:continue
        raw=bytearray();pointers=[]
        for line in match[2].splitlines():
            code=line.split(';')[0].strip()
            if not code:continue
            if code.startswith('dd DATA_'):pointers.append(int(code[8:]));continue
            if code.startswith('db '):
                for token in names._tokens(code[3:]):
                    if token.startswith(("'",'"')):raw.extend(token[1:-1].encode('latin1'))
                    else:raw.append(int(token,0))
            else:raise ValueError('Unexpected galaxy string data '+code)
        blocks[number]=pointers if pointers else bytes(raw)
    assert blocks[6796]==list(range(6830,7097))
    blob=b''.join(blocks[n] for n in range(6830,7097));at=original.find(blob)
    assert at>=0 and original.find(blob,at+1)<0,'Original system-name bytes differ'
    gateway=blocks[6823];gateway_at=original.find(gateway);assert gateway_at>=0
    return {'schema':1,'source_sha256':names.SOURCE_SHA,'source_assembly_sha256':names.ASM_SHA,'source_data_sha256':names.DATA_SHA,
            'pointer_labels':blocks[6796],'strings_hex':[blocks[n].hex() for n in blocks[6796]],
            'text_executable_offset':at,'text_bytes':len(blob),'text_sha256':sha(blob),
            'gateway_hex':gateway.hex(),'gateway_executable_offset':gateway_at,'gateway_sha256':sha(gateway),
            'format_sector_hex':blocks[7097].hex(),'format_generated_hex':blocks[7098].hex(),
            'scope':'Original F830 system-name table, generated trigraphs in ffe_galaxy.json and the Gateway exception.'}

def assembly(source,original,data_source,resource,galaxy,metadata,names,galaxy_module,metadata_module):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    library,names_meta=names.library_assembly(source,original,data_source)
    # These old-library gates become real procedures/data in this caller.
    library=library.replace('FUNC_000860:\n','')
    for number in range(7106,7117):library=re.sub(r'^\.equ DATA_%06d,0\n'%number,'',library,flags=re.M)
    library=library.replace('_sprintf:\n call names_unreachable\n','')
    normalized=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
    normalized=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),normalized)
    normalized=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),normalized)
    lines,_=procedures(normalized,NUMBERS);extra='\n'.join(lines).replace('qword [','QWORD PTR [')
    # NASM label operands without brackets are addresses; GAS Intel syntax
    # otherwise treats the trigraph-base additions as memory reads.
    extra=re.sub(r'\badd (e[a-z]{2}),DATA_(\d+)',r'add \1,OFFSET FLAT:DATA_\2',extra)
    extra=re.sub(r'\[rbp\+(e[a-z]{2})\*([1248])\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[rbp+r%s*%s-%d]'%(m[1][1:],m[2],0x100000000-int(m[3],16)),extra)
    for number in [830,833]:extra=extra.replace('FUNC_%06d:\npush rbp\nmov rbp,rsp\nadd rsp,-8'%number,'FUNC_%06d:\npush rbp\nmov rbp,rsp\nadd rsp,-16'%number)
    # F833 frees one 8-byte inline double, not two pointer-width arguments.
    extra=extra.replace('call _sqrt\nadd rsp,16','call _sqrt\nadd rsp,8')
    sector_code,_=galaxy_module.assembly(source,galaxy)
    sector_code=sector_code.split('_start:',1)[0].replace('.global _start','')
    tables=[]
    for key,value in sorted(galaxy['tables_hex'].items(),key=lambda x:int(x[0])):
        tables.append('DATA_%06d:\n.byte '%int(key)+','.join(str(x) for x in bytes.fromhex(value)))
    string_data='DATA_006796:\n'+''.join('.long DATA_%06d\n'%n for n in resource['pointer_labels'])
    for n,raw in zip(resource['pointer_labels'],resource['strings_hex']):string_data+='DATA_%06d:\n.byte '%n+','.join(str(x) for x in bytes.fromhex(raw))+'\n'
    for label,key in [(6823,'gateway_hex'),(7097,'format_sector_hex'),(7098,'format_generated_hex')]:string_data+='DATA_%06d:\n.byte '%label+','.join(str(x) for x in bytes.fromhex(resource[key]))+'\n'
    hashes={}
    for number in NUMBERS:
        match=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:.*?(?=^FUNC_\d+(?:_[A-Za-z0-9_]+)?:|\Z)'%number,source,re.M|re.S);hashes[str(number)]=sha(match[0].encode())
    text=library+'\n'+sector_code+'\n.section .text\n'+extra+'''
_sqrt:
 fld QWORD PTR [rsp+8]
 fsqrt
 ret
_strcpy:
 push rsi
 push rdi
 mov edi,DWORD PTR [rsp+24]
 mov esi,DWORD PTR [rsp+32]
 mov eax,edi
strcpy_loop:
 mov dl,BYTE PTR [rsi]
 inc esi
 mov BYTE PTR [rdi],dl
 inc edi
 test dl,dl
 jne strcpy_loop
 pop rdi
 pop rsi
 ret
_sprintf:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 push r12
 mov r12,rsp
 and rsp,-16
 mov edi,DWORD PTR [rbp+16]
 mov esi,512
 mov edx,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov r8d,DWORD PTR [rbp+40]
 mov r9d,DWORD PTR [rbp+48]
 xor eax,eax
 call snprintf
 mov rsp,r12
 pop r12
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 mov esp,OFFSET FLAT:stack_end
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,8
 sub rdx,r8
 syscall
 test rax,rax
 jle end_input
 add r8,rax
 cmp r8,8
 jb read_more
 mov edi,OFFSET FLAT:params
 mov ecx,64
 mov al,0x5a
 rep stosb
 mov edi,OFFSET FLAT:name
 mov ecx,512
 xor eax,eax
 rep stosb
 mov DWORD PTR [guard_params],0x4f524143
 mov DWORD PTR [guard_name],0x4f524143
 push QWORD PTR [input]
 push OFFSET FLAT:params
 call FUNC_000860
 add rsp,16
 mov DWORD PTR [output],eax
 mov esi,OFFSET FLAT:params
 mov edi,OFFSET FLAT:output+4
 mov ecx,64
 rep movsb
 push QWORD PTR [input]
 push OFFSET FLAT:name
 push OFFSET FLAT:context
 push 0x1ff
 call FUNC_000830
 add rsp,32
 mov esi,OFFSET FLAT:name
 mov edi,OFFSET FLAT:output+68
 mov ecx,128
 rep movsb
 xor eax,eax
 cmp DWORD PTR [guard_params],0x4f524143
 jne bad_guard
 cmp DWORD PTR [guard_name],0x4f524143
 jne bad_guard
 mov eax,1
bad_guard:
 mov DWORD PTR [output+196],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,200
 syscall
 cmp eax,200
 jne failure
 jmp next_case
end_input:
 test r8,r8
 jne failure
 xor edi,edi
 jmp exit_now
failure:
 mov edi,1
exit_now:
 mov eax,60
 syscall
.section .rodata
'''+ '\n'.join(tables)+'\n'+string_data+'\n'+metadata_module.metadata_assembly(metadata,False,False)+'''
DATA_007808: .quad render_trap
DATA_007807: .quad render_trap
.section .bss
.align 16
input: .zero 8
output: .zero 200
params: .zero 64
guard_params: .zero 4
name: .zero 512
guard_name: .zero 4
context: .zero 64
DATA_008947: .zero 4
DATA_008948: .zero 4
DATA_008776: .zero 256
DATA_008950: .zero 4
DATA_008951: .zero 4
DATA_008952: .zero 4
DATA_008912: .zero 4
DATA_008913: .zero 4
.align 16
stack: .zero 65536
stack_end:
'''
    return text,hashes

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));args=parser.parse_args()
    names=module('source_names_library',PROJECT/'tools/rebuild_source_names_native.py');galaxy_module=module('galaxy_library',PROJECT/'tools/rebuild_source_galaxy_native.py');metadata_module=module('metadata_library',PROJECT/'tools/rebuild_source_system_native.py')
    asm=args.source.read_bytes();dat=args.data_source.read_bytes();original=args.exe.read_bytes();assert sha(asm)==names.ASM_SHA and sha(dat)==names.DATA_SHA and sha(original)==names.SOURCE_SHA
    source=asm.decode();data_source=dat.decode();resource=strings_resource(data_source,original,names)
    galaxy=json.loads((PROJECT/'data/ffe_galaxy.json').read_text());metadata=json.loads((PROJECT/'data/ffe_system_metadata.json').read_text());text,hashes=assembly(source,original,data_source,resource,galaxy,metadata,names,galaxy_module,metadata_module)
    fixture_path=PROJECT/'tests/fixtures/source_galaxy_native.json';fixture=json.loads(fixture_path.read_text());ids=[]
    for row in fixture['cases']:
        for i in range(row['expected']['count']):
            id=row['x']|(row['y']<<13)|(i<<26)
            if id not in ids:ids.append(id)
    for id in [0x1aa51717,0,0xffffffff,0xfea49718]:
        if id not in ids:ids.append(id)
    def execute(path,items):
        raw=subprocess.run([str(path)],input=b''.join(struct.pack('<2I',id,0) for id in items),stdout=subprocess.PIPE,check=True,timeout=60).stdout
        assert len(raw)==len(items)*OUTPUT
        return [raw[i*OUTPUT:(i+1)*OUTPUT] for i in range(len(items))]
    with tempfile.TemporaryDirectory(prefix='ffe-definition-native-',dir='/workspace') as work:
        work=Path(work);(work/'oracle.s').write_text(text)
        subprocess.run(['gcc','-nostartfiles','-no-pie','-o',str(work/'oracle'),str(work/'oracle.s')],check=True)
        outputs=execute(work/'oracle',ids)
        for _ in range(2):assert execute(work/'oracle',ids)==outputs
        assert execute(work/'oracle',list(reversed(ids)))==list(reversed(outputs))
    rows=[]
    for id,out in zip(ids,outputs):
        assert struct.unpack_from('<I',out,196)[0]==1
        status=struct.unpack_from('<i',out)[0];params=out[4:68];name=out[68:196].split(b'\0',1)[0]+b'\0'
        rows.append({'id':id,'return_s32':status,'params_hex':params.hex(),'name_hex':name.hex()})
    result={'schema':1,'source_sha256':names.SOURCE_SHA,'source_assembly_sha256':names.ASM_SHA,'source_data_sha256':names.DATA_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','scope':'Actual F830 system names and F860 source headers through F852/F841/F853/F856/F861/F868/F869. Standard formatting and scalar sqrt ABI adapters documented.','source_procedure_hashes':hashes,'adapted_assembly_sha256':sha(text.encode()),'native_ordered_output_sha256':sha(b''.join(outputs)),'input_sector_fixture_sha256':sha(fixture_path.read_bytes()),'system_name_resource_sha256':sha((json.dumps(resource,ensure_ascii=False,indent=2)+'\n').encode()),'metadata_resource_sha256':sha((PROJECT/'data/ffe_system_metadata.json').read_bytes()),'case_count':len(rows),'fresh_process_runs':3,'reverse_repeat_count':len(rows),'canaries_unchanged':True,'cases':rows}
    (PROJECT/'data/ffe_system_names.json').write_text(json.dumps(resource,ensure_ascii=False,indent=2)+'\n');(PROJECT/'tests/fixtures/source_system_definition_native.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('Native definitions:',len(rows),'source headers/names; 3 fresh and reverse runs agree')

if __name__=='__main__':main()
