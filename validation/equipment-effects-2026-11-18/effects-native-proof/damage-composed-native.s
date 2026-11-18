.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000034:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],34
inc DWORD PTR [s_order_count]
pop rcx
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
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],35
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov eax,[eax*4+DATA_008548]
pop rbp
ret
FUNC_000144:
pushfq
push rax
mov eax,DWORD PTR [rsp+24]
mov DWORD PTR [s_current_module],eax
mov eax,DWORD PTR [rsp+32]
mov DWORD PTR [s_current_event],eax
pop rax
popfq
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],144
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov eax,[eax*4+DATA_004892]
mov edx,[rbp+24]
mov eax,[eax+edx*4]
test eax,eax
jz JUMP_001170
mov edx,[rbp+32]
push rdx
call rax
pop rcx
JUMP_001170:
pop rbp
ret
FUNC_000148:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],148
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
mov eax,[rbp+16]
mov [rbp-0x8],eax
mov eax,[rbp+24]
mov [rbp-0x4],eax
xor ebx,ebx
mov esi,OFFSET FLAT:DATA_008623
JUMP_001177:
test BYTE PTR [esi],0x2
jz JUMP_001178
lea eax,[rbp-0x8]
push rax
push +0x2
push rbx
call FUNC_000144
add rsp,24
JUMP_001178:
inc ebx
add esi,+0x8
cmp ebx,+0x15
jl JUMP_001177
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_000922:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],922
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[DATA_008818]
mov edx,[DATA_008820]
add eax,edx
mov ecx,edx
shr ecx,0x1b
shl edx,0x5
or ecx,edx
mov edx,ecx
add eax,edx
mov ecx,eax
shl ecx,0x10
shr eax,0x10
or ecx,eax
mov eax,ecx
mov [DATA_008818],eax
mov [DATA_008820],edx
and eax,0xffff
mov edx,[rbp+16]
imul edx,eax
mov eax,edx
shr eax,0x10
pop rbp
ret
FUNC_000953:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],953
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov edi,[rbp+24]
mov ebx,[rbp+16]
test edi,edi
jnl JUMP_003996
mov edi,0x7fffffff
JUMP_003996:
xor eax,eax
mov al,[ebx+0x86]
push rax
push +0xd
call FUNC_000034
add rsp,16
mov eax,[rbp+32]
push rax
push +0xe
call FUNC_000034
add rsp,16
push rdi
push +0xc
call FUNC_000034
add rsp,16
push +0xc
call FUNC_000035
pop rcx
mov edi,eax
xor esi,esi
mov DWORD PTR [rbp-0x10],OFFSET FLAT:DATA_008623
jmp JUMP_003999
JUMP_003997:
mov eax,[rbp-0x10]
test BYTE PTR [eax],0x4
jz JUMP_003998
mov DWORD PTR [rbp-0xc],0x1
mov [rbp-0x8],ebx
mov al,[ebx+0x86]
mov [rbp-0x4],al
lea eax,[rbp-0xc]
push rax
push +0xb
push rsi
call FUNC_000144
add rsp,24
JUMP_003998:
inc esi
add DWORD PTR [rbp-0x10],+0x8
JUMP_003999:
cmp esi,[DATA_008621]
jl JUMP_003997
cmp BYTE PTR [ebx+0x87],0x3
jz JUMP_004000
cmp BYTE PTR [ebx+0x87],0xb
jnz JUMP_004006
xor eax,eax
mov al,[ebx+0x86]
mov edx,[DATA_007758]
test BYTE PTR [edx+eax],0x10
jnz JUMP_004006
mov eax,[ebx+0x82]
push rax
mov eax,DWORD PTR [DATA_007756]
call rax
pop rcx
cmp DWORD PTR [eax+0x38],+0x0
jz JUMP_004006
JUMP_004000:
movzx eax,WORD PTR [ebx+0xe0]
cmp edi,eax
jg JUMP_004001
sub [ebx+0xe0],di
movsx eax,BYTE PTR [ebx+0x88]
push rax
push +0x1c
call FUNC_001907
add rsp,16
or BYTE PTR [ebx+0x151],0x1
jmp JUMP_004004
JUMP_004001:
movzx eax,WORD PTR [ebx+0xe0]
sub edi,eax
mov WORD PTR [ebx+0xe0],0x0
movzx eax,WORD PTR [ebx+0xe4]
cmp edi,eax
jl JUMP_004002
mov eax,[rbp+32]
push rax
push rbx
call FUNC_000942
add rsp,16
jmp JUMP_004007
JUMP_004002:
sub [ebx+0xe4],di
mov BYTE PTR [ebx+0x14e],0xa
movsx eax,BYTE PTR [ebx+0x88]
push rax
push +0x1d
call FUNC_001907
add rsp,16
movzx esi,WORD PTR [ebx+0xe4]
sar esi,0x2
cmp edi,esi
jnl JUMP_004003
mov eax,DWORD PTR [DATA_007752]
call rax
mov ecx,eax
mov eax,edi
shl eax,0xf
cdq
idiv esi
cmp ecx,eax
jnc JUMP_004004
JUMP_004003:
push rbx
call FUNC_000952
pop rcx
jmp JUMP_004007
JUMP_004004:
cmp BYTE PTR [ebx+0x118],0xff
jnz JUMP_004005
push +0x0
push +0x17
call FUNC_000148
add rsp,16
JUMP_004005:
mov eax,0x1
jmp JUMP_004007
JUMP_004006:
movsx eax,BYTE PTR [ebx+0x88]
push rax
push +0x1d
call FUNC_001907
add rsp,16
mov eax,0x1
JUMP_004007:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001530:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],1530
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

mov edx,[DATA_008818]
mov eax,[DATA_008820]
xor eax,0x1234567f
mov ecx,eax
shl ecx,0x19
shr eax,0x7
or ecx,eax
mov eax,ecx
add [DATA_008818],eax
mov eax,edx
shl eax,0xd
shr edx,0x13
or eax,edx
mov edx,eax
mov [DATA_008820],edx
mov eax,[DATA_008818]
and eax,0xffff
ret
FUNC_001538:
pushfq
push rax
mov eax,DWORD PTR [rsp+24]
cmp eax,149
jae s_bad
cmp DWORD PTR [s_models+rax*4],0
je s_bad
pop rax
popfq
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],1538
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov eax,[eax*4+DATA_004681]
pop rbp
ret

.section .text
FUNC_000048:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],48
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov DWORD PTR [s_request],48
mov DWORD PTR [s_request+4],3
mov edi,OFFSET FLAT:s_request+8
xor eax,eax
mov ecx,5
rep stosd
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_request+8],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_request+12],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_request+16],eax
call s_boundary
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001907:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],1907
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov DWORD PTR [s_request],1907
mov DWORD PTR [s_request+4],2
mov edi,OFFSET FLAT:s_request+8
xor eax,eax
mov ecx,5
rep stosd
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_request+8],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_request+12],eax
call s_boundary
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000942:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],942
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov DWORD PTR [s_request],942
mov DWORD PTR [s_request+4],2
mov edi,OFFSET FLAT:s_request+8
xor eax,eax
mov ecx,5
rep stosd
mov eax,DWORD PTR [rbp+16]
cmp eax,OFFSET FLAT:s_body
jne s_bad
movzx eax,BYTE PTR [s_body+0x86]
mov DWORD PTR [s_request+8],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_request+12],eax
call s_boundary
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000952:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],952
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov DWORD PTR [s_request],952
mov DWORD PTR [s_request+4],1
mov edi,OFFSET FLAT:s_request+8
xor eax,eax
mov ecx,5
rep stosd
mov eax,DWORD PTR [rbp+16]
cmp eax,OFFSET FLAT:s_body
jne s_bad
movzx eax,BYTE PTR [s_body+0x86]
mov DWORD PTR [s_request+8],eax
call s_boundary
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_014400:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],14400
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov DWORD PTR [s_request],14400
mov DWORD PTR [s_request+4],4
mov edi,OFFSET FLAT:s_request+8
xor eax,eax
mov ecx,5
rep stosd
mov eax,DWORD PTR [s_current_module]
mov DWORD PTR [s_request+8],eax
mov eax,DWORD PTR [s_current_event]
mov DWORD PTR [s_request+12],eax
mov esi,DWORD PTR [rbp+16]
mov DWORD PTR [s_current_payload],esi
mov edx,DWORD PTR [rsi]
mov DWORD PTR [s_request+16],edx
cmp eax,11
jne s_module_broadcast
cmp DWORD PTR [rsi+4],OFFSET FLAT:s_body
jne s_bad
movzx eax,BYTE PTR [rsi+8]
jmp s_module_ready
s_module_broadcast:
cmp eax,2
jne s_bad
mov eax,DWORD PTR [rsi+4]
s_module_ready:
mov DWORD PTR [s_request+20],eax
call s_boundary
pop rdi
pop rsi
pop rbx
pop rbp
ret

s_boundary:
mov eax,DWORD PTR [s_used]
cmp eax,DWORD PTR [s_script_count]
jae s_pending
imul ebx,eax,512
add ebx,OFFSET FLAT:s_input+32768
mov esi,OFFSET FLAT:s_request
mov edi,ebx
mov ecx,7
repe cmpsd
jne s_bad
mov eax,DWORD PTR [s_used]
imul eax,eax,34640
add eax,OFFSET FLAT:s_output+17920
mov r9d,eax
mov esi,OFFSET FLAT:s_request
mov edi,r9d
mov ecx,28
rep movsb
mov eax,DWORD PTR [rbx+28]
mov DWORD PTR [r9+28],eax
mov DWORD PTR [r9+34620],0
lea r8,[r9+32]
call s_capture
mov r10d,DWORD PTR [rbx+32]
cmp r10d,10
ja s_bad
lea r11,[rbx+64]
s_patch_next:
test r10d,r10d
jz s_patch_done
mov eax,DWORD PTR [r11]
cmp eax,5
ja s_bad
mov rdi,QWORD PTR [s_owner_bases+rax*8]
mov edx,DWORD PTR [s_owner_sizes+rax*4]
mov eax,DWORD PTR [r11+4]
mov ecx,DWORD PTR [r11+8]
cmp ecx,32
ja s_bad
add eax,ecx
jc s_bad
cmp eax,edx
ja s_bad
add edi,DWORD PTR [r11+4]
lea rsi,[r11+12]
rep movsb
add r11,44
dec r10d
jmp s_patch_next
s_patch_done:
cmp DWORD PTR [rbx+48],0
je effects_replacement_done
cmp DWORD PTR [rbx+48],1
jne s_bad
mov eax,DWORD PTR [s_used]
imul esi,eax,17293
add esi,OFFSET FLAT:s_input+65536
mov edi,OFFSET FLAT:s_body
mov ecx,338
rep movsb
mov edi,OFFSET FLAT:s_root
mov ecx,16384
rep movsb
mov edi,OFFSET FLAT:s_flags
mov ecx,115
rep movsb
mov edi,OFFSET FLAT:s_event_registers
mov ecx,284
rep movsb
mov edi,OFFSET FLAT:s_module_entries
mov ecx,168
rep movsb
mov edi,OFFSET FLAT:s_module_count_s32
mov ecx,4
rep movsb
effects_replacement_done:
cmp DWORD PTR [rbx+36],0
je s_payload_done
cmp DWORD PTR [rbx+36],1
jne s_bad
cmp DWORD PTR [s_request],14400
jne s_bad
cmp DWORD PTR [s_current_event],2
jne s_bad
mov edi,DWORD PTR [s_current_payload]
mov eax,DWORD PTR [rbx+40]
mov DWORD PTR [rdi],eax
mov DWORD PTR [r9+34624],eax
mov eax,DWORD PTR [rbx+44]
mov DWORD PTR [rdi+4],eax
mov DWORD PTR [r9+34628],eax
mov DWORD PTR [r9+34620],1
s_payload_done:
lea r8,[r9+17325]
call s_capture
inc DWORD PTR [s_used]
mov eax,DWORD PTR [rbx+28]
ret
s_pending:
mov DWORD PTR [s_status],1
jmp s_emit
s_capture:
mov esi,OFFSET FLAT:s_body
lea rdi,[r8+0]
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:s_root
lea rdi,[r8+338]
mov ecx,16384
rep movsb
mov esi,OFFSET FLAT:s_flags
lea rdi,[r8+16722]
mov ecx,115
rep movsb
mov esi,OFFSET FLAT:s_event_registers
lea rdi,[r8+16837]
mov ecx,284
rep movsb
mov esi,OFFSET FLAT:s_module_entries
lea rdi,[r8+17121]
mov ecx,168
rep movsb
mov esi,OFFSET FLAT:s_module_count_s32
lea rdi,[r8+17289]
mov ecx,4
rep movsb
ret
_start:
cld
s_next:
mov esp,OFFSET FLAT:s_stack_end
xor r8d,r8d
s_read:
xor eax,eax
xor edi,edi
mov esi,OFFSET FLAT:s_input
add rsi,r8
mov edx,1172288
sub edx,r8d
syscall
test eax,eax
jle s_finished
add r8d,eax
cmp r8d,1172288
jne s_read
mov edi,OFFSET FLAT:s_output
mov ecx,2234880
mov al,0xa5
rep stosb
mov DWORD PTR [s_used],0
mov DWORD PTR [s_order_count],0
mov DWORD PTR [s_status],0
mov DWORD PTR [s_return],0xa5a5a5a5
mov edi,OFFSET FLAT:s_request
mov ecx,8
xor eax,eax
rep stosd
mov eax,DWORD PTR [s_input+20]
cmp eax,64
ja s_bad
mov DWORD PTR [s_script_count],eax
mov esi,OFFSET FLAT:s_input+128
mov edi,OFFSET FLAT:s_body
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:s_input+512
mov edi,OFFSET FLAT:s_flags
mov ecx,115
rep movsb
mov esi,OFFSET FLAT:s_input+640
mov edi,OFFSET FLAT:s_event_registers
mov ecx,284
rep movsb
mov esi,OFFSET FLAT:s_input+1024
mov edi,OFFSET FLAT:s_module_entries
mov ecx,168
rep movsb
mov esi,OFFSET FLAT:s_input+16384
mov edi,OFFSET FLAT:s_root
mov ecx,16384
rep movsb
mov eax,DWORD PTR [s_input+12]
mov DWORD PTR [s_module_count_s32],eax
mov edi,OFFSET FLAT:s_models
mov ecx,256
xor eax,eax
rep stosd
mov r10d,DWORD PTR [s_input+16]
cmp r10d,149
ja s_bad
mov esi,OFFSET FLAT:s_input+2048
mov edi,OFFSET FLAT:s_descriptors
s_model_next:
test r10d,r10d
jz s_models_done
mov eax,DWORD PTR [rsi]
cmp eax,256
jae s_bad
mov DWORD PTR [s_models+rax*4],edi
add esi,4
mov ecx,68
rep movsb
dec r10d
jmp s_model_next
s_models_done:
mov rax,0xa5a5a5a5a5a5a5a5
mov QWORD PTR [s_descriptors_guard_a],rax
mov QWORD PTR [s_descriptors_guard_b],rax
mov QWORD PTR [s_body_guard_a],rax
mov QWORD PTR [s_body_guard_b],rax
mov QWORD PTR [s_root_guard_a],rax
mov QWORD PTR [s_root_guard_b],rax
mov QWORD PTR [s_flags_guard_a],rax
mov QWORD PTR [s_flags_guard_b],rax
mov QWORD PTR [s_event_registers_guard_a],rax
mov QWORD PTR [s_event_registers_guard_b],rax
mov QWORD PTR [s_module_entries_guard_a],rax
mov QWORD PTR [s_module_entries_guard_b],rax
mov QWORD PTR [s_module_count_s32_guard_a],rax
mov QWORD PTR [s_module_count_s32_guard_b],rax
mov eax,DWORD PTR [s_input]
test eax,eax
jz s_damage
cmp eax,1
je s_rng1530
cmp eax,2
jne s_bad
mov eax,DWORD PTR [s_input+24]
push rax
call FUNC_000922
add rsp,8
jmp s_called
s_rng1530:
call FUNC_001530
jmp s_called
s_damage:
mov eax,DWORD PTR [s_input+8]
push rax
mov eax,DWORD PTR [s_input+4]
push rax
push OFFSET FLAT:s_body
call FUNC_000953
add rsp,24
s_called:
mov DWORD PTR [s_return],eax
s_emit:
mov esp,OFFSET FLAT:s_stack_end
mov eax,DWORD PTR [s_used]
cmp eax,DWORD PTR [s_script_count]
jne s_bad
cmp DWORD PTR [s_status],1
ja s_bad
s_emit_ready:
mov DWORD PTR [s_output],0x44414d47
mov eax,DWORD PTR [s_used]
imul eax,eax,34640
add eax,17920
mov DWORD PTR [s_output+4],eax
mov eax,DWORD PTR [s_status]
mov DWORD PTR [s_output+8],eax
mov eax,DWORD PTR [s_return]
mov DWORD PTR [s_output+12],eax
mov eax,DWORD PTR [s_used]
mov DWORD PTR [s_output+16],eax
mov eax,DWORD PTR [s_order_count]
mov DWORD PTR [s_output+20],eax
mov esi,OFFSET FLAT:s_request
mov edi,OFFSET FLAT:s_output+24
mov ecx,28
rep movsb
mov r8d,OFFSET FLAT:s_output+64
call s_capture
mov r10d,DWORD PTR [s_input+16]
mov esi,OFFSET FLAT:s_input+2052
mov edi,OFFSET FLAT:s_descriptors
s_model_check:
test r10d,r10d
jz s_model_checked
mov ecx,68
repe cmpsb
jne s_bad
add esi,4
dec r10d
jmp s_model_check
s_model_checked:
mov rax,0xa5a5a5a5a5a5a5a5
cmp QWORD PTR [s_descriptors_guard_a],rax
jne s_bad
cmp QWORD PTR [s_descriptors_guard_b],rax
jne s_bad
cmp QWORD PTR [s_body_guard_a],rax
jne s_bad
cmp QWORD PTR [s_body_guard_b],rax
jne s_bad
cmp QWORD PTR [s_root_guard_a],rax
jne s_bad
cmp QWORD PTR [s_root_guard_b],rax
jne s_bad
cmp QWORD PTR [s_flags_guard_a],rax
jne s_bad
cmp QWORD PTR [s_flags_guard_b],rax
jne s_bad
cmp QWORD PTR [s_event_registers_guard_a],rax
jne s_bad
cmp QWORD PTR [s_event_registers_guard_b],rax
jne s_bad
cmp QWORD PTR [s_module_entries_guard_a],rax
jne s_bad
cmp QWORD PTR [s_module_entries_guard_b],rax
jne s_bad
cmp QWORD PTR [s_module_count_s32_guard_a],rax
jne s_bad
cmp QWORD PTR [s_module_count_s32_guard_b],rax
jne s_bad
mov eax,1
mov edi,1
mov esi,OFFSET FLAT:s_output
mov edx,DWORD PTR [s_output+4]
syscall
jmp s_next
s_bad:
mov eax,60
mov edi,97
syscall
s_finished:
mov eax,60
xor edi,edi
syscall

.section .data
DATA_007752: .long FUNC_001530
DATA_007756: .long FUNC_001538
DATA_007758: .long s_flags
s_owner_bases: .quad s_body,s_root,s_flags,s_event_registers,s_module_entries,s_module_count_s32
s_owner_sizes: .long 338,16384,115,284,168,4
DATA_004892: .long s_registry_0,s_registry_1,s_registry_2,s_registry_3,s_registry_4,s_registry_5,s_registry_6,s_registry_7,s_registry_8,s_registry_9,s_registry_10,s_registry_11,s_registry_12,s_registry_13,s_registry_14,s_registry_15,s_registry_16,s_registry_17,s_registry_18,s_registry_19,s_registry_20
s_registry_0: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_1: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_2: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_3: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,FUNC_014400
s_registry_4: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_5: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_6: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_7: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_8: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_9: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_10: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_11: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,FUNC_014400
s_registry_12: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_13: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_14: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_15: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_16: .long 0,0,0,0,0,0,0,0,0,0,0,0
s_registry_17: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,FUNC_014400
s_registry_18: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_19: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,0
s_registry_20: .long 0,0,FUNC_014400,0,0,0,0,0,0,0,0,FUNC_014400

.section .bss
.balign 16
s_input: .zero 1172288
s_output: .zero 2234880
s_stack: .zero 1048576
s_stack_end:
s_request: .zero 32
s_script_count: .zero 4
s_used: .zero 4
s_order_count: .zero 4
s_return: .zero 4
s_status: .zero 4
s_current_module: .zero 4
s_current_event: .zero 4
s_current_payload: .zero 4
s_models: .zero 1024
s_descriptors_guard_a: .zero 8
s_descriptors: .zero 10132
s_descriptors_guard_b: .zero 8
s_body_guard_a: .zero 8
s_body: .zero 338
s_body_guard_b: .zero 8
s_root_guard_a: .zero 8
s_root: .zero 16384
s_root_guard_b: .zero 8
s_flags_guard_a: .zero 8
s_flags: .zero 115
s_flags_guard_b: .zero 8
s_event_registers_guard_a: .zero 8
s_event_registers: .zero 284
s_event_registers_guard_b: .zero 8
s_module_entries_guard_a: .zero 8
s_module_entries: .zero 168
s_module_entries_guard_b: .zero 8
s_module_count_s32_guard_a: .zero 8
s_module_count_s32: .zero 4
s_module_count_s32_guard_b: .zero 8
DATA_008548=s_event_registers
DATA_008621=s_module_count_s32
DATA_008623=s_module_entries
DATA_008818=s_root+0x24
DATA_008820=s_root+0x28
DATA_004681=s_models
.section .note.GNU-stack,"",@progbits
