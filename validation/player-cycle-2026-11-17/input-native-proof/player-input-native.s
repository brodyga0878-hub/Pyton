.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_001037:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1037
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,[rbp+16]
mov ebx,OFFSET FLAT:DATA_008804
cmp BYTE PTR [DATA_008630],0x0
jnl JUMP_004290
test BYTE PTR [ebx+0xe9],0x1
jnz JUMP_004289
cmp BYTE PTR [DATA_007692],0x0
jnz JUMP_004285
cmp DWORD PTR [ebx+0x1b8],+0x0
jnl JUMP_004284
xor eax,eax
mov [ebx+0x1b8],eax
push rsi
call FUNC_001038
pop rcx
jmp JUMP_004290
JUMP_004284:
mov eax,[ebx+0x1b8]
push rax
call FUNC_001121
pop rcx
add [ebx+0x1b8],eax
cmp DWORD PTR [ebx+0x1b8],+0x0
jnl JUMP_004285
mov DWORD PTR [ebx+0x1b8],0x7fffffff
JUMP_004285:
cmp BYTE PTR [DATA_007694],0x0
jnz JUMP_004288
mov eax,[ebx+0x1b8]
test eax,eax
jg JUMP_004286
test BYTE PTR [ebx+0xe9],0x80
jnz JUMP_004289
mov edx,[DATA_009122]
shr edx,0x8
push rdx
mov edx,eax
pop rax
sub edx,eax
mov [ebx+0x1b8],edx
test edx,edx
jng JUMP_004289
mov DWORD PTR [ebx+0x1b8],0x80000000
jmp JUMP_004289
JUMP_004286:
mov edi,[ebx+0x1b8]
or BYTE PTR [ebx+0xe9],0x80
mov eax,[ebx+0x1b8]
push rax
call FUNC_001121
pop rcx
sub [ebx+0x1b8],eax
mov eax,[ebx+0x1b8]
cmp edi,eax
jl JUMP_004287
test eax,eax
jnl JUMP_004289
JUMP_004287:
xor eax,eax
mov [ebx+0x1b8],eax
jmp JUMP_004289
JUMP_004288:
and BYTE PTR [ebx+0xe9],0x7f
JUMP_004289:
push rsi
call FUNC_001038
pop rcx
JUMP_004290:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_001038:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1038
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
mov esi,DWORD PTR [rbp+16]
mov ebx,OFFSET FLAT:DATA_008804
mov eax,DWORD PTR [ebx+0xd0]
mov DWORD PTR [rbp-0x4],eax
call QWORD PTR [DATA_007682]
mov DWORD PTR [ebx+0xd0],eax
mov ax,WORD PTR [ebx+0xd0]
sub ax,WORD PTR [rbp-0x4]
shl eax,0x6
mov WORD PTR [rbp-0x8],ax
mov ax,WORD PTR [ebx+0xd2]
sub ax,WORD PTR [rbp-0x2]
shl eax,0x6
mov WORD PTR [rbp-0x6],ax
mov al,BYTE PTR [ebx+0xea]
cmp al,0x2
je INPUT_441df2
cmp al,0x3
je INPUT_441df2
cmp BYTE PTR [ebx+0x3f54],0x0
jne INPUT_441d88
movsx eax,WORD PTR [rbp-0x8]
mov edx,eax
neg eax
mov WORD PTR [rbp-0x8],ax
INPUT_441d88:
cmp BYTE PTR [ebx+0x3f55],0x0
jne INPUT_441d9d
movsx eax,WORD PTR [rbp-0x6]
mov edx,eax
neg eax
mov WORD PTR [rbp-0x6],ax
INPUT_441d9d:
mov ax,WORD PTR [rbp-0x6]
add WORD PTR [esi+0xb0],ax
cmp BYTE PTR [ebx+0x3f56],0x0
jne INPUT_441dc1
mov ax,WORD PTR [rbp-0x8]
sub WORD PTR [esi+0xb4],ax
jmp INPUT_441e5e
INPUT_441dc1:
test BYTE PTR [ebx+0x212],0x20
jne INPUT_441e5e
mov ax,WORD PTR [rbp-0x8]
add WORD PTR [esi+0xb2],ax
cmp DWORD PTR [ebx+0xdc],0x2625a00
jg INPUT_441e5e
mov ax,WORD PTR [rbp-0x6]
sub WORD PTR [esi+0xb4],ax
jmp INPUT_441e5e
INPUT_441df2:
mov ax,WORD PTR [rbp-0x8]
add WORD PTR [ebx+0x204],ax
mov ax,WORD PTR [rbp-0x6]
sub WORD PTR [ebx+0x206],ax
cmp WORD PTR [ebx+0x206],0x0
jge INPUT_441e2f
mov BYTE PTR [ebx+0xea],0x2
cmp WORD PTR [ebx+0x206],0xc000
jg INPUT_441e5e
mov WORD PTR [ebx+0x206],0xc001
jmp INPUT_441e5e
INPUT_441e2f:
cmp BYTE PTR [esi+0xd1],0x4
jl INPUT_441e55
mov BYTE PTR [ebx+0xea],0x3
cmp WORD PTR [ebx+0x206],0x4000
jl INPUT_441e5e
mov WORD PTR [ebx+0x206],0x3fff
jmp INPUT_441e5e
INPUT_441e55:
mov WORD PTR [ebx+0x206],0xffff
INPUT_441e5e:
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_001039:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1039
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov al,[DATA_008872]
cmp al,0x2
jz JUMP_004298
cmp al,0x3
jnz JUMP_004299
JUMP_004298:
mov eax,[rbp+16]
push rax
call FUNC_001038
pop rcx
JUMP_004299:
pop rbp
ret
FUNC_001040:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1040
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
call QWORD PTR [DATA_007682]
cmp BYTE PTR [DATA_008872],0x5
jz JUMP_004304
cmp BYTE PTR [DATA_007696],0x0
jz JUMP_004300
test BYTE PTR [DATA_009163],0x10
jz JUMP_004300
test BYTE PTR [DATA_009163],0x20
jz JUMP_004300
cmp BYTE PTR [DATA_007708],0x0
jz JUMP_004304
cmp BYTE PTR [DATA_007711],0x0
jz JUMP_004304
JUMP_004300:
mov al,[DATA_008872]
cmp al,0x4
jz JUMP_004301
cmp al,0x6
jnz JUMP_004302
JUMP_004301:
xor eax,eax
jmp JUMP_004303
JUMP_004302:
movsx eax,BYTE PTR [DATA_008872]
JUMP_004303:
push rax
mov eax,[rbp+16]
push rax
call FUNC_000931
add rsp,16
JUMP_004304:
pop rbp
ret
FUNC_001121:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1121
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
xor edx,edx
JUMP_004635:
test eax,0x80000000
jz JUMP_004636
mov eax,0x7ffeffff
jmp JUMP_004637
JUMP_004636:
add eax,eax
inc edx
cmp edx,+0x5
jl JUMP_004635
JUMP_004637:
shr eax,0x10
inc eax
mov edx,[DATA_007690]
mov ecx,edx
and ecx,0xff
cmp ecx,+0x10
jng JUMP_004638
imul edx,eax
mov eax,edx
shr eax,0x4
cmp eax,0x7fff
jna JUMP_004638
mov eax,0x7fff
JUMP_004638:
imul DWORD PTR [DATA_009122]
shr eax,0x6
pop rbp
ret

gui_observer:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1445
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

 inc DWORD PTR [output+4]
 mov eax,DWORD PTR [input+40]
 ret
FUNC_000931:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],931
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

 push rbp
 mov rbp,rsp
 pushfq
 push rax
 inc DWORD PTR [output+8]
 mov eax,DWORD PTR [rbp+24]
 mov DWORD PTR [output+12],eax
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 sete al
 movzx eax,al
 mov DWORD PTR [output+16],eax
 pop rax
 popfq
 pop rbp
 ret
bad_trace:
 mov edi,91
 jmp finish
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
 mov edx,16770
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,16770
 jne read_more
 cld
 mov edi,OFFSET FLAT:body_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:root_before
 mov ecx,16384+32
 rep stosb
 mov esi,OFFSET FLAT:input+48
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+386
 mov edi,OFFSET FLAT:DATA_008804
 mov ecx,16384
 rep movsb
 mov edi,OFFSET FLAT:output
 mov ecx,16946
 xor eax,eax
 rep stosb
 mov DWORD PTR [trace_count],eax
 mov edi,OFFSET FLAT:trace_codes
 mov ecx,64
 rep stosb
mov eax,DWORD PTR [input+4]
mov BYTE PTR [DATA_008630],al
mov eax,DWORD PTR [input+8]
mov DWORD PTR [DATA_009122],eax
mov eax,DWORD PTR [input+12]
mov DWORD PTR [DATA_007690],eax
mov eax,DWORD PTR [input+16]
mov BYTE PTR [DATA_007692],al
mov eax,DWORD PTR [input+20]
mov BYTE PTR [DATA_007694],al
mov eax,DWORD PTR [input+24]
mov BYTE PTR [DATA_007696],al
mov eax,DWORD PTR [input+28]
mov BYTE PTR [DATA_007708],al
mov eax,DWORD PTR [input+32]
mov BYTE PTR [DATA_007711],al
mov eax,DWORD PTR [input+36]
mov BYTE PTR [DATA_009163],al
cmp DWORD PTR [input],0
je input_op0
cmp DWORD PTR [input],1
je input_op1
cmp DWORD PTR [input],2
je input_op2
cmp DWORD PTR [input],3
je input_op3
cmp DWORD PTR [input],4
je input_op4
jmp bad_trace
input_op0:
push OFFSET FLAT:body
call FUNC_001037
add rsp,8
jmp operation_done
input_op1:
push OFFSET FLAT:body
call FUNC_001038
add rsp,8
jmp operation_done
input_op2:
push OFFSET FLAT:body
call FUNC_001039
add rsp,8
jmp operation_done
input_op3:
push OFFSET FLAT:body
call FUNC_001040
add rsp,8
jmp operation_done
input_op4:
mov eax,DWORD PTR [input+44]
push rax
call FUNC_001121
add rsp,8
mov DWORD PTR [output+20],eax
jmp operation_done

operation_done:
 mov DWORD PTR [output],0x50494e50
 mov eax,DWORD PTR [trace_count]
 mov DWORD PTR [output+24],eax
 mov esi,OFFSET FLAT:trace_codes
 mov edi,OFFSET FLAT:output+32
 mov ecx,64
 rep movsb
movsx eax,BYTE PTR [DATA_008630]
mov DWORD PTR [output+96],eax
mov eax,DWORD PTR [DATA_009122]
mov DWORD PTR [output+100],eax
mov eax,DWORD PTR [DATA_007690]
mov DWORD PTR [output+104],eax
movzx eax,BYTE PTR [DATA_007692]
mov DWORD PTR [output+108],eax
movzx eax,BYTE PTR [DATA_007694]
mov DWORD PTR [output+112],eax
movzx eax,BYTE PTR [DATA_007696]
mov DWORD PTR [output+116],eax
movzx eax,BYTE PTR [DATA_007708]
mov DWORD PTR [output+120],eax
movzx eax,BYTE PTR [DATA_007711]
mov DWORD PTR [output+124],eax
movzx eax,BYTE PTR [DATA_009163]
mov DWORD PTR [output+128],eax
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+160
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:DATA_008804
 mov ecx,16384
 rep movsb
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:root_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:root_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,16946
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle write_failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
write_failed:
 mov edi,93
 jmp finish
finished:
 xor edi,edi
finish:
 mov eax,60
 syscall
.section .data
DATA_007682: .quad gui_observer
.section .bss
.balign 16
input: .zero 16770
body_before: .zero 16
body: .zero 338
body_after: .zero 16
root_before: .zero 16
DATA_008804: .zero 16384
root_after: .zero 16
.set DATA_008872,DATA_008804+0xea
output: .zero 16946
trace_codes: .zero 64
trace_count: .zero 4
DATA_008630: .zero 1
DATA_009122: .zero 4
DATA_007690: .zero 4
DATA_007692: .zero 1
DATA_007694: .zero 1
DATA_007696: .zero 1
DATA_007708: .zero 1
DATA_007711: .zero 1
DATA_009163: .zero 1
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
