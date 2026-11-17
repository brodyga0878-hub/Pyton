.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_001046:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1046
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
cmp BYTE PTR [ebx+0x14e],0x0
jz JUMP_004318
push +0x0
lea eax,[ebx+0x3e]
push rax
push rbx
call FUNC_000939
add rsp,24
JUMP_004318:
push rbx
call FUNC_001045
pop rcx
cmp BYTE PTR [DATA_009030],0x0
jz JUMP_004327
cmp DWORD PTR [DATA_009116],+0x0
jnl JUMP_004327
cmp WORD PTR [ebx+0xb6],+0x0
jl JUMP_004319
movsx edx,WORD PTR [ebx+0xb6]
jmp JUMP_004320
JUMP_004319:
movsx edx,WORD PTR [ebx+0xb6]
neg edx
JUMP_004320:
cmp WORD PTR [ebx+0xb8],+0x0
jl JUMP_004321
movsx eax,WORD PTR [ebx+0xb8]
jmp JUMP_004322
JUMP_004321:
movsx eax,WORD PTR [ebx+0xb8]
neg eax
JUMP_004322:
cmp WORD PTR [ebx+0xba],+0x0
jl JUMP_004323
movsx ecx,WORD PTR [ebx+0xba]
jmp JUMP_004324
JUMP_004323:
movsx ecx,WORD PTR [ebx+0xba]
neg ecx
JUMP_004324:
cmp edx,eax
jng JUMP_004325
mov eax,edx
JUMP_004325:
cmp ecx,eax
jng JUMP_004326
mov eax,ecx
JUMP_004326:
sub eax,0x221
test eax,eax
jl JUMP_004327
push rbx
mov edx,0x1ae
sub edx,eax
push rdx
push rax
push +0x3
call FUNC_001910
add rsp,32
or WORD PTR [DATA_008860],0x80
JUMP_004327:
pop rbx
pop rbp
ret
FUNC_001033:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1033
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-56
push rbx
push rsi
push rdi
mov ebx,[rbp+32]
mov edi,[rbp+16]
mov esi,OFFSET FLAT:DATA_008804
mov eax,[rbp+48]
push rax
lea eax,[rbp-0x4]
push rax
push rbx
mov eax,[rbp+40]
push rax
lea eax,[rbp-0x5]
push rax
mov eax,[rbp+24]
push rax
push rdi
call QWORD PTR [DATA_006141]
add rsp,56
mov al,[rbp-0x5]
mov [esi+0x212],al
cmp DWORD PTR [rbp-0x4],-0x1
jnz JUMP_004261
mov eax,0x7fffffff
jmp JUMP_004262
JUMP_004261:
mov eax,[rbp-0x4]
JUMP_004262:
mov [esi+0xdc],eax
cmp eax,0xb71b00
jl JUMP_004264
cmp BYTE PTR [esi+0xe8],0x2c
jz JUMP_004266
test BYTE PTR [esi+0xc6],0x40
jz JUMP_004263
cmp BYTE PTR [DATA_008630],0x0
jnl JUMP_004263
call FUNC_001116
JUMP_004263:
or WORD PTR [esi+0xc6],+0x40
jmp JUMP_004266
JUMP_004264:
test BYTE PTR [esi+0xc6],0x40
jz JUMP_004265
cmp BYTE PTR [DATA_008630],0x0
jnl JUMP_004265
call FUNC_001116
JUMP_004265:
and WORD PTR [esi+0xc6],0xffbf
JUMP_004266:
test BYTE PTR [esi+0x212],0x1
jnz JUMP_004267
push rdi
call FUNC_001034
pop rcx
movsx eax,BYTE PTR [esi+0x212]
jmp JUMP_004274
JUMP_004267:
mov eax,[ebx]
mov eax,[eax+0x82]
cmp eax,0x86
jc JUMP_004273
cmp eax,0x94
ja JUMP_004273
test BYTE PTR [edi+0xca],0x10
jz JUMP_004270
cmp DWORD PTR [rbp-0x4],0x1c9c380
jg JUMP_004268
cmp DWORD PTR [esi+0xd8],0x2328
jl JUMP_004268
mov eax,[esi+0x1e8]
cmp eax,[DATA_009155]
jna JUMP_004269
JUMP_004268:
movsx eax,BYTE PTR [esi+0x212]
jmp JUMP_004274
JUMP_004269:
mov eax,[esi+0x120]
cmp eax,[esi+0x118]
jnl JUMP_004270
inc DWORD PTR [esi+0x120]
inc WORD PTR [esi+0x15a]
mov DWORD PTR [rbp-0x38],0x9906
movzx eax,WORD PTR [esi+0x15a]
mov [rbp-0x34],eax
lea eax,[rbp-0x38]
push rax
call FUNC_000349
pop rcx
push 0x8e13
push +0x16
call FUNC_000148
add rsp,16
push +0x11
call FUNC_001906
pop rcx
JUMP_004270:
mov DWORD PTR [esi+0x1e8],0x2468a
mov eax,[ebx]
mov edx,[eax+0x82]
cmp edx,0x89
jc JUMP_004273
mov eax,[esi+0x1ec]
cmp edx,0x8c
jc JUMP_004271
mov edx,[DATA_009155]
shr edx,0x8
jmp JUMP_004272
JUMP_004271:
mov edx,[DATA_009155]
shr edx,0xa
JUMP_004272:
add edx,[esi+0x1ec]
mov [esi+0x1ec],edx
cmp eax,[esi+0x1ec]
jng JUMP_004273
push +0x0
push -0x1
push rdi
call FUNC_000953
add rsp,24
JUMP_004273:
movsx eax,BYTE PTR [esi+0x212]
JUMP_004274:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001034:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1034
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
test BYTE PTR [eax+0xca],0x2
jnz JUMP_004276
cmp WORD PTR [DATA_008900],+0x0
jz JUMP_004275
dec WORD PTR [DATA_008900]
inc WORD PTR [DATA_008898]
JUMP_004275:
cmp WORD PTR [DATA_008899],+0x0
jz JUMP_004276
dec WORD PTR [DATA_008899]
inc WORD PTR [DATA_008897]
JUMP_004276:
pop rbp
ret
FUNC_001045:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1045
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[DATA_008868]
push rax
mov eax,[DATA_008869]
push rax
mov eax,[rbp+16]
push rax
call QWORD PTR [DATA_007744]
add rsp,24
pop rbp
ret
FUNC_001512:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1512
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
lea edx,[eax+0x8c]
push rdx
push QWORD PTR [rbp+32]
push QWORD PTR [rbp+24]
add eax,+0x3e
push rax
call FUNC_001511
add rsp,32
pop rbp
ret
FUNC_001511:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1511
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-36
push rbx
push rsi
push rdi
mov ebx,[rbp+32]
mov edi,[rbp+24]
xor esi,esi
test edi,0x80000000
setnz al
and eax,+0x1
mov [rbp-0x4],eax
cmp DWORD PTR [rbp-0x4],+0x0
jz JUMP_005682
not ebx
inc ebx
not edi
test ebx,ebx
setz al
and eax,+0x1
add edi,eax
JUMP_005682:
shr ebx,0x7
mov eax,edi
shl eax,0x19
or ebx,eax
shr edi,0x7
test edi,edi
jz JUMP_005683
push rdi
call FUNC_001656
pop rcx
mov esi,eax
inc esi
mov ecx,esi
shr ebx,cl
mov ecx,0x20
sub ecx,esi
shl edi,cl
or ebx,edi
JUMP_005683:
push rbx
call FUNC_001656
pop rcx
add eax,-0xe
test eax,eax
jnl JUMP_005684
xor eax,eax
JUMP_005684:
add esi,eax
mov ecx,eax
shr ebx,cl
mov eax,[rbp+40]
mov eax,[eax]
mov [rbp-0xc],eax
mov eax,[rbp+40]
mov eax,[eax]
sar eax,0x1f
mov [rbp-0x8],eax
push rbx
push QWORD PTR [rbp-0x8]
push QWORD PTR [rbp-0xc]
lea eax,[rbp-0x24]
push rax
call FUNC_001338
add rsp,32
mov eax,[rbp+40]
mov eax,[eax+0x4]
mov [rbp-0xc],eax
mov eax,[rbp+40]
mov eax,[eax+0x4]
sar eax,0x1f
mov [rbp-0x8],eax
push rbx
push QWORD PTR [rbp-0x8]
push QWORD PTR [rbp-0xc]
lea eax,[rbp-0x1c]
push rax
call FUNC_001338
add rsp,32
mov eax,[rbp+40]
mov eax,[eax+0x8]
mov [rbp-0xc],eax
mov eax,[rbp+40]
mov eax,[eax+0x8]
sar eax,0x1f
mov [rbp-0x8],eax
push rbx
push QWORD PTR [rbp-0x8]
push QWORD PTR [rbp-0xc]
lea eax,[rbp-0x14]
push rax
call FUNC_001338
add rsp,32
mov eax,[rbp-0x24]
shr eax,0x2
mov edx,[rbp-0x20]
shl edx,0x1e
or eax,edx
mov [rbp-0x24],eax
sar DWORD PTR [rbp-0x20],0x2
mov eax,[rbp-0x1c]
shr eax,0x2
mov edx,[rbp-0x18]
shl edx,0x1e
or eax,edx
mov [rbp-0x1c],eax
sar DWORD PTR [rbp-0x18],0x2
mov eax,[rbp-0x14]
shr eax,0x2
mov edx,[rbp-0x10]
shl edx,0x1e
or eax,edx
mov [rbp-0x14],eax
sar DWORD PTR [rbp-0x10],0x2
test esi,esi
jz JUMP_005685
mov ecx,esi
mov eax,[rbp-0x20]
shl eax,cl
mov ecx,0x20
sub ecx,esi
mov edx,[rbp-0x24]
shr edx,cl
or eax,edx
mov [rbp-0x20],eax
mov ecx,esi
shl DWORD PTR [rbp-0x24],cl
mov ecx,esi
mov eax,[rbp-0x18]
shl eax,cl
mov ecx,0x20
sub ecx,esi
mov edx,[rbp-0x1c]
shr edx,cl
or eax,edx
mov [rbp-0x18],eax
mov ecx,esi
shl DWORD PTR [rbp-0x1c],cl
mov ecx,esi
mov eax,[rbp-0x10]
shl eax,cl
mov ecx,0x20
sub ecx,esi
mov edx,[rbp-0x14]
shr edx,cl
or eax,edx
mov [rbp-0x10],eax
mov ecx,esi
shl DWORD PTR [rbp-0x14],cl
JUMP_005685:
cmp DWORD PTR [rbp-0x4],+0x0
jz JUMP_005686
mov eax,[rbp-0x24]
not eax
inc eax
mov [rbp-0x24],eax
mov eax,[rbp-0x20]
not eax
cmp DWORD PTR [rbp-0x24],+0x0
setz dl
and edx,+0x1
add eax,edx
mov [rbp-0x20],eax
mov eax,[rbp-0x1c]
not eax
inc eax
mov [rbp-0x1c],eax
mov eax,[rbp-0x18]
not eax
cmp DWORD PTR [rbp-0x1c],+0x0
setz dl
and edx,+0x1
add eax,edx
mov [rbp-0x18],eax
mov eax,[rbp-0x14]
not eax
inc eax
mov [rbp-0x14],eax
mov eax,[rbp-0x10]
not eax
cmp DWORD PTR [rbp-0x14],+0x0
setz dl
and edx,+0x1
add eax,edx
mov [rbp-0x10],eax
JUMP_005686:
lea eax,[rbp-0x24]
push rax
push QWORD PTR [rbp+16]
call FUNC_001661
add rsp,16
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001338:
push rbp
mov rbp,rsp
push rcx
mov eax,[rbp+24]
mul DWORD PTR [rbp+40]
mov ecx,[rbp+16]
mov [ecx],eax
mov [ecx+0x4],edx
mov eax,[rbp+32]
mul DWORD PTR [rbp+40]
add [ecx+0x4],eax
pop rcx
pop rbp
ret
FUNC_001656:
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
FUNC_001661:
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
call FUNC_001333
add rsp,40
push QWORD PTR [rsi+0xc]
push QWORD PTR [rsi+0x8]
push QWORD PTR [rbx+0xc]
push QWORD PTR [rbx+0x8]
lea eax,[ebx+0x8]
push rax
call FUNC_001333
add rsp,40
push QWORD PTR [rsi+0x14]
push QWORD PTR [rsi+0x10]
push QWORD PTR [rbx+0x14]
push QWORD PTR [rbx+0x10]
add ebx,+0x10
push rbx
call FUNC_001333
add rsp,40
pop rsi
pop rbx
pop rbp
ret
FUNC_001333:
push rbp
mov rbp,rsp
mov edx,[rbp+16]
mov eax,[rbp+24]
add eax,[rbp+40]
mov [edx],eax
mov eax,[rbp+32]
adc eax,[rbp+48]
mov [edx+0x4],eax
pop rbp
ret

# Append a24byte request using EAXkind, EDXa, ECXb, ESIc, EDIbodySlot or-1.
record_request:
 push rbx
 mov ebx,DWORD PTR [request_count]
 cmp ebx,8
 jae bad_trace
 imul ebx,ebx,24
 mov DWORD PTR [requests+rbx],eax
 mov DWORD PTR [requests+rbx+4],edx
 mov DWORD PTR [requests+rbx+8],ecx
 mov DWORD PTR [requests+rbx+12],esi
 mov DWORD PTR [requests+rbx+16],0
 test edi,edi
 js record_done
 mov DWORD PTR [requests+rbx+16],1
 mov DWORD PTR [requests+rbx+20],edi
 push rsi
 push rdi
 push rcx
 imul edi,edi,338
 add edi,OFFSET FLAT:snapshots
 mov esi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 pop rcx
 pop rdi
 pop rsi
record_done:
 inc DWORD PTR [request_count]
 pop rbx
 ret
FUNC_000939:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 cmp DWORD PTR [rbp+24],OFFSET FLAT:body+0x3e
 jne bad_pointer
 cmp DWORD PTR [rbp+32],0
 jne bad_pointer
 call trace_939
 mov eax,939
 xor edx,edx
 xor ecx,ecx
 xor esi,esi
 xor edi,edi
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_001910:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+40],OFFSET FLAT:body
 jne bad_pointer
 call trace_1910
 mov eax,1910
 mov edx,DWORD PTR [rbp+16]
 mov ecx,DWORD PTR [rbp+24]
 mov esi,DWORD PTR [rbp+32]
 mov edi,1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_000569:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 cmp DWORD PTR [rbp+24],OFFSET FLAT:bank
 jne bad_pointer
 call trace_569
 mov eax,569
 xor edx,edx
 xor ecx,ecx
 xor esi,esi
 xor edi,edi
 call record_request
 mov esi,OFFSET FLAT:input+946
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov eax,DWORD PTR [rbp+32]
 mov dl,BYTE PTR [input+20]
 mov BYTE PTR [rax],dl
 mov eax,DWORD PTR [rbp+40]
 mov dl,BYTE PTR [input+32]
 mov BYTE PTR [rax],dl
 mov eax,DWORD PTR [rbp+48]
 mov edx,DWORD PTR [input+28]
 test edx,edx
 jz no_collider_ref
 mov edx,OFFSET FLAT:collider
no_collider_ref:
 mov DWORD PTR [rax],edx
 mov eax,DWORD PTR [rbp+56]
 mov edx,DWORD PTR [input+24]
 mov DWORD PTR [rax],edx
 mov eax,DWORD PTR [rbp+64]
 mov dl,BYTE PTR [input+36]
 mov BYTE PTR [rax],dl
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_001116:
 push rdi
 push rsi
 call trace_1116
 mov eax,1116
 xor edx,edx
 xor ecx,ecx
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 ret
FUNC_000349:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 call trace_349
 mov eax,DWORD PTR [rbp+16]
 mov edx,DWORD PTR [rax]
 mov ecx,DWORD PTR [rax+4]
 mov eax,349
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_000148:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 call trace_148
 mov eax,148
 mov edx,DWORD PTR [rbp+16]
 mov ecx,DWORD PTR [rbp+24]
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_001906:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 call trace_1906
 mov eax,1906
 mov edx,DWORD PTR [rbp+16]
 xor ecx,ecx
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_000953:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 call trace_953
 mov eax,953
 mov edx,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 xor esi,esi
 mov edi,1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
trace_939:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],939
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
trace_1910:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1910
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
trace_569:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],569
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
trace_1116:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1116
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
trace_349:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],349
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
trace_148:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],148
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
trace_1906:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1906
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
trace_953:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],953
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
ret
_start:
 mov esp,OFFSET FLAT:stack_end
 cld
next_packet:
 xor r8d,r8d
read_packet:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,1622
 sub edx,r8d
 syscall
 test eax,eax
 jle finish
 add r8d,eax
 cmp r8d,1622
 jne read_packet
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,18200
 rep stosb
 mov edi,OFFSET FLAT:root
 mov eax,DWORD PTR [input+40]
 mov ecx,16384
 rep stosb
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:root
 mov ecx,544
 rep movsb
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+1284
 mov edi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:trace_codes
 xor eax,eax
 mov ecx,32+48+169
 rep stosd
 mov DWORD PTR [trace_count],0
 mov DWORD PTR [request_count],0
 mov DWORD PTR [return_value],0
 mov DWORD PTR [collider_ref],0
 mov BYTE PTR [collider_index],0
 mov BYTE PTR [material],0
 mov eax,DWORD PTR [input+4]
 mov BYTE PTR [DATA_009030],al
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_009116],eax
 mov eax,DWORD PTR [input+12]
 mov BYTE PTR [DATA_008630],al
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [DATA_009155],eax
 mov rax,5570763937920463666
 mov QWORD PTR [root_guard_before],rax
 mov QWORD PTR [root_guard_after],rax
 mov QWORD PTR [body_guard_before],rax
 mov QWORD PTR [body_guard_after],rax
 mov QWORD PTR [collider_guard_before],rax
 mov QWORD PTR [collider_guard_after],rax
 cmp DWORD PTR [input],0
 jne try_contact
 push OFFSET FLAT:body
 call FUNC_001046
 add rsp,8
 jmp capture
try_contact:
 cmp DWORD PTR [input],1
 jne try_decay
 push OFFSET FLAT:material
 push OFFSET FLAT:collider_index
 push OFFSET FLAT:collider_ref
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_001033
 add rsp,40
 mov DWORD PTR [return_value],eax
 jmp capture
try_decay:
 cmp DWORD PTR [input],2
 jne bad_pointer
 push OFFSET FLAT:body
 call FUNC_001034
 add rsp,8
capture:
 mov rax,5570763937920463666
 cmp QWORD PTR [root_guard_before],rax
 jne bad_pointer
 cmp QWORD PTR [root_guard_after],rax
 jne bad_pointer
 cmp QWORD PTR [body_guard_before],rax
 jne bad_pointer
 cmp QWORD PTR [body_guard_after],rax
 jne bad_pointer
 cmp QWORD PTR [collider_guard_before],rax
 jne bad_pointer
 cmp QWORD PTR [collider_guard_after],rax
 jne bad_pointer
 mov DWORD PTR [output],0x4d4f444f
 mov eax,DWORD PTR [return_value]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [trace_count]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [request_count]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [collider_ref]
 test eax,eax
 jz capture_no_ref
 cmp eax,OFFSET FLAT:collider
 jne bad_pointer
 mov eax,DWORD PTR [input+28]
capture_no_ref:
 mov DWORD PTR [output+16],eax
 movzx eax,BYTE PTR [collider_index]
 mov DWORD PTR [output+20],eax
 movzx eax,BYTE PTR [material]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [output+32],eax
 mov esi,OFFSET FLAT:root
 mov edi,OFFSET FLAT:output+64
 mov ecx,16384
 rep movsb
 mov esi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 movzx eax,BYTE PTR [DATA_009030]
 mov DWORD PTR [output+17124],eax
 mov eax,DWORD PTR [DATA_009116]
 mov DWORD PTR [output+17124+4],eax
 movsx eax,BYTE PTR [DATA_008630]
 mov DWORD PTR [output+17124+8],eax
 mov eax,DWORD PTR [DATA_009155]
 mov DWORD PTR [output+17124+12],eax
 mov esi,OFFSET FLAT:trace_codes
 mov edi,OFFSET FLAT:output+17140
 mov ecx,128+192+676
 rep movsb
 mov edi,OFFSET FLAT:output+18136
 mov eax,0xa5
 mov ecx,64
 rep stosb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,18200
 syscall
 cmp eax,18200
 jne bad_pointer
 jmp next_packet
finish:
 mov eax,60
 xor edi,edi
 syscall
bad_pointer:
 mov eax,60
 mov edi,91
 syscall
bad_trace:
 mov eax,60
 mov edi,92
 syscall
.section .data
DATA_006141: .quad FUNC_000569
DATA_007744: .quad FUNC_001512
.section .bss
.balign 16
input: .zero 1622
output: .zero 18200
root_guard_before: .zero 8
root: .zero 16384
root_guard_after: .zero 8
body_guard_before: .zero 8
body: .zero 338
body_guard_after: .zero 8
collider_guard_before: .zero 8
collider: .zero 338
collider_guard_after: .zero 8
bank: .zero 16
.equ DATA_009030,root+0x3f5e
DATA_009116: .zero 4
DATA_008630: .zero 1
DATA_009155: .zero 4
trace_count: .zero 4
request_count: .zero 4
return_value: .zero 4
collider_ref: .zero 4
collider_index: .zero 1
material: .zero 1
trace_codes: .zero 128
requests: .zero 192
snapshots: .zero 676
.equ DATA_008804,root
.equ DATA_008860,root+0xc6
.equ DATA_008868,root+0xe0
.equ DATA_008869,root+0xe4
.equ DATA_008897,root+0x13c
.equ DATA_008898,root+0x146
.equ DATA_008899,root+0x14a
.equ DATA_008900,root+0x14c
.balign 16
stack: .zero 131072
stack_end:
