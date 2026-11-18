.intel_syntax noprefix
.code64
.section .text
FUNC_000020:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],20
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
mov edx,[rbp+16]
mov eax,[edx]
xor ecx,ecx
mov cl,[eax]
xor ebx,ebx
mov bl,[eax+0x1]
shl ebx,0x8
add ecx,ebx
xor ebx,ebx
mov bl,[eax+0x2]
shl ebx,0x10
add ecx,ebx
xor ebx,ebx
mov bl,[eax+0x3]
shl ebx,0x18
add ecx,ebx
add eax,+0x4
mov [edx],eax
mov eax,ecx
pop rbx
pop rbp
ret
FUNC_000032:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [rsp+96]
mov DWORD PTR [g_current_ip],eax
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],32
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+16]
mov eax,[esi]
inc DWORD PTR [esi]
mov bl,[eax]
xor eax,eax
mov al,bl
shl eax,0x4
cmp DWORD PTR [eax+DATA_001702],+0x0
jng JUMP_000319
mov edi,[esi]
mov eax,[eax+DATA_001703]
sub eax,+0x1
jc JUMP_000310
jz JUMP_000311
dec eax
jz JUMP_000312
dec eax
jz JUMP_000313
jmp JUMP_000314
JUMP_000310:
xor eax,eax
mov [rbp-0x4],eax
jmp JUMP_000314
JUMP_000311:
mov eax,[rbp+24]
mov eax,[eax+0x1c]
mov [rbp-0x4],eax
jmp JUMP_000314
JUMP_000312:
mov eax,[rbp+24]
mov [rbp-0x4],eax
jmp JUMP_000314
JUMP_000313:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov [rbp-0x4],eax
JUMP_000314:
xor eax,eax
mov al,bl
shl eax,0x4
mov eax,[eax+DATA_001704]
sub eax,+0x1
jc JUMP_000315
jz JUMP_000316
dec eax
jz JUMP_000317
jmp JUMP_000318
JUMP_000315:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000318
JUMP_000316:
push rsi
call FUNC_000020
pop rcx
mov [rbp-0x8],eax
jmp JUMP_000318
JUMP_000317:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov [rbp-0x8],eax
JUMP_000318:
mov eax,[rbp+40]
push rax
mov eax,[rbp+24]
push rax
push 0x413ff4
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
push rax
xor eax,eax
mov al,bl
shl eax,0x4
mov eax,[eax+DATA_001702]
push rax
call QWORD PTR [rbp+32]
add rsp,48
mov [esi],edi
JUMP_000319:
xor eax,eax
mov al,bl
shl eax,0x4
cmp DWORD PTR [eax+DATA_001701],+0x0
jng JUMP_000322
xor edi,edi
xor eax,eax
mov al,bl
add eax,eax
lea eax,[eax*8+DATA_001701]
mov ebx,eax
jmp JUMP_000321
JUMP_000320:
mov eax,[rbp+40]
push rax
mov eax,[rbp+32]
push rax
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000032
add rsp,32
inc edi
JUMP_000321:
cmp edi,[ebx]
jl JUMP_000320
jmp JUMP_000323
JUMP_000322:
add DWORD PTR [esi],+0x4
JUMP_000323:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_000033:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],33
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
push rcx
push rbx
push rsi
push rdi
mov edi,[rbp+24]
mov esi,[rbp+16]
xor ebx,ebx
jmp JUMP_000325
JUMP_000324:
mov eax,[eax+ebx*4+0x8]
pushfq
sub eax,DWORD PTR [g_source_base]
add eax,DWORD PTR [g_program_pointer]
popfq
mov [rbp-0x4],eax
push rbx
push rdi
push rsi
lea eax,[rbp-0x4]
push rax
call FUNC_000032
add rsp,32
inc ebx
JUMP_000325:
mov eax,[esi+0x8]
cmp ebx,[eax+0x4]
jl JUMP_000324
pop rdi
pop rsi
pop rbx
pop rcx
pop rbp
ret
FUNC_000034:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],34
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,[rbp+24]
mov [eax*4+DATA_008548],edx
push rax
push +0x0
push +0x2
call FUNC_000048
add rsp,24
pop rbp
ret
FUNC_000035:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],35
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov eax,[eax*4+DATA_008548]
pop rbp
ret

.global call_kernel
call_kernel:
mov [g_saved_rsp],rsp
mov esp,OFFSET FLAT:g_stack_end
mov eax,DWORD PTR [g_operation]
cmp eax,3
je g_read
cmp eax,2
je g_write
mov eax,OFFSET FLAT:FUNC_000044
cmp DWORD PTR [g_registration],0
je g_registration_ready
mov eax,OFFSET FLAT:FUNC_000045
g_registration_ready:
cmp DWORD PTR [g_operation],0
jne g_block
mov ecx,DWORD PTR [g_clause]
push rcx
push rax
push OFFSET FLAT:g_task+8
push OFFSET FLAT:g_entry_ip
call FUNC_000032
jmp g_called
g_block:
push rax
push OFFSET FLAT:g_task+8
call FUNC_000033
jmp g_called
g_write:
mov eax,DWORD PTR [g_value]
push rax
mov eax,DWORD PTR [g_index]
push rax
call FUNC_000034
jmp g_called
g_read:
mov eax,DWORD PTR [g_index]
push rax
call FUNC_000035
g_called:
mov rsp,[g_saved_rsp]
ret
g_abort:
mov edi,97
mov eax,60
syscall

FUNC_000031:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],31
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [g_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [g_args+4],eax
mov edi,31
and rsp,-16
call g_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000044:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],44
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [g_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [g_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [g_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [g_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [g_args+16],eax
mov eax,DWORD PTR [rbp+56]
mov DWORD PTR [g_args+20],eax
movzx eax,bl
shl eax,4
mov eax,DWORD PTR [eax+DATA_001703]
mov DWORD PTR [g_key_a_kind],eax
mov edi,44
and rsp,-16
call g_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000045:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],45
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [g_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [g_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [g_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [g_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [g_args+16],eax
mov eax,DWORD PTR [rbp+56]
mov DWORD PTR [g_args+20],eax
movzx eax,bl
shl eax,4
mov eax,DWORD PTR [eax+DATA_001703]
mov DWORD PTR [g_key_a_kind],eax
mov edi,45
and rsp,-16
call g_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000048:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov eax,DWORD PTR [g_trace_count]
cmp eax,8192
jae g_abort
mov DWORD PTR [g_trace+rax*4],48
inc DWORD PTR [g_trace_count]
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [g_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [g_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [g_args+8],eax
mov edi,48
and rsp,-16
call g_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

DATA_008548=g_events+8
DATA_001701=g_metadata+8
DATA_001702=g_metadata+12
DATA_001703=g_metadata+16
DATA_001704=g_metadata+20

.section .bss
.balign 16
g_stack: .zero 2097152
g_stack_end:
g_saved_rsp: .zero 8
.section .note.GNU-stack,"",@progbits
