.intel_syntax noprefix
.code64
.section .text
.global _start
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
FUNC_000933:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],933
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov edi,[rbp+16]
mov esi,[edi+0xc8]
mov edx,esi
shr edx,0x10
shl esi,0x10
or edx,esi
mov esi,edx
test esi,esi
jz JUMP_003915
mov ebx,0x1c
JUMP_003912:
push +0x1d
mov eax,DWORD PTR [DATA_007217]
call rax
pop rcx
mov ecx,eax
mov edx,0x1
shl edx,cl
test edx,esi
jnz JUMP_003913
dec ebx
test ebx,ebx
jnl JUMP_003912
JUMP_003913:
test ebx,ebx
jnl JUMP_003914
xor eax,eax
jmp JUMP_003916
JUMP_003914:
mov ecx,eax
xor ecx,+0x10
mov edx,0x1
shl edx,cl
or [edi+0xcc],edx
not edx
and [edi+0xc8],edx
mov eax,[eax*4+DATA_007211]
jmp JUMP_003916
JUMP_003915:
xor eax,eax
JUMP_003916:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000943:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],943
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp BYTE PTR [eax+0x118],0xff
jnz JUMP_003975
push +0x0
push +0x17
call FUNC_000148
add rsp,16
JUMP_003975:
mov eax,0x1
pop rbp
ret
FUNC_000944:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],944
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-48
push rbx
mov ebx,[rbp+16]
cmp BYTE PTR [ebx+0x118],0xff
jnz JUMP_003976
mov DWORD PTR [rbp-0x18],0xffffffff
mov eax,[rbp+24]
mov [rbp-0x30],eax
mov eax,[rbp+32]
mov [rbp-0x2c],eax
lea eax,[rbp-0x30]
push rax
call FUNC_000349
pop rcx
push +0x0
push +0x17
call FUNC_000148
add rsp,16
JUMP_003976:
push rbx
call FUNC_000943
pop rcx
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000945:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],945
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
push rbx
call FUNC_000933
pop rcx
test eax,eax
jz JUMP_003977
push rax
push 0x98c9
push rbx
call FUNC_000944
add rsp,24
pop rbx
pop rbp
ret
JUMP_003977:
push rbx
call FUNC_000943
pop rcx
pop rbx
pop rbp
ret
FUNC_000946:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],946
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
add [DATA_008904],ax
mov edx,[DATA_008891]
add edx,eax
mov [DATA_008891],edx
add eax,[DATA_008889]
mov [DATA_008889],eax
pop rbp
ret
FUNC_000947:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],947
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
movsx eax,BYTE PTR [ebx+0xd0]
mov BYTE PTR [ebx+0xd0],0x0
xor edx,edx
mov [ebx+0x11e],edx
cmp BYTE PTR [ebx+0x118],0xff
jnz JUMP_003978
mov eax,[eax*4+DATA_007210]
push rax
call FUNC_000946
pop rcx
JUMP_003978:
push +0x0
push 0x98ca
push rbx
call FUNC_000944
add rsp,24
pop rbx
pop rbp
ret
FUNC_000948:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],948
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
mov al,[ebx+0xd0]
test al,al
jz JUMP_003979
movsx eax,al
mov BYTE PTR [ebx+0xd0],0x1
cmp BYTE PTR [ebx+0x118],0xff
jnz JUMP_003979
mov eax,[eax*4+DATA_007210]
sub eax,+0x4
push rax
call FUNC_000946
pop rcx
JUMP_003979:
push +0x0
push 0x98ca
push rbx
call FUNC_000944
add rsp,24
pop rbx
pop rbp
ret
FUNC_000949:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],949
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
push +0x6
mov eax,DWORD PTR [DATA_007217]
call rax
pop rcx
mov edx,eax
cmp edx,+0x5
ja JUMP_003986
mov r11d,DWORD PTR [rdx*4+DATA_000038]
jmp r11
DATA_000038:
.long JUMP_003980
.long JUMP_003981
.long JUMP_003982
.long JUMP_003983
.long JUMP_003984
.long JUMP_003985
JUMP_003980:
mov WORD PTR [ebx+0xbc],0x0
jmp JUMP_003986
JUMP_003981:
mov WORD PTR [ebx+0xbe],0x0
jmp JUMP_003986
JUMP_003982:
mov WORD PTR [ebx+0xc0],0x0
jmp JUMP_003986
JUMP_003983:
mov WORD PTR [ebx+0xc2],0x0
jmp JUMP_003986
JUMP_003984:
mov WORD PTR [ebx+0xc4],0x0
jmp JUMP_003986
JUMP_003985:
mov WORD PTR [ebx+0xc6],0x0
JUMP_003986:
cmp BYTE PTR [ebx+0x118],0xff
jnz JUMP_003987
xor edx,edx
mov [eax*4+DATA_008935],edx
JUMP_003987:
add eax,0x99ae
push rax
push 0x98cb
push rbx
call FUNC_000944
add rsp,24
pop rbx
pop rbp
ret
FUNC_000950:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],950
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
mov eax,DWORD PTR [DATA_007752]
call rax
cmp ax,0x5555
jc JUMP_003988
push rbx
call FUNC_000945
pop rcx
pop rbx
pop rbp
ret
JUMP_003988:
cmp ax,0x888
jnc JUMP_003989
push rbx
call FUNC_000947
pop rcx
pop rbx
pop rbp
ret
JUMP_003989:
cmp ax,0x1c71
jnc JUMP_003990
push rbx
call FUNC_000948
pop rcx
pop rbx
pop rbp
ret
JUMP_003990:
push rbx
call FUNC_000949
pop rcx
pop rbx
pop rbp
ret
FUNC_000951:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],951
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
push rsi
mov ecx,[rbp+24]
mov esi,[rbp+16]
cmp ecx,[DATA_008891]
jnl JUMP_003993
mov edx,0x25
mov eax,OFFSET FLAT:DATA_008906
JUMP_003991:
movzx ebx,WORD PTR [eax]
sub ecx,ebx
jns JUMP_003992
dec WORD PTR [eax]
inc WORD PTR [DATA_008904]
add edx,0x8e00
push rdx
push 0x98c8
push rsi
call FUNC_000944
add rsp,24
jmp JUMP_003994
JUMP_003992:
dec edx
add eax,-0x2
test edx,edx
jnl JUMP_003991
JUMP_003993:
push rsi
call FUNC_000943
pop rcx
JUMP_003994:
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
mov ebx,[rbp+16]
cmp BYTE PTR [ebx+0x118],0xff
jnz JUMP_003995
mov eax,[ebx+0x82]
push rax
mov eax,DWORD PTR [DATA_007756]
call rax
pop rcx
mov eax,[eax+0x38]
movsx eax,WORD PTR [eax+0x8]
push rax
mov eax,DWORD PTR [DATA_007217]
call rax
pop rcx
cmp eax,[DATA_008889]
jnl JUMP_003995
push rax
push rbx
call FUNC_000951
add rsp,16
pop rbx
pop rbp
ret
JUMP_003995:
push rbx
call FUNC_000950
pop rcx
pop rbx
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

FUNC_000349:
pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],349
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov DWORD PTR [s_request],349
mov DWORD PTR [s_request+4],3
mov edi,OFFSET FLAT:s_request+8
xor eax,eax
mov ecx,5
rep stosd
mov esi,DWORD PTR [rbp+16]
mov eax,DWORD PTR [rsi]
mov DWORD PTR [s_request+8],eax
mov eax,DWORD PTR [rsi+4]
mov DWORD PTR [s_request+12],eax
mov eax,DWORD PTR [rsi+24]
mov DWORD PTR [s_request+16],eax
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
add ebx,OFFSET FLAT:s_input+65536
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
mov edx,131072
sub edx,r8d
syscall
test eax,eax
jle s_finished
add r8d,eax
cmp r8d,131072
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
mov esi,OFFSET FLAT:s_input+32768
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
mov r12d,OFFSET FLAT:s_specs
s_model_next:
test r10d,r10d
jz s_models_done
mov r13d,esi
mov eax,DWORD PTR [rsi]
cmp eax,149
jae s_bad
mov DWORD PTR [s_models+rax*4],edi
mov r14d,edi
add esi,4
mov ecx,68
rep movsb
mov r15d,edi
mov edi,r12d
mov ecx,24
rep movsb
cmp DWORD PTR [r14+0x38],0
je s_no_physical
cmp DWORD PTR [r13+96],1
jne s_bad
mov DWORD PTR [r14+0x38],r12d
s_no_physical:
mov edi,r15d
lea esi,[r13+100]
add r12d,24
dec r10d
jmp s_model_next
s_models_done:
mov rax,0xa5a5a5a5a5a5a5a5
mov QWORD PTR [s_descriptors_guard_a],rax
mov QWORD PTR [s_descriptors_guard_b],rax
mov QWORD PTR [s_specs_guard_a],rax
mov QWORD PTR [s_specs_guard_b],rax
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
cmp eax,0
je s_call_F952
cmp eax,1
je s_call_F933
cmp eax,2
je s_call_F943
cmp eax,3
je s_call_F944
cmp eax,4
je s_call_F945
cmp eax,5
je s_call_F946
cmp eax,6
je s_call_F947
cmp eax,7
je s_call_F948
cmp eax,8
je s_call_F949
cmp eax,9
je s_call_F950
cmp eax,10
je s_call_F951
jmp s_bad
s_call_F952:
push OFFSET FLAT:s_body
call FUNC_000952
add rsp,8
jmp s_called
s_call_F933:
push OFFSET FLAT:s_body
call FUNC_000933
add rsp,8
jmp s_called
s_call_F943:
push OFFSET FLAT:s_body
call FUNC_000943
add rsp,8
jmp s_called
s_call_F944:
mov eax,DWORD PTR [s_input+8]
push rax
mov eax,DWORD PTR [s_input+4]
push rax
push OFFSET FLAT:s_body
call FUNC_000944
add rsp,24
jmp s_called
s_call_F945:
push OFFSET FLAT:s_body
call FUNC_000945
add rsp,8
jmp s_called
s_call_F946:
mov eax,DWORD PTR [s_input+4]
push rax
call FUNC_000946
add rsp,8
jmp s_called
s_call_F947:
push OFFSET FLAT:s_body
call FUNC_000947
add rsp,8
jmp s_called
s_call_F948:
push OFFSET FLAT:s_body
call FUNC_000948
add rsp,8
jmp s_called
s_call_F949:
push OFFSET FLAT:s_body
call FUNC_000949
add rsp,8
jmp s_called
s_call_F950:
push OFFSET FLAT:s_body
call FUNC_000950
add rsp,8
jmp s_called
s_call_F951:
mov eax,DWORD PTR [s_input+4]
push rax
push OFFSET FLAT:s_body
call FUNC_000951
add rsp,16
jmp s_called
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
mov esi,OFFSET FLAT:s_input+2048
mov edi,OFFSET FLAT:s_descriptors
mov r12d,OFFSET FLAT:s_specs
s_model_check:
test r10d,r10d
jz s_model_checked
mov r13d,esi
mov r14d,edi
mov eax,DWORD PTR [rsi+4+0x38]
test eax,eax
jz s_expect_null
cmp DWORD PTR [rdi+0x38],r12d
jne s_bad
jmp s_restore_pointer
s_expect_null:
cmp DWORD PTR [rdi+0x38],0
jne s_bad
s_restore_pointer:
mov DWORD PTR [rdi+0x38],eax
add esi,4
mov ecx,68
repe cmpsb
jne s_bad
mov r15d,edi
mov edi,r12d
mov ecx,24
repe cmpsb
jne s_bad
mov edi,r15d
lea esi,[r13+100]
add r12d,24
dec r10d
jmp s_model_check
s_model_checked:
mov rax,0xa5a5a5a5a5a5a5a5
cmp QWORD PTR [s_descriptors_guard_a],rax
jne s_bad
cmp QWORD PTR [s_descriptors_guard_b],rax
jne s_bad
cmp QWORD PTR [s_specs_guard_a],rax
jne s_bad
cmp QWORD PTR [s_specs_guard_b],rax
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
mov rax,0xa5a5a5a5a5a5a5a5
cmp QWORD PTR [DATA_007210_guard_a],rax
jne s_bad
cmp QWORD PTR [DATA_007210_guard_b],rax
jne s_bad
cmp DWORD PTR [DATA_007210+0],0x0
jne s_bad
cmp DWORD PTR [DATA_007210+4],0x4
jne s_bad
cmp DWORD PTR [DATA_007210+8],0xa
jne s_bad
cmp DWORD PTR [DATA_007210+12],0x19
jne s_bad
cmp DWORD PTR [DATA_007210+16],0x2d
jne s_bad
cmp DWORD PTR [DATA_007210+20],0x50
jne s_bad
cmp DWORD PTR [DATA_007210+24],0x96
jne s_bad
cmp DWORD PTR [DATA_007210+28],0xfa
jne s_bad
cmp DWORD PTR [DATA_007210+32],0x190
jne s_bad
cmp DWORD PTR [DATA_007210+36],0x258
jne s_bad
cmp DWORD PTR [DATA_007210+40],0x6
jne s_bad
cmp DWORD PTR [DATA_007210+44],0xc
jne s_bad
cmp DWORD PTR [DATA_007210+48],0x18
jne s_bad
cmp DWORD PTR [DATA_007210+52],0x24
jne s_bad
cmp DWORD PTR [DATA_007210+56],0x0
jne s_bad
cmp QWORD PTR [DATA_007211_guard_a],rax
jne s_bad
cmp QWORD PTR [DATA_007211_guard_b],rax
jne s_bad
cmp DWORD PTR [DATA_007211+0],0x9888
jne s_bad
cmp DWORD PTR [DATA_007211+4],0x9888
jne s_bad
cmp DWORD PTR [DATA_007211+8],0x9889
jne s_bad
cmp DWORD PTR [DATA_007211+12],0x988c
jne s_bad
cmp DWORD PTR [DATA_007211+16],0x9892
jne s_bad
cmp DWORD PTR [DATA_007211+20],0x988d
jne s_bad
cmp DWORD PTR [DATA_007211+24],0x988b
jne s_bad
cmp DWORD PTR [DATA_007211+28],0x989c
jne s_bad
cmp DWORD PTR [DATA_007211+32],0x988f
jne s_bad
cmp DWORD PTR [DATA_007211+36],0x98a7
jne s_bad
cmp DWORD PTR [DATA_007211+40],0x989e
jne s_bad
cmp DWORD PTR [DATA_007211+44],0x989f
jne s_bad
cmp DWORD PTR [DATA_007211+48],0x9899
jne s_bad
cmp DWORD PTR [DATA_007211+52],0x9893
jne s_bad
cmp DWORD PTR [DATA_007211+56],0x9884
jne s_bad
cmp DWORD PTR [DATA_007211+60],0x989d
jne s_bad
cmp DWORD PTR [DATA_007211+64],0x9887
jne s_bad
cmp DWORD PTR [DATA_007211+68],0x9883
jne s_bad
cmp DWORD PTR [DATA_007211+72],0x98b2
jne s_bad
cmp DWORD PTR [DATA_007211+76],0x98b0
jne s_bad
cmp DWORD PTR [DATA_007211+80],0x98b1
jne s_bad
cmp DWORD PTR [DATA_007211+84],0x9885
jne s_bad
cmp DWORD PTR [DATA_007211+88],0x9886
jne s_bad
cmp DWORD PTR [DATA_007211+92],0x9880
jne s_bad
cmp DWORD PTR [DATA_007211+96],0x98b3
jne s_bad
cmp DWORD PTR [DATA_007211+100],0x987f
jne s_bad
cmp DWORD PTR [DATA_007211+104],0x9898
jne s_bad
cmp DWORD PTR [DATA_007211+108],0x9881
jne s_bad
cmp DWORD PTR [DATA_007211+112],0x9882
jne s_bad
cmp DWORD PTR [DATA_007211+116],0x98b4
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
DATA_007217: .long FUNC_000922
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
s_input: .zero 131072
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
s_specs_guard_a: .zero 8
s_specs: .zero 3576
s_specs_guard_b: .zero 8
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

.section .data
DATA_007210_guard_a: .quad 0xa5a5a5a5a5a5a5a5
DATA_007210: .long 0,4,10,25,45,80,150,250,400,600,6,12,24,36,0
DATA_007210_guard_b: .quad 0xa5a5a5a5a5a5a5a5
DATA_007211_guard_a: .quad 0xa5a5a5a5a5a5a5a5
DATA_007211: .long 39048,39048,39049,39052,39058,39053,39051,39068,39055,39079,39070,39071,39065,39059,39044,39069,39047,39043,39090,39088,39089,39045,39046,39040,39091,39039,39064,39041,39042,39092
DATA_007211_guard_b: .quad 0xa5a5a5a5a5a5a5a5
DATA_008889=s_root+0x118
DATA_008891=s_root+0x120
DATA_008904=s_root+0x170
DATA_008906=s_root+0x17e
DATA_008935=s_root+0x214
