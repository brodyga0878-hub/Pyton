.intel_syntax noprefix
.code64
.section .text
FUNC_000349:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [m_order_count]
cmp ecx,512
jae m_abort
mov DWORD PTR [m_order+rcx*4],349
inc DWORD PTR [m_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
cmp BYTE PTR [DATA_008870],0x4
jz JUMP_001985
call QWORD PTR [DATA_004920]
JUMP_001985:
mov eax,[rbp+16]
push rax
call FUNC_000351
pop rcx
pop rbp
ret
FUNC_000350:
pushfq
push rax
mov eax,DWORD PTR [rsp+24]
mov eax,DWORD PTR [rax+24]
shr eax,31
mov DWORD PTR [m_actor_mode],eax
mov eax,DWORD PTR [rsp+24]
mov eax,DWORD PTR [rax+24]
or DWORD PTR [m_actor_mode],eax
and DWORD PTR [m_actor_mode],0x80000001
pop rax
popfq
pushfq
push rax
push rcx
mov ecx,DWORD PTR [m_order_count]
cmp ecx,512
jae m_abort
mov DWORD PTR [m_order+rcx*4],350
inc DWORD PTR [m_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
add rsp,-2068
push rbx
push rsi
mov eax,[rbp+16]
lea esi,[rbp-0x814]
mov edx,[eax+0x8]
mov [esi+0x4],edx
mov edx,[eax+0xc]
mov [esi+0x8],edx
mov edx,[eax+0x18]
test edx,edx
jl JUMP_001989
test dl,0x1
jnz JUMP_001988
mov edx,[eax]
mov [esi],edx
mov edx,[eax+0x2c]
mov [esi+0xc],edx
mov edx,[eax+0x1c]
test edx,edx
jnz JUMP_001986
mov eax,OFFSET FLAT:DATA_009148
mov [esi+0x10],eax
jmp JUMP_001987
JUMP_001986:
add edx,0x124
mov [esi+0x10],edx
JUMP_001987:
mov eax,0x9917
mov bl,0x5f
jmp JUMP_001990
JUMP_001988:
mov edx,[eax+0x4]
mov [esi],edx
mov edx,[eax+0x24]
mov [esi+0xc],edx
mov edx,[eax+0x2c]
mov [esi+0x10],edx
mov eax,[eax]
mov bl,0x5f
jmp JUMP_001990
JUMP_001989:
mov edx,[eax+0x4]
mov [esi],edx
mov edx,[eax+0x8]
mov [esi+0x4],edx
mov edx,[eax+0xc]
mov [esi+0x8],edx
mov edx,[eax+0x24]
mov [esi+0xc],edx
mov edx,[eax+0x2c]
mov [esi+0x10],edx
mov eax,[eax]
mov bl,0x11
JUMP_001990:
push rsi
push rax
lea eax,[rbp-0x800]
push rax
call QWORD PTR [DATA_007639]
add rsp,24
xor eax,eax
cmp DWORD PTR [rbp+24],+0x0
jnz JUMP_001991
inc eax
JUMP_001991:
push rax
push rbx
lea eax,[rbp-0x800]
push rax
call FUNC_000271
add rsp,24
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000351:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [m_order_count]
cmp ecx,512
jae m_abort
mov DWORD PTR [m_order+rcx*4],351
inc DWORD PTR [m_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
cmp BYTE PTR [DATA_008870],0x2c
jz JUMP_001993
cmp DWORD PTR [ebx+0x18],+0x0
jl JUMP_001992
push +0x16
call FUNC_001906
pop rcx
JUMP_001992:
push +0x1
push rbx
call FUNC_000350
add rsp,16
JUMP_001993:
pop rbx
pop rbp
ret
FUNC_000352:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [m_order_count]
cmp ecx,512
jae m_abort
mov DWORD PTR [m_order+rcx*4],352
inc DWORD PTR [m_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
add rsp,-48
push rsi
push rdi
mov eax,[rbp+16]
mov esi,eax
lea edi,[rbp-0x30]
mov ecx,0xc
rep movsd
mov DWORD PTR [rbp-0x18],0xffffffff
push +0x0
lea eax,[rbp-0x30]
push rax
call FUNC_000350
add rsp,16
pop rdi
pop rsi
mov rsp,rbp
pop rbp
ret
FUNC_000271:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [m_order_count]
cmp ecx,512
jae m_abort
mov DWORD PTR [m_order+rcx*4],271
inc DWORD PTR [m_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
add rsp,-1024
push rbx
push rsi
push rdi
mov esi,[rbp+16]
test esi,esi
jz JUMP_001597
xor ebx,ebx
push rsi
mov edi,esi
lea esi,[rbp-0x400]
xor eax,eax
or ecx,-0x1
repne scasb
not ecx
sub edi,ecx
xchg esi,edi
mov eax,edi
mov edx,ecx
shr ecx,0x2
rep movsd
mov ecx,edx
and ecx,+0x3
rep movsb
pop rsi
push +0x78
lea eax,[rbp-0x400]
push rax
call QWORD PTR [DATA_007643]
add rsp,16
lea eax,[rbp-0x400]
jmp JUMP_001591
JUMP_001589:
cmp dl,0xd
jnz JUMP_001590
inc ebx
JUMP_001590:
inc eax
JUMP_001591:
mov dl,[eax]
test dl,dl
jnz JUMP_001589
mov eax,[DATA_005099]
mov edx,eax
shl eax,0x6
add eax,edx
shl eax,0x3
sub eax,edx
add eax,eax
add eax,OFFSET FLAT:DATA_008681
push rsi
mov edi,esi
mov esi,eax
xor eax,eax
or ecx,-0x1
repne scasb
not ecx
sub edi,ecx
xchg esi,edi
mov eax,edi
mov edx,ecx
shr ecx,0x2
rep movsd
mov ecx,edx
and ecx,+0x3
rep movsb
pop rsi
mov ecx,[DATA_005099]
mov eax,ecx
shl ecx,0x6
add ecx,eax
shl ecx,0x3
sub ecx,eax
mov eax,[rbp+32]
mov [ecx*2+DATA_008682],eax
mov al,[rbp+24]
mov [ecx*2+DATA_008680],al
mov eax,[DATA_008807]
mov [ecx*2+DATA_008678],eax
mov eax,[DATA_008804]
mov [ecx*2+DATA_008679],eax
mov edi,[DATA_005099]
mov esi,edi
mov [DATA_005098],esi
mov eax,esi
inc eax
mov esi,0xa
cdq
idiv esi
mov [DATA_005097],edx
test BYTE PTR [ecx*2+DATA_008682],0x1
jnz JUMP_001592
mov eax,edi
inc eax
mov ecx,0xa
cdq
idiv ecx
mov [DATA_005099],edx
mov DWORD PTR [DATA_005094],0xffffffff
jmp JUMP_001593
JUMP_001592:
mov [DATA_005094],ebx
JUMP_001593:
mov eax,ebx
shl eax,0x3
add eax,-0x18
sub eax,[DATA_005096]
test eax,eax
jng JUMP_001594
mov eax,ebx
shl eax,0x3
add eax,-0x18
sub eax,[DATA_005096]
jmp JUMP_001595
JUMP_001594:
mov eax,ebx
shl eax,0x3
add eax,-0x18
sub eax,[DATA_005096]
neg eax
JUMP_001595:
mov [DATA_005092],eax
or eax,-0x1
shl ebx,0x3
add ebx,-0x18
cmp ebx,[DATA_005096]
jl JUMP_001596
add eax,+0x2
JUMP_001596:
mov [DATA_008677],eax
mov eax,[DATA_008799]
mov [DATA_005093],eax
jmp JUMP_001599
JUMP_001597:
mov ecx,[DATA_005099]
mov eax,ecx
shl ecx,0x6
add ecx,eax
shl ecx,0x3
sub ecx,eax
test BYTE PTR [ecx*2+DATA_008682],0x1
jz JUMP_001599
dec DWORD PTR [DATA_005098]
cmp DWORD PTR [DATA_005098],-0x1
jnz JUMP_001598
mov DWORD PTR [DATA_005098],0x9
JUMP_001598:
mov eax,[DATA_005098]
inc eax
mov ebx,0xa
cdq
idiv ebx
mov [DATA_005097],edx
xor eax,eax
mov [ecx*2+DATA_008682],eax
mov BYTE PTR [ecx*2+DATA_008681],0x0
mov DWORD PTR [DATA_005094],0xffffffff
JUMP_001599:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
.global call_kernel
call_kernel:
mov [m_saved_rsp],rsp
mov esp,OFFSET FLAT:m_stack_end
cmp edi,4
je m_direct_queue
cmp edi,1
je m_direct_format
push OFFSET FLAT:m_packet
cmp edi,2
je m_notify
cmp edi,3
je m_immediate
call FUNC_000349
jmp m_leave
m_notify:call FUNC_000351
jmp m_leave
m_immediate:call FUNC_000352
jmp m_leave
m_direct_format:
push rsi
push OFFSET FLAT:m_packet
call FUNC_000350
jmp m_leave
m_direct_queue:
push 0
push 0
xor eax,eax
test edx,edx
jz m_text_ready
mov eax,OFFSET FLAT:m_text
m_text_ready:push rax
call FUNC_000271
m_leave:mov rsp,[m_saved_rsp]
ret
m_abort:mov edi,97
mov eax,60
syscall

FUNC_000217:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
mov edi,217
and rsp,-16
call m_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001906:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
mov esi,DWORD PTR [rbp+16]
mov edi,1906
and rsp,-16
call m_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001344:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov edi,1344
and rsp,-16
call m_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001398:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov edi,1398
and rsp,-16
call m_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

.section .data
DATA_004920:.quad FUNC_000217
DATA_007639:.quad FUNC_001344
DATA_007643:.quad FUNC_001398
m_root=m_store+8
m_bank=m_store+16392
m_packet=m_store+55378
m_queue_records=m_store+55426
m_queue_control=m_store+65806
m_fallback_name=m_store+65842
DATA_008804=m_root
DATA_008807=m_root+4
DATA_008870=m_root+0xe8
DATA_009148=m_fallback_name
DATA_008678=m_queue_records
DATA_008679=m_queue_records+4
DATA_008680=m_queue_records+8
DATA_008681=m_queue_records+9
DATA_008682=m_queue_records+1034
DATA_005092=m_queue_control
DATA_005093=m_queue_control+4
DATA_005094=m_queue_control+8
DATA_005096=m_queue_control+12
DATA_005097=m_queue_control+16
DATA_005098=m_queue_control+20
DATA_005099=m_queue_control+24
DATA_008677=m_queue_control+28
DATA_008799=m_queue_control+32
.section .bss
.balign 16
m_stack:.zero 1048576
m_stack_end:
m_saved_rsp:.zero 8
.section .note.GNU-stack,"",@progbits
