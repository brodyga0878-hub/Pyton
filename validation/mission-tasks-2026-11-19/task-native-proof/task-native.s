.intel_syntax noprefix
.code64
.section .text
FUNC_000038:
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
push r12
mov edi,38
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov eax,[rbp+16]
mov edx,eax
and edx,0xffff
mov ebx,edx
shl ebx,0x2
lea ebx,[ebx+ebx*8]
add ebx,OFFSET FLAT:DATA_008561
cmp eax,[ebx+0x4]
jnz JUMP_000356
cmp DWORD PTR [ebx+0x8],+0x0
jz JUMP_000354
push 45
push rbx
call FUNC_000033
add rsp,16
xor eax,eax
mov [ebx+0x8],eax
mov DWORD PTR [ebx+0xc],0xffffffff
JUMP_000354:
mov eax,[ebx+0x1c]
cmp DWORD PTR [eax+0xc],+0x0
jl JUMP_000355
mov DWORD PTR [ebx],0x5
pop rbx
pop rbp
ret
JUMP_000355:
inc WORD PTR [ebx+0x6]
mov DWORD PTR [ebx],0x6
JUMP_000356:
pop rbx
pop rbp
ret
FUNC_000047:
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
push r12
mov edi,47
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov ebx,[rbp+16]
cmp DWORD PTR [ebx],+0x1
jnz JUMP_000473
mov eax,[ebx+0x8]
mov edx,[rbp+24]
mov eax,[eax+edx*4+0x8]
call t_translate_eax

mov [rbp-0x4],eax
push rbx
lea eax,[rbp-0x4]
push rax
call FUNC_000031
add rsp,16
test eax,eax
jz JUMP_000473
mov DWORD PTR [ebx],0x2
push rbx
lea eax,[rbp-0x4]
push rax
call FUNC_000041
add rsp,16
cmp DWORD PTR [ebx],+0x2
jnz JUMP_000473
mov DWORD PTR [ebx],0x1
JUMP_000473:
pop rbx
pop rcx
pop rbp
ret
FUNC_000052:
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
push r12
mov edi,52
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov eax,[rbp+40]
push rax
mov eax,[rbp+32]
push rax
call FUNC_000051
add rsp,16
mov esi,eax
mov eax,[rbp+32]
mov eax,[eax*4+DATA_001697]
mov eax,[eax]
call t_translate_eax

mov [rbp-0x4],eax
xor ebx,ebx
mov eax,[rbp+32]
lea edi,[eax*4+DATA_001697]
jmp JUMP_000488
JUMP_000487:
mov eax,[rbp+24]
push rax
mov eax,[rbp+16]
push rax
call FUNC_000031
add rsp,16
push rax
push rsi
lea eax,[rbp-0x4]
push rax
call FUNC_000037
add rsp,24
inc ebx
JUMP_000488:
mov eax,[edi]
cmp ebx,[eax+0x8]
jl JUMP_000487
mov eax,[rbp+32]
mov eax,[eax*4+DATA_001697]
mov eax,[eax+0x1c]
call t_translate_eax

mov [esi+0x10],eax
xor eax,eax
mov [esi+0x14],eax
mov eax,[esi+0x4]
pop rdi
pop rsi
pop rbx
pop rcx
pop rbp
ret
FUNC_000053:
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
push r12
mov edi,53
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov ebx,[rbp+16]
lea edi,[rbp-0x4]
mov DWORD PTR [ebx],0x3
cmp DWORD PTR [ebx+0x8],+0x0
jz JUMP_000489
push 45
push rbx
call FUNC_000033
add rsp,16
xor eax,eax
mov [ebx+0x8],eax
mov DWORD PTR [ebx+0xc],0xffffffff
JUMP_000489:
mov eax,[ebx+0x10]
mov eax,[eax]
call t_translate_eax

mov [edi],eax
push rbx
push rdi
call FUNC_000041
add rsp,16
cmp DWORD PTR [ebx],+0x3
jnz JUMP_000493
xor esi,esi
jmp JUMP_000492
JUMP_000490:
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
push r12
mov edi,53000
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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

mov eax,[eax+esi*4+0x8]
call t_translate_eax

mov [edi],eax
push rbx
push rdi
call FUNC_000031
add rsp,16
test eax,eax
jz JUMP_000491
push rbx
push rdi
call FUNC_000041
add rsp,16
cmp DWORD PTR [ebx],+0x3
jnz JUMP_000493
xor esi,esi
JUMP_000491:
inc esi
JUMP_000492:
mov eax,[ebx+0x10]
cmp esi,[eax+0x4]
jl JUMP_000490
mov eax,[ebx+0x10]
mov [ebx+0x8],eax
mov eax,[ebx+0x14]
mov [ebx+0xc],eax
push 44
push rbx
call FUNC_000033
add rsp,16
mov DWORD PTR [ebx],0x1
JUMP_000493:
pop rdi
pop rsi
pop rbx
pop rcx
pop rbp
ret

.global call_kernel
call_kernel:
mov [t_saved_rsp],rsp
mov esp,OFFSET FLAT:t_stack_end
mov eax,DWORD PTR [t_operation]
test eax,eax
jz t_cancel
cmp eax,1
je t_callback
cmp eax,2
je t_create
mov eax,DWORD PTR [t_command]
imul eax,eax,36
add eax,OFFSET FLAT:t_arena+8
push rax
call FUNC_000053
jmp t_called
t_cancel:
mov eax,DWORD PTR [t_command]
push rax
call FUNC_000038
jmp t_called
t_callback:
mov eax,DWORD PTR [t_command+4]
push rax
mov eax,DWORD PTR [t_command]
imul eax,eax,36
add eax,OFFSET FLAT:t_arena+8
push rax
call FUNC_000047
jmp t_called
t_create:
mov eax,DWORD PTR [t_command+8]
push rax
mov eax,DWORD PTR [t_command+4]
push rax
mov eax,DWORD PTR [t_command]
cmp eax,0xffffffff
je t_null_task
imul eax,eax,36
add eax,OFFSET FLAT:t_arena+8
jmp t_task_ready
t_null_task:
xor eax,eax
t_task_ready:
push rax
xor eax,eax
cmp DWORD PTR [t_caller_ip],0
je t_null_cursor
mov eax,OFFSET FLAT:t_caller_ip
t_null_cursor:
push rax
call FUNC_000052
t_called:
mov rsp,[t_saved_rsp]
ret
t_translate_eax:
pushfq
push r11
cmp eax,DWORD PTR [t_base]
jb t_translate_done
mov r11d,DWORD PTR [t_base]
add r11d,DWORD PTR [t_length]
cmp eax,r11d
ja t_translate_done
sub eax,DWORD PTR [t_base]
add eax,DWORD PTR [t_program_ptr]
t_translate_done:
pop r11
popfq
ret

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
push r12
mov edi,31
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov DWORD PTR [t_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [t_args+4],eax
mov edi,31
and rsp,-16
call t_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000037:
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
push r12
mov edi,37
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov DWORD PTR [t_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [t_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [t_args+8],eax
mov edi,37
and rsp,-16
call t_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000041:
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
push r12
mov edi,41
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov DWORD PTR [t_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [t_args+4],eax
mov edi,41
and rsp,-16
call t_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000051:
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
push r12
mov edi,51
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov DWORD PTR [t_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [t_args+4],eax
mov edi,51
and rsp,-16
call t_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
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
push r12
mov edi,33
mov r12,rsp
and rsp,-16
call t_trace
mov rsp,r12
pop r12
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
mov DWORD PTR [t_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [t_args+4],eax
mov edi,33
and rsp,-16
call t_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

DATA_008561=t_arena+8
DATA_001697=t_module_table
.section .bss
.balign 16
t_stack: .zero 2097152
t_stack_end:
t_saved_rsp: .zero 8
.section .note.GNU-stack,"",@progbits
