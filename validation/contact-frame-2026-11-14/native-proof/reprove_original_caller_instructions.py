#!/usr/bin/env python3
"""Optional original-file reproof; default replay needs only archived assemblies."""
import inspect,re,sys,json,hashlib
from pathlib import Path
sys.dont_write_bytecode=True;sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'tools'));import rebuild_source_natural_contact_native as N
P=Path(__file__).resolve().parents[3];D=Path(__file__).resolve().parent;S=Path('/workspace/ffe-upstream/jjffe/ffe.asm').read_text();A=Path('/workspace/ffe-upstream/jjffe/ffedat.asm').read_text();E=Path('/workspace/ffe-original/FIRSTENC.EXE');nums=[569,570,574,575,1333,1335,1531,1532,1661,1662,1677];native_nums=[569,570,1335,1532,1662]
assert hashlib.sha256(E.read_bytes()).hexdigest()==N.EXE_SHA, 'Unsupported original executable'
assert hashlib.sha256(Path('/workspace/ffe-upstream/jjffe/ffe.asm').read_bytes()).hexdigest()==N.ASM_SHA, 'Unsupported pinned source'
ns=dict(N.__dict__);exec(inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000570',0x4272a0)"),ns)
bodies,records,dis,cb=ns['proof'](S,A,E.read_bytes(),E,nums)
source='\n'.join(bodies[n]for n in native_nums)+'\nFUNC_999999:\nret\n';source=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source);source=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
lines,_=N.Q.procedures(source,native_nums);text='\n'.join(lines);text=re.sub(r'call QWORD PTR \[([^\]]+)\]',lambda m:'mov eax,DWORD PTR ['+m[1]+']\ncall rax',text)
(D/'caller-source-procedures.s').write_text('.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n')
(D/'caller-instruction-proofs.json').write_text(json.dumps({'source_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'scope':'Full DOSF569/F570/F1532/F1662/F1335 plus static-onlyF574/F575/F1333/F1531/F1661/F1677 instructioncomparison. NativeexecutioninterceptsF575 atentry andexcludesframeconversion/worldrecursivebranches.','byte_instruction_proofs':records,'source_procedure_sha256':{str(n):hashlib.sha256(N.G.block(S,n).encode()).hexdigest()for n in nums},'adapted_native_procedures_sha256':hashlib.sha256((D/'caller-source-procedures.s').read_bytes()).hexdigest(),'adapted_native_procedure_numbers':native_nums},indent=2)+'\n')
for key,body in dis.items():(D/f'dos-F{key}.txt').write_text(body)
print('CALLER DOS PROOFS',len(records),sum(v['instruction_count']for v in records.values()))
