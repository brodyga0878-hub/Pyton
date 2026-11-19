.intel_syntax noprefix
.code64
.section .text
FUNC_000020:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],20
inc DWORD PTR [s_trace_count]
pop rcx
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
FUNC_000037:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],37
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,[rbp+16]
mov eax,[esi]
inc DWORD PTR [esi]
movzx eax,BYTE PTR [eax]
cmp eax,+0x42
ja JUMP_000353
mov al,[eax+DATA_000003]
mov r11d,DWORD PTR [rax*4+DATA_000004]
jmp r11
.section .rodata
DATA_000003:
.byte 0x0, 0x0, 0x0, 0x11, 0x10, 0xf, 0xe, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xd
.byte 0x0, 0x0, 0xc, 0xb, 0xa, 0x9, 0x0, 0x0
.byte 0x8, 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x0, 0x4, 0x3, 0x0
.byte 0x0, 0x2, 0x1
DATA_000004:
.long JUMP_000353
.long JUMP_000352
.long JUMP_000351
.long JUMP_000350
.long JUMP_000349
.long JUMP_000348
.long JUMP_000347
.long JUMP_000353
.long JUMP_000353
.long JUMP_000340
.long JUMP_000339
.long JUMP_000338
.long JUMP_000353
.long JUMP_000337
.long JUMP_000336
.long JUMP_000335
.long JUMP_000334
.long JUMP_000333
.section .text
JUMP_000333:
mov eax,[rbp+32]
push rax
push rsi
call FUNC_000020
pop rcx
push rax
call FUNC_000022
add rsp,16
jmp JUMP_000353
JUMP_000334:
push rsi
call FUNC_000020
pop rcx
mov ebx,eax
mov eax,[rbp+32]
push rax
push rbx
call FUNC_000034
add rsp,16
jmp JUMP_000353
JUMP_000335:
push rsi
call FUNC_000020
pop rcx
mov ebx,eax
mov eax,[rbp+24]
mov eax,[eax+0x1c]
mov eax,[eax+0x14]
mov edx,[rbp+32]
mov [eax+ebx*4],edx
push rbx
mov eax,[rbp+24]
mov eax,[eax+0x1c]
push rax
push +0x3
call FUNC_000048
add rsp,24
jmp JUMP_000353
JUMP_000336:
push rsi
call FUNC_000020
pop rcx
mov ebx,eax
mov eax,[rbp+24]
mov eax,[eax+0x20]
mov edx,[rbp+32]
mov [eax+ebx*4],edx
push rbx
mov eax,[rbp+24]
push rax
push +0x4
call FUNC_000048
add rsp,24
jmp JUMP_000353
JUMP_000337:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
test ebx,ebx
jl JUMP_000353
cmp ebx,+0x6
jnl JUMP_000353
mov eax,[rbp+32]
mov [ebx*4+DATA_009093],eax
push rbx
push +0x0
push +0x15
call FUNC_000048
add rsp,24
jmp JUMP_000353
JUMP_000338:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
test ebx,ebx
jl JUMP_000353
cmp ebx,+0x6
jnl JUMP_000353
mov eax,[rbp+32]
mov [ebx*4+DATA_009095],eax
push rbx
push +0x0
push +0xa
call FUNC_000048
add rsp,24
jmp JUMP_000353
JUMP_000339:
mov eax,[DATA_009133]
push rax
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov edi,eax
mov eax,[edi+0xa0]
push rax
mov eax,[rbp+32]
push rax
push rdi
call FUNC_000441
add rsp,24
jmp JUMP_000353
JUMP_000340:
mov eax,[DATA_009133]
push rax
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov edi,eax
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
cmp ebx,0x3e8
jnl JUMP_000344
sub ebx,+0x64
push rbx
push rdi
call FUNC_000392
add rsp,16
mov esi,[rbp+32]
sub esi,eax
test esi,esi
jng JUMP_000342
test esi,esi
jng JUMP_000353
JUMP_000341:
push rbx
push rdi
call FUNC_000390
add rsp,16
test eax,eax
jnz JUMP_000353
dec esi
test esi,esi
jg JUMP_000341
jmp JUMP_000353
JUMP_000342:
test esi,esi
jnl JUMP_000353
JUMP_000343:
push rbx
push rdi
call FUNC_000391
add rsp,16
test eax,eax
jnz JUMP_000353
inc esi
test esi,esi
jl JUMP_000343
jmp JUMP_000353
JUMP_000344:
sub ebx,0x3e8
cmp edi,[DATA_008861]
jnz JUMP_000353
cmp ebx,+0x26
jnl JUMP_000353
movzx eax,WORD PTR [ebx*2+DATA_008896]
mov esi,[rbp+32]
sub esi,eax
test esi,esi
jng JUMP_000345
mov edx,[DATA_008891]
mov ecx,edx
add ecx,esi
mov eax,[DATA_008889]
cmp ecx,eax
jng JUMP_000346
mov esi,eax
sub esi,edx
jmp JUMP_000346
JUMP_000345:
cmp DWORD PTR [rbp+32],+0x0
jnl JUMP_000346
mov esi,eax
neg esi
JUMP_000346:
add [DATA_008891],esi
add [ebx*2+DATA_008896],si
jmp JUMP_000353
JUMP_000347:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
test ebx,ebx
jl JUMP_000353
cmp ebx,+0x6
jnl JUMP_000353
mov eax,[rbp+32]
mov [ebx*4+DATA_008908],eax
push rbx
push +0x0
push +0x11
call FUNC_000048
add rsp,24
jmp JUMP_000353
JUMP_000348:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
mov eax,[DATA_009133]
push rax
push rbx
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov edx,[rbp+32]
mov [eax+0xa0],edx
jmp JUMP_000353
JUMP_000349:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
mov eax,[rbp+32]
push rax
mov eax,[DATA_009133]
push rax
push rbx
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
push rax
call FUNC_000036
add rsp,16
jmp JUMP_000353
JUMP_000350:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
mov eax,[DATA_009133]
push rax
push rbx
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov dl,[rbp+32]
mov [eax+0xff],dl
push rbx
push +0x0
push +0x17
call FUNC_000048
add rsp,24
jmp JUMP_000353
JUMP_000351:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
mov eax,[DATA_009133]
push rax
push rbx
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov dl,[rbp+32]
mov [eax+0xfe],dl
jmp JUMP_000353
JUMP_000352:
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
mov ebx,eax
mov eax,[rbp+24]
push rax
push rsi
call FUNC_000031
add rsp,16
add eax,0xfffffc18
mov esi,eax
push rbx
call FUNC_000649
pop rcx
test eax,eax
jz JUMP_000353
test esi,esi
jl JUMP_000353
cmp esi,+0x26
jnl JUMP_000353
mov edx,[rbp+32]
mov [eax+esi*8+0x4],edx
add esi,0x3e8
push rsi
push rbx
push +0x18
call FUNC_000048
add rsp,24
JUMP_000353:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_001532:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],1532
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
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
.section .text

.global call_kernel
call_kernel:
mov [s_saved_rsp],rsp
mov esp,OFFSET FLAT:s_stack_end
push rdi
push OFFSET FLAT:s_task
push OFFSET FLAT:s_ip
call FUNC_000037
xor eax,eax
mov rsp,[s_saved_rsp]
ret
s_abort:
mov edi,97
mov eax,60
syscall
FUNC_000022:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],22
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,22
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000031:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],31
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,31
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000034:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],34
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,34
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000036:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],36
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,36
and rsp,-16
call s_observe
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
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],48
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov edi,48
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000390:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],390
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,390
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000391:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],391
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,391
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000392:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],392
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
xor ecx,ecx
mov edi,392
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000441:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],441
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov edi,441
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000649:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
cmp ecx,1024
jae s_abort
mov DWORD PTR [s_trace+rcx*4],649
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
xor edx,edx
xor ecx,ecx
mov edi,649
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

.section .data
DATA_007754:.long FUNC_001532
DATA_008861=s_root+200
DATA_008889=s_root+280
DATA_008891=s_root+288
DATA_008896=s_root+308
DATA_008908=s_root+388
DATA_009093=s_root+20704
DATA_009095=s_root+20728
DATA_009133=s_root+22540
.section .bss
.balign 16
s_stack:.zero 2097152
s_stack_end:
s_saved_rsp:.zero 8
.section .note.GNU-stack,"",@progbits
