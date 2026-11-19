.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000036:
push rbp
mov rbp,rsp
push rcx
push rbx
push rsi
mov eax,[rbp+24]
mov ebx,[rbp+16]
mov [ebx+0x82],eax
push rax
call QWORD PTR [DATA_007756]
pop rcx
mov esi,eax
mov ax,[esi+0x2c]
mov [rbp-0x4],ax
mov ax,[esi+0x14]
add ax,[esi+0x18]
add ax,+0x7
mov [rbp-0x2],ax
mov eax,[rbp-0x4]
push rax
lea eax,[ebx+0x138]
push rax
call QWORD PTR [DATA_007734]
add rsp,16
mov ax,[esi+0x30]
mov [rbp-0x4],ax
mov ax,[esi+0x14]
add ax,[esi+0x18]
add ax,+0x7
mov [rbp-0x2],ax
mov eax,[rbp-0x4]
push rax
lea eax,[ebx+0x140]
push rax
call QWORD PTR [DATA_007734]
add rsp,16
xor edx,edx
mov dl,[esi+0x24]
sar edx,0x4
and dl,0x7
mov eax,[esi+0x34]
test eax,eax
jz JUMP_000326
cmp BYTE PTR [eax],0x0
jz JUMP_000326
mov al,0x80
jmp JUMP_000327
JUMP_000326:
xor eax,eax
JUMP_000327:
or dl,al
mov [ebx+0x14c],dl
mov eax,[esi+0x38]
test eax,eax
jz JUMP_000332
mov ax,[eax]
mov [ebx+0xc4],ax
mov eax,[esi+0x38]
mov ax,[eax+0x2]
mov [ebx+0xc6],ax
mov [ebx+0xc2],ax
mov [ebx+0xbe],ax
neg ax
mov [ebx+0xc0],ax
mov edx,eax
mov [ebx+0xbc],dx
cmp dx,0x1329
jl JUMP_000328
mov BYTE PTR [ebx+0x101],0x2
jmp JUMP_000330
JUMP_000328:
cmp WORD PTR [ebx+0xbc],0xaa5
jl JUMP_000329
mov BYTE PTR [ebx+0x101],0x1
jmp JUMP_000330
JUMP_000329:
mov BYTE PTR [ebx+0x101],0x0
JUMP_000330:
mov eax,[esi+0x38]
mov al,[eax+0x4]
mov [ebx+0xd1],al
mov eax,[esi+0x38]
mov ax,[eax+0x6]
shl eax,0x2
mov [ebx+0xe4],ax
mov edx,[esi+0x38]
movsx eax,WORD PTR [edx+0x8]
mov si,[edx+0x14]
test si,si
jnl JUMP_000331
mov edx,esi
mov [ebx+0xd0],dl
movsx edx,dl
sub eax,[edx*4+DATA_007210]
JUMP_000331:
mov [ebx+0x116],ax
JUMP_000332:
pop rsi
pop rbx
pop rcx
pop rbp
ret
FUNC_001538:
pushfq
inc DWORD PTR [lookup_calls]
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov eax,[eax*4+DATA_004681]
pop rbp
ret
FUNC_001495:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
mov ebx,[rbp+16]
movsx eax,WORD PTR [rbp+24]
mov [rbp-0x8],eax
movsx eax,WORD PTR [rbp+24]
sar eax,0x1f
mov [rbp-0x4],eax
movsx eax,WORD PTR [rbp+26]
add eax,-0xf
push rax
lea eax,[rbp-0x8]
push rax
call FUNC_001341
add rsp,16
mov eax,[rbp-0x8]
mov [ebx],eax
mov eax,[rbp-0x4]
mov [ebx+0x4],eax
mov eax,ebx
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_001341:
push rbp
mov rbp,rsp
push rbx
push rsi
mov eax,[rbp+24]
mov edx,[rbp+16]
test eax,eax
jz JUMP_005286
test eax,eax
jnl JUMP_005284
neg eax
cmp eax,+0x20
jnl JUMP_005283
mov ecx,eax
mov ebx,[edx]
shr ebx,cl
mov ecx,0x20
sub ecx,eax
mov esi,[edx+0x4]
shl esi,cl
or ebx,esi
mov [edx],ebx
mov ecx,eax
sar DWORD PTR [edx+0x4],cl
jmp JUMP_005286
JUMP_005283:
lea ecx,[eax-0x20]
mov eax,[edx+0x4]
sar eax,cl
mov [edx],eax
sar DWORD PTR [edx+0x4],0x1f
jmp JUMP_005286
JUMP_005284:
test eax,eax
jng JUMP_005286
cmp eax,+0x20
jnl JUMP_005285
mov ecx,eax
mov ebx,[edx+0x4]
shl ebx,cl
mov ecx,0x20
sub ecx,eax
mov esi,[edx]
shr esi,cl
or ebx,esi
mov [edx+0x4],ebx
mov ecx,eax
shl DWORD PTR [edx],cl
jmp JUMP_005286
JUMP_005285:
lea ecx,[eax-0x20]
mov eax,[edx]
shl eax,cl
mov [edx+0x4],eax
xor eax,eax
mov [edx],eax
JUMP_005286:
pop rsi
pop rbx
pop rbp
ret

_memcpy:
 push rbp
 mov rbp,rsp
 push rsi
 push rdi
 inc DWORD PTR [copy_calls]
 mov edi,DWORD PTR [rbp+16]
 mov esi,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov eax,edi
 cld
 rep movsb
 pop rdi
 pop rsi
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
 mov edx,800
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,800
 jne read_more
 cld
 mov edi,OFFSET FLAT:guarded_before
 mov ecx,832
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+32
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_008804],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [DATA_008807],eax
 mov eax,DWORD PTR [input+24]
 mov BYTE PTR [collision],al
 mov DWORD PTR [copy_calls],0
 mov DWORD PTR [lookup_calls],0
 mov DWORD PTR [descriptor+0x34],0
 cmp DWORD PTR [input+16],0
 je collision_ready
 mov DWORD PTR [descriptor+0x34],OFFSET FLAT:collision
collision_ready:
 mov DWORD PTR [descriptor+0x38],0
 cmp DWORD PTR [input+20],0
 je physical_ready
 mov DWORD PTR [descriptor+0x38],OFFSET FLAT:physical
physical_ready:
 mov edi,OFFSET FLAT:DATA_004681
 mov ecx,466
 mov eax,OFFSET FLAT:descriptor
 rep stosd
 cmp DWORD PTR [input+28],0
 je resource_ready
 mov DWORD PTR [DATA_004681+149*4],0
resource_ready:
 mov eax,DWORD PTR [input+4]
 push rax
 cmp DWORD PTR [input],1
 je lookup_only
 push OFFSET FLAT:body
 call FUNC_000036
 add rsp,16
 mov DWORD PTR [pointer_result],0
 jmp replacement_done
lookup_only:
 call FUNC_001538
 add rsp,8
 test eax,eax
 setnz al
 movzx eax,al
 mov DWORD PTR [pointer_result],eax
replacement_done:
 mov eax,DWORD PTR [input+708+0x34]
 mov DWORD PTR [descriptor+0x34],eax
 mov eax,DWORD PTR [input+708+0x38]
 mov DWORD PTR [descriptor+0x38],eax
 mov DWORD PTR [output],0x1533fac7
 mov DWORD PTR [output+4],0
 mov eax,DWORD PTR [lookup_calls]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [pointer_result]
 mov DWORD PTR [output+12],eax
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+16
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:guarded_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:descriptor_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:descriptor_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,848
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
failed:
 mov edi,99
 jmp leave
finished:
 xor edi,edi
leave:
 mov eax,60
 syscall
.section .data
DATA_007734: .quad FUNC_001495
DATA_007756: .quad FUNC_001538
DATA_007210: .long 0,4,10,25,45,80,150,250,400,600,6,12,24,36,0
DATA_008804: .long 0
DATA_008807: .long 0
.section .bss
.balign 16
input: .zero 800
output: .zero 848
guarded_before: .zero 8
body: .zero 338
body_after: .zero 8
source_before: .zero 8
source: .zero 338
source_after: .zero 8
descriptor_before: .zero 8
descriptor: .zero 68
descriptor_after: .zero 8
physical_before: .zero 8
physical: .zero 24
physical_after: .zero 8
collision: .zero 1
copy_calls: .zero 4
lookup_calls: .zero 4
pointer_result: .zero 4
DATA_004681: .zero 1864
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
