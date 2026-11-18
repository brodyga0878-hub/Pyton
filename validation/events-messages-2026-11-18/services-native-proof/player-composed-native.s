.intel_syntax noprefix
.code64
.section .text
FUNC_001103:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],1103
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,[eax]
push rdx
mov al,[eax+0x8]
push rax
call FUNC_001102
add rsp,16
pop rbp
ret
FUNC_001102:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],1102
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
mov ebx,[rbp+16]
cmp DWORD PTR [rbp+24],+0x0
jnz JUMP_004558
cmp bl,[DATA_008887]
jnz JUMP_004555
mov BYTE PTR [DATA_008887],0x0
JUMP_004555:
cmp bl,[DATA_008877]
jnz JUMP_004557
mov BYTE PTR [DATA_008877],0x0
cmp BYTE PTR [DATA_008872],0x5
jnz JUMP_004556
mov BYTE PTR [DATA_008872],0x0
JUMP_004556:
push +0x0
push +0x14
call FUNC_000262
add rsp,16
call FUNC_000991
jmp JUMP_004559
JUMP_004557:
movsx esi,bl
push rsi
call FUNC_001101
pop rcx
push rsi
call FUNC_001104
pop rcx
jmp JUMP_004559
JUMP_004558:
movsx eax,bl
cmp eax,[DATA_008857]
jnz JUMP_004559
mov DWORD PTR [DATA_008886],0x1e
JUMP_004559:
pop rsi
pop rbx
pop rbp
ret
FUNC_001101:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],1101
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
mov ebx,[rbp+16]
mov esi,OFFSET FLAT:DATA_008804
movsx eax,BYTE PTR [esi+0xec]
cmp ebx,eax
jz JUMP_004551
movsx eax,BYTE PTR [esi+0xed]
cmp ebx,eax
jnz JUMP_004552
JUMP_004551:
push -0x1
push 0x98c2
call FUNC_001097
add rsp,16
JUMP_004552:
movsx eax,BYTE PTR [esi+0xec]
cmp ebx,eax
jnz JUMP_004553
mov BYTE PTR [esi+0xec],0x0
cmp ebx,[esi+0xc0]
jz JUMP_004553
cmp BYTE PTR [esi+0xe8],0x2
jnz JUMP_004553
mov BYTE PTR [esi+0xe8],0x0
call FUNC_001116
push +0xe
push +0x0
push +0x1
call FUNC_000048
add rsp,24
JUMP_004553:
movsx eax,BYTE PTR [esi+0xed]
cmp ebx,eax
jnz JUMP_004554
mov BYTE PTR [esi+0xed],0x0
JUMP_004554:
pop rsi
pop rbx
pop rbp
ret
FUNC_000061:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],61
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp DWORD PTR [eax],+0x0
jnz JUMP_000510
movsx edx,BYTE PTR [eax+0x8]
mov [DATA_008560],edx
push rdx
push +0x0
push +0x16
call FUNC_000048
add rsp,24
xor eax,eax
mov [DATA_008560],eax
JUMP_000510:
pop rbp
ret

.global call_kernel
call_kernel:
mov [p_saved_rsp],rsp
mov esp,OFFSET FLAT:p_stack_end
cmp edi,1
je p_call1102
push OFFSET FLAT:p_payload
test edi,edi
jnz p_call61
call FUNC_001103
jmp p_called
p_call61:
call FUNC_000061
jmp p_called
p_call1102:
push rdx
push rsi
call FUNC_001102
p_called:
mov rsp,[p_saved_rsp]
ret
p_abort:
mov edi,97
mov eax,60
syscall

FUNC_000262:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],262
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,262
and rsp,-16
call p_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000991:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],991
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
mov edi,991
and rsp,-16
call p_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001097:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],1097
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,1097
and rsp,-16
call p_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001116:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],1116
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
mov edi,1116
and rsp,-16
call p_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000048:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],48
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov edi,48
and rsp,-16
call p_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001104:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [p_trace_count]
cmp ecx,128
jae p_abort
mov DWORD PTR [p_trace+rcx*4],1104
inc DWORD PTR [p_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,DWORD PTR [rbp+16]
xor edx,edx
xor ecx,ecx
mov edi,1104
and rsp,-16
call p_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

.section .bss
.balign 16
p_stack:.zero 1048576
p_stack_end:
p_saved_rsp:.zero 8
DATA_008804=p_root
DATA_008857=p_root+0xc0
DATA_008887=p_root+0x112
DATA_008877=p_watched
DATA_008872=p_root+0xea
DATA_008886=p_root+0x10e
DATA_008560=p_temporary
.section .note.GNU-stack,"",@progbits
