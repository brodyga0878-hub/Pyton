.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000149:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov eax,[rbp+24]
mov [rbp-0xc],eax
mov eax,[rbp+32]
mov [rbp-0x8],eax
mov eax,[rbp+16]
mov [DATA_007758],eax
mov esi,0x72
mov eax,[rbp+16]
lea ebx,[eax+0x9783]
mov eax,[rbp+16]
lea edi,[eax+0x72]
JUMP_001179:
test BYTE PTR [edi],0x1
jz JUMP_001180
mov al,[ebx]
add BYTE PTR [ebx],0xff
test al,al
jnz JUMP_001180
mov al,[ebx-0x1]
mov [ebx],al
lea eax,[esi+esi*4]
lea eax,[esi+eax*4]
lea eax,[esi+eax*8]
add eax,eax
add eax,[rbp+16]
add eax,+0x74
mov [rbp-0x4],eax
lea eax,[rbp-0xc]
push rax
push +0x5
xor eax,eax
mov al,[ebx-0x4]
push rax
call FUNC_000144
add rsp,24
JUMP_001180:
dec esi
add ebx,0xfffffeae
dec edi
test esi,esi
jg JUMP_001179
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
DOS_000144:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov rax,QWORD PTR [rax*8+DATA_004892]
mov edx,[rbp+24]
mov rax,QWORD PTR [rax+rdx*8]
test eax,eax
jz JUMP_001170
mov edx,[rbp+32]
push rdx
call rax
pop rcx
JUMP_001170:
pop rbp
ret

FUNC_000144:
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

 mov r10d,DWORD PTR [rsp+104]
 mov r11d,DWORD PTR [rsp+112]
 mov edx,DWORD PTR [rsp+120]
 call append_attempt
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

 jmp DOS_000144
callback_type_0:
 mov r10d,0
 jmp callback_common
callback_type_1:
 mov r10d,1
 jmp callback_common
callback_type_2:
 mov r10d,2
 jmp callback_common
callback_type_3:
 mov r10d,3
 jmp callback_common
callback_type_4:
 mov r10d,4
 jmp callback_common
callback_type_5:
 mov r10d,5
 jmp callback_common
callback_type_6:
 mov r10d,6
 jmp callback_common
callback_type_7:
 mov r10d,7
 jmp callback_common
callback_type_8:
 mov r10d,8
 jmp callback_common
callback_type_9:
 mov r10d,9
 jmp callback_common
callback_type_10:
 mov r10d,10
 jmp callback_common
callback_type_11:
 mov r10d,11
 jmp callback_common
callback_type_12:
 mov r10d,12
 jmp callback_common
callback_type_13:
 mov r10d,13
 jmp callback_common
callback_type_14:
 mov r10d,14
 jmp callback_common
callback_type_15:
 mov r10d,15
 jmp callback_common
callback_type_16:
 mov r10d,16
 jmp callback_common
callback_type_17:
 mov r10d,17
 jmp callback_common
callback_type_18:
 mov r10d,18
 jmp callback_common
callback_type_19:
 mov r10d,19
 jmp callback_common
callback_type_20:
 mov r10d,20
 jmp callback_common
callback_common:
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

 mov r11d,5
 mov edx,DWORD PTR [rsp+104]
 call append_callback
 mov esi,OFFSET FLAT:input+32
 mov ecx,DWORD PTR [input+28]
.Lmutation_loop:
 test ecx,ecx
 jz .Lmutations_done
 movzx eax,BYTE PTR [esi]
 cmp eax,DWORD PTR [last_callback_index]
 jne .Lmutation_next
 movzx eax,BYTE PTR [esi+1]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 movzx edx,WORD PTR [esi+2]
 mov bl,BYTE PTR [esi+4]
 mov BYTE PTR [eax+edx],bl
 inc DWORD PTR [output+16]
.Lmutation_next:
 add esi,8
 dec ecx
 jmp .Lmutation_loop
.Lmutations_done:
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
append_attempt:
 mov r9d,OFFSET FLAT:output+39050
 mov edi,OFFSET FLAT:output+8
 jmp append_trace
append_callback:
 mov r9d,OFFSET FLAT:output+41330
 mov edi,OFFSET FLAT:output+12
append_trace:
 mov r8d,edx
 mov eax,DWORD PTR [r8+8]
 sub eax,OFFSET FLAT:bank+0x74
 xor edx,edx
 mov ecx,338
 div ecx
 test edx,edx
 jnz failed
 cmp eax,1
 jb failed
 cmp eax,114
 ja failed
 mov DWORD PTR [last_callback_index],eax
 mov ecx,DWORD PTR [edi]
 cmp ecx,114
 jae failed
 inc DWORD PTR [edi]
 imul ecx,20
 add r9d,ecx
 mov DWORD PTR [r9],eax
 mov DWORD PTR [r9+4],r10d
 mov DWORD PTR [r9+8],r11d
 mov eax,DWORD PTR [r8]
 mov DWORD PTR [r9+12],eax
 mov eax,DWORD PTR [r8+4]
 mov DWORD PTR [r9+16],eax
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 mov esp,OFFSET FLAT:stack_end
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,39146
 sub edx,r8d
 syscall
 test eax,eax
 js failed
 jnz got_input
 test r8d,r8d
 jnz failed
 mov eax,60
 xor edi,edi
 syscall
got_input:
 add r8d,eax
 cmp r8d,39146
 jb read_more
 cld
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,43674
 rep stosb
 mov DWORD PTR [output],0x14914444
 mov eax,DWORD PTR [input]
 mov DWORD PTR [output+4],eax
 mov edi,OFFSET FLAT:bank_before
 mov eax,0xa5
 mov ecx,38986+32
 rep stosb
 mov edi,OFFSET FLAT:output+43674-64
 mov ecx,64
 rep stosb
 mov esi,OFFSET FLAT:input+160
 mov edi,OFFSET FLAT:bank
 mov ecx,38986
 rep movsb
 mov edi,OFFSET FLAT:callback_tables
 xor eax,eax
 mov ecx,1008
 rep stosb
 mov QWORD PTR [DATA_004892+0],OFFSET FLAT:callback_tables+0
 mov QWORD PTR [callback_tables+40],0
 test DWORD PTR [input+20],1
 jz .Ltable_0_ready
 mov QWORD PTR [callback_tables+40],OFFSET FLAT:callback_type_0
.Ltable_0_ready:
 mov QWORD PTR [DATA_004892+8],OFFSET FLAT:callback_tables+48
 mov QWORD PTR [callback_tables+88],0
 test DWORD PTR [input+20],2
 jz .Ltable_1_ready
 mov QWORD PTR [callback_tables+88],OFFSET FLAT:callback_type_1
.Ltable_1_ready:
 mov QWORD PTR [DATA_004892+16],OFFSET FLAT:callback_tables+96
 mov QWORD PTR [callback_tables+136],0
 test DWORD PTR [input+20],4
 jz .Ltable_2_ready
 mov QWORD PTR [callback_tables+136],OFFSET FLAT:callback_type_2
.Ltable_2_ready:
 mov QWORD PTR [DATA_004892+24],OFFSET FLAT:callback_tables+144
 mov QWORD PTR [callback_tables+184],0
 test DWORD PTR [input+20],8
 jz .Ltable_3_ready
 mov QWORD PTR [callback_tables+184],OFFSET FLAT:callback_type_3
.Ltable_3_ready:
 mov QWORD PTR [DATA_004892+32],OFFSET FLAT:callback_tables+192
 mov QWORD PTR [callback_tables+232],0
 test DWORD PTR [input+20],16
 jz .Ltable_4_ready
 mov QWORD PTR [callback_tables+232],OFFSET FLAT:callback_type_4
.Ltable_4_ready:
 mov QWORD PTR [DATA_004892+40],OFFSET FLAT:callback_tables+240
 mov QWORD PTR [callback_tables+280],0
 test DWORD PTR [input+20],32
 jz .Ltable_5_ready
 mov QWORD PTR [callback_tables+280],OFFSET FLAT:callback_type_5
.Ltable_5_ready:
 mov QWORD PTR [DATA_004892+48],OFFSET FLAT:callback_tables+288
 mov QWORD PTR [callback_tables+328],0
 test DWORD PTR [input+20],64
 jz .Ltable_6_ready
 mov QWORD PTR [callback_tables+328],OFFSET FLAT:callback_type_6
.Ltable_6_ready:
 mov QWORD PTR [DATA_004892+56],OFFSET FLAT:callback_tables+336
 mov QWORD PTR [callback_tables+376],0
 test DWORD PTR [input+20],128
 jz .Ltable_7_ready
 mov QWORD PTR [callback_tables+376],OFFSET FLAT:callback_type_7
.Ltable_7_ready:
 mov QWORD PTR [DATA_004892+64],OFFSET FLAT:callback_tables+384
 mov QWORD PTR [callback_tables+424],0
 test DWORD PTR [input+20],256
 jz .Ltable_8_ready
 mov QWORD PTR [callback_tables+424],OFFSET FLAT:callback_type_8
.Ltable_8_ready:
 mov QWORD PTR [DATA_004892+72],OFFSET FLAT:callback_tables+432
 mov QWORD PTR [callback_tables+472],0
 test DWORD PTR [input+20],512
 jz .Ltable_9_ready
 mov QWORD PTR [callback_tables+472],OFFSET FLAT:callback_type_9
.Ltable_9_ready:
 mov QWORD PTR [DATA_004892+80],OFFSET FLAT:callback_tables+480
 mov QWORD PTR [callback_tables+520],0
 test DWORD PTR [input+20],1024
 jz .Ltable_10_ready
 mov QWORD PTR [callback_tables+520],OFFSET FLAT:callback_type_10
.Ltable_10_ready:
 mov QWORD PTR [DATA_004892+88],OFFSET FLAT:callback_tables+528
 mov QWORD PTR [callback_tables+568],0
 test DWORD PTR [input+20],2048
 jz .Ltable_11_ready
 mov QWORD PTR [callback_tables+568],OFFSET FLAT:callback_type_11
.Ltable_11_ready:
 mov QWORD PTR [DATA_004892+96],OFFSET FLAT:callback_tables+576
 mov QWORD PTR [callback_tables+616],0
 test DWORD PTR [input+20],4096
 jz .Ltable_12_ready
 mov QWORD PTR [callback_tables+616],OFFSET FLAT:callback_type_12
.Ltable_12_ready:
 mov QWORD PTR [DATA_004892+104],OFFSET FLAT:callback_tables+624
 mov QWORD PTR [callback_tables+664],0
 test DWORD PTR [input+20],8192
 jz .Ltable_13_ready
 mov QWORD PTR [callback_tables+664],OFFSET FLAT:callback_type_13
.Ltable_13_ready:
 mov QWORD PTR [DATA_004892+112],OFFSET FLAT:callback_tables+672
 mov QWORD PTR [callback_tables+712],0
 test DWORD PTR [input+20],16384
 jz .Ltable_14_ready
 mov QWORD PTR [callback_tables+712],OFFSET FLAT:callback_type_14
.Ltable_14_ready:
 mov QWORD PTR [DATA_004892+120],OFFSET FLAT:callback_tables+720
 mov QWORD PTR [callback_tables+760],0
 test DWORD PTR [input+20],32768
 jz .Ltable_15_ready
 mov QWORD PTR [callback_tables+760],OFFSET FLAT:callback_type_15
.Ltable_15_ready:
 mov QWORD PTR [DATA_004892+128],OFFSET FLAT:callback_tables+768
 mov QWORD PTR [callback_tables+808],0
 test DWORD PTR [input+20],65536
 jz .Ltable_16_ready
 mov QWORD PTR [callback_tables+808],OFFSET FLAT:callback_type_16
.Ltable_16_ready:
 mov QWORD PTR [DATA_004892+136],OFFSET FLAT:callback_tables+816
 mov QWORD PTR [callback_tables+856],0
 test DWORD PTR [input+20],131072
 jz .Ltable_17_ready
 mov QWORD PTR [callback_tables+856],OFFSET FLAT:callback_type_17
.Ltable_17_ready:
 mov QWORD PTR [DATA_004892+144],OFFSET FLAT:callback_tables+864
 mov QWORD PTR [callback_tables+904],0
 test DWORD PTR [input+20],262144
 jz .Ltable_18_ready
 mov QWORD PTR [callback_tables+904],OFFSET FLAT:callback_type_18
.Ltable_18_ready:
 mov QWORD PTR [DATA_004892+152],OFFSET FLAT:callback_tables+912
 mov QWORD PTR [callback_tables+952],0
 test DWORD PTR [input+20],524288
 jz .Ltable_19_ready
 mov QWORD PTR [callback_tables+952],OFFSET FLAT:callback_type_19
.Ltable_19_ready:
 mov QWORD PTR [DATA_004892+160],OFFSET FLAT:callback_tables+960
 mov QWORD PTR [callback_tables+1000],0
 test DWORD PTR [input+20],1048576
 jz .Ltable_20_ready
 mov QWORD PTR [callback_tables+1000],OFFSET FLAT:callback_type_20
.Ltable_20_ready:

 mov DWORD PTR [DATA_007758],0x13572468
 cmp DWORD PTR [input],0
 jne direct_dispatch
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:bank
 call FUNC_000149
 add rsp,24
 cmp DWORD PTR [DATA_007758],OFFSET FLAT:bank
 jne failed
 mov DWORD PTR [output+24],1
 jmp capture
direct_dispatch:
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [direct_context],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [direct_context+4],eax
 mov eax,DWORD PTR [input+12]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 mov DWORD PTR [direct_context+8],eax
 push OFFSET FLAT:direct_context
 push 5
 mov eax,DWORD PTR [input+16]
 push rax
 call FUNC_000144
 add rsp,24
 cmp DWORD PTR [DATA_007758],0x13572468
 jne failed
capture:
 mov esi,OFFSET FLAT:bank_before
 mov ecx,16
.Lguard_before:
 cmp BYTE PTR [esi],0xa5
 jne failed
 inc esi
 loop .Lguard_before
 mov esi,OFFSET FLAT:bank_after
 mov ecx,16
.Lguard_after:
 cmp BYTE PTR [esi],0xa5
 jne failed
 inc esi
 loop .Lguard_after
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:output+64
 mov ecx,38986
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 add rsi,r8
 mov edx,43674
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,43674
 jb write_more
 jmp next_case
failed:
 mov eax,60
 mov edi,93
 syscall
.section .bss
.balign 16
input: .zero 39146
bank_before: .zero 16
bank: .zero 38986
bank_after: .zero 16
output: .zero 43674
DATA_004892: .zero 168
callback_tables: .zero 1008
DATA_007758: .zero 4
last_callback_index: .zero 4
direct_context: .zero 12
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
