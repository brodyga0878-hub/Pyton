.intel_syntax noprefix
.code64
.section .text
FUNC_000569:
push rbp
mov rbp,rsp
mov BYTE PTR [DATA_008700],0xff
mov eax,[rbp+64]
push rax
mov eax,[rbp+56]
push rax
mov eax,[rbp+48]
push rax
mov eax,[rbp+40]
push rax
mov eax,[rbp+32]
push rax
mov eax,[rbp+24]
push rax
mov eax,[rbp+16]
push rax
call FUNC_000570
add rsp,56
pop rbp
ret
FUNC_000570:
push rbp
mov rbp,rsp
add rsp,-56
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov BYTE PTR [DATA_008696],0x0
mov BYTE PTR [DATA_008697],0x0
mov BYTE PTR [DATA_008698],0x0
mov BYTE PTR [DATA_008701],0x0
mov DWORD PTR [DATA_008703],0xffffffff
mov BYTE PTR [DATA_008707],0x0
mov al,[ebx+0x56]
test al,al
jz JUMP_002393
mov edx,[rbp+24]
push rdx
and eax,0xff
push rax
mov eax,DWORD PTR [DATA_007754]
call rax
add rsp,16
mov esi,eax
mov [DATA_008702],esi
push rsi
lea esi,[ebx+0x3e]
lea edi,[rbp-0x20]
mov ecx,0x6
rep movsd
pop rsi
push rsi
push rbx
lea eax,[rbp-0x20]
push rax
call FUNC_000575
add rsp,24
mov [rbp-0x1],al
mov edx,[ebx+0x148]
test edx,edx
jz JUMP_002391
mov eax,[DATA_009155]
sar eax,1
jns JUMP_002389
adc eax,+0x0
JUMP_002389:
cmp eax,edx
jg JUMP_002390
sub [ebx+0x148],eax
jmp JUMP_002393
JUMP_002390:
xor eax,eax
mov [ebx+0x148],eax
jmp JUMP_002393
JUMP_002391:
test BYTE PTR [rbp-0x1],0x2
jz JUMP_002392
cmp BYTE PTR [ebx+0x57],0x0
jnz JUMP_002393
push rsi
push rbx
call FUNC_000572
add rsp,16
mov DWORD PTR [ebx+0x148],0x7f
jmp JUMP_002393
JUMP_002392:
cmp BYTE PTR [ebx+0x57],0x0
jz JUMP_002393
push rsi
push rbx
call FUNC_000573
add rsp,16
mov DWORD PTR [ebx+0x148],0x7f
JUMP_002393:
mov eax,[rbp+40]
mov dl,[ebx+0x56]
mov [eax],dl
mov al,[DATA_008696]
mov [rbp-0x1],al
mov edi,0x72
mov eax,[rbp+24]
add eax,+0x72
mov [rbp-0x8],eax
JUMP_002394:
mov eax,[rbp-0x8]
test BYTE PTR [eax],0x4
jz JUMP_002398
xor eax,eax
mov al,[ebx+0x86]
cmp edi,eax
jz JUMP_002398
mov eax,[rbp+24]
push rax
push rdi
mov eax,DWORD PTR [DATA_007754]
call rax
add rsp,16
mov esi,eax
cmp BYTE PTR [esi+0x8b],0x0
jnz JUMP_002398
mov eax,[rbp+40]
movsx eax,BYTE PTR [eax]
xor edx,edx
mov dl,[esi+0x56]
cmp eax,edx
jnz JUMP_002398
cmp DWORD PTR [esi+0x82],0x99
jnz JUMP_002395
cmp DWORD PTR [ebx+0x82],0x99
jnz JUMP_002398
JUMP_002395:
mov al,[ebx+0x57]
cmp al,[esi+0x57]
jz JUMP_002396
push rbx
lea eax,[rbp-0x20]
push rax
mov eax,DWORD PTR [DATA_007802]
call rax
add rsp,16
push rsi
lea eax,[rbp-0x38]
push rax
mov eax,DWORD PTR [DATA_007802]
call rax
add rsp,16
lea eax,[rbp-0x38]
push rax
lea eax,[rbp-0x20]
push rax
call FUNC_001662
add rsp,16
jmp JUMP_002397
JUMP_002396:
push rsi
push rdi
lea esi,[ebx+0x3e]
lea edi,[rbp-0x20]
mov ecx,0x6
rep movsd
pop rdi
pop rsi
lea eax,[esi+0x3e]
push rax
lea eax,[rbp-0x20]
push rax
call FUNC_001662
add rsp,16
JUMP_002397:
push rsi
push rbx
lea eax,[rbp-0x20]
push rax
call FUNC_000575
add rsp,24
JUMP_002398:
dec edi
dec DWORD PTR [rbp-0x8]
test edi,edi
jg JUMP_002394
mov al,[rbp-0x1]
or [DATA_008696],al
cmp DWORD PTR [DATA_008704],+0x0
jnz JUMP_002399
cmp DWORD PTR [DATA_008703],+0x0
jnl JUMP_002400
JUMP_002399:
mov eax,[rbp+56]
mov DWORD PTR [eax],0xffffffff
jmp JUMP_002401
JUMP_002400:
mov eax,[rbp+56]
mov edx,[DATA_008703]
mov [eax],edx
JUMP_002401:
mov eax,[rbp+48]
mov edx,[DATA_008702]
mov [eax],edx
mov al,[DATA_008701]
and al,0x1f
mov edx,[rbp+64]
mov [edx],al
mov eax,[rbp+40]
mov dl,[DATA_008698]
mov [eax],dl
mov eax,[rbp+32]
mov dl,[DATA_008696]
mov [eax],dl
mov al,[DATA_008696]
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001335:
push rbp
mov rbp,rsp
mov edx,[rbp+16]
mov eax,[rbp+24]
sub eax,[rbp+40]
mov [edx],eax
mov eax,[rbp+32]
sbb eax,[rbp+48]
mov [edx+0x4],eax
pop rbp
ret
FUNC_001532:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,eax
lea eax,[edx+eax*4]
lea eax,[edx+eax*4]
lea eax,[edx+eax*8]
add eax,eax
add eax,[rbp+24]
add eax,+0x74
pop rbp
ret
FUNC_001662:
push rbp
mov rbp,rsp
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
push QWORD PTR [rsi+0x4]
push QWORD PTR [rsi]
push QWORD PTR [rbx+0x4]
push QWORD PTR [rbx]
push rbx
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0xc]
push QWORD PTR [rsi+0x8]
push QWORD PTR [rbx+0xc]
push QWORD PTR [rbx+0x8]
lea eax,[ebx+0x8]
push rax
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0x14]
push QWORD PTR [rsi+0x10]
push QWORD PTR [rbx+0x14]
push QWORD PTR [rbx+0x10]
add ebx,+0x10
push rbx
call FUNC_001335
add rsp,40
pop rsi
pop rbx
pop rbp
ret
