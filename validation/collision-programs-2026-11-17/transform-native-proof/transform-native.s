.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000580:
push rbp
mov rbp,rsp
add rsp,-48
push rbx
push rsi
mov ebx,[rbp+24]
mov eax,[rbp+32]
push rax
call QWORD PTR [DATA_007756]
pop rcx
mov esi,eax
mov eax,[esi+0xc]
mov [rbp-0x24],eax
mov eax,[esi+0x4]
mov [rbp-0x20],eax
mov eax,[esi+0x14]
add eax,[esi+0x18]
mov [rbp-0x1c],eax
mov eax,[ebx+0x18]
mov [rbp-0x18],eax
movsx eax,BYTE PTR [rbp+40]
sar eax,1
lea eax,[eax+eax*2]
mov edx,[ebx+0x10]
mov ecx,[edx+eax*2]
mov [rbp-0x8],ecx
mov cx,[edx+eax*2+0x4]
mov [rbp-0x4],cx
test BYTE PTR [rbp+40],0x1
jz JUMP_002463
movsx eax,BYTE PTR [rbp-0x6]
neg eax
mov [rbp-0x14],eax
jmp JUMP_002464
JUMP_002463:
movsx eax,BYTE PTR [rbp-0x6]
mov [rbp-0x14],eax
JUMP_002464:
movsx eax,BYTE PTR [rbp-0x5]
mov [rbp-0x10],eax
movsx eax,BYTE PTR [rbp-0x4]
mov [rbp-0xc],eax
mov eax,[ebx+0x14]
sub eax,[ebx+0x18]
test eax,eax
jnl JUMP_002465
neg eax
mov ecx,eax
sar DWORD PTR [rbp-0x14],cl
mov ecx,eax
sar DWORD PTR [rbp-0x10],cl
mov ecx,eax
sar DWORD PTR [rbp-0xc],cl
jmp JUMP_002466
JUMP_002465:
test eax,eax
jz JUMP_002466
mov ecx,eax
shl DWORD PTR [rbp-0x14],cl
mov ecx,eax
shl DWORD PTR [rbp-0x10],cl
mov ecx,eax
shl DWORD PTR [rbp-0xc],cl
JUMP_002466:
mov eax,[ebx]
sub eax,[rbp-0x14]
mov [rbp-0x14],eax
mov eax,[ebx+0x4]
sub eax,[rbp-0x10]
mov [rbp-0x10],eax
mov eax,[ebx+0x8]
sub eax,[rbp-0xc]
mov [rbp-0xc],eax
cmp BYTE PTR [rbp+48],0x0
jnz JUMP_002467
mov eax,[rbp-0x14]
mov [rbp-0x30],eax
mov eax,[rbp-0x10]
mov [rbp-0x2c],eax
mov eax,[rbp-0xc]
mov [rbp-0x28],eax
jmp JUMP_002477
JUMP_002467:
mov al,[rbp+48]
test al,0x20
jz JUMP_002468
neg DWORD PTR [rbp-0x14]
JUMP_002468:
test al,0x10
jz JUMP_002469
neg DWORD PTR [rbp-0x10]
JUMP_002469:
test al,0x8
jz JUMP_002470
neg DWORD PTR [rbp-0xc]
JUMP_002470:
mov al,[rbp+48]
and eax,+0x7
cmp eax,+0x5
ja JUMP_002477
mov eax,DWORD PTR [eax*4+DATA_000028]
jmp rax
DATA_000028:
.long JUMP_002471
.long JUMP_002472
.long JUMP_002473
.long JUMP_002474
.long JUMP_002475
.long JUMP_002476
JUMP_002471:
mov eax,[rbp-0x14]
mov [rbp-0x30],eax
mov eax,[rbp-0x10]
mov [rbp-0x2c],eax
mov eax,[rbp-0xc]
mov [rbp-0x28],eax
jmp JUMP_002477
JUMP_002472:
mov eax,[rbp-0x14]
mov [rbp-0x2c],eax
mov eax,[rbp-0x10]
mov [rbp-0x28],eax
mov eax,[rbp-0xc]
mov [rbp-0x30],eax
jmp JUMP_002477
JUMP_002473:
mov eax,[rbp-0x14]
mov [rbp-0x28],eax
mov eax,[rbp-0x10]
mov [rbp-0x30],eax
mov eax,[rbp-0xc]
mov [rbp-0x2c],eax
jmp JUMP_002477
JUMP_002474:
mov eax,[rbp-0x14]
mov [rbp-0x28],eax
mov eax,[rbp-0x10]
mov [rbp-0x2c],eax
mov eax,[rbp-0xc]
mov [rbp-0x30],eax
jmp JUMP_002477
JUMP_002475:
mov eax,[rbp-0x14]
mov [rbp-0x2c],eax
mov eax,[rbp-0x10]
mov [rbp-0x30],eax
mov eax,[rbp-0xc]
mov [rbp-0x28],eax
jmp JUMP_002477
JUMP_002476:
mov eax,[rbp-0x14]
mov [rbp-0x30],eax
mov eax,[rbp-0x10]
mov [rbp-0x28],eax
mov eax,[rbp-0xc]
mov [rbp-0x2c],eax
JUMP_002477:
mov eax,[rbp+56]
push rax
mov eax,[rbp+64]
push rax
mov eax,[esi+0x34]
push rax
lea eax,[rbp-0x30]
push rax
mov eax,[rbp+16]
push rax
call FUNC_000582
add rsp,40
movsx eax,al
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001538:
 cmp DWORD PTR [rsp+8],37
 jne failed
 mov eax,OFFSET FLAT:descriptor
 ret
FUNC_000582:
 push rbp
 mov rbp,rsp
 mov esi,DWORD PTR [rbp+24]
 mov eax,DWORD PTR [rsi]
 mov DWORD PTR [output+36],eax
 mov eax,DWORD PTR [rsi+4]
 mov DWORD PTR [output+40],eax
 mov eax,DWORD PTR [rsi+8]
 mov DWORD PTR [output+44],eax
 mov eax,DWORD PTR [rsi+20]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [rsi+24]
 mov DWORD PTR [output+32],eax
 mov eax,DWORD PTR [rsi+12]
 mov edx,OFFSET FLAT:normals
 add edx,DWORD PTR [input+1190]
 cmp eax,edx
 jne failed
 mov DWORD PTR [output+12],1
 mov eax,DWORD PTR [rsi+16]
 mov edx,OFFSET FLAT:newvertices
 add edx,DWORD PTR [input+1186]
 cmp eax,edx
 jne failed
 mov DWORD PTR [output+16],2
 mov eax,DWORD PTR [rbp+32]
 cmp eax,OFFSET FLAT:program
 jne failed
 mov DWORD PTR [output+20],3
 mov eax,DWORD PTR [rbp+40]
 cmp eax,OFFSET FLAT:body
 jne failed
 mov eax,DWORD PTR [rbp+48]
 mov DWORD PTR [output+24],eax
 mov edi,DWORD PTR [rbp+16]
 mov al,BYTE PTR [input+1182]
 mov BYTE PTR [rdi],al
 mov eax,DWORD PTR [input+1178]
 pop rbp
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
 mov edx,1216
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,1216
 jne read_more
 cld
 mov edi,OFFSET FLAT:output
 mov ecx,1280
 mov al,0xa5
 rep stosb
 mov DWORD PTR [output],0x54524e53
 mov rax,0xa5a5a5a5a5a5a5a5
 mov QWORD PTR [oldcontext_guard_a],rax
 mov QWORD PTR [oldcontext_guard_b],rax
 mov QWORD PTR [context_before_guard_a],rax
 mov QWORD PTR [context_before_guard_b],rax
 mov QWORD PTR [descriptor_guard_a],rax
 mov QWORD PTR [descriptor_guard_b],rax
 mov QWORD PTR [descriptor_before_guard_a],rax
 mov QWORD PTR [descriptor_before_guard_b],rax
 mov QWORD PTR [oldnormals_guard_a],rax
 mov QWORD PTR [oldnormals_guard_b],rax
 mov QWORD PTR [oldvertices_guard_a],rax
 mov QWORD PTR [oldvertices_guard_b],rax
 mov QWORD PTR [newvertices_guard_a],rax
 mov QWORD PTR [newvertices_guard_b],rax
 mov QWORD PTR [normals_guard_a],rax
 mov QWORD PTR [normals_guard_b],rax
 mov QWORD PTR [program_guard_a],rax
 mov QWORD PTR [program_guard_b],rax
 mov QWORD PTR [body_guard_a],rax
 mov QWORD PTR [body_guard_b],rax
 mov QWORD PTR [primitive_guard_a],rax
 mov QWORD PTR [primitive_guard_b],rax
 mov esi,OFFSET FLAT:input+36
 mov edi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:input+104
 mov edi,OFFSET FLAT:oldvertices
 mov ecx,384
 rep movsb
 mov esi,OFFSET FLAT:input+488
 mov edi,OFFSET FLAT:normals
 mov ecx,96
 rep movsb
 mov esi,OFFSET FLAT:input+584
 mov edi,OFFSET FLAT:newvertices
 mov ecx,192
 rep movsb
 mov esi,OFFSET FLAT:input+776
 mov edi,OFFSET FLAT:program
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:input+840
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input
 mov edi,OFFSET FLAT:oldcontext
 mov ecx,12
 rep movsb
 mov DWORD PTR [oldcontext+12],OFFSET FLAT:oldnormals
 mov eax,DWORD PTR [input+20]
 add eax,OFFSET FLAT:oldvertices
 mov DWORD PTR [oldcontext+16],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [oldcontext+20],eax
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [oldcontext+24],eax
 mov eax,DWORD PTR [input+1186]
 add eax,OFFSET FLAT:newvertices
 mov DWORD PTR [descriptor+4],eax
 mov eax,DWORD PTR [input+1190]
 add eax,OFFSET FLAT:normals
 mov DWORD PTR [descriptor+12],eax
 mov DWORD PTR [descriptor+52],OFFSET FLAT:program
 mov esi,OFFSET FLAT:descriptor
 mov edi,OFFSET FLAT:descriptor_before
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:oldcontext
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 rep movsb
 mov BYTE PTR [primitive],0x77
 push OFFSET FLAT:body
 mov eax,DWORD PTR [input+32]
 push rax
 mov eax,DWORD PTR [input+28]
 push rax
 mov eax,DWORD PTR [input+24]
 push rax
 push 37
 push OFFSET FLAT:oldcontext
 push OFFSET FLAT:primitive
 call FUNC_000580
 add rsp,56
 mov DWORD PTR [output+4],eax
 movzx eax,BYTE PTR [primitive]
 mov DWORD PTR [output+8],eax
 mov rax,0xa5a5a5a5a5a5a5a5
 cmp QWORD PTR [oldcontext_guard_a],rax
 jne failed
 cmp QWORD PTR [oldcontext_guard_b],rax
 jne failed
 cmp QWORD PTR [context_before_guard_a],rax
 jne failed
 cmp QWORD PTR [context_before_guard_b],rax
 jne failed
 cmp QWORD PTR [descriptor_guard_a],rax
 jne failed
 cmp QWORD PTR [descriptor_guard_b],rax
 jne failed
 cmp QWORD PTR [descriptor_before_guard_a],rax
 jne failed
 cmp QWORD PTR [descriptor_before_guard_b],rax
 jne failed
 cmp QWORD PTR [oldnormals_guard_a],rax
 jne failed
 cmp QWORD PTR [oldnormals_guard_b],rax
 jne failed
 cmp QWORD PTR [oldvertices_guard_a],rax
 jne failed
 cmp QWORD PTR [oldvertices_guard_b],rax
 jne failed
 cmp QWORD PTR [newvertices_guard_a],rax
 jne failed
 cmp QWORD PTR [newvertices_guard_b],rax
 jne failed
 cmp QWORD PTR [normals_guard_a],rax
 jne failed
 cmp QWORD PTR [normals_guard_b],rax
 jne failed
 cmp QWORD PTR [program_guard_a],rax
 jne failed
 cmp QWORD PTR [program_guard_b],rax
 jne failed
 cmp QWORD PTR [body_guard_a],rax
 jne failed
 cmp QWORD PTR [body_guard_b],rax
 jne failed
 cmp QWORD PTR [primitive_guard_a],rax
 jne failed
 cmp QWORD PTR [primitive_guard_b],rax
 jne failed
 mov esi,OFFSET FLAT:descriptor
 mov edi,OFFSET FLAT:descriptor_before
 mov ecx,68
 repe cmpsb
 jne failed
 mov esi,OFFSET FLAT:oldcontext
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 repe cmpsb
 jne failed
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+48
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:oldvertices
 mov edi,OFFSET FLAT:output+386
 mov ecx,384
 rep movsb
 mov esi,OFFSET FLAT:newvertices
 mov edi,OFFSET FLAT:output+770
 mov ecx,192
 rep movsb
 mov esi,OFFSET FLAT:normals
 mov edi,OFFSET FLAT:output+962
 mov ecx,96
 rep movsb
 mov esi,OFFSET FLAT:program
 mov edi,OFFSET FLAT:output+1058
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:input+36
 mov edi,OFFSET FLAT:output+1122
 mov ecx,68
 rep movsb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,1280
 syscall
 cmp eax,1280
 jne failed
 jmp next_case
failed:
 mov eax,60
 mov edi,9
 syscall
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .data
.balign 8
DATA_007756: .quad FUNC_001538
.section .bss
.balign 16
input: .zero 1216
output: .zero 1280
oldcontext_guard_a: .zero 8
oldcontext: .zero 28
oldcontext_guard_b: .zero 8
context_before_guard_a: .zero 8
context_before: .zero 28
context_before_guard_b: .zero 8
descriptor_guard_a: .zero 8
descriptor: .zero 68
descriptor_guard_b: .zero 8
descriptor_before_guard_a: .zero 8
descriptor_before: .zero 68
descriptor_before_guard_b: .zero 8
oldnormals_guard_a: .zero 8
oldnormals: .zero 6
oldnormals_guard_b: .zero 8
oldvertices_guard_a: .zero 8
oldvertices: .zero 384
oldvertices_guard_b: .zero 8
newvertices_guard_a: .zero 8
newvertices: .zero 192
newvertices_guard_b: .zero 8
normals_guard_a: .zero 8
normals: .zero 96
normals_guard_b: .zero 8
program_guard_a: .zero 8
program: .zero 64
program_guard_b: .zero 8
body_guard_a: .zero 8
body: .zero 338
body_guard_b: .zero 8
primitive_guard_a: .zero 8
primitive: .zero 1
primitive_guard_b: .zero 8
.balign 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
