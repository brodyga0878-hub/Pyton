.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000583:
push rbp
mov rbp,rsp
add rsp,-40
push rbx
push rsi
push rdi
mov edx,[rbp+32]
mov eax,[rbp+24]
mov ecx,eax
sar ecx,1
lea ecx,[ecx+ecx*2]
mov ebx,[edx+0xc]
mov esi,[ebx+ecx*2-0x6]
mov [rbp-0x8],esi
mov si,[ebx+ecx*2-0x2]
mov [rbp-0x4],si
mov bl,[rbp-0x8]
xor ecx,ecx
mov cl,bl
sar ecx,1
lea ecx,[ecx+ecx*2]
mov esi,[edx+0x10]
mov edi,[esi+ecx*2]
mov [rbp-0x10],edi
mov di,[esi+ecx*2+0x4]
mov [rbp-0xc],di
test al,0x1
jz JUMP_002533
movsx eax,BYTE PTR [rbp-0x6]
neg eax
shl eax,0x8
mov [rbp-0x1c],eax
movsx eax,BYTE PTR [rbp-0x5]
shl eax,0x8
mov [rbp-0x18],eax
movsx eax,BYTE PTR [rbp-0x4]
shl eax,0x8
mov [rbp-0x14],eax
xor eax,eax
mov al,[rbp-0x8]
test al,0x1
jnz JUMP_002534
neg BYTE PTR [rbp-0xe]
jmp JUMP_002534
JUMP_002533:
movsx eax,BYTE PTR [rbp-0x6]
shl eax,0x8
mov [rbp-0x1c],eax
movsx eax,BYTE PTR [rbp-0x5]
shl eax,0x8
mov [rbp-0x18],eax
movsx eax,BYTE PTR [rbp-0x4]
shl eax,0x8
mov [rbp-0x14],eax
test bl,0x1
jz JUMP_002534
neg BYTE PTR [rbp-0xe]
JUMP_002534:
mov eax,[edx+0x14]
sub eax,[edx+0x18]
test eax,eax
jnl JUMP_002535
neg eax
mov ecx,eax
movsx ebx,BYTE PTR [rbp-0xe]
sar ebx,cl
mov [rbp-0x28],ebx
mov ecx,eax
movsx ebx,BYTE PTR [rbp-0xd]
sar ebx,cl
mov [rbp-0x24],ebx
mov ecx,eax
movsx eax,BYTE PTR [rbp-0xc]
sar eax,cl
mov [rbp-0x20],eax
jmp JUMP_002536
JUMP_002535:
mov ecx,eax
movsx ebx,BYTE PTR [rbp-0xe]
shl ebx,cl
mov [rbp-0x28],ebx
mov ecx,eax
movsx ebx,BYTE PTR [rbp-0xd]
shl ebx,cl
mov [rbp-0x24],ebx
mov ecx,eax
movsx eax,BYTE PTR [rbp-0xc]
shl eax,cl
mov [rbp-0x20],eax
JUMP_002536:
mov eax,[edx]
sub [rbp-0x28],eax
mov eax,[edx+0x4]
sub [rbp-0x24],eax
mov eax,[edx+0x8]
sub [rbp-0x20],eax
mov eax,[rbp-0x28]
push rax
call _abs
pop rcx
mov ebx,eax
mov eax,[rbp-0x24]
push rax
call _abs
pop rcx
or ebx,eax
mov eax,[rbp-0x20]
push rax
call _abs
pop rcx
or ebx,eax
push rbx
call FUNC_001656
pop rcx
add eax,-0xd
test eax,eax
jnl JUMP_002537
xor eax,eax
JUMP_002537:
mov ecx,eax
mov edx,[rbp-0x28]
sar edx,cl
imul edx,[rbp-0x1c]
mov ecx,eax
mov ebx,[rbp-0x24]
sar ebx,cl
imul ebx,[rbp-0x18]
add edx,ebx
mov ecx,eax
mov ebx,[rbp-0x20]
sar ebx,cl
imul ebx,[rbp-0x14]
add edx,ebx
neg edx
add edx,edx
mov ecx,eax
mov eax,[rbp+16]
sar eax,cl
cmp edx,eax
mov r11d,DWORD PTR [rbp-0x1c]
mov DWORD PTR [output+16],r11d
mov r11d,DWORD PTR [rbp-0x18]
mov DWORD PTR [output+20],r11d
mov r11d,DWORD PTR [rbp-0x14]
mov DWORD PTR [output+24],r11d
mov r11d,DWORD PTR [rbp-0x28]
mov DWORD PTR [output+28],r11d
mov r11d,DWORD PTR [rbp-0x24]
mov DWORD PTR [output+32],r11d
mov r11d,DWORD PTR [rbp-0x20]
mov DWORD PTR [output+36],r11d
mov DWORD PTR [output+40],ecx
mov DWORD PTR [output+44],edx
mov DWORD PTR [output+48],eax
setnl al
and eax,+0x1
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001656:
pushfq
inc DWORD PTR [msb_count]
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp eax,0x10000
jc JUMP_006329
shr eax,0x10
mov edx,0x10
jmp JUMP_006330
JUMP_006329:
xor edx,edx
JUMP_006330:
cmp eax,0x100
jc JUMP_006331
shr eax,0x8
add edx,+0x8
JUMP_006331:
cmp eax,+0x10
jc JUMP_006332
shr eax,0x4
add edx,+0x4
JUMP_006332:
cmp eax,+0x4
jc JUMP_006333
shr eax,0x2
add edx,+0x2
JUMP_006333:
cmp eax,+0x2
jc JUMP_006334
lea eax,[edx+0x1]
pop rbp
ret
JUMP_006334:
mov eax,edx
pop rbp
ret

_abs:
 push rbp
 mov rbp,rsp
 inc DWORD PTR [abs_count]
 mov eax,DWORD PTR [rbp+16]
 test eax,eax
 jge abs_nonnegative
 mov edx,eax
 neg edx
 jmp abs_done
abs_nonnegative:
 mov edx,eax
abs_done:
 mov eax,edx
 pop rbp
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
 cld
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,2096
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,2096
 jb read_more
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,2112
 rep stosb
 mov edi,OFFSET FLAT:output+2112
 mov al,0xa5
 mov ecx,64
 rep stosb
 mov DWORD PTR [abs_count],0
 mov DWORD PTR [msb_count],0
 mov esi,OFFSET FLAT:input+48
 mov edi,OFFSET FLAT:normals
 mov ecx,1024
 rep movsb
 mov edi,OFFSET FLAT:vertices
 mov ecx,1024
 rep movsb
 mov QWORD PTR [normals_guard_a],-1
 mov QWORD PTR [normals_guard_b],-1
 mov QWORD PTR [vertices_guard_a],-1
 mov QWORD PTR [vertices_guard_b],-1
 mov esi,OFFSET FLAT:input+8
 mov edi,OFFSET FLAT:context
 mov ecx,12
 rep movsb
 mov eax,DWORD PTR [input+28]
 add eax,OFFSET FLAT:normals
 mov DWORD PTR [context+12],eax
 mov eax,DWORD PTR [input+32]
 add eax,OFFSET FLAT:vertices
 mov DWORD PTR [context+16],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [context+20],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [context+24],eax
 mov esi,OFFSET FLAT:context
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 rep movsb
 push OFFSET FLAT:context
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input]
 push rax
 call FUNC_000583
 add rsp,24
 mov DWORD PTR [output+4],eax
 mov DWORD PTR [output],0x504c414e
 mov eax,DWORD PTR [abs_count]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [msb_count]
 mov DWORD PTR [output+12],eax
 cmp QWORD PTR [normals_guard_a],-1
 jne failed
 cmp QWORD PTR [normals_guard_b],-1
 jne failed
 cmp QWORD PTR [vertices_guard_a],-1
 jne failed
 cmp QWORD PTR [vertices_guard_b],-1
 jne failed
 mov esi,OFFSET FLAT:context
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 repe cmpsb
 jne failed
 mov esi,OFFSET FLAT:normals
 mov edi,OFFSET FLAT:output+64
 mov ecx,1024
 rep movsb
 mov esi,OFFSET FLAT:vertices
 mov ecx,1024
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,2176
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,2176
 jb write_more
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,91
 syscall
.section .bss
.balign 16
input: .zero 2096
output: .zero 2176
abs_count: .zero 4
msb_count: .zero 4
context: .zero 28
context_before: .zero 28
normals_guard_a: .zero 8
normals: .zero 1024
normals_guard_b: .zero 8
vertices_guard_a: .zero 8
vertices: .zero 1024
vertices_guard_b: .zero 8
.balign 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
