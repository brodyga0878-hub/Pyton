.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_001008:
push rbp
mov rbp,rsp
push rbx
push rsi
mov ebx,[rbp+16]
mov esi,OFFSET FLAT:DATA_008804
mov ax,[ebx+0xe8]
test ax,ax
jz JUMP_004178
mov edx,[DATA_009155]
cmp edx,0xffff
ja JUMP_004177
movzx eax,ax
cmp edx,eax
ja JUMP_004176
mov ax,[DATA_009155]
sub [ebx+0xe8],ax
jmp JUMP_004178
JUMP_004176:
mov WORD PTR [ebx+0xe8],0x0
jmp JUMP_004178
JUMP_004177:
mov WORD PTR [ebx+0xe8],0x0
JUMP_004178:
cmp BYTE PTR [esi+0xe8],0x2
jnz JUMP_004181
and WORD PTR [esi+0xc6],0xfffd
cmp BYTE PTR [ebx+0xff],0x1e
jna JUMP_004180
test BYTE PTR [esi+0xe9],0x2
jz JUMP_004179
call FUNC_001116
JUMP_004179:
and BYTE PTR [esi+0xe9],0xfd
jmp JUMP_004181
JUMP_004180:
or BYTE PTR [esi+0xe9],0x2
test BYTE PTR [esi+0xe9],0x2
jz JUMP_004181
call FUNC_001116
JUMP_004181:
test BYTE PTR [esi+0xe9],0x2
jz JUMP_004183
movzx edx,WORD PTR [ebx+0x9e]
mov eax,[DATA_009155]
shr eax,1
cmp edx,eax
jna JUMP_004182
sub [ebx+0x9e],ax
jmp JUMP_004187
JUMP_004182:
mov WORD PTR [ebx+0x9e],0x0
jmp JUMP_004187
JUMP_004183:
cmp BYTE PTR [esi+0xe8],0x2
jz JUMP_004185
cmp DWORD PTR [esi+0xd8],0x186a0
jl JUMP_004185
test BYTE PTR [esi+0xc6],0x2
jnz JUMP_004184
push -0x1
push 0x98ce
call FUNC_001097
add rsp,16
JUMP_004184:
or WORD PTR [esi+0xc6],+0x2
JUMP_004185:
movzx eax,WORD PTR [ebx+0x9e]
mov edx,[DATA_009155]
shr edx,1
add eax,edx
cmp eax,0xffff
jna JUMP_004186
mov WORD PTR [ebx+0x9e],0xffff
jmp JUMP_004187
JUMP_004186:
mov eax,[DATA_009155]
shr eax,1
add [ebx+0x9e],ax
JUMP_004187:
pop rsi
pop rbx
pop rbp
ret
FUNC_001009:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov eax,[rbp+16]
mov ebx,[eax+0x8]
mov edx,[eax]
mov ecx,edx
sub ecx,[ebx+0xa8]
mov esi,[eax+0x4]
sub esi,[ebx+0xac]
cmp edx,[ebx+0xa8]
mov edi,0x1
jc JUMP_004188
dec edi
JUMP_004188:
sub esi,edi
mov [ebx+0xa8],edx
mov eax,[eax+0x4]
mov [ebx+0xac],eax
mov [DATA_008868],ecx
mov [DATA_008869],esi
mov BYTE PTR [ebx+0x8a],0x0
mov BYTE PTR [ebx+0x8b],0x0
push rbx
call FUNC_001008
pop rcx
push rbx
movsx eax,BYTE PTR [DATA_008870]
sar eax,1
mov eax,[eax*8+DATA_007255]
call rax
pop rcx
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_001010:
push rbp
mov rbp,rsp
mov al,[DATA_008872]
cmp al,0x6
jz JUMP_004190
cmp al,0x5
jz JUMP_004190
cmp DWORD PTR [DATA_007246],+0x0
jz JUMP_004189
call FUNC_001062
JUMP_004189:
cmp DWORD PTR [DATA_007247],+0x0
jz JUMP_004190
call FUNC_001064
JUMP_004190:
movsx eax,BYTE PTR [DATA_008870]
sar eax,1
mov eax,[eax*8+DATA_007256]
call rax
pop rbp
ret
FUNC_001116:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,1
mov esi,1116
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
FUNC_001097:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,2
mov esi,1097
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
FUNC_001062:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,3
mov esi,1062
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
FUNC_001064:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,4
mov esi,1064
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1011:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1011
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1012:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1012
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1013:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1013
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1019:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1019
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1021:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1021
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1024:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1024
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1025:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1025
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1027:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1027
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1028:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1028
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1029:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1029
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1030:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1030
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1031:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1031
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_control_1044:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,5
mov esi,1044
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1047:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1047
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1048:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1048
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1050:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1050
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1051:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1051
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1066:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1066
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1069:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1069
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1074:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1074
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1075:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1075
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1076:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1076
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1078:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1078
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1081:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1081
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1082:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1082
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1083:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1083
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1084:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1084
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1085:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1085
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1087:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1087
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1088:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1088
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1089:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1089
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1090:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1090
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1091:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1091
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1092:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1092
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret
mode_post_1107:
pushfq
push rax
push rcx
push rdx
push rbx
push rbp
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15
lea rdx,[rsp+128]
mov edi,6
mov esi,1107
call observe
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbp
pop rbx
pop rdx
pop rcx
pop rax
popfq
ret

observe:
 mov eax,DWORD PTR [output+4]
 cmp eax,4
 jae bad
 mov r8d,eax
 imul eax,33488
 add eax,OFFSET FLAT:output+8+16734
 mov r12d,eax
 mov DWORD PTR [r12],edi
 mov DWORD PTR [r12+4],esi
 cmp edi,2
 jne no_fx_args
 mov eax,DWORD PTR [rdx+8]
 cmp eax,0x98ce
 jne bad
 mov DWORD PTR [r12+8],eax
 mov eax,DWORD PTR [rdx+16]
 cmp eax,-1
 jne bad
 mov DWORD PTR [r12+12],eax
no_fx_args:
 cmp edi,5
 jne no_body_arg
 cmp DWORD PTR [rdx+8],OFFSET FLAT:body
 jne bad
 mov DWORD PTR [r12+16],1
no_body_arg:
 mov esi,OFFSET FLAT:body
 lea edi,[r12+20]
 mov ecx,16734
 rep movsb
 inc r8d
 xor r9d,r9d
mutation_next:
 cmp r9d,DWORD PTR [input+16746]
 jae mutation_done
 mov eax,r9d
 shl eax,4
 lea r10d,[input+16750+eax]
 cmp DWORD PTR [r10],r8d
 jne mutation_skip
 mov edi,OFFSET FLAT:body
 mov eax,DWORD PTR [r10+4]
 cmp eax,0
 je mutation_base
 mov edi,OFFSET FLAT:root
 cmp eax,1
 je mutation_base
 mov edi,OFFSET FLAT:externals
mutation_base:
 add edi,DWORD PTR [r10+8]
 mov eax,DWORD PTR [r10+12]
 mov BYTE PTR [rdi],al
mutation_skip:
 inc r9d
 jmp mutation_next
mutation_done:
 mov esi,OFFSET FLAT:body
 lea edi,[r12+20+16734]
 mov ecx,16734
 rep movsb
 inc DWORD PTR [output+4]
 ret
bad:
 mov edi,93
 jmp finish
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 mov esp,OFFSET FLAT:stack_end
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea esi,[input+r8d]
 mov edx,17262
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,17262
 jne read_more
 cld
 mov edi,OFFSET FLAT:guard_before
 mov ecx,64+16734+64
 mov eax,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+12
 mov edi,OFFSET FLAT:body
 mov ecx,16734
 rep movsb
 mov edi,OFFSET FLAT:output
 mov ecx,150758
 xor eax,eax
 rep stosb
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [context],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [context+4],eax
 mov DWORD PTR [context+8],OFFSET FLAT:body
 mov eax,DWORD PTR [input]
 cmp eax,0
 je run1008
 cmp eax,1
 je run1009
 cmp eax,2
 jne bad
 call FUNC_001010
 jmp operation_done
run1008:
 push OFFSET FLAT:body
 call FUNC_001008
 add rsp,8
 jmp operation_done
run1009:
 push OFFSET FLAT:context
 call FUNC_001009
 add rsp,8
operation_done:
 mov esi,OFFSET FLAT:guard_before
 mov ecx,64
check_before:
 cmp BYTE PTR [rsi],0xa5
 jne bad
 inc esi
 loop check_before
 mov esi,OFFSET FLAT:guard_after
 mov ecx,64
check_after:
 cmp BYTE PTR [rsi],0xa5
 jne bad
 inc esi
 loop check_after
 mov DWORD PTR [output],0x504d444f
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+8
 mov ecx,16734
 rep movsb
 mov esi,OFFSET FLAT:guard_after
 mov edi,OFFSET FLAT:output+150758-64
 mov ecx,64
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea esi,[output+r8d]
 mov edx,150758
 sub edx,r8d
 syscall
 test eax,eax
 jle bad
 add r8d,eax
 cmp r8d,150758
 jne write_more
 jmp next_case
finished:
 xor edi,edi
finish:
 mov eax,60
 syscall
.section .data
.align 4
DATA_007255:
.long mode_control_1021,mode_post_1051
.long mode_control_1019,mode_post_1051
.long mode_control_1030,mode_post_1066
.long mode_control_1024,mode_post_1051
.long mode_control_1025,mode_post_1051
.long mode_control_1025,mode_post_1051
.long mode_control_1029,mode_post_1069
.long mode_control_1030,mode_post_1074
.long mode_control_1028,mode_post_1075
.long mode_control_1029,mode_post_1076
.long mode_control_1028,mode_post_1078
.long mode_control_1029,mode_post_1081
.long mode_control_1030,mode_post_1082
.long mode_control_1028,mode_post_1083
.long mode_control_1029,mode_post_1084
.long mode_control_1028,mode_post_1085
.long mode_control_1029,mode_post_1087
.long mode_control_1027,mode_post_1088
.long mode_control_1013,mode_post_1051
.long mode_control_1031,mode_post_1051
.long mode_control_1030,mode_post_1091
.long mode_control_1030,mode_post_1092
.long mode_control_1044,mode_post_1107
.long mode_control_1030,mode_post_1048
.long mode_control_1011,mode_post_1050
.long mode_control_1030,mode_post_1047
.long mode_control_1012,mode_post_1050
.long mode_control_1030,mode_post_1089
.long mode_control_1030,mode_post_1090
.long 0,0
.set DATA_007256,DATA_007255+4
.section .bss
.align 16
input:.skip 17262
output:.skip 150758
context:.skip 12
guard_before:.skip 64
body:.skip 338
root:.skip 16384
externals:.skip 12
guard_after:.skip 64
.set DATA_008804,root
.set DATA_008868,root+0xe0
.set DATA_008869,root+0xe4
.set DATA_008870,root+0xe8
.set DATA_008872,root+0xea
.set DATA_009155,externals
.set DATA_007246,externals+4
.set DATA_007247,externals+8
.align 16
stack:.skip 65536
stack_end:
