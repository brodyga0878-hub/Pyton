.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000928:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov edx,[rbp+32]
mov esi,[rbp+16]
mov ebx,0x72
lea edi,[esi+0x977e]
lea eax,[esi+0x72]
JUMP_003878:
cmp BYTE PTR [eax],0x0
jnz JUMP_003880
mov [eax],dl
test dl,0x20
jz JUMP_003879
inc DWORD PTR [DATA_008834]
JUMP_003879:
mov eax,[rbp+48]
mov [eax],ebx
mov eax,[rbp+40]
push rax
mov eax,[rbp+24]
push rax
lea eax,[ebx+ebx*4]
lea eax,[ebx+eax*4]
lea eax,[ebx+eax*8]
add eax,eax
add eax,esi
add eax,+0x74
push rax
call QWORD PTR [DATA_007755]
add rsp,24
mov [edi],bl
lea eax,[ebx+ebx*4]
lea eax,[ebx+eax*4]
lea eax,[ebx+eax*8]
add eax,eax
add eax,esi
add eax,+0x74
jmp JUMP_003884
JUMP_003880:
dec ebx
add edi,0xfffffeae
dec eax
test ebx,ebx
jg JUMP_003878
mov ebx,0x72
lea edi,[esi+0x977e]
lea eax,[esi+0x72]
JUMP_003881:
test BYTE PTR [eax],0x20
jz JUMP_003883
dec DWORD PTR [DATA_008834]
mov [eax],dl
test dl,0x20
jz JUMP_003882
inc DWORD PTR [DATA_008834]
JUMP_003882:
mov eax,[rbp+48]
mov [eax],ebx
mov eax,[rbp+40]
push rax
mov eax,[rbp+24]
push rax
lea eax,[ebx+ebx*4]
lea eax,[ebx+eax*4]
lea eax,[ebx+eax*8]
add eax,eax
add eax,esi
add eax,+0x74
push rax
call QWORD PTR [DATA_007755]
add rsp,24
mov [edi],bl
lea eax,[ebx+ebx*4]
lea eax,[ebx+eax*4]
lea eax,[ebx+eax*8]
add eax,eax
add eax,esi
add eax,+0x74
jmp JUMP_003884
JUMP_003883:
dec ebx
add edi,0xfffffeae
dec eax
test ebx,ebx
jg JUMP_003881
mov eax,[rbp+48]
xor edx,edx
mov [eax],edx
xor eax,eax
JUMP_003884:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000924:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov eax,[rbp+16]
movzx edi,BYTE PTR [eax+0x86]
mov eax,[DATA_007758]
test BYTE PTR [eax+edi],0x20
jz JUMP_003860
dec DWORD PTR [DATA_008834]
mov BYTE PTR [eax+edi],0x0
jmp JUMP_003864
JUMP_003860:
xor ebx,ebx
mov esi,OFFSET FLAT:DATA_008623
jmp JUMP_003863
JUMP_003861:
test BYTE PTR [esi],0x4
jz JUMP_003862
xor eax,eax
mov [rbp-0xc],eax
mov eax,[rbp+16]
mov [rbp-0x8],eax
mov eax,edi
mov [rbp-0x4],al
mov al,[rbp+24]
mov [rbp-0x3],al
lea eax,[rbp-0xc]
push rax
push +0xb
push rbx
call FUNC_000144
add rsp,24
JUMP_003862:
inc ebx
add esi,+0x8
JUMP_003863:
cmp ebx,[DATA_008621]
jng JUMP_003861
mov eax,[DATA_007758]
mov BYTE PTR [eax+edi],0x0
JUMP_003864:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000925:
push rbp
mov rbp,rsp
push +0x0
mov eax,[rbp+16]
push rax
call FUNC_000924
add rsp,16
pop rbp
ret
FUNC_001533:
push rbp
mov rbp,rsp
push rcx
push rbx
push rsi
push rdi
mov esi,[rbp+32]
mov eax,[rbp+24]
mov ebx,[rbp+16]
movzx edi,BYTE PTR [ebx+0x86]
cmp eax,ebx
jz JUMP_005711
push 0x152
push rax
push rbx
call _memcpy
add rsp,24
test esi,esi
jz JUMP_005710
mov eax,edi
mov [ebx+0x86],al
jmp JUMP_005711
JUMP_005710:
mov BYTE PTR [ebx+0x86],0x0
JUMP_005711:
test esi,esi
jz JUMP_005718
mov eax,[DATA_008804]
mov [ebx+0xa8],eax
mov eax,[DATA_008807]
mov [ebx+0xac],eax
mov [ebx+0x82],esi
push rsi
call FUNC_001538
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
mov BYTE PTR [ebx+0x151],0x0
mov BYTE PTR [ebx+0x25],0x0
mov BYTE PTR [ebx+0x124],0x0
xor edx,edx
mov dl,[esi+0x24]
sar edx,0x4
and dl,0x7
mov eax,[esi+0x34]
test eax,eax
jz JUMP_005712
cmp BYTE PTR [eax],0x0
jz JUMP_005712
mov al,0x80
jmp JUMP_005713
JUMP_005712:
xor eax,eax
JUMP_005713:
or dl,al
mov [ebx+0x14c],dl
mov BYTE PTR [ebx+0x88],0xff
mov eax,[esi+0x38]
test eax,eax
jz JUMP_005718
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
jl JUMP_005714
mov BYTE PTR [ebx+0x101],0x2
jmp JUMP_005716
JUMP_005714:
cmp WORD PTR [ebx+0xbc],0xaa5
jl JUMP_005715
mov BYTE PTR [ebx+0x101],0x1
jmp JUMP_005716
JUMP_005715:
mov BYTE PTR [ebx+0x101],0x0
JUMP_005716:
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
jnl JUMP_005717
mov edx,esi
mov [ebx+0xd0],dl
movsx edx,dl
sub eax,[edx*4+DATA_007210]
JUMP_005717:
mov [ebx+0x116],ax
mov WORD PTR [ebx+0xe0],0x0
mov WORD PTR [ebx+0xe2],0x0
JUMP_005718:
pop rdi
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
FUNC_000144:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [event_count]
 cmp eax,DWORD PTR [input+40]
 jae event_error
 imul ebx,eax,39194
 add ebx,OFFSET FLAT:output+39728
 imul eax,eax,344
 add eax,OFFSET FLAT:input+39660
 mov DWORD PTR [reply_ptr],eax
 mov ecx,DWORD PTR [rbp+16]
 cmp ecx,DWORD PTR [eax]
 jne event_error
 mov DWORD PTR [ebx],ecx
 mov ecx,DWORD PTR [rbp+24]
 mov DWORD PTR [ebx+4],ecx
 mov edx,DWORD PTR [rbp+32]
 mov ecx,DWORD PTR [edx]
 mov DWORD PTR [ebx+8],ecx
 mov ecx,DWORD PTR [edx+4]
 sub ecx,OFFSET FLAT:bank
 mov DWORD PTR [ebx+12],ecx
 movzx ecx,BYTE PTR [edx+8]
 mov DWORD PTR [ebx+16],ecx
 movzx ecx,BYTE PTR [edx+9]
 mov DWORD PTR [ebx+20],ecx
 mov ecx,DWORD PTR [DATA_008834]
 mov DWORD PTR [ebx+24],ecx
 mov ecx,DWORD PTR [DATA_008621]
 mov DWORD PTR [ebx+28],ecx
 lea edi,[ebx+40]
 mov esi,OFFSET FLAT:bank
 mov ecx,38986
 rep movsb
 mov esi,OFFSET FLAT:DATA_008623
 mov ecx,168
 rep movsb
 mov ebx,DWORD PTR [reply_ptr]
 mov eax,DWORD PTR [ebx+4]
 mov DWORD PTR [DATA_008834],eax
 mov eax,DWORD PTR [ebx+8]
 mov DWORD PTR [DATA_008621],eax
 mov edx,DWORD PTR [ebx+12]
 lea esi,[ebx+24]
bank_patch_loop:
 test edx,edx
 jz module_patches
 mov edi,DWORD PTR [esi]
 add edi,OFFSET FLAT:bank
 mov ecx,DWORD PTR [esi+4]
 push rsi
 add esi,8
 rep movsb
 pop rsi
 add esi,24
 dec edx
 jmp bank_patch_loop
module_patches:
 mov edx,DWORD PTR [ebx+16]
 lea esi,[ebx+216]
module_patch_loop:
 test edx,edx
 jz event_done
 mov edi,DWORD PTR [esi]
 add edi,OFFSET FLAT:DATA_008623
 mov ecx,DWORD PTR [esi+4]
 push rsi
 add esi,8
 rep movsb
 pop rsi
 add esi,16
 dec edx
 jmp module_patch_loop
event_error:
 mov DWORD PTR [native_error],1
 mov DWORD PTR [DATA_008621],-1
event_done:
 inc DWORD PTR [event_count]
 pop rdi
 pop rsi
 pop rbx
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
 add esi,r8d
 mov edx,46884
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,46884
 jne read_more
 cld
 mov edi,OFFSET FLAT:guard_begin
 mov ecx,guard_end-guard_begin
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,39728+21*39194
 xor eax,eax
 rep stosb
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:bank
 mov ecx,38986
 rep movsb
 mov edi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:DATA_008623
 mov ecx,168
 rep movsb
 mov edi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [DATA_008834],eax
 mov eax,DWORD PTR [input+28]
 mov DWORD PTR [DATA_008621],eax
 mov eax,DWORD PTR [input+32]
 mov DWORD PTR [DATA_008804],eax
 mov eax,DWORD PTR [input+36]
 mov DWORD PTR [DATA_008807],eax
 mov eax,DWORD PTR [input+39648]
 mov BYTE PTR [collision],al
 mov DWORD PTR [descriptor+0x34],0
 cmp DWORD PTR [input+39648+4],0
 je collision_ready
 mov DWORD PTR [descriptor+0x34],OFFSET FLAT:collision
collision_ready:
 mov DWORD PTR [descriptor+0x38],0
 cmp DWORD PTR [input+39648+8],0
 je physical_ready
 mov DWORD PTR [descriptor+0x38],OFFSET FLAT:physical
physical_ready:
 mov edi,OFFSET FLAT:DATA_004681
 mov ecx,149
 mov eax,OFFSET FLAT:descriptor
 rep stosd
 mov DWORD PTR [native_error],0
 mov DWORD PTR [copy_calls],0
 mov DWORD PTR [lookup_calls],0
 mov DWORD PTR [event_count],0
 mov DWORD PTR [selected],0
 mov DWORD PTR [return_offset],0xffffffff
 cmp DWORD PTR [input],0
 jne free_operation
 mov eax,DWORD PTR [input+12]
 cmp eax,-1
 je external_source
 imul eax,eax,338
 add eax,OFFSET FLAT:bank+116
 jmp source_ready
external_source:
 mov eax,OFFSET FLAT:source
source_ready:
 push OFFSET FLAT:selected
 mov ecx,DWORD PTR [input+4]
 push rcx
 mov ecx,DWORD PTR [input+8]
 push rcx
 push rax
 push OFFSET FLAT:bank
 call FUNC_000928
 add rsp,40
 test eax,eax
 jz execute_done
 sub eax,OFFSET FLAT:bank
 mov DWORD PTR [return_offset],eax
 jmp execute_done
free_operation:
 mov eax,DWORD PTR [input+16]
 imul eax,eax,338
 add eax,OFFSET FLAT:bank+116
 cmp DWORD PTR [input],2
 je free_zero
 mov ecx,DWORD PTR [input+20]
 push rcx
 push rax
 call FUNC_000924
 add rsp,16
 jmp execute_done
free_zero:
 push rax
 call FUNC_000925
 add rsp,8
execute_done:
 mov eax,DWORD PTR [input+39556+0x34]
 mov DWORD PTR [descriptor+0x34],eax
 mov eax,DWORD PTR [input+39556+0x38]
 mov DWORD PTR [descriptor+0x38],eax
 mov DWORD PTR [output],0x928924aa
 mov eax,DWORD PTR [event_count]
 imul eax,eax,39194
 add eax,39728
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [selected]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [DATA_008834]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [DATA_008621]
 mov DWORD PTR [output+16],eax
 mov eax,DWORD PTR [event_count]
 mov DWORD PTR [output+20],eax
 mov eax,DWORD PTR [native_error]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [copy_calls]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [lookup_calls]
 mov DWORD PTR [output+32],eax
 mov eax,DWORD PTR [return_offset]
 mov DWORD PTR [output+36],eax
 mov edi,OFFSET FLAT:output+64
 mov esi,OFFSET FLAT:bank
 mov ecx,38986
 rep movsb
 mov esi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:DATA_008623
 mov ecx,168
 rep movsb
 mov esi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:bank_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:bank_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:table_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:table_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:desc_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:desc_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,DWORD PTR [output+4]
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
DATA_007755: .quad FUNC_001533
DATA_007734: .quad FUNC_001495
DATA_007758: .long bank
DATA_007210: .long 0,4,10,25,45,80,150,250,400,600,6,12,24,36,0
DATA_008834: .long 0
DATA_008621: .long 0
DATA_008804: .long 0
DATA_008807: .long 0
.section .bss
.balign 16
input: .zero 46884
output: .zero 39728+21*39194
guard_begin:
bank_before: .zero 8
bank: .zero 38986
bank_after: .zero 8
source_before: .zero 8
source: .zero 338
source_after: .zero 8
table_before: .zero 8
DATA_008623: .zero 168
table_after: .zero 8
desc_before: .zero 8
descriptor: .zero 68
desc_after: .zero 8
physical_before: .zero 8
physical: .zero 24
physical_after: .zero 8
guard_end:
collision: .zero 1
copy_calls: .zero 4
lookup_calls: .zero 4
event_count: .zero 4
native_error: .zero 4
selected: .zero 4
return_offset: .zero 4
reply_ptr: .zero 4
DATA_004681: .zero 596
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
