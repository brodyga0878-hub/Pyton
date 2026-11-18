.intel_syntax noprefix
.code64
.section .text
FUNC_000042:
call trace_42
push rbp
mov rbp,rsp
push rbx
mov edx,[rbp+24]
mov eax,[rbp+16]
mov ecx,[eax]
mov ebx,[edx]
cmp ecx,ebx
jz JUMP_000451
sub ecx,ebx
mov eax,ecx
pop rbx
pop rbp
ret
JUMP_000451:
mov ecx,[eax+0x4]
mov ebx,[edx+0x4]
cmp ecx,ebx
jz JUMP_000452
sub ecx,ebx
mov eax,ecx
pop rbx
pop rbp
ret
JUMP_000452:
mov ecx,[eax+0x8]
mov ebx,[edx+0x8]
cmp ecx,ebx
jz JUMP_000453
sub ecx,ebx
mov eax,ecx
pop rbx
pop rbp
ret
JUMP_000453:
mov ecx,[eax+0x10]
mov ebx,[edx+0x10]
cmp ecx,ebx
jz JUMP_000454
sub ecx,ebx
mov eax,ecx
pop rbx
pop rbp
ret
JUMP_000454:
mov ecx,[eax+0x14]
mov ebx,[edx+0x14]
cmp ecx,ebx
jz JUMP_000455
sub ecx,ebx
mov eax,ecx
pop rbx
pop rbp
ret
JUMP_000455:
mov eax,[eax+0xc]
sub eax,[edx+0xc]
pop rbx
pop rbp
ret
FUNC_000043:
call trace_43
push rbp
mov rbp,rsp
push rbx
mov edx,[rbp+24]
mov eax,[rbp+16]
mov ecx,[eax]
mov ebx,[edx]
cmp ecx,ebx
jz JUMP_000456
sub ecx,ebx
mov eax,ecx
pop rbx
pop rbp
ret
JUMP_000456:
mov ecx,[eax+0x4]
mov ebx,[edx+0x4]
cmp ecx,ebx
jz JUMP_000457
sub ecx,ebx
mov eax,ecx
pop rbx
pop rbp
ret
JUMP_000457:
mov eax,[eax+0x8]
sub eax,[edx+0x8]
pop rbx
pop rbp
ret
FUNC_000044:
call trace_44
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push +0x20
call bridge_alloc_node
pop rcx
mov esi,eax
xor eax,eax
mov [esi],eax
xor eax,eax
mov [esi+0x4],eax
mov eax,[rbp+16]
mov [esi+0x8],eax
mov eax,[rbp+24]
mov [esi+0xc],eax
mov eax,[rbp+32]
mov [esi+0x10],eax
mov eax,[rbp+40]
mov [esi+0x14],eax
mov eax,[rbp+48]
mov [esi+0x18],eax
mov eax,[rbp+56]
mov [esi+0x1c],eax
mov ebx,OFFSET FLAT:DATA_008564
jmp JUMP_000460
JUMP_000458:
add edi,+0x8
push rdi
lea eax,[esi+0x8]
push rax
call FUNC_000042
add rsp,16
test eax,eax
jnl JUMP_000459
mov ebx,[ebx]
jmp JUMP_000460
JUMP_000459:
mov eax,[ebx]
add eax,+0x4
mov ebx,eax
JUMP_000460:
mov edi,[ebx]
test edi,edi
jnz JUMP_000458
mov [ebx],esi
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000045:
call trace_45
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
mov eax,[rbp+16]
mov [rbp-0x18],eax
mov eax,[rbp+24]
mov [rbp-0x14],eax
mov eax,[rbp+32]
mov [rbp-0x10],eax
mov eax,[rbp+40]
mov [rbp-0xc],eax
mov eax,[rbp+48]
mov [rbp-0x8],eax
mov eax,[rbp+56]
mov [rbp-0x4],eax
mov ebx,OFFSET FLAT:DATA_008564
jmp JUMP_000463
JUMP_000461:
add eax,+0x8
push rax
lea eax,[rbp-0x18]
push rax
call FUNC_000042
add rsp,16
test eax,eax
jnl JUMP_000462
mov ebx,[ebx]
jmp JUMP_000463
JUMP_000462:
test eax,eax
jng JUMP_000464
mov eax,[ebx]
add eax,+0x4
mov ebx,eax
JUMP_000463:
mov eax,[ebx]
test eax,eax
jnz JUMP_000461
JUMP_000464:
mov eax,[ebx]
test eax,eax
jz JUMP_000470
mov edx,[eax+0x4]
test edx,edx
jz JUMP_000468
cmp DWORD PTR [eax],+0x0
jnz JUMP_000465
mov esi,edx
push rax
call bridge_free
pop rcx
mov [ebx],esi
jmp JUMP_000470
JUMP_000465:
mov eax,[ebx]
jmp JUMP_000467
JUMP_000466:
add edx,+0x4
mov eax,edx
JUMP_000467:
mov edx,[eax]
cmp DWORD PTR [edx+0x4],+0x0
jnz JUMP_000466
mov edx,[eax]
mov esi,edx
mov edx,[edx]
mov [eax],edx
mov eax,[ebx]
mov eax,[eax]
mov [esi],eax
mov eax,[ebx]
mov eax,[eax+0x4]
mov [esi+0x4],eax
mov eax,[ebx]
push rax
call bridge_free
pop rcx
mov [ebx],esi
jmp JUMP_000470
JUMP_000468:
mov edx,[ebx]
mov eax,[edx]
test eax,eax
jz JUMP_000469
mov esi,eax
push rdx
call bridge_free
pop rcx
mov [ebx],esi
jmp JUMP_000470
JUMP_000469:
mov eax,[ebx]
push rax
call bridge_free
pop rcx
xor eax,eax
mov [ebx],eax
JUMP_000470:
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000046:
call trace_46
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov ebx,[rbp+16]
test esi,esi
jz JUMP_000472
mov eax,[rbp+32]
push rax
mov eax,[esi]
push rax
push rbx
call FUNC_000046
add rsp,24
mov eax,[rbp+32]
push rax
lea eax,[esi+0x8]
push rax
call FUNC_000043
add rsp,16
test eax,eax
jnz JUMP_000471
push +0x10
call bridge_alloc_snapshot
pop rcx
mov edi,eax
mov eax,[ebx]
mov [eax],edi
xor eax,eax
mov [edi],eax
mov eax,[esi+0x14]
mov [edi+0x4],eax
mov eax,[esi+0x18]
mov [edi+0x8],eax
mov eax,[esi+0x1c]
mov [edi+0xc],eax
mov [ebx],edi
JUMP_000471:
mov eax,[rbp+32]
push rax
mov eax,[esi+0x4]
push rax
push rbx
call FUNC_000046
add rsp,24
JUMP_000472:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000048:
call trace_48
push rbp
mov rbp,rsp
add rsp,-32
push rbx
push rsi
lea esi,[rbp-0x4]
mov eax,[rbp+16]
mov [rbp-0x20],eax
mov eax,[rbp+24]
mov [rbp-0x1c],eax
mov eax,[rbp+32]
mov [rbp-0x18],eax
mov ebx,OFFSET FLAT:DATA_008564
jmp JUMP_000476
JUMP_000474:
add eax,+0x8
push rax
lea eax,[rbp-0x20]
push rax
call FUNC_000043
add rsp,16
test eax,eax
jnl JUMP_000475
mov ebx,[ebx]
jmp JUMP_000476
JUMP_000475:
test eax,eax
jng JUMP_000477
mov eax,[ebx]
add eax,+0x4
mov ebx,eax
JUMP_000476:
mov eax,[ebx]
test eax,eax
jnz JUMP_000474
JUMP_000477:
cmp DWORD PTR [ebx],+0x0
jz JUMP_000482
xor eax,eax
mov [esi],eax
mov [rbp-0x8],esi
lea eax,[rbp-0x20]
push rax
mov eax,[ebx]
push rax
lea eax,[rbp-0x8]
push rax
call FUNC_000046
add rsp,24
mov ebx,[esi]
test ebx,ebx
jz JUMP_000479
JUMP_000478:
mov eax,[ebx+0xc]
push rax
mov eax,[ebx+0x8]
push rax
mov r11d,DWORD PTR [rbx+0x4]
call bridge_event_callback
add rsp,16
mov ebx,[ebx]
test ebx,ebx
jnz JUMP_000478
JUMP_000479:
cmp DWORD PTR [esi],+0x0
jz JUMP_000481
JUMP_000480:
mov ebx,[esi]
mov eax,[esi]
mov eax,[eax]
mov [esi],eax
push rbx
call bridge_free
pop rcx
cmp DWORD PTR [esi],+0x0
jnz JUMP_000480
JUMP_000481:
call FUNC_000054
JUMP_000482:
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000049:
call trace_49
push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
test ebx,ebx
jz JUMP_000483
mov eax,[ebx]
push rax
call FUNC_000049
pop rcx
mov eax,[ebx+0x4]
push rax
call FUNC_000049
pop rcx
push rbx
call bridge_free
pop rcx
JUMP_000483:
pop rbx
pop rbp
ret
FUNC_000050:
call trace_50
push rbp
mov rbp,rsp
mov eax,[DATA_008564]
push rax
call FUNC_000049
pop rcx
xor eax,eax
mov [DATA_008564],eax
pop rbp
ret
FUNC_000051:
call trace_51
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov eax,[rbp+16]
xor esi,esi
lea edi,[eax*4+DATA_001697]
mov ebx,OFFSET FLAT:DATA_008561
JUMP_000484:
cmp DWORD PTR [ebx],+0x0
jnz JUMP_000485
mov DWORD PTR [ebx],0x4
mov [ebx+0x4],si
inc WORD PTR [ebx+0x6]
xor edx,edx
mov [ebx+0x8],edx
mov DWORD PTR [ebx+0xc],0xffffffff
xor edx,edx
mov [ebx+0x10],edx
mov DWORD PTR [ebx+0x14],0xffffffff
mov [ebx+0x18],eax
mov eax,[edi]
mov [ebx+0x1c],eax
mov eax,[edi]
mov eax,[eax+0x10]
shl eax,0x2
push rax
call bridge_alloc_variables
pop rcx
mov [ebx+0x20],eax
mov eax,[ebx+0x20]
mov edx,[ebx+0x4]
mov [eax],edx
mov eax,[ebx+0x20]
mov edx,[rbp+24]
mov [eax+0x4],edx
mov eax,esi
shl eax,0x2
lea eax,[eax+eax*8]
add eax,OFFSET FLAT:DATA_008561
jmp JUMP_000486
JUMP_000485:
inc esi
add ebx,+0x24
cmp esi,0x96
jl JUMP_000484
xor eax,eax
JUMP_000486:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000054:
call trace_54
push rbp
mov rbp,rsp
push rcx
push rbx
push rsi
JUMP_000494:
call scheduler_guard
xor ecx,ecx
xor edx,edx
mov eax,OFFSET FLAT:DATA_008561
JUMP_000495:
mov ebx,[eax]
cmp ecx,ebx
jnl JUMP_000496
mov ecx,ebx
mov esi,edx
JUMP_000496:
inc edx
add eax,+0x24
cmp edx,0x96
jl JUMP_000495
cmp ecx,+0x3
jng JUMP_000500
sub ecx,+0x4
jz JUMP_000497
dec ecx
jz JUMP_000498
dec ecx
jz JUMP_000499
jmp JUMP_000494
JUMP_000497:
mov eax,esi
shl eax,0x2
lea eax,[eax+eax*8]
add eax,OFFSET FLAT:DATA_008561
push rax
call FUNC_000053
pop rcx
jmp JUMP_000494
JUMP_000498:
lea eax,[esi+esi*8]
mov DWORD PTR [eax*4+DATA_008561],0x6
mov eax,[eax*4+DATA_008562]
mov edx,[eax*4+DATA_001697]
mov ecx,[edx+0xc]
mov eax,[edx+ecx*4+0x1c]
mov eax,[eax]
mov [rbp-0x4],eax
mov eax,esi
shl eax,0x2
lea eax,[eax+eax*8]
add eax,OFFSET FLAT:DATA_008561
push rax
lea eax,[rbp-0x4]
push rax
call FUNC_000041
add rsp,16
jmp JUMP_000494
JUMP_000499:
lea ebx,[esi+esi*8]
mov eax,[ebx*4+DATA_008563]
push rax
call bridge_free
pop rcx
xor eax,eax
mov [ebx*4+DATA_008561],eax
jmp JUMP_000494
JUMP_000500:
pop rsi
pop rbx
pop rcx
pop rbp
ret
FUNC_000055:
call trace_55
push rbp
mov rbp,rsp
xor eax,eax
mov [DATA_008557],eax
mov [DATA_008556],eax
mov [DATA_008555],eax
mov [DATA_008554],eax
mov [DATA_008553],eax
mov [DATA_008552],eax
mov [DATA_008551],eax
mov [DATA_008550],eax
push +0x0
push +0x0
push +0x0
push +0x0
call FUNC_000052
add rsp,32
call FUNC_000054
pop rbp
ret
FUNC_000056:
call trace_56
push rbp
mov rbp,rsp
push rbx
push rsi
xor esi,esi
mov ebx,OFFSET FLAT:DATA_008561
JUMP_000501:
cmp DWORD PTR [ebx],+0x0
jng JUMP_000502
mov eax,[ebx+0x20]
push rax
call bridge_free
pop rcx
xor eax,eax
mov [ebx],eax
JUMP_000502:
inc esi
add ebx,+0x24
cmp esi,0x96
jl JUMP_000501
call FUNC_000050
pop rsi
pop rbx
pop rbp
ret
.section .text
.global run_low
run_low:
push rbx
push rbp
push r12
push r13
push r14
push r15
mov r12,rsp
mov rsp,OFFSET FLAT:low_stack_end
and rsp,-16
call c_run_case
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rbp
pop rbx
ret
.global invoke_original
invoke_original:
push rbx
mov r11,rdi
mov ebx,esi
shl ebx,3
mov ecx,esi
test ecx,ecx
jz invoke_go
invoke_push:
dec ecx
mov eax,DWORD PTR [rdx+rcx*4]
push rax
test ecx,ecx
jnz invoke_push
invoke_go:
call r11
add rsp,rbx
pop rbx
ret
trace_42:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,42
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_43:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,43
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_44:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,44
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_45:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,45
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_46:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,46
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_48:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,48
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_49:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,49
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_50:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,50
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_51:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,51
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_54:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,54
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_55:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,55
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
trace_56:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
mov edi,56
call c_trace
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
scheduler_guard:
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
mov r15,rsp
and rsp,-16
call c_scheduler_guard
mov rsp,r15
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rbp
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
ret
bridge_alloc_node:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,DWORD PTR [rbp+16]
and rsp,-16
call c_alloc_node
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
bridge_alloc_snapshot:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,DWORD PTR [rbp+16]
and rsp,-16
call c_alloc_snapshot
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
bridge_alloc_variables:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,DWORD PTR [rbp+16]
and rsp,-16
call c_alloc_variables
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
bridge_free:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,DWORD PTR [rbp+16]
and rsp,-16
call c_free
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
bridge_event_callback:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,r11d
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
and rsp,-16
call c_event_callback
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000053:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,DWORD PTR [rbp+16]
and rsp,-16
call c_f53
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000041:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,DWORD PTR [rbp+16]
mov esi,DWORD PTR [rbp+24]
and rsp,-16
call c_f41
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000052:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
push r13
push r14
push r15
mov r12,rsp
mov edi,DWORD PTR [rbp+16]
mov esi,DWORD PTR [rbp+24]
mov edx,DWORD PTR [rbp+32]
mov ecx,DWORD PTR [rbp+40]
and rsp,-16
call c_f52
mov rsp,r12
pop r15
pop r14
pop r13
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
.global FUNC_000042
.global FUNC_000043
.global FUNC_000044
.global FUNC_000045
.global FUNC_000046
.global FUNC_000048
.global FUNC_000049
.global FUNC_000050
.global FUNC_000051
.global FUNC_000054
.global FUNC_000055
.global FUNC_000056
s_root=g_root+8
s_bank=g_bank+8
s_events=g_events+8
s_arena=g_arena+8
s_scratch_words=g_scratch+8
DATA_008564=s_registry_root
DATA_008561=s_arena
DATA_008562=s_arena+0x18
DATA_008563=s_arena+0x20
DATA_001697=s_module_table
DATA_008550=s_scratch_words+0
DATA_008551=s_scratch_words+4
DATA_008552=s_scratch_words+8
DATA_008553=s_scratch_words+12
DATA_008554=s_scratch_words+16
DATA_008555=s_scratch_words+20
DATA_008556=s_scratch_words+24
DATA_008557=s_scratch_words+28
.section .bss
.balign 16
low_stack: .zero 2097152
low_stack_end:
.section .note.GNU-stack,"",@progbits
