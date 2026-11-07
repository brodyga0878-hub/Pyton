#!/usr/bin/env python3
"""Original DOS F929/F938/F289 instruction controls, with explicit JJFFE delta.

The DOS reference differs from unmarked JJFFE edits in F929: ordinary debit
never restores nozzle limits; exhaustion clears only BC/C0/C4. All three full
DOS procedures are independently matched instruction-for-instruction against
reassembled source, normalizing branch destinations to instruction ordinals.
The native oracle executes those reviewed instructions; Python supplies inputs,
never computes expected debit/refill results. F938's other maintenance writes
are captured as diagnostic bytes and explicitly excluded from the jet kernel.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
NUMBERS=[289,929,938,1538]
DOS_FUNCTIONS={289:(63868,64213),929:(186760,187025),938:(188988,189478)}
DOS_EXTERNAL={287:0x41ea9c,293:0x41f3c8,349:0x421c78,929:0x43cb88}
GLOBALS_BYTES=556
INPUT_BYTES=950
OUTPUT_BYTES=1030
GUARD=0x4a45544655454c53
OPS=['F929','F938','F289','initial_profile','cooling','cadence']


def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return (int(v)&0x7fffffff)-(int(v)&0x80000000)
def block(source,n):
    a=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%n,source,re.M)
    b=re.search(r'^FUNC_\d+(?:_[A-Za-z0-9_]+)?:',source[a.end():],re.M)
    return source[a.start():a.end()+b.start() if b else len(source)]
def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result


def dos_source(source):
    original=block(source,929)
    changed,count=re.subn(r'(\t\tsub \[ebx\+0x11e\],edx\r?\n).*?(\t\tjmp JUMP_003890\r?\n)',r'\1\2',original,count=1,flags=re.S)
    if count!=1:raise ValueError('Unreviewed F929 ordinary-debit edit')
    for offset in ['be','c2','c6']:
        changed,count=re.subn(r'\t\tmov word \[ebx\+0x'+offset+r'\],0x0\r?\n','',changed,count=1)
        if count!=1:raise ValueError('Unreviewed F929 empty-limit edit')
    return source.replace(original,changed,1)


def pe_sections(exe):
    pe=struct.unpack_from('<I',exe,60)[0];base=struct.unpack_from('<I',exe,pe+52)[0]
    at=pe+24+struct.unpack_from('<H',exe,pe+20)[0]
    return base,[struct.unpack_from('<4I',exe,at+i*40+8)for i in range(struct.unpack_from('<H',exe,pe+6)[0])]
def file_to_va(exe,at):
    base,sections=pe_sections(exe)
    for _,rva,size,start in sections:
        if start<=at<start+size:return base+rva+at-start
    raise ValueError('Unmapped original offset')


def resources(exe,data_source):
    helper=load_module('jet_original_hyperdrive_resources',PROJECT/'tools/rebuild_source_hyperdrive_native.py')
    _,specs=helper.resources(exe,data_source)
    tables={}
    for n in [5111,6266]:
        raw=helper.byte_block(data_source,n);at=exe.find(raw)
        if len(raw)!=60 or at<0 or exe.find(raw,at+1)>=0:raise ValueError('Original jet table is not unique60B')
        tables[str(n)]={'hex':raw.hex(),'executable_offset':at,'virtual_address':file_to_va(exe,at),'sha256':sha(raw),'u32':list(struct.unpack('<15I',raw))}
    if tables['6266']['executable_offset']!=822396 or tables['6266']['sha256']!='6fd21579d4bf35590dee289b2a1cbe12f1bc4e0d10a9ee71d56efea80cac21cb':raise ValueError('Unreviewed initial jet table')
    # Exact original F773 four-instruction initial-jet slice, not full NPC gen.
    signature=bytes.fromhex('0fbe86d00000008b1c85')+struct.pack('<I',tables['6266']['virtual_address'])+bytes.fromhex('c1e318899e1e010000')
    at=exe.find(signature)
    if at<0 or exe.find(signature,at+1)>=0:raise ValueError('Original F773 initial jet instructions differ')
    return tables,specs,{'source_procedure':'F773','executable_offset':at,'hex':signature.hex(),'sha256':sha(signature),'scope':'Only MOVSX drive; table lookup; SHL24; store jet raw. No full NPC/player initialization claim.'}


def instructions(disassembly):
    rows=[]
    for line in disassembly.splitlines():
        match=re.match(r'^\s*([0-9a-f]+):\s+([a-z][a-z0-9]*)\s*(.*?)\s*$',line)
        if match:rows.append((int(match[1],16),match[2],re.sub(r'\s*<.*?>','',match[3]).strip()))
    return rows

def canonical(rows,external_exit=False):
    labels={at:i for i,(at,_,_)in enumerate(rows)};result=[]
    for at,op,args in rows:
        args=re.sub(r'\s+','',args.lower())
        if op.startswith('j'):
            target=int(args,16)
            if target not in labels:
                if not external_exit:raise ValueError('Jump outside reviewed procedure')
                args='slice_exit'
            else:args='instruction:'+str(labels[target])
        if op=='call'and re.fullmatch(r'(?:0x)?[0-9a-f]+',args):args=hex(int(args,16))
        result.append(op+' '+args)
    return result


def proof32(source,exe,exe_path,tables):
    proof={}
    aliases={**{'FUNC_%06d'%n:v for n,v in DOS_EXTERNAL.items()},'DATA_008804':0x64213c,'DATA_007756':0x501848,'DATA_005111':tables['5111']['virtual_address']}
    for number,(start,end)in DOS_FUNCTIONS.items():
        original=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn','--start-address='+hex(file_to_va(exe,start)),'--stop-address='+hex(file_to_va(exe,end-1)+1),str(exe_path)],capture_output=True,text=True,check=True).stdout
        original_rows=instructions(original)
        raw_block=block(source,number)
        adapted=[]
        for line in raw_block.splitlines():
            line=line.split(';',1)[0].strip()
            if not line:continue
            line=re.sub(r'\b(?:near|short)\s+','',line)
            line=re.sub(r'\b(byte|word|dword)\s*\[',lambda m:m[1].upper()+' PTR [',line)
            line=re.sub(r'\b(?:byte|word|dword)\s+(?=[+\-0-9])','',line)
            line=re.sub(r'^push dword (DATA_\d+)$',r'push OFFSET FLAT:\1',line)
            line=re.sub(r'^(mov \w+,)(DATA_\d+)$',r'\1OFFSET FLAT:\2',line)
            line=line.replace('call [','call DWORD PTR [')
            if line.startswith('add esp,0x'):
                value=int(line.split(',')[1],16)
                if value>=0x80000000:line='add esp,'+str(value-0x100000000)
            line=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',line)
            adapted.append(line)
        prologue='.intel_syntax noprefix\n.code32\n.section .text\n'
        prologue+=''.join('.equ %s,0x%x\n'%(name,at)for name,at in aliases.items()if name!='FUNC_%06d'%number)
        with tempfile.TemporaryDirectory(prefix='jet-dos-instruction-proof-')as directory:
            work=Path(directory);(work/'p.s').write_text(prologue+'\n'.join(adapted)+'\n')
            subprocess.run(['as','--32',str(work/'p.s'),'-o',str(work/'p.o')],check=True,capture_output=True)
            subprocess.run(['ld','-m','elf_i386','-e','FUNC_%06d'%number,'--section-start=.text='+hex(file_to_va(exe,start)),str(work/'p.o'),'-o',str(work/'p')],check=True,capture_output=True)
            observed=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn',str(work/'p')],capture_output=True,text=True,check=True).stdout
        expected=canonical(original_rows);actual=canonical(instructions(observed))
        if expected!=actual:
            mismatch=[{'instruction':i,'original':a,'source':b}for i,(a,b)in enumerate(zip(expected,actual))if a!=b]
            raise ValueError('DOS instruction proof failed F'+str(number)+' counts'+str((len(expected),len(actual)))+' diff'+str(mismatch[:8]))
        raw=exe[start:end]
        if exe.find(raw)!=start or exe.find(raw,start+1)>=0:raise ValueError('DOS code block not unique')
        proof[str(number)]={'executable_offset':start,'virtual_address':file_to_va(exe,start),'byte_length':len(raw),'sha256':sha(raw),
                            'instruction_count':len(expected),'normalized_instruction_sha256':sha('\n'.join(expected).encode()),
                            'all_instructions_equal_after_only_branch_destination_normalization':True}
    return proof



def source_slices(source):
    maintenance=block(source,1007)
    cooling=re.search(r'(cmp dword \[ebx\+0x1ec\],byte \+0x0.*?)(?=\tJUMP_004168:)',maintenance,re.S)[1]+'\nJUMP_004168:\n'
    scheduler=block(source,152)
    cadence=re.search(r'(mov eax,\[DATA_008804\]\s+sub eax,\[DATA_008808\]\s+mov ecx,0xc22e.*?add \[DATA_008808\],eax)',scheduler,re.S)[1]+'\nJUMP_001191:\n'
    return {'cooling':cooling,'cadence':cadence}

def prove_slices(source,exe,exe_path):
    ranges={'cooling':(201684,201749),'cadence':(41977,42015)}
    result={}
    for name,body in source_slices(source).items():
        start,end=ranges[name]
        original=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn','--start-address='+hex(file_to_va(exe,start)),'--stop-address='+hex(file_to_va(exe,end-1)+1),str(exe_path)],capture_output=True,text=True,check=True).stdout
        adapted=[]
        for line in body.splitlines():
            line=line.split(';',1)[0].strip()
            if not line:continue
            line=re.sub(r'\b(?:near|short)\s+','',line)
            line=re.sub(r'\b(byte|word|dword)\s*\[',lambda m:m[1].upper()+' PTR [',line)
            line=re.sub(r'\b(?:byte|word|dword)\s+(?=[+\-0-9])','',line)
            adapted.append(line)
        text='.intel_syntax noprefix\n.code32\n.section .text\n.equ DATA_008804,0x64213c\n.equ DATA_008808,0x642144\n.global slice_start\nslice_start:\n'+'\n'.join(adapted)+'\n'
        with tempfile.TemporaryDirectory(prefix='jet-dos-slice-proof-')as directory:
            work=Path(directory);(work/'p.s').write_text(text)
            subprocess.run(['as','--32',str(work/'p.s'),'-o',str(work/'p.o')],check=True,capture_output=True)
            subprocess.run(['ld','-m','elf_i386','-e','slice_start','--section-start=.text='+hex(file_to_va(exe,start)),str(work/'p.o'),'-o',str(work/'p')],check=True,capture_output=True)
            observed=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn',str(work/'p')],capture_output=True,text=True,check=True).stdout
        expected=canonical(instructions(original),True);actual=canonical(instructions(observed),True)
        if expected!=actual:raise ValueError('DOS slice proof failed '+name+str([(a,b)for a,b in zip(expected,actual)if a!=b])+str((len(expected),len(actual))))
        result[name]={'executable_offset':start,'byte_length':end-start,'sha256':sha(exe[start:end]),'instruction_count':len(expected),
                      'normalized_instruction_sha256':sha('\n'.join(expected).encode()),'all_instructions_equal':True,
                      'outgoing_slice_edge':'Original outgoing branch is normalized to slice_exit; omitted GUI/module loops are never executed.'}
    return result


def native(source,tables):
    adapter=load_module('jet_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
    normalized=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
    normalized=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),normalized)
    normalized=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),normalized)
    pieces=source_slices(normalized)
    helpers='\nFUNC_900007:\npush ebp\nmov ebp,esp\npush ebx\npush esi\nmov esi,[ebp+0x8]\nmov ebx,DATA_008804\n'+pieces['cooling']+'pop esi\npop ebx\npop ebp\nret\n'
    helpers+='FUNC_900152:\npush ebp\nmov ebp,esp\npush edi\n'+pieces['cadence']+'mov [output+28],edi\npop edi\npop ebp\nret\nFUNC_999999:\nret\n'
    lines,_=adapter.procedures(normalized+helpers,NUMBERS+[900007,900152]);text='\n'.join(lines)
    text=text.replace('FUNC_000929:\n','''FUNC_000929:
 push rax
 mov eax,DWORD PTR [rsp+24]
 mov DWORD PTR [output+4],eax
 inc DWORD PTR [output]
 pop rax
''')
    text+="\n.section .text\n"+'''
FUNC_000349:
 push rax
 push rcx
 push rdx
 mov eax,DWORD PTR [rsp+32]
 mov edx,DWORD PTR [rax]
 cmp DWORD PTR [rax+24],0xffffffff
 jne failed
 mov ecx,DWORD PTR [output+8]
 cmp ecx,16
 jae failed
 mov DWORD PTR [output+32+rcx*4],edx
 inc DWORD PTR [output+8]
 pop rdx
 pop rcx
 pop rax
 ret
FUNC_000287:
 inc DWORD PTR [output+12]
 ret
FUNC_000293:
 inc DWORD PTR [output+16]
 ret
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,950
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,950
 jb read_more
 mov rax,0x4a45544655454c53
 mov QWORD PTR [object_before],rax
 mov QWORD PTR [object_after],rax
 mov QWORD PTR [spec_before],rax
 mov QWORD PTR [spec_after],rax
 mov QWORD PTR [globals_before],rax
 mov QWORD PTR [globals_after],rax
 mov QWORD PTR [output_before],rax
 mov QWORD PTR [output_after],rax
 mov esi,OFFSET FLAT:input+32
 mov edi,OFFSET FLAT:ship_spec
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:input+56
 mov edi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+394
 mov edi,OFFSET FLAT:DATA_008804
 mov ecx,556
 rep movsb
 mov DWORD PTR [DATA_008804+0xc8],OFFSET FLAT:object
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,1030
 rep stosb
 mov DWORD PTR [output+24],0x90793829
 mov DWORD PTR [iteration],0
run_repeat:
 cmp DWORD PTR [input],0
 je consume_case
 cmp DWORD PTR [input],1
 je maintenance_case
 cmp DWORD PTR [input],2
 je manual_case
 cmp DWORD PTR [input],3
 je initial_case
 cmp DWORD PTR [input],4
 je cooling_case
 cmp DWORD PTR [input],5
 je cadence_case
 jmp failed
consume_case:
 push QWORD PTR [input+4]
 push OFFSET FLAT:object
 call FUNC_000929
 add rsp,16
 jmp iteration_done
maintenance_case:
 push QWORD PTR [input+4]
 push OFFSET FLAT:object
 call FUNC_000938
 add rsp,16
 jmp iteration_done
manual_case:
 call FUNC_000289
 jmp iteration_done
cooling_case:
 push QWORD PTR [input+4]
 call FUNC_900007
 add rsp,8
 jmp iteration_done
cadence_case:
 call FUNC_900152
 jmp iteration_done
initial_case:
 mov esi,OFFSET FLAT:object
 # Original F773 exact four-instruction slice, verified in DOS executable.
 movsx eax,BYTE PTR [esi+0xd0]
 mov ebx,DWORD PTR [eax*4+DATA_006266]
 shl ebx,0x18
 mov DWORD PTR [esi+0x11e],ebx
iteration_done:
 inc DWORD PTR [iteration]
 mov eax,DWORD PTR [iteration]
 cmp eax,DWORD PTR [input+8]
 jb run_repeat
 mov DWORD PTR [output+20],eax
 mov esi,OFFSET FLAT:ship_spec
 mov edi,OFFSET FLAT:output+96
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:DATA_008804
 mov ecx,556
 rep movsb
 # The host relocates only the object pointer; it is not a source output.
 mov DWORD PTR [output+458+0xc8],0
 mov rax,0x4a45544655454c53
 stosq
 stosq
 cmp QWORD PTR [object_before],rax
 jne failed
 cmp QWORD PTR [object_after],rax
 jne failed
 cmp QWORD PTR [spec_before],rax
 jne failed
 cmp QWORD PTR [spec_after],rax
 jne failed
 cmp QWORD PTR [globals_before],rax
 jne failed
 cmp QWORD PTR [globals_after],rax
 jne failed
 cmp QWORD PTR [output_before],rax
 jne failed
 cmp QWORD PTR [output_after],rax
 jne failed
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,1030
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,1030
 jb write_more
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,94
 syscall
.section .rodata
.align 8
DATA_007756: .quad FUNC_001538
DATA_004681:
.rept 65536
.long descriptor
.endr
'''
    for n in [5111,6266]:text+='DATA_%06d: .byte '%n+','.join(map(str,bytes.fromhex(tables[str(n)]['hex'])))+'\n'
    text+='''
.section .data
descriptor: .zero 56
 .long ship_spec
 .zero 8
.section .bss
.align 8
input: .zero 950
iteration: .zero 4
object_before: .zero 8
object: .zero 338
object_after: .zero 8
spec_before: .zero 8
ship_spec: .zero 24
spec_after: .zero 8
globals_before: .zero 8
DATA_008804: .zero 556
.equ DATA_008808,DATA_008804+8
globals_after: .zero 8
output_before: .zero 8
output: .zero 1030
output_after: .zero 8
.align 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return '.intel_syntax noprefix\n.code64\n.section .text\n'+text


def make_cases(specs,tables):
    rows=[]
    def add(operation='F929',model=38,amount=1,step=1,repeat=1,jet=0x20000000,drive=2,player=True,auto=False,
            hydrogen=2,military=2,waste=65535,cargo=0,status=0,commands=None,thrust=None,cached=None,spec_raw=None,
            player_id=17,domain='normal',equipment=0,**extra):
        raw=bytearray((i*43+7)&255 for i in range(338))
        struct.pack_into('<I',raw,0x82,model);raw[0x86]=17 if player else 18
        struct.pack_into('<3h',raw,0xb6,*(commands or [0,0,0]))
        struct.pack_into('<6H',raw,0xbc,*(thrust or [111,222,333,444,555,666]))
        struct.pack_into('<I',raw,0xc8,equipment|(2 if auto else 0));raw[0xd0]=drive&255;raw[0x119]=hydrogen&255
        struct.pack_into('<I',raw,0x11e,jet&0xffffffff)
        # Neutral non-jet maintenance fields unless a diagnostic case opts in.
        struct.pack_into('<HHHHHH',raw,0xe0,0,0,400,0,0,0);raw[0x14e]=0;raw[0x14f]=0;raw[0x151]=0
        for k,v in extra.get('body_byte_overrides',{}).items():raw[int(k)]=v
        row={'operation':operation,'domain':domain,'model_index':model,'spec_hex':(bytes.fromhex(specs[str(model)]['spec_hex'])if spec_raw is None else spec_raw).hex(),
             'object_hex':raw.hex(),'amount_u32':amount&0xffffffff,'step_s32':s32(step),'repeat_count':repeat,
             'globals':{'player_object_index_u32':player_id,'status_u16':status,'cargo_s32':s32(cargo),'hydrogen_u16':hydrogen&65535,
                        'military_u16':military&65535,'waste_u16':waste&65535,'cached_thrust_u32':cached or [0xaaaabbbb,0xccccdddd,0xeeeeffff,0x12345678,0x87654321,0x98765432]}}
        row.update(extra);rows.append(row)
    for jet in [0,1,2,0x1fffffff,0x20000000,0x20000001,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]:
        for amount in sorted({0,1,2,max(0,jet-1),jet,(jet+1)&0xffffffff,0x7fffffff,0x80000000,0xffffffff}):
            for player in [False,True]:
                for auto in [False,True]:add(jet=jet,amount=amount,player=player,auto=auto,domain='unsigned_debit_boundaries')
    for drive in [0,1,2,9,10,12,13,14,127,128,255]:
        for hydrogen,military in [(0,0),(1,0),(0,1),(1,1),(65535,65535)]:
            for player in [False,True]:
                for auto in [False,True]:
                    for repeat in [1,3]:add(drive=drive,jet=0,amount=1,hydrogen=hydrogen,military=military,player=player,auto=auto,repeat=repeat,domain='refill_empty_signed_drive')
    for status in [0,1,0x100,0xffff]:
        for repeat in [1,2,3,8]:add(jet=0,amount=0,status=status,hydrogen=0,military=0,repeat=repeat,domain='alert_once')
    for player_id in [17,18,273,0xffffffff]:
        add(player_id=player_id,jet=10,amount=1,domain='player_dword_identity')
        add(player_id=player_id,jet=0,amount=1,auto=True,domain='player_dword_identity')
    # F938 command sign, zero, all-axis summation, signed IMUL overflow.
    for model in [15,16,25,38,50,60,68,71]:
        for axis in range(3):
            for value in [-32768,-32767,-1,0,1,32767]:
                for step in [0,1,16,65535,-1,0x7fffffff,-2147483648]:
                    commands=[0,0,0];commands[axis]=value
                    add('F938',model=model,commands=commands,step=step,jet=0xffffffff,auto=True,domain='source_three_command_axes')
    for commands in [[32767]*3,[-32768]*3,[32767,-32768,1],[1,1,1],[0,0,0]]:
        for step in [0,1,2,16,65536,0x7fffffff,-2147483648]:
            for player in [False,True]:add('F938',commands=commands,step=step,player=player,jet=100,auto=True,domain='source_command_sum_wrap')
    for mass in [0,1,32767,32768,65535]:
        spec=bytearray.fromhex(specs['38']['spec_hex']);struct.pack_into('<H',spec,6,mass)
        for commands in [[32767]*3,[-32768]*3,[1,-1,0]]:
            for step in [1,65536,-1]:add('F938',spec_raw=spec,commands=commands,step=step,domain='signed_mass_debit_wrap')
    # Run full original maintenance, while declaring its non-jet state outside live scope.
    for equipment in [0,0x10000000,0x80000000,1,0x80000001]:
        for step in [0,1,2,65535,-1]:
            add('F938',equipment=equipment,step=step,commands=[10,-20,30],domain='other_maintenance_diagnostic',
                body_byte_overrides={224:1,225:0,226:255,227:255,228:1,229:0,234:255,235:255,334:127,335:255,337:255})
    # Near-full epsilon, add-wrap/clamp and no-fuel branches for every supported row.
    for drive,capacity in enumerate(tables['5111']['u32']):
        threshold=(capacity-0x1999999)&0xffffffff
        for jet in sorted({0,1,capacity,max(0,capacity-1),threshold,max(0,threshold-1),(threshold+1)&0xffffffff,0xf0000000,0xffffffff}):
            for fuel in [0,1,65535]:add('F289',drive=drive,jet=jet,hydrogen=fuel,military=fuel,status=1,domain='manual_refill_boundaries')
    for drive in range(15):
        for repeat in [2,8]:add('F289',drive=drive,jet=0,repeat=repeat,domain='manual_repeated')
        add('initial_profile',drive=drive,jet=0x12345678,domain='original_f773_start_profile')
    for index in range(6):
        thrust=[0]*6;thrust[index]=0xffff
        add(jet=0,hydrogen=0,thrust=thrust,domain='dos_three_nozzle_mask')
        add(jet=100,amount=1,thrust=thrust,domain='dos_no_ordinary_restore')
    rng=random.Random(0x929938289)
    for _ in range(512):
        commands=[rng.randrange(-32768,32768)for _ in range(3)]
        add('F938',commands=commands,step=s32(rng.getrandbits(32)),jet=rng.getrandbits(32),auto=bool(rng.randrange(2)),
            drive=rng.randrange(256),hydrogen=rng.randrange(65536),military=rng.randrange(65536),player=bool(rng.randrange(2)),domain='random_raw_controls')
    for heat in [-2147483648,-1,0,1,127,128,129,511,512,513,65535,2147483647]:
        for step in [-2147483648,-1,0,1,2,65535,0x1000000,2147483647]:
            for shield in [False,True]:add('cooling',step=step,heat_s32=heat,shield_bool=shield,equipment=0x40000000 if shield else 0,domain='f1007_thermal_cooling')
    for current in [0,1,49709,49710,49711,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]:
        for last in [0,1,49709,49710,49711,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]:
            add('cadence',current_tick_u32=current,last_tick_u32=last,domain='f152_calendar_second_cadence')
    for last in [0,0x7fffffff,0x80000000,0xffffffff]:
        for delta in [49709,49710,49711,99419,99420,99421,0x7fffffff,0xffffffff]:
            add('cadence',current_tick_u32=(last+delta)&0xffffffff,last_tick_u32=last,domain='f152_remainder_wrap')
    return rows


def context_bytes(g):
    raw=bytearray([0x6b]*GLOBALS_BYTES)
    struct.pack_into('<I',raw,0xc0,g['player_object_index_u32']);struct.pack_into('<H',raw,0xc6,g['status_u16']);struct.pack_into('<I',raw,0xc8,0)
    struct.pack_into('<I',raw,0x120,g['cargo_s32']&0xffffffff)
    struct.pack_into('<HH',raw,0x15a,g['hydrogen_u16'],g['military_u16']);struct.pack_into('<H',raw,0x16e,g['waste_u16'])
    struct.pack_into('<6I',raw,0x214,*g['cached_thrust_u32']);return bytes(raw)
def packet(row):
    value=row['step_s32']if row['operation']in['F938','cooling']else row['amount_u32']
    return struct.pack('<8I',OPS.index(row['operation']),value&0xffffffff,row['repeat_count'],0,0,0,0,0)+bytes.fromhex(row['spec_hex'])+bytes.fromhex(row['object_hex'])+input_context(row)

def input_context(row):
    raw=bytearray(context_bytes(row['globals']))
    if row['operation']=='cooling':struct.pack_into('<I',raw,0x1ec,row['heat_s32']&0xffffffff)
    if row['operation']=='cadence':
        struct.pack_into('<I',raw,0,row['current_tick_u32']);struct.pack_into('<I',raw,8,row['last_tick_u32'])
    return bytes(raw)

def decoded_context(raw):
    return {'player_object_index_u32':struct.unpack_from('<I',raw,0xc0)[0],'status_u16':struct.unpack_from('<H',raw,0xc6)[0],
            'cargo_s32':struct.unpack_from('<i',raw,0x120)[0],'hydrogen_u16':struct.unpack_from('<H',raw,0x15a)[0],
            'military_u16':struct.unpack_from('<H',raw,0x15c)[0],'waste_u16':struct.unpack_from('<H',raw,0x16e)[0],
            'cached_thrust_u32':list(struct.unpack_from('<6I',raw,0x214))}
def expected(row,raw):
    count,last,messages,refresh,error,repeated,sentinel,_=struct.unpack_from('<8I',raw)
    if sentinel!=0x90793829 or repeated!=row['repeat_count']or messages>16:raise ValueError('Bad callbacks/header')
    if raw[96:120].hex()!=row['spec_hex']or struct.unpack_from('<2Q',raw,1014)!=(GUARD,GUARD):raise ValueError('Inputspec/guard changed')
    body=raw[120:458];ctx=raw[458:1014];before=input_context(row)
    global_writes={0xc6,0xc7,*range(0x120,0x124),0x15a,0x15b,0x15c,0x15d,0x16e,0x16f}
    if row['operation']=='cooling':global_writes|=set(range(0x1ec,0x1f0))
    if row['operation']=='cadence':global_writes|=set(range(8,12))
    if any(a!=b for i,(a,b)in enumerate(zip(before,ctx))if i not in global_writes):raise ValueError('Unexpected global write')
    allowed={0x119,*range(0xbc,0xc8),*range(0x11e,0x122)}
    if row['operation']=='F938':allowed|={0xe0,0xe1,0xe4,0xe5,0xea,0xeb,0x14e,0x14f,0x151}
    if any(a!=b for i,(a,b)in enumerate(zip(bytes.fromhex(row['object_hex']),body))if i not in allowed):raise ValueError('Unexpected object write '+str([(hex(i),a,b)for i,(a,b)in enumerate(zip(bytes.fromhex(row['object_hex']),body))if i not in allowed and a!=b])+' row'+str(row))
    result={'object_hex':body.hex(),'globals':decoded_context(ctx),'debit_u32_last':last,'consume_call_count':count,
            'messages_u32':list(struct.unpack_from('<%dI'%messages,raw,32))if messages else[],
            'refresh_call_count':refresh,'no_fuel_call_count':error}
    if row['operation']=='cooling':result['heat_s32']=struct.unpack_from('<i',ctx,0x1ec)[0]
    if row['operation']=='cadence':result['whole_seconds']=struct.unpack_from('<I',raw,28)[0];result['updated_last_tick_u32']=struct.unpack_from('<I',ctx,8)[0]
    return result


def run_native(text,rows,debugname):
    ordered=rows+list(reversed(rows));packets=b''.join(map(packet,ordered))
    with tempfile.TemporaryDirectory(prefix='ffe-jet-native-')as directory:
        work=Path(directory);(work/'native.s').write_text(text)
        for command in [['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')]]:
            process=subprocess.run(command,capture_output=True)
            if process.returncode:
                debug=Path('/workspace/recovery')/debugname;debug.mkdir(parents=True,exist_ok=True);(debug/'native.s').write_text(text)
                raise ValueError(process.stderr.decode())
        outputs=[]
        for _ in range(3):
            process=subprocess.run([str(work/'native')],input=packets,capture_output=True,timeout=45)
            if process.returncode:
                import shutil
                index=len(process.stdout)//OUTPUT_BYTES;debug=Path('/workspace/recovery')/debugname;debug.mkdir(parents=True,exist_ok=True)
                for name in ['native.s','native']:shutil.copyfile(work/name,debug/name)
                (debug/'input.bin').write_bytes(packets[index*INPUT_BYTES:(index+1)*INPUT_BYTES])
                raise ValueError('Nativefailedat'+str(ordered[index])+'exit'+str(process.returncode))
            outputs.append(process.stdout)
    if len(outputs[0])!=len(ordered)*OUTPUT_BYTES or any(x!=outputs[0]for x in outputs[1:]):raise ValueError('Incomplete/process-dependent output')
    result=[]
    for i,row in enumerate(rows):
        raw=outputs[0][i*OUTPUT_BYTES:(i+1)*OUTPUT_BYTES];j=len(ordered)-1-i
        if raw!=outputs[0][j*OUTPUT_BYTES:(j+1)*OUTPUT_BYTES]:raise ValueError('Case-order dependence')
        result.append(expected(row,raw))
    return result,{'fresh_process_runs':3,'reverse_repeat_count':len(rows),'adapted_assembly_sha256':sha(text.encode()),
                   'input_packets_sha256':sha(packets),'native_output_sha256':sha(outputs[0]),'canaries_unchanged':True}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_jet_fuel_native.json')
    args=parser.parse_args();source_raw=args.source.read_bytes();data_raw=args.data_source.read_bytes();exe=args.exe.read_bytes()
    if sha(source_raw)!=ASM_SHA or sha(data_raw)!=DATA_SHA or sha(exe)!=EXE_SHA:raise ValueError('Unreviewed original revision')
    source=source_raw.decode();dos=dos_source(source);tables,specs,startproof=resources(exe,data_raw.decode());proof=proof32(dos,exe,args.exe,tables);slice_proof=prove_slices(dos,exe,args.exe)
    rows=make_cases(specs,tables);results,observed=run_native(native(dos,tables),rows,'jet-dos-native-debug')
    for row,value in zip(rows,results):row['expected']=value
    compared=[row.copy()for row in rows if row['domain']in['dos_three_nozzle_mask','dos_no_ordinary_restore','player_dword_identity']]
    compared.extend(row.copy()for row in rows if row['domain']=='unsigned_debit_boundaries'and row['globals']['player_object_index_u32']==17 and bytes.fromhex(row['object_hex'])[0x86]==17) 
    compared=compared[:128]
    alt,alt_observed=run_native(native(source,tables),compared,'jet-jjffe-native-debug')
    differences=[]
    for row,value in zip(compared,alt):
        if row['expected']!=value:
            row['expected_dos']=row.pop('expected');row['expected_jjffe']=value;differences.append(row)
    if not differences:raise ValueError('Expected unmarked DOS/JJFFE F929 differences absent')
    fixture={'schema':1,'revision':'original-dos-jet-fuel-v1','source_variant':'dos-firstenc-f929-f938-f289-v1','source_sha256':EXE_SHA,
             'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d',
             'source_procedure_hashes':{str(n):sha(block(source,n).encode())for n in NUMBERS+[152,1007]},'dos_transformed_f929_sha256':sha(block(dos,929).encode()),
             'dos_instruction_proof':proof,'dos_slice_instruction_proof':slice_proof,'initial_profile_instruction_proof':startproof,'tables':tables,'ship_specs':specs,
             'cadence_contract':{'source_procedure':'F152 arithmetic slice','raw_ticks_per_calendar_second':49710,'delta':'uint32(current_tick-last_tick)','whole_seconds_range':[0,86400],'last_tick_update':'uint32(last_tick+whole_seconds*49710)','day_word_used':False,'os_real_seconds_mapping_proven':False,'caller_chain_npc':'F152→F151 event6→F707→F706→DATA9045→F732→F938','caller_chain_player':'F152→F151 event6→F1007→F938'},
             'case_count':len(rows),'operation_counts':{op:sum(r['operation']==op for r in rows)for op in OPS},
             'domain_counts':{domain:sum(r['domain']==domain for r in rows)for domain in sorted({r['domain']for r in rows})},
             **observed,'cases':rows,'jjffe_counterfactual':{'not_canonical_dos':True,'case_count':len(compared),'difference_count':len(differences),
             **alt_observed,'differences':differences,
             'unmarked_patches':['JJFFE F929 ordinary debit restores all six cached player nozzle limits; DOS does not.',
                 'JJFFE F929 exhaustion clears all six nozzle limits; DOS clears BC/C0/C4 only, preserving BE/C2/C6.']},
             'scope':'Canonical original DOS F929 and F289 with source-only rendering/message callbacks recorded. Full F938 executes to supply its actual F929 debit and jet/nozzle/global result; shield/hull/heat/timer maintenance is diagnostic and outside the live jet kernel. Original F773 four-instruction initial-jet slice executes with exact DOS DATA6266. Native F1538 lookup uses host-selected exact DOS spec. F1007 thermal cooling and F152 calendar-second quotient/remainder slices are byte-verified and executed, while their remaining GUI/module/event loops are omitted. No full F773 NPC generation, F930 weapons, full original event scheduler or complete physical/FOR integration claim.',
             'callback_adapters':{'F349':'Record message code and verify duration-1; no original GUI queue simulation.','F287':'Record refresh count only.','F293':'Record original no-cargo-fuel UI branch count, not an invented F349 message.'},
             'input_contract':'F929 debit u32; F938 step s32 incl diagnostic negative/wrap controls. F929/F938 drive comparison uses signed byte and admits all256 bit patterns; F289 and initial-profile table indices must be0..14. Actual F938 callers supply whole calendar seconds quantized at49710 source ticks; raw negative/wrapped steps are diagnostic controls, with no OS-real-second mapping inferred.'}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    print(json.dumps({k:fixture[k]for k in ['case_count','operation_counts','domain_counts','native_output_sha256','dos_instruction_proof']},indent=2))
    print(json.dumps({'jjffe_counterfactual_cases':len(compared),'jjffe_difference_count':len(differences),'fixture_sha256':sha(args.output.read_bytes())}))
if __name__=='__main__':main()
