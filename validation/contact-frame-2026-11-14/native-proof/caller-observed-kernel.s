.intel_syntax noprefix
.code64
.section .text
FUNC_000569:
push rbp
mov rbp,rsp
mov BYTE PTR [DATA_008700],0xff
mov eax,[rbp+64]
push rax
mov eax,[rbp+56]
push rax
mov eax,[rbp+48]
push rax
mov eax,[rbp+40]
push rax
mov eax,[rbp+32]
push rax
mov eax,[rbp+24]
push rax
mov eax,[rbp+16]
push rax
call FUNC_000570
add rsp,56
pop rbp
ret
FUNC_000570:
push rbp
mov rbp,rsp
add rsp,-56
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov BYTE PTR [DATA_008696],0x0
mov BYTE PTR [DATA_008697],0x0
mov BYTE PTR [DATA_008698],0x0
mov BYTE PTR [DATA_008701],0x0
mov DWORD PTR [DATA_008703],0xffffffff
mov BYTE PTR [DATA_008707],0x0
mov al,[ebx+0x56]
test al,al
jz JUMP_002393
mov edx,[rbp+24]
push rdx
and eax,0xff
push rax
mov eax,DWORD PTR [DATA_007754]
call rax
add rsp,16
mov esi,eax
mov [DATA_008702],esi
push rsi
lea esi,[ebx+0x3e]
lea edi,[rbp-0x20]
mov ecx,0x6
rep movsd
pop rsi
push rsi
push rbx
lea eax,[rbp-0x20]
push rax
call FUNC_000575
add rsp,24
mov [rbp-0x1],al
mov edx,[ebx+0x148]
test edx,edx
jz JUMP_002391
mov eax,[DATA_009155]
sar eax,1
jns JUMP_002389
adc eax,+0x0
JUMP_002389:
cmp eax,edx
jg JUMP_002390
sub [ebx+0x148],eax
jmp JUMP_002393
JUMP_002390:
xor eax,eax
mov [ebx+0x148],eax
jmp JUMP_002393
JUMP_002391:
test BYTE PTR [rbp-0x1],0x2
jz JUMP_002392
cmp BYTE PTR [ebx+0x57],0x0
jnz JUMP_002393
push rsi
push rbx
call FUNC_000572
add rsp,16
mov DWORD PTR [ebx+0x148],0x7f
jmp JUMP_002393
JUMP_002392:
cmp BYTE PTR [ebx+0x57],0x0
jz JUMP_002393
push rsi
push rbx
call FUNC_000573
add rsp,16
mov DWORD PTR [ebx+0x148],0x7f
JUMP_002393:
mov eax,[rbp+40]
mov dl,[ebx+0x56]
mov [eax],dl
mov al,[DATA_008696]
mov [rbp-0x1],al
mov edi,0x72
mov eax,[rbp+24]
add eax,+0x72
mov [rbp-0x8],eax
JUMP_002394:
mov eax,[rbp-0x8]
test BYTE PTR [eax],0x4
jz JUMP_002398
xor eax,eax
mov al,[ebx+0x86]
cmp edi,eax
jz JUMP_002398
mov eax,[rbp+24]
push rax
push rdi
mov eax,DWORD PTR [DATA_007754]
call rax
add rsp,16
mov esi,eax
cmp BYTE PTR [esi+0x8b],0x0
jnz JUMP_002398
mov eax,[rbp+40]
movsx eax,BYTE PTR [eax]
xor edx,edx
mov dl,[esi+0x56]
cmp eax,edx
jnz JUMP_002398
cmp DWORD PTR [esi+0x82],0x99
jnz JUMP_002395
cmp DWORD PTR [ebx+0x82],0x99
jnz JUMP_002398
JUMP_002395:
mov al,[ebx+0x57]
cmp al,[esi+0x57]
jz JUMP_002396
push rbx
lea eax,[rbp-0x20]
push rax
mov eax,DWORD PTR [DATA_007802]
call rax
add rsp,16
push rsi
lea eax,[rbp-0x38]
push rax
mov eax,DWORD PTR [DATA_007802]
call rax
add rsp,16
lea eax,[rbp-0x38]
push rax
lea eax,[rbp-0x20]
push rax
call FUNC_001662
add rsp,16
jmp JUMP_002397
JUMP_002396:
push rsi
push rdi
lea esi,[ebx+0x3e]
lea edi,[rbp-0x20]
mov ecx,0x6
rep movsd
pop rdi
pop rsi
lea eax,[esi+0x3e]
push rax
lea eax,[rbp-0x20]
push rax
call FUNC_001662
add rsp,16
JUMP_002397:
push rsi
push rbx
lea eax,[rbp-0x20]
push rax
call FUNC_000575
add rsp,24
JUMP_002398:
dec edi
dec DWORD PTR [rbp-0x8]
test edi,edi
jg JUMP_002394
mov al,[rbp-0x1]
or [DATA_008696],al
cmp DWORD PTR [DATA_008704],+0x0
jnz JUMP_002399
cmp DWORD PTR [DATA_008703],+0x0
jnl JUMP_002400
JUMP_002399:
mov eax,[rbp+56]
mov DWORD PTR [eax],0xffffffff
jmp JUMP_002401
JUMP_002400:
mov eax,[rbp+56]
mov edx,[DATA_008703]
mov [eax],edx
JUMP_002401:
mov eax,[rbp+48]
mov edx,[DATA_008702]
mov [eax],edx
mov al,[DATA_008701]
and al,0x1f
mov edx,[rbp+64]
mov [edx],al
mov eax,[rbp+40]
mov dl,[DATA_008698]
mov [eax],dl
mov eax,[rbp+32]
mov dl,[DATA_008696]
mov [eax],dl
mov al,[DATA_008696]
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001335:
push rbp
mov rbp,rsp
mov edx,[rbp+16]
mov eax,[rbp+24]
sub eax,[rbp+40]
mov [edx],eax
mov eax,[rbp+32]
sbb eax,[rbp+48]
mov [edx+0x4],eax
pop rbp
ret
FUNC_001532:
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
FUNC_001662:
push rbp
mov rbp,rsp
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
push QWORD PTR [rsi+0x4]
push QWORD PTR [rsi]
push QWORD PTR [rbx+0x4]
push QWORD PTR [rbx]
push rbx
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0xc]
push QWORD PTR [rsi+0x8]
push QWORD PTR [rbx+0xc]
push QWORD PTR [rbx+0x8]
lea eax,[ebx+0x8]
push rax
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0x14]
push QWORD PTR [rsi+0x10]
push QWORD PTR [rbx+0x14]
push QWORD PTR [rbx+0x10]
add ebx,+0x10
push rbx
call FUNC_001335
add rsp,40
pop rsi
pop rbx
pop rbp
ret

.global _start
_start:
 mov esp,OFFSET FLAT:caller_stack_end
 cld
caller_next:
 xor r8d,r8d
caller_read:
 xor eax,eax
 xor edi,edi
 lea rsi,[caller_input+r8]
 mov edx,96
 sub edx,r8d
 syscall
 test eax,eax
 jle caller_done
 add r8d,eax
 cmp r8d,96
 jne caller_read
 mov edi,OFFSET FLAT:caller_bank
 xor eax,eax
 mov ecx,86644
 rep stosb
 mov edi,OFFSET FLAT:caller_body
 mov ecx,338
 rep stosb
 mov edi,OFFSET FLAT:caller_output
 mov ecx,64
 rep stosd
 mov edi,OFFSET FLAT:caller_primary
 mov DWORD PTR [rdi],0x7fffffff
 mov DWORD PTR [rdi+16],0x7fffffff
 mov DWORD PTR [rdi+32],0x7fffffff
 mov BYTE PTR [rdi+0x86],1
 mov edi,OFFSET FLAT:caller_candidate
 mov BYTE PTR [rdi+0x86],2
 mov eax,DWORD PTR [caller_input+88]
 mov BYTE PTR [rdi+0x56],al
 mov eax,DWORD PTR [caller_input+12]
 mov BYTE PTR [rdi+0x57],al
 mov esi,OFFSET FLAT:caller_input+64
 add edi,0x3e
 mov ecx,6
 rep movsd
 mov esi,OFFSET FLAT:caller_input+40
 mov edi,OFFSET FLAT:caller_primary+0x3e
 mov ecx,6
 rep movsd
 mov esi,OFFSET FLAT:caller_input+16
 mov edi,OFFSET FLAT:caller_body+0x3e
 mov ecx,6
 rep movsd
 mov BYTE PTR [caller_body+0x86],3
 mov eax,DWORD PTR [caller_input+4]
 mov BYTE PTR [caller_body+0x56],al
 mov eax,DWORD PTR [caller_input+8]
 mov BYTE PTR [caller_body+0x57],al
 mov DWORD PTR [caller_body+0x148],1
 mov eax,DWORD PTR [caller_input+92]
 mov BYTE PTR [caller_bank+2],al
 mov DWORD PTR [caller_count],0
 mov DWORD PTR [DATA_009155],0
 push OFFSET FLAT:caller_primitive
 push OFFSET FLAT:caller_height
 push OFFSET FLAT:caller_collider
 push OFFSET FLAT:caller_ref
 push OFFSET FLAT:caller_flags
 push OFFSET FLAT:caller_bank
 push OFFSET FLAT:caller_body
 call FUNC_000569
 lea rsp,[rsp+56]
 movzx eax,al
 mov DWORD PTR [caller_output],eax
 mov eax,DWORD PTR [caller_count]
 mov DWORD PTR [caller_output+4],eax
 mov esi,OFFSET FLAT:caller_body+0x3e
 mov edi,OFFSET FLAT:caller_output+8
 mov ecx,6
 rep movsd
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:caller_output
 mov edx,256
 syscall
 jmp caller_next
caller_done:
 mov eax,60
 xor edi,edi
 syscall
FUNC_000575:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov ebx,DWORD PTR [caller_count]
 cmp ebx,2
 jae caller_bad
 shl ebx,5
 add ebx,OFFSET FLAT:caller_output+32
 mov esi,DWORD PTR [rbp+16]
 mov edi,ebx
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [rbp+24]
 movzx eax,BYTE PTR [eax+0x86]
 mov DWORD PTR [rbx+24],eax
 mov eax,DWORD PTR [rbp+32]
 movzx eax,BYTE PTR [eax+0x86]
 mov DWORD PTR [rbx+28],eax
 inc DWORD PTR [caller_count]
 xor eax,eax
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
caller_bad:
 mov eax,60
 mov edi,109
 syscall
FUNC_000572:
 mov eax,60
 mov edi,110
 syscall
FUNC_000573:
 mov eax,60
 mov edi,111
 syscall
FUNC_001677:
 mov eax,60
 mov edi,112
 syscall
.section .data
DATA_007754: .long FUNC_001532
DATA_007802: .long FUNC_001677
DATA_008696: .byte 0
DATA_008697: .byte 0
DATA_008698: .byte 0
DATA_008700: .byte 0
DATA_008701: .byte 0
DATA_008702: .long 0
DATA_008703: .long 0
DATA_008704: .long 0
DATA_008707: .byte 0
DATA_009155: .long 0
.section .bss
caller_input: .zero 96
caller_output: .zero 256
caller_body: .zero 338
caller_bank: .zero 86644
.set caller_primary,caller_bank+454
.set caller_candidate,caller_bank+792
caller_count: .zero 4
caller_primitive: .zero 4
caller_height: .zero 4
caller_collider: .zero 4
caller_ref: .zero 4
caller_flags: .zero 4
.balign 16
caller_stack: .zero 1048576
caller_stack_end:
