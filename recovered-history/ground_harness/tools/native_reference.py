"""Adapt reviewed JJFFE integer procedures for host-only x86_64 controls.
All pointers must live below 2 GiB; callers provide a low BSS stack for pointer arguments.
"""
import hashlib,re

def procedures(source,numbers):
 lines=[];hashes={}
 for number in numbers:
  start=source.index(f'FUNC_{number:06d}:');end=re.search(r'^FUNC_\d+:',source[start+1:],re.M)
  block=source[start:start+1+end.start()];hashes[str(number)]=hashlib.sha256(block.encode()).hexdigest()
  for line in block.splitlines():
   line=line.split(';')[0].strip()
   if not line:continue
   line=re.sub(r'\b(?:near|short)\s+','',line)
   line=re.sub(r'\b(byte|word|dword)\s*\[',lambda m:m[1].upper()+' PTR [',line)
   line=re.sub(r'\b(?:byte|word|dword)\s+(?=[+\-0-9])','',line)
   line=re.sub(r'\[ebp\+0x([0-9a-f]+)\]',lambda m:'[rbp+%d]'%(16+((int(m[1],16)-8)//4)*8+(int(m[1],16)-8)%4),line)
   line=line.replace('[ebp','[rbp').replace('mov ebp,esp','mov rbp,rsp').replace('mov esp,ebp','mov rsp,rbp')
   if line.startswith(('push ','pop ')):
    for old,new in [('ebp','rbp'),('ebx','rbx'),('esi','rsi'),('edi','rdi'),('eax','rax'),('ecx','rcx'),('edx','rdx')]:line=re.sub(r'\b'+old+r'\b',new,line)
    line=line.replace('push DWORD PTR','push QWORD PTR')
   if line.startswith('add esp,'):
    n=int(line.split(',')[1],0);line='add rsp,'+str(n*2 if n>0 else n)
   line=re.sub(r'^push dword (DATA_\d+)$',r'push OFFSET FLAT:\1',line)
   line=re.sub(r'^(mov \w+,)(DATA_\d+)$',r'\1OFFSET FLAT:\2',line)
   if line.startswith('call ['):line=line.replace('call [','call QWORD PTR [')
   line=re.sub(r'^call (eax|ebx|ecx|edx|esi|edi)$',lambda m:'call r'+m[1][1:],line)
   lines.append(line)
 return lines,hashes
