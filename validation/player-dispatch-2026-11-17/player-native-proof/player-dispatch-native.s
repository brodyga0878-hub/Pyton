.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_001041:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1041
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-24
push rbx
mov ebx,[rbp+16]
mov eax,[DATA_009155]
shr eax,1
push rax
push +0x0
push rax
push rbx
call QWORD PTR [DATA_006143]
add rsp,32
mov eax,[DATA_009155]
shr eax,1
push rax
push +0x0
push rax
push rbx
call QWORD PTR [DATA_006143]
add rsp,32
mov eax,[DATA_009155]
push rax
mov eax,[DATA_009133]
push rax
push rbx
call QWORD PTR [DATA_006153]
add rsp,24
cmp DWORD PTR [DATA_008867],0x2625a00
jg JUMP_004305
push rbx
call QWORD PTR [DATA_006157]
pop rcx
mov ax,[ebx+0x112]
mov [ebx+0xb2],ax
JUMP_004305:
dec BYTE PTR [ebx+0x14d]
mov al,[ebx+0x14d]
test al,al
jnl JUMP_004306
mov eax,[DATA_009133]
push rax
push rbx
call QWORD PTR [DATA_006154]
add rsp,16
mov BYTE PTR [ebx+0x14d],0xd
JUMP_004306:
cmp BYTE PTR [DATA_008870],0x24
jnz JUMP_004307
xor eax,eax
mov [rbp-0xc],eax
xor eax,eax
mov [rbp-0x4],eax
mov DWORD PTR [rbp-0x8],0xcc6
lea eax,[rbp-0x18]
push rax
lea eax,[rbp-0xc]
push rax
push rbx
call QWORD PTR [DATA_006151]
add rsp,24
jmp JUMP_004309
JUMP_004307:
test BYTE PTR [DATA_008871],0x1
jz JUMP_004308
push rbx
call FUNC_001043
pop rcx
jmp JUMP_004309
JUMP_004308:
lea eax,[rbp-0xc]
push rax
mov eax,[DATA_008918]
push rax
push rbx
call QWORD PTR [DATA_006155]
add rsp,24
lea eax,[rbp-0x18]
push rax
lea eax,[rbp-0xc]
push rax
push rbx
call QWORD PTR [DATA_006151]
add rsp,24
JUMP_004309:
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001043:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1043
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
mov ebx,[rbp+16]
xor eax,eax
mov [rbp-0x4],eax
mov [rbp-0x8],eax
mov [rbp-0xc],eax
test BYTE PTR [DATA_009046],0x2
jz JUMP_004314
mov eax,[ebx+0x8c]
sub eax,[DATA_008839]
mov [rbp-0x24],eax
mov eax,[ebx+0x90]
sub eax,[DATA_008840]
mov [rbp-0x20],eax
mov eax,[ebx+0x94]
sub eax,[DATA_008841]
mov [rbp-0x1c],eax
mov eax,[rbp-0x24]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov esi,eax
mov eax,[rbp-0x20]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add esi,eax
mov eax,[rbp-0x1c]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add esi,eax
mov eax,[rbp-0x24]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[rbp-0x20]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[rbp-0x1c]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,edi
cmp eax,0x100
jng JUMP_004311
mov edx,eax
neg edx
shl edx,0x2
mov [rbp-0xc],edx
JUMP_004311:
cmp eax,0xffffff00
jnl JUMP_004312
neg eax
shl eax,0x2
mov [rbp-0xc],eax
JUMP_004312:
cmp esi,0x100
jng JUMP_004313
mov eax,esi
neg eax
shl eax,0x2
mov [rbp-0x8],eax
JUMP_004313:
cmp esi,0xffffff00
jnl JUMP_004314
neg esi
shl esi,0x2
mov [rbp-0x8],esi
JUMP_004314:
cmp BYTE PTR [DATA_007692],0x0
jnz JUMP_004315
mov DWORD PTR [rbp-0x4],0x7fff
jmp JUMP_004317
JUMP_004315:
cmp BYTE PTR [DATA_007694],0x0
jnz JUMP_004316
mov DWORD PTR [rbp-0x4],0xffff8001
jmp JUMP_004317
JUMP_004316:
push rbx
push 0x12c
push +0x1
push +0x3
call FUNC_001910
add rsp,32
JUMP_004317:
lea eax,[rbp-0x18]
push rax
lea eax,[rbp-0xc]
push rax
push rbx
call QWORD PTR [DATA_006151]
add rsp,24
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001044:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],1044
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
push rax
call FUNC_001045
pop rcx
pop rbp
ret
FUNC_001045:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
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
FUNC_000585:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],585
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov eax,[rbp+40]
mov esi,[rbp+24]
mov ebx,[rbp+16]
lea edi,[rbp-0x4]
mov edx,[ebx+0x82]
cmp edx,+0x35
jc JUMP_002545
sar esi,1
cmp edx,+0x3b
jc JUMP_002545
sar esi,1
JUMP_002545:
cmp DWORD PTR [rbp+32],+0x0
jz JUMP_002547
cmp eax,0x7fff
jl JUMP_002546
mov eax,0x7fff
JUMP_002546:
movsx edx,WORD PTR [ebx+0x110]
imul edx,eax
sar edx,0x10
add [ebx+0xb0],dx
movsx edx,WORD PTR [ebx+0x112]
imul edx,eax
sar edx,0x10
add [ebx+0xb2],dx
movsx edx,WORD PTR [ebx+0x114]
imul edx,eax
sar edx,0x10
add [ebx+0xb4],dx
JUMP_002547:
cmp esi,0x7fff
jl JUMP_002548
mov esi,0x7fff
JUMP_002548:
movsx eax,WORD PTR [ebx+0xb0]
mov [edi],eax
cmp DWORD PTR [edi],+0x0
jl JUMP_002550
cmp esi,[edi]
jnl JUMP_002549
mov [edi],esi
JUMP_002549:
cmp DWORD PTR [edi],+0xf
jl JUMP_002552
lea eax,[rbp-0x8]
push rax
push rdi
call FUNC_000584
add rsp,16
mov ax,[edi]
sub [ebx+0xb0],ax
mov eax,[rbp-0x8]
push rax
push +0x70
lea eax,[ebx+0xc]
push rax
lea eax,[ebx+0x18]
push rax
push rbx
call FUNC_000611
add rsp,40
jmp JUMP_002552
JUMP_002550:
neg DWORD PTR [edi]
cmp esi,[edi]
jnl JUMP_002551
mov [edi],esi
JUMP_002551:
cmp DWORD PTR [edi],+0xf
jl JUMP_002552
lea eax,[rbp-0x8]
push rax
push rdi
call FUNC_000584
add rsp,16
mov ax,[edi]
add [ebx+0xb0],ax
mov eax,[rbp-0x8]
push rax
push +0x6d
lea eax,[ebx+0xc]
push rax
lea eax,[ebx+0x18]
push rax
push rbx
call FUNC_000611
add rsp,40
JUMP_002552:
movsx eax,WORD PTR [ebx+0xb2]
mov [edi],eax
cmp DWORD PTR [edi],+0x0
jl JUMP_002554
cmp esi,[edi]
jnl JUMP_002553
mov [edi],esi
JUMP_002553:
cmp DWORD PTR [edi],+0xf
jl JUMP_002556
lea eax,[rbp-0x8]
push rax
push rdi
call FUNC_000584
add rsp,16
mov ax,[edi]
sub [ebx+0xb2],ax
mov eax,[rbp-0x8]
push rax
push +0x70
push rbx
lea eax,[ebx+0xc]
push rax
push rbx
call FUNC_000611
add rsp,40
jmp JUMP_002556
JUMP_002554:
neg DWORD PTR [edi]
cmp esi,[edi]
jnl JUMP_002555
mov [edi],esi
JUMP_002555:
cmp DWORD PTR [edi],+0xf
jl JUMP_002556
lea eax,[rbp-0x8]
push rax
push rdi
call FUNC_000584
add rsp,16
mov ax,[edi]
add [ebx+0xb2],ax
mov eax,[rbp-0x8]
push rax
push +0x6d
push rbx
lea eax,[ebx+0xc]
push rax
push rbx
call FUNC_000611
add rsp,40
JUMP_002556:
movsx eax,WORD PTR [ebx+0xb4]
mov [edi],eax
cmp DWORD PTR [edi],+0x0
jl JUMP_002558
cmp esi,[edi]
jnl JUMP_002557
mov [edi],esi
JUMP_002557:
cmp DWORD PTR [edi],+0xf
jl JUMP_002560
lea eax,[rbp-0x8]
push rax
push rdi
call FUNC_000584
add rsp,16
mov ax,[edi]
sub [ebx+0xb4],ax
mov eax,[rbp-0x8]
push rax
push +0x70
lea eax,[ebx+0x18]
push rax
push rbx
push rbx
call FUNC_000611
add rsp,40
xor eax,eax
mov al,[ebx+0x86]
cmp eax,[DATA_008857]
jnz JUMP_002560
mov ax,[edi]
sub [DATA_008933],ax
jmp JUMP_002560
JUMP_002558:
neg DWORD PTR [edi]
cmp esi,[edi]
jnl JUMP_002559
mov [edi],esi
JUMP_002559:
cmp DWORD PTR [edi],+0xf
jl JUMP_002560
lea eax,[rbp-0x8]
push rax
push rdi
call FUNC_000584
add rsp,16
mov ax,[edi]
add [ebx+0xb4],ax
mov eax,[rbp-0x8]
push rax
push +0x6d
lea eax,[ebx+0x18]
push rax
push rbx
push rbx
call FUNC_000611
add rsp,40
xor eax,eax
mov al,[ebx+0x86]
cmp eax,[DATA_008857]
jnz JUMP_002560
mov ax,[edi]
add [DATA_008933],ax
JUMP_002560:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_000584:
push rbp
mov rbp,rsp
mov edx,[rbp+24]
mov eax,[rbp+16]
cmp DWORD PTR [eax],0x9fb
jl JUMP_002538
mov DWORD PTR [edx],0x2
mov DWORD PTR [eax],0x9fb
pop rbp
ret
JUMP_002538:
cmp DWORD PTR [eax],0x511
jl JUMP_002539
mov DWORD PTR [edx],0x3
mov DWORD PTR [eax],0x511
pop rbp
ret
JUMP_002539:
cmp DWORD PTR [eax],0x28b
jl JUMP_002540
mov DWORD PTR [edx],0x4
mov DWORD PTR [eax],0x28b
pop rbp
ret
JUMP_002540:
cmp DWORD PTR [eax],0x146
jl JUMP_002541
mov DWORD PTR [edx],0x5
mov DWORD PTR [eax],0x146
pop rbp
ret
JUMP_002541:
cmp DWORD PTR [eax],0xa3
jl JUMP_002542
mov DWORD PTR [edx],0x6
mov DWORD PTR [eax],0xa3
pop rbp
ret
JUMP_002542:
cmp DWORD PTR [eax],+0x52
jl JUMP_002543
mov DWORD PTR [edx],0x7
mov DWORD PTR [eax],0x52
pop rbp
ret
JUMP_002543:
cmp DWORD PTR [eax],+0x29
jl JUMP_002544
mov DWORD PTR [edx],0x8
mov DWORD PTR [eax],0x29
pop rbp
ret
JUMP_002544:
mov DWORD PTR [edx],0x9
mov DWORD PTR [eax],0x14
pop rbp
ret
nop
FUNC_000611:
push rbp
mov rbp,rsp
add rsp,-36
push rbx
push rsi
push rdi
mov ebx,[rbp+48]
mov eax,[rbp+32]
mov edx,[rbp+24]
mov ecx,[DATA_006159]
mov [rbp-0xc],ecx
mov ecx,[DATA_006160]
mov [rbp-0x8],ecx
mov cx,[DATA_006161]
mov [rbp-0x4],cx
cmp ebx,+0x5
jg JUMP_002690
mov esi,ebx
add esi,esi
inc esi
mov ecx,esi
mov edi,[edx]
sar edi,cl
sub [edx],edi
mov ecx,esi
mov edi,[edx+0x4]
sar edi,cl
sub [edx+0x4],edi
mov ecx,esi
mov edi,[edx+0x8]
sar edi,cl
sub [edx+0x8],edi
mov ecx,esi
mov edi,[eax]
sar edi,cl
sub [eax],edi
mov ecx,esi
mov edi,[eax+0x4]
sar edi,cl
sub [eax+0x4],edi
mov ecx,esi
mov esi,[eax+0x8]
sar esi,cl
sub [eax+0x8],esi
JUMP_002690:
cmp BYTE PTR [rbp+40],0x70
jnz JUMP_002691
mov ecx,ebx
mov esi,[edx]
sar esi,cl
add esi,[eax]
mov [rbp-0x18],esi
mov ecx,ebx
mov esi,[edx+0x4]
sar esi,cl
add esi,[eax+0x4]
mov [rbp-0x14],esi
mov ecx,ebx
mov esi,[edx+0x8]
sar esi,cl
add esi,[eax+0x8]
mov [rbp-0x10],esi
jmp JUMP_002692
JUMP_002691:
mov ecx,ebx
mov esi,[edx]
sar esi,cl
mov ecx,[eax]
sub ecx,esi
mov [rbp-0x18],ecx
mov ecx,ebx
mov esi,[edx+0x4]
sar esi,cl
mov ecx,[eax+0x4]
sub ecx,esi
mov [rbp-0x14],ecx
mov ecx,ebx
mov esi,[edx+0x8]
sar esi,cl
mov ecx,[eax+0x8]
sub ecx,esi
mov [rbp-0x10],ecx
JUMP_002692:
mov ecx,ebx
mov esi,[eax]
sar esi,cl
mov [rbp-0x24],esi
mov ecx,ebx
mov esi,[eax+0x4]
sar esi,cl
mov [rbp-0x20],esi
mov ecx,ebx
mov esi,[eax+0x8]
sar esi,cl
mov [rbp-0x1c],esi
mov ecx,[rbp-0x18]
mov [eax],ecx
mov ecx,[rbp-0x14]
mov [eax+0x4],ecx
mov ecx,[rbp-0x10]
mov [eax+0x8],ecx
cmp BYTE PTR [rbp+40],0x70
jnz JUMP_002693
mov eax,[rbp-0x24]
sub [edx],eax
mov eax,[rbp-0x20]
sub [edx+0x4],eax
mov eax,[rbp-0x1c]
sub [edx+0x8],eax
jmp JUMP_002694
JUMP_002693:
mov eax,[rbp-0x24]
add [edx],eax
mov eax,[rbp-0x20]
add [edx+0x4],eax
mov eax,[rbp-0x1c]
add [edx+0x8],eax
JUMP_002694:
mov al,[rbp+rbx-0xe]
mov edx,[rbp+16]
sub [edx+0x24],al
mov eax,[rbp+16]
cmp BYTE PTR [eax+0x24],0x0
jnl JUMP_002695
mov eax,[rbp+16]
push rax
call QWORD PTR [DATA_007719]
pop rcx
mov eax,[rbp+16]
mov BYTE PTR [eax+0x24],0x3c
JUMP_002695:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000609:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],609
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,[eax]
sar edx,0x10
imul edx,[DATA_008708]
mov ecx,[eax+0x4]
sar ecx,0x10
imul ecx,[DATA_008709]
add edx,ecx
mov ecx,[eax+0x8]
sar ecx,0x10
imul ecx,[DATA_008710]
add edx,ecx
sar edx,0x12
neg dx
mov [eax+0x112],dx
pop rbp
ret
FUNC_001520:
push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
push rbx
push rbx
call FUNC_001519
add rsp,16
lea eax,[ebx+0x18]
push rax
lea eax,[ebx+0x18]
push rax
call FUNC_001519
add rsp,16
push rbx
lea eax,[ebx+0x18]
push rax
lea eax,[ebx+0xc]
push rax
call FUNC_001552
add rsp,24
lea eax,[ebx+0xc]
push rax
lea eax,[ebx+0xc]
push rax
call FUNC_001519
add rsp,16
lea eax,[ebx+0x18]
push rax
lea eax,[ebx+0xc]
push rax
push rbx
call FUNC_001552
add rsp,24
pop rbx
pop rbp
ret
FUNC_001519:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov edi,[rbp+24]
push rdi
call FUNC_001466
pop rcx
mov ebx,eax
inc ebx
push rbx
call FUNC_001656
pop rcx
mov esi,0x1f
sub esi,eax
mov ecx,esi
shl ebx,cl
shr ebx,1
push rbx
push 0x3f800000
call FUNC_001523
add rsp,16
shr eax,1
mov ebx,eax
mov eax,ebx
dec eax
push rax
push QWORD PTR [rdi]
call FUNC_001521
add rsp,16
lea ecx,[esi+0x1]
shl eax,cl
mov edx,[rbp+16]
mov [edx],eax
mov eax,ebx
dec eax
push rax
push QWORD PTR [rdi+0x4]
call FUNC_001521
add rsp,16
lea ecx,[esi+0x1]
shl eax,cl
mov edx,[rbp+16]
mov [edx+0x4],eax
dec ebx
push rbx
push QWORD PTR [rdi+0x8]
call FUNC_001521
add rsp,16
lea ecx,[esi+0x1]
shl eax,cl
mov edx,[rbp+16]
mov [edx+0x8],eax
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_001552:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov edx,[rbp+32]
mov eax,[rbp+24]
mov ebx,[rbp+16]
mov esi,[eax]
mov edi,[eax+0x4]
mov eax,[eax+0x8]
mov [rbp-0x4],eax
mov eax,[edx]
mov [rbp-0x8],eax
mov eax,[edx+0x4]
mov [rbp-0xc],eax
mov eax,[edx+0x8]
mov [rbp-0x10],eax
mov eax,[rbp-0x10]
push rax
push rdi
call FUNC_001521
add rsp,16
push rax
mov eax,[rbp-0xc]
push rax
mov eax,[rbp-0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
sub edx,eax
mov [ebx],edx
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[rbp-0x10]
push rax
push rsi
call FUNC_001521
add rsp,16
pop rdx
sub edx,eax
mov [ebx+0x4],edx
mov eax,[rbp-0xc]
push rax
push rsi
call FUNC_001521
add rsp,16
push rax
mov eax,[rbp-0x8]
push rax
push rdi
call FUNC_001521
add rsp,16
pop rdx
sub edx,eax
mov [ebx+0x8],edx
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001466:
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
lea esi,[rbp-0xc]
push QWORD PTR [rbx]
call _abs
pop rcx
mov [esi],eax
push QWORD PTR [rbx+0x4]
call _abs
pop rcx
mov [esi+0x4],eax
push QWORD PTR [rbx+0x8]
call _abs
pop rcx
mov [esi+0x8],eax
mov eax,[esi]
mov [rbp-0x18],eax
mov eax,[esi+0x4]
mov [rbp-0x14],eax
mov eax,[esi+0x8]
mov [rbp-0x10],eax
mov eax,[esi]
or eax,[esi+0x4]
or eax,[esi+0x8]
push rax
call FUNC_001656
pop rcx
mov ebx,0x1e
sub ebx,eax
mov ecx,ebx
shl DWORD PTR [esi],cl
mov ecx,ebx
shl DWORD PTR [esi+0x4],cl
mov ecx,ebx
shl DWORD PTR [esi+0x8],cl
test ebx,ebx
jng JUMP_005489
push QWORD PTR [rsi]
push QWORD PTR [rsi]
call FUNC_001521
add rsp,16
mov edi,eax
sar edi,0x2
push QWORD PTR [rsi+0x4]
push QWORD PTR [rsi+0x4]
call FUNC_001521
add rsp,16
sar eax,0x2
add edi,eax
push QWORD PTR [rsi+0x8]
push QWORD PTR [rsi+0x8]
call FUNC_001521
add rsp,16
sar eax,0x2
add edi,eax
push rdi
call QWORD PTR [DATA_007738]
pop rcx
lea ecx,[ebx-0x1]
shr eax,cl
jmp JUMP_005490
JUMP_005489:
push QWORD PTR [rsi]
push QWORD PTR [rsi]
call FUNC_001521
add rsp,16
mov ebx,eax
sar ebx,0x2
push QWORD PTR [rsi+0x4]
push QWORD PTR [rsi+0x4]
call FUNC_001521
add rsp,16
sar eax,0x2
add ebx,eax
push QWORD PTR [rsi+0x8]
push QWORD PTR [rsi+0x8]
call FUNC_001521
add rsp,16
sar eax,0x2
add ebx,eax
push rbx
call QWORD PTR [DATA_007738]
pop rcx
add eax,eax
JUMP_005490:
cmp eax,[rbp-0x18]
jnc JUMP_005491
mov eax,[rbp-0x18]
JUMP_005491:
cmp eax,[rbp-0x14]
jnc JUMP_005492
mov eax,[rbp-0x14]
JUMP_005492:
cmp eax,[rbp-0x10]
jnc JUMP_005493
mov eax,[rbp-0x10]
JUMP_005493:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
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
FUNC_001523:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
shr eax,1
cmp eax,[rbp+24]
jc JUMP_005691
or eax,-0x1
pop rbp
ret
JUMP_005691:
mov edx,[rbp+16]
mov eax,edx
shr edx,1
shl eax,0x1f
div DWORD PTR [rbp+24]
pop rbp
ret
FUNC_001521:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
imul DWORD PTR [rbp+24]
shl eax,1
rcl edx,1
mov eax,edx
pop rbp
ret
FUNC_001502:
push rbp
mov rbp,rsp
push rcx
push rbx
push rsi
xor eax,eax
mov edx,0x80000000
cmp edx,[rbp+16]
jna JUMP_005673
JUMP_005672:
inc eax
shr edx,0x2
cmp edx,[rbp+16]
ja JUMP_005672
JUMP_005673:
xor edx,edx
mov [rbp-0x4],edx
xor edx,edx
cmp eax,+0xf
jg JUMP_005676
JUMP_005674:
lea ecx,[eax-0x1]
mov ebx,[rbp-0x4]
shr ebx,cl
add ebx,edx
mov ecx,eax
add ecx,ecx
mov esi,0x80000000
shr esi,cl
add ebx,esi
mov ecx,ebx
cmp ecx,[rbp+16]
ja JUMP_005675
mov edx,ecx
mov ecx,eax
mov ebx,0x80000000
shr ebx,cl
add [rbp-0x4],ebx
JUMP_005675:
inc eax
cmp eax,+0xf
jng JUMP_005674
JUMP_005676:
cmp eax,+0x1f
jg JUMP_005679
JUMP_005677:
lea ecx,[eax-0x1]
mov ebx,[rbp-0x4]
shr ebx,cl
mov ecx,ebx
add ecx,edx
cmp ecx,[rbp+16]
ja JUMP_005678
mov edx,ecx
mov ecx,eax
mov ebx,0x80000000
shr ebx,cl
add [rbp-0x4],ebx
JUMP_005678:
inc eax
cmp eax,+0x1f
jng JUMP_005677
JUMP_005679:
mov eax,[rbp-0x4]
pop rsi
pop rbx
pop rcx
pop rbp
ret
FUNC_000603:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],603
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
mov esi,[rbp+16]
mov al,[esi+0x56]
test al,al
jz JUMP_002662
mov edx,[rbp+24]
push rdx
and eax,0xff
push rax
call QWORD PTR [DATA_007754]
add rsp,16
mov edi,eax
cmp WORD PTR [edi+0xa4],+0x0
jz JUMP_002662
push rsi
push rdi
add esi,+0x3e
lea edi,[rbp-0x2c]
mov ecx,0x6
rep movsd
pop rdi
pop rsi
push +0xd
lea eax,[rbp-0x2c]
push rax
call FUNC_001658
add rsp,16
mov [rbp-0x14],eax
mov eax,[rbp-0x2c]
mov [rbp-0x38],eax
mov eax,[rbp-0x24]
mov [rbp-0x34],eax
mov eax,[rbp-0x1c]
mov [rbp-0x30],eax
mov eax,[rbp-0x38]
mov [DATA_008708],eax
mov eax,[rbp-0x34]
mov [DATA_008709],eax
mov eax,[rbp-0x30]
mov [DATA_008710],eax
lea eax,[rbp-0x38]
push rax
call FUNC_001466
pop rcx
mov [rbp-0x4],ax
mov ax,[rbp-0x14]
mov [rbp-0x2],ax
mov eax,[rbp-0x4]
push rax
call QWORD PTR [DATA_007722]
pop rcx
mov [rbp-0x4],eax
cmp WORD PTR [rbp-0x4],+0x0
jz JUMP_002662
mov eax,[rbp-0x4]
push rax
mov eax,[rbp-0x4]
push rax
call FUNC_001482
add rsp,16
mov [rbp-0x10],eax
movsx eax,WORD PTR [rbp-0x4]
movsx edx,WORD PTR [rbp-0x10]
imul edx
sar eax,0xf
mov [rbp-0x8],ax
mov ax,[rbp-0xe]
mov [rbp-0x6],ax
mov eax,[rbp-0x8]
push rax
call QWORD PTR [DATA_007722]
pop rcx
push rax
mov eax,[edi+0xa4]
push rax
call QWORD PTR [DATA_007731]
add rsp,16
mov [rbp-0x8],eax
test ebx,ebx
jnl JUMP_002656
cmp ebx,0xffff8001
jnl JUMP_002658
JUMP_002655:
inc WORD PTR [rbp-0x6]
sar ebx,1
cmp ebx,0xffff8001
jl JUMP_002655
jmp JUMP_002658
JUMP_002656:
cmp ebx,0x7fff
jng JUMP_002658
JUMP_002657:
inc WORD PTR [rbp-0x6]
sar ebx,1
cmp ebx,0x7fff
jg JUMP_002657
JUMP_002658:
movsx eax,WORD PTR [rbp-0x8]
imul ebx
sar eax,0xf
neg eax
mov edx,eax
imul edx,[rbp-0x38]
mov [rbp-0x38],edx
mov edx,eax
imul edx,[rbp-0x34]
mov [rbp-0x34],edx
imul eax,[rbp-0x30]
mov [rbp-0x30],eax
mov ax,[rbp-0x6]
test ax,ax
jg JUMP_002660
cmp ax,-0x20
jng JUMP_002662
test ax,ax
jz JUMP_002659
movsx edx,ax
neg edx
mov ecx,edx
sar DWORD PTR [rbp-0x38],cl
movsx eax,WORD PTR [rbp-0x6]
neg eax
mov ecx,edx
sar DWORD PTR [rbp-0x34],cl
movsx eax,WORD PTR [rbp-0x6]
neg eax
mov ecx,edx
sar DWORD PTR [rbp-0x30],cl
JUMP_002659:
movzx eax,WORD PTR [esi+0xec]
add eax,[rbp-0x38]
mov edx,eax
and dx,0xffff
mov [esi+0xec],dx
sar eax,0x10
add [esi+0x8c],eax
movzx eax,WORD PTR [esi+0xee]
add eax,[rbp-0x34]
mov edx,eax
and dx,0xffff
mov [esi+0xee],dx
sar eax,0x10
add [esi+0x90],eax
movzx eax,WORD PTR [esi+0xf0]
add eax,[rbp-0x30]
mov edx,eax
and dx,0xffff
mov [esi+0xf0],dx
sar eax,0x10
add [esi+0x94],eax
jmp JUMP_002662
JUMP_002660:
add WORD PTR [rbp-0x6],-0x10
mov dx,[rbp-0x6]
test dx,dx
jnl JUMP_002661
movsx eax,dx
neg eax
mov ecx,eax
sar DWORD PTR [rbp-0x38],cl
movsx edx,WORD PTR [rbp-0x6]
neg edx
mov ecx,eax
sar DWORD PTR [rbp-0x34],cl
movsx edx,WORD PTR [rbp-0x6]
neg edx
mov ecx,eax
sar DWORD PTR [rbp-0x30],cl
JUMP_002661:
mov eax,[rbp-0x38]
add [esi+0x8c],eax
mov eax,[rbp-0x34]
add [esi+0x90],eax
mov eax,[rbp-0x30]
add [esi+0x94],eax
JUMP_002662:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000599:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],599
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
mov eax,[rbp+16]
mov edx,[rbp+32]
mov ecx,[rbp+24]
mov ebx,[ecx]
mov [edx],ebx
mov ebx,[ecx+0x4]
mov [edx+0x4],ebx
mov ebx,[ecx+0x8]
mov [edx+0x8],ebx
movsx edx,WORD PTR [eax+0xbc]
movsx ecx,WORD PTR [eax+0xbe]
mov ebx,[rbp+24]
cmp edx,[ebx]
jnl JUMP_002604
mov ebx,[rbp+32]
mov [ebx],edx
JUMP_002604:
mov edx,[rbp+24]
cmp ecx,[edx]
jng JUMP_002605
mov edx,[rbp+32]
mov [edx],ecx
JUMP_002605:
movsx edx,WORD PTR [eax+0xc0]
movsx ecx,WORD PTR [eax+0xc2]
mov ebx,[rbp+24]
cmp edx,[ebx+0x4]
jnl JUMP_002606
mov ebx,[rbp+32]
mov [ebx+0x4],edx
JUMP_002606:
mov edx,[rbp+24]
cmp ecx,[edx+0x4]
jng JUMP_002607
mov edx,[rbp+32]
mov [edx+0x4],ecx
JUMP_002607:
movsx edx,WORD PTR [eax+0xc4]
movsx ecx,WORD PTR [eax+0xc6]
mov ebx,[rbp+24]
cmp edx,[ebx+0x8]
jnl JUMP_002608
mov ebx,[rbp+32]
mov [ebx+0x8],edx
JUMP_002608:
mov edx,[rbp+24]
cmp ecx,[edx+0x8]
jng JUMP_002609
mov edx,[rbp+32]
mov [edx+0x8],ecx
JUMP_002609:
mov edx,[rbp+32]
mov dx,[edx]
mov [eax+0xb6],dx
mov edx,[rbp+32]
mov dx,[edx+0x4]
mov [eax+0xb8],dx
mov edx,[rbp+32]
mov dx,[edx+0x8]
mov [eax+0xba],dx
pop rbx
pop rbp
ret
FUNC_000607:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],607
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov edi,[rbp+32]
mov esi,[rbp+24]
mov ebx,[rbp+16]
mov eax,esi
mov ecx,0x64
cdq
idiv ecx
add esi,eax
test esi,esi
jnl JUMP_002671
neg esi
mov eax,[ebx+0x18]
sar eax,0x10
push rax
push rsi
call QWORD PTR [DATA_007748]
add rsp,16
neg eax
mov [rbp-0xc],eax
mov eax,[ebx+0x1c]
sar eax,0x10
push rax
push rsi
call QWORD PTR [DATA_007748]
add rsp,16
neg eax
mov [rbp-0x8],eax
mov eax,[ebx+0x20]
sar eax,0x10
push rax
push rsi
call QWORD PTR [DATA_007748]
add rsp,16
neg eax
mov [rbp-0x4],eax
jmp JUMP_002672
JUMP_002671:
mov eax,[ebx+0x18]
sar eax,0x10
push rax
push rsi
call QWORD PTR [DATA_007748]
add rsp,16
mov [rbp-0xc],eax
mov eax,[ebx+0x1c]
sar eax,0x10
push rax
push rsi
call QWORD PTR [DATA_007748]
add rsp,16
mov [rbp-0x8],eax
mov eax,[ebx+0x20]
sar eax,0x10
push rax
push rsi
call QWORD PTR [DATA_007748]
add rsp,16
mov [rbp-0x4],eax
JUMP_002672:
mov eax,[ebx+0x8c]
sub [rbp-0xc],eax
mov eax,[ebx+0x90]
sub [rbp-0x8],eax
mov eax,[ebx+0x94]
sub [rbp-0x4],eax
mov eax,[rbp-0xc]
mov [ebx+0xf2],eax
mov eax,[rbp-0x8]
mov [ebx+0xf6],eax
mov eax,[rbp-0x4]
mov [ebx+0xfa],eax
push rbx
lea eax,[rbp-0xc]
push rax
push rdi
call FUNC_001670
add rsp,24
shl DWORD PTR [edi],0x2
shl DWORD PTR [edi+0x4],0x2
shl DWORD PTR [edi+0x8],0x2
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000601:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov edx,[rbp+24]
mov eax,[rbp+16]
lea edi,[rbp-0xc]
shr edx,0x3
or esi,-0x1
cmp edx,0x7fff
jng JUMP_002617
mov esi,0x10
cmp edx,0x7fff
jng JUMP_002617
JUMP_002616:
shr edx,1
dec esi
cmp edx,0x7fff
jg JUMP_002616
JUMP_002617:
xor ecx,ecx
mov [edi],ecx
xor ecx,ecx
mov [edi+0x4],ecx
xor ecx,ecx
mov [edi+0x8],ecx
movsx ecx,WORD PTR [eax+0xb6]
test ecx,ecx
jz JUMP_002618
mov ebx,[eax]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
mov [edi],ebx
mov ebx,[eax+0x4]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
mov [edi+0x4],ebx
mov ebx,[eax+0x8]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
mov [edi+0x8],ebx
JUMP_002618:
movsx ecx,WORD PTR [eax+0xb8]
test ecx,ecx
jz JUMP_002619
mov ebx,[eax+0xc]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi],ebx
mov ebx,[eax+0x10]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x4],ebx
mov ebx,[eax+0x14]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x8],ebx
JUMP_002619:
movsx ecx,WORD PTR [eax+0xba]
test ecx,ecx
jz JUMP_002620
mov ebx,[eax+0x18]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi],ebx
mov ebx,[eax+0x1c]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x4],ebx
mov ebx,[eax+0x20]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x8],ebx
JUMP_002620:
shl DWORD PTR [edi],1
shl DWORD PTR [edi+0x4],1
shl DWORD PTR [edi+0x8],1
test esi,esi
jnl JUMP_002634
cmp edx,0x4014
jnl JUMP_002621
movzx ecx,WORD PTR [eax+0xec]
add ecx,[edi]
mov edx,ecx
and dx,0xffff
mov [eax+0xec],dx
sar ecx,0x10
add [eax+0x8c],ecx
movzx ecx,WORD PTR [eax+0xee]
add ecx,[edi+0x4]
mov edx,ecx
and dx,0xffff
mov [eax+0xee],dx
sar ecx,0x10
add [eax+0x90],ecx
movzx ecx,WORD PTR [eax+0xf0]
add ecx,[edi+0x8]
mov edx,ecx
and dx,0xffff
mov [eax+0xf0],dx
sar ecx,0x10
add [eax+0x94],ecx
jmp JUMP_002647
JUMP_002621:
movzx ecx,WORD PTR [eax+0xec]
add ecx,[edi]
mov edx,ecx
and dx,0xffff
mov [eax+0xec],dx
mov edx,[eax+0xf2]
sar ecx,0x10
test edx,edx
jl JUMP_002623
cmp edx,ecx
jnl JUMP_002622
mov ecx,edx
JUMP_002622:
test ecx,ecx
jnl JUMP_002623
xor ecx,ecx
JUMP_002623:
test edx,edx
jnl JUMP_002625
cmp edx,ecx
jng JUMP_002624
mov ecx,edx
JUMP_002624:
test ecx,ecx
jng JUMP_002625
xor ecx,ecx
JUMP_002625:
add [eax+0x8c],ecx
movzx ecx,WORD PTR [eax+0xee]
add ecx,[edi+0x4]
mov edx,ecx
and dx,0xffff
mov [eax+0xee],dx
mov edx,[eax+0xf6]
sar ecx,0x10
test edx,edx
jl JUMP_002627
cmp edx,ecx
jnl JUMP_002626
mov ecx,edx
JUMP_002626:
test ecx,ecx
jnl JUMP_002627
xor ecx,ecx
JUMP_002627:
test edx,edx
jnl JUMP_002629
cmp edx,ecx
jng JUMP_002628
mov ecx,edx
JUMP_002628:
test ecx,ecx
jng JUMP_002629
xor ecx,ecx
JUMP_002629:
add [eax+0x90],ecx
movzx ecx,WORD PTR [eax+0xf0]
add ecx,[edi+0x8]
mov edx,ecx
and dx,0xffff
mov [eax+0xf0],dx
mov edx,[eax+0xfa]
sar ecx,0x10
test edx,edx
jl JUMP_002631
cmp edx,ecx
jnl JUMP_002630
mov ecx,edx
JUMP_002630:
test ecx,ecx
jnl JUMP_002631
xor ecx,ecx
JUMP_002631:
test edx,edx
jnl JUMP_002633
cmp edx,ecx
jng JUMP_002632
mov ecx,edx
JUMP_002632:
test ecx,ecx
jng JUMP_002633
xor ecx,ecx
JUMP_002633:
add [eax+0x94],ecx
jmp JUMP_002647
JUMP_002634:
mov ecx,esi
sar DWORD PTR [edi],cl
mov ecx,esi
sar DWORD PTR [edi+0x4],cl
mov ecx,esi
sar DWORD PTR [edi+0x8],cl
mov edx,[eax+0xf2]
test edx,edx
jl JUMP_002636
cmp edx,[edi]
jnl JUMP_002635
mov [edi],edx
JUMP_002635:
cmp DWORD PTR [edi],+0x0
jnl JUMP_002636
xor ecx,ecx
mov [edi],ecx
JUMP_002636:
test edx,edx
jnl JUMP_002638
cmp edx,[edi]
jng JUMP_002637
mov [edi],edx
JUMP_002637:
cmp DWORD PTR [edi],+0x0
jng JUMP_002638
xor edx,edx
mov [edi],edx
JUMP_002638:
mov edx,[eax+0xf6]
test edx,edx
jl JUMP_002640
cmp edx,[edi+0x4]
jnl JUMP_002639
mov [edi+0x4],edx
JUMP_002639:
cmp DWORD PTR [edi+0x4],+0x0
jnl JUMP_002640
xor ecx,ecx
mov [edi+0x4],ecx
JUMP_002640:
test edx,edx
jnl JUMP_002642
cmp edx,[edi+0x4]
jng JUMP_002641
mov [edi+0x4],edx
JUMP_002641:
cmp DWORD PTR [edi+0x4],+0x0
jng JUMP_002642
xor edx,edx
mov [edi+0x4],edx
JUMP_002642:
mov edx,[eax+0xfa]
test edx,edx
jl JUMP_002644
cmp edx,[edi+0x8]
jnl JUMP_002643
mov [edi+0x8],edx
JUMP_002643:
cmp DWORD PTR [edi+0x8],+0x0
jnl JUMP_002644
xor ecx,ecx
mov [edi+0x8],ecx
JUMP_002644:
test edx,edx
jnl JUMP_002646
cmp edx,[edi+0x8]
jng JUMP_002645
mov [edi+0x8],edx
JUMP_002645:
cmp DWORD PTR [edi+0x8],+0x0
jng JUMP_002646
xor edx,edx
mov [edi+0x8],edx
JUMP_002646:
mov edx,[edi]
add [eax+0x8c],edx
mov edx,[edi+0x4]
add [eax+0x90],edx
mov edx,[edi+0x8]
add [eax+0x94],edx
JUMP_002647:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000602:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov edx,[rbp+24]
mov eax,[rbp+16]
lea edi,[rbp-0xc]
sar edx,0x3
or esi,-0x1
cmp edx,0x7fff
jng JUMP_002649
mov esi,0xf
cmp edx,0x7fff
jng JUMP_002649
JUMP_002648:
sar edx,1
dec esi
cmp edx,0x7fff
jg JUMP_002648
JUMP_002649:
xor ecx,ecx
mov [edi],ecx
xor ecx,ecx
mov [edi+0x4],ecx
xor ecx,ecx
mov [edi+0x8],ecx
movsx ecx,WORD PTR [eax+0xb6]
test ecx,ecx
jz JUMP_002650
mov ebx,[eax]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
mov [edi],ebx
mov ebx,[eax+0x4]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
mov [edi+0x4],ebx
mov ebx,[eax+0x8]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
mov [edi+0x8],ebx
JUMP_002650:
movsx ecx,WORD PTR [eax+0xb8]
test ecx,ecx
jz JUMP_002651
mov ebx,[eax+0xc]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi],ebx
mov ebx,[eax+0x10]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x4],ebx
mov ebx,[eax+0x14]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x8],ebx
JUMP_002651:
movsx ecx,WORD PTR [eax+0xba]
test ecx,ecx
jz JUMP_002652
mov ebx,[eax+0x18]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi],ebx
mov ebx,[eax+0x1c]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x4],ebx
mov ebx,[eax+0x20]
sar ebx,0x10
imul ebx,edx
sar ebx,0xf
imul ebx,ecx
add [edi+0x8],ebx
JUMP_002652:
shl DWORD PTR [edi],1
shl DWORD PTR [edi+0x4],1
shl DWORD PTR [edi+0x8],1
test esi,esi
jnl JUMP_002653
movzx edx,WORD PTR [eax+0xec]
add edx,[edi]
mov ecx,edx
and cx,0xffff
mov [eax+0xec],cx
sar edx,0x10
add [eax+0x8c],edx
movzx edx,WORD PTR [eax+0xee]
add edx,[edi+0x4]
mov ecx,edx
and cx,0xffff
mov [eax+0xee],cx
sar edx,0x10
add [eax+0x90],edx
movzx edx,WORD PTR [eax+0xf0]
add edx,[edi+0x8]
mov ecx,edx
and cx,0xffff
mov [eax+0xf0],cx
sar edx,0x10
add [eax+0x94],edx
jmp JUMP_002654
JUMP_002653:
mov ecx,esi
sar DWORD PTR [edi],cl
mov ecx,esi
sar DWORD PTR [edi+0x4],cl
mov ecx,esi
sar DWORD PTR [edi+0x8],cl
mov edx,[edi]
add [eax+0x8c],edx
mov edx,[edi+0x4]
add [eax+0x90],edx
mov edx,[edi+0x8]
add [eax+0x94],edx
JUMP_002654:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
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
FUNC_001482:
push rbp
mov rbp,rsp
push rcx
mov ax,[rbp+18]
add ax,[rbp+26]
mov [rbp-0x2],ax
movsx eax,WORD PTR [rbp+16]
movsx edx,WORD PTR [rbp+24]
imul edx
sar eax,0xf
mov [rbp-0x4],ax
mov eax,[rbp-0x4]
pop rcx
pop rbp
ret
FUNC_001483:
push rbp
mov rbp,rsp
push rcx
cmp WORD PTR [rbp+24],+0x0
jnz JUMP_005624
mov WORD PTR [rbp-0x2],0x7f
mov WORD PTR [rbp-0x4],0x7fff
mov eax,[rbp-0x4]
pop rcx
pop rbp
ret
JUMP_005624:
mov ax,[rbp+18]
sub ax,[rbp+26]
mov [rbp-0x2],ax
movsx eax,WORD PTR [rbp+16]
shl eax,0xe
movsx edx,WORD PTR [rbp+24]
mov ecx,edx
cdq
idiv ecx
mov [rbp-0x4],ax
movsx eax,WORD PTR [rbp-0x4]
cdq
xor eax,edx
sub eax,edx
cmp eax,0x4000
jl JUMP_005625
inc WORD PTR [rbp-0x2]
jmp JUMP_005626
JUMP_005625:
shl WORD PTR [rbp-0x4],1
JUMP_005626:
mov eax,[rbp-0x4]
pop rcx
pop rbp
ret
FUNC_001496:
push rbp
mov rbp,rsp
cmp WORD PTR [rbp+16],+0x0
jz JUMP_005657
jmp JUMP_005656
JUMP_005655:
shl WORD PTR [rbp+16],1
dec WORD PTR [rbp+18]
JUMP_005656:
movsx eax,WORD PTR [rbp+16]
test ah,0x40
jz JUMP_005655
JUMP_005657:
mov eax,[rbp+16]
pop rbp
ret
FUNC_001511:
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
FUNC_001512:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
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
FUNC_001515:
push rbp
mov rbp,rsp
mov edx,[rbp+24]
mov eax,[rbp+16]
mov ecx,eax
and ecx,0xffff
imul ecx,edx
shr ecx,0x10
shr eax,0x10
imul edx
add ecx,eax
mov eax,ecx
pop rbp
ret
FUNC_001516:
push rbp
mov rbp,rsp
push rbx
push rsi
mov ebx,[rbp+24]
mov esi,[rbp+16]
test ebx,ebx
jnl JUMP_005687
neg ebx
push rbx
push rsi
call QWORD PTR [DATA_007747]
add rsp,16
add eax,eax
neg eax
jmp JUMP_005688
JUMP_005687:
push rbx
push rsi
call QWORD PTR [DATA_007747]
add rsp,16
add eax,eax
JUMP_005688:
pop rsi
pop rbx
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
FUNC_001657:
push rbp
mov rbp,rsp
push rsi
mov eax,[rbp+16]
mov edx,[eax+0x4]
test edx,edx
jz JUMP_006335
inc edx
jnz JUMP_006337
JUMP_006335:
mov ecx,[eax+0xc]
test ecx,ecx
jz JUMP_006336
inc ecx
jnz JUMP_006337
JUMP_006336:
mov esi,[eax+0x14]
test esi,esi
jz JUMP_006344
inc esi
jz JUMP_006344
JUMP_006337:
cmp DWORD PTR [eax+0x4],+0x0
jnl JUMP_006338
mov edx,[eax+0x4]
neg edx
jmp JUMP_006339
JUMP_006338:
mov edx,[eax+0x4]
JUMP_006339:
cmp DWORD PTR [eax+0xc],+0x0
jnl JUMP_006340
mov ecx,[eax+0xc]
neg ecx
jmp JUMP_006341
JUMP_006340:
mov ecx,[eax+0xc]
JUMP_006341:
or edx,ecx
cmp DWORD PTR [eax+0x14],+0x0
jnl JUMP_006342
mov ecx,[eax+0x14]
neg ecx
jmp JUMP_006343
JUMP_006342:
mov ecx,[eax+0x14]
JUMP_006343:
or edx,ecx
mov eax,0x20
jmp JUMP_006351
JUMP_006344:
cmp DWORD PTR [eax+0x4],+0x0
jnl JUMP_006345
mov edx,[eax]
neg edx
jmp JUMP_006346
JUMP_006345:
mov edx,[eax]
JUMP_006346:
cmp DWORD PTR [eax+0xc],+0x0
jnl JUMP_006347
mov ecx,[eax+0x8]
neg ecx
jmp JUMP_006348
JUMP_006347:
mov ecx,[eax+0x8]
JUMP_006348:
or edx,ecx
cmp DWORD PTR [eax+0x14],+0x0
jnl JUMP_006349
mov ecx,[eax+0x10]
neg ecx
jmp JUMP_006350
JUMP_006349:
mov ecx,[eax+0x10]
JUMP_006350:
or edx,ecx
xor eax,eax
JUMP_006351:
cmp edx,0xffff
jna JUMP_006352
shr edx,0x10
add eax,+0x10
JUMP_006352:
cmp edx,0xff
jna JUMP_006353
shr edx,0x8
add eax,+0x8
JUMP_006353:
cmp edx,+0xf
jna JUMP_006354
shr edx,0x4
add eax,+0x4
JUMP_006354:
cmp edx,+0x3
jna JUMP_006355
shr edx,0x2
add eax,+0x2
JUMP_006355:
cmp edx,+0x1
jna JUMP_006356
inc eax
JUMP_006356:
pop rsi
pop rbp
ret
FUNC_001658:
push rbp
mov rbp,rsp
push rbx
push rsi
mov esi,[rbp+16]
push rsi
call FUNC_001657
pop rcx
mov ebx,eax
sub ebx,[rbp+24]
test ebx,ebx
jg JUMP_006357
xor eax,eax
jmp JUMP_006358
JUMP_006357:
push rbx
push rsi
call FUNC_001660
add rsp,16
mov eax,ebx
JUMP_006358:
pop rsi
pop rbx
pop rbp
ret
FUNC_001660:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov edx,[rbp+24]
mov eax,[rbp+16]
test edx,edx
jz JUMP_006362
cmp edx,+0x20
jnl JUMP_006359
mov ebx,0x20
sub ebx,edx
mov ecx,ebx
mov esi,[eax+0x4]
shl esi,cl
mov ecx,edx
mov edi,[eax]
shr edi,cl
or esi,edi
mov [eax],esi
mov ecx,edx
sar DWORD PTR [eax+0x4],cl
mov ecx,ebx
mov esi,[eax+0xc]
shl esi,cl
mov ecx,edx
mov edi,[eax+0x8]
shr edi,cl
or esi,edi
mov [eax+0x8],esi
mov ecx,edx
sar DWORD PTR [eax+0xc],cl
mov ecx,ebx
mov ebx,[eax+0x14]
shl ebx,cl
mov ecx,edx
mov esi,[eax+0x10]
shr esi,cl
or ebx,esi
mov [eax+0x10],ebx
mov ecx,edx
sar DWORD PTR [eax+0x14],cl
jmp JUMP_006362
JUMP_006359:
cmp edx,+0x20
jng JUMP_006360
lea ebx,[edx-0x20]
mov ecx,ebx
mov esi,[eax+0x4]
sar esi,cl
mov [eax],esi
mov ecx,ebx
mov esi,[eax+0xc]
sar esi,cl
mov [eax+0x8],esi
mov ecx,ebx
mov edx,[eax+0x14]
sar edx,cl
mov [eax+0x10],edx
jmp JUMP_006361
JUMP_006360:
mov edx,[eax+0x4]
mov [eax],edx
mov edx,[eax+0xc]
mov [eax+0x8],edx
mov edx,[eax+0x14]
mov [eax+0x10],edx
JUMP_006361:
sar DWORD PTR [eax+0x4],0x1f
sar DWORD PTR [eax+0xc],0x1f
sar DWORD PTR [eax+0x14],0x1f
JUMP_006362:
pop rdi
pop rsi
pop rbx
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
FUNC_001670:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+32]
mov ebx,[rbp+24]
mov edi,[rbp+16]
mov eax,[esi]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[esi+0x4]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
push rdx
mov eax,[esi+0x8]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [rbp-0x4],edx
mov eax,[esi+0xc]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[esi+0x10]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
push rdx
mov eax,[esi+0x14]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [rbp-0x8],edx
mov eax,[esi+0x18]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
push rdx
mov eax,[esi+0x20]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [edi+0x8],edx
mov eax,[rbp-0x4]
mov [edi],eax
mov eax,[rbp-0x8]
mov [edi+0x4],eax
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret

_abs:
 push rbp
 mov rbp,rsp
 mov eax,DWORD PTR [rbp+16]
 test eax,eax
 jge abs_nonnegative
 mov edx,eax
 neg edx
 jmp abs_return
abs_nonnegative:
 mov edx,eax
abs_return:
 mov eax,edx
 pop rbp
 ret
FUNC_000606:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],606
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq

 push rbp
 mov rbp,rsp
 pushfq
 push rax
 push rcx
 push rdx
 push rsi
 push rdi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 cmp DWORD PTR [rbp+24],OFFSET FLAT:bank
 jne bad_pointer
 mov DWORD PTR [boundary_called],1
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:boundary_body
 mov ecx,338
 rep movsb
 mov eax,DWORD PTR [request_count]
 cmp eax,2
 jae bad_trace
 shl eax,4
 mov DWORD PTR [requests+eax],606
 inc DWORD PTR [request_count]
 cmp DWORD PTR [input+76],0
 je frame_response_done
 mov esi,OFFSET FLAT:input+756
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov DWORD PTR [response_applied],1
frame_response_done:
 pop rdi
 pop rsi
 pop rdx
 pop rcx
 pop rax
 popfq
 pop rbp
 ret
FUNC_001910:
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 push rcx
 push rdx
 cmp DWORD PTR [rbp+40],OFFSET FLAT:body
 jne bad_pointer
 mov eax,DWORD PTR [request_count]
 cmp eax,2
 jae bad_trace
 shl eax,4
 mov DWORD PTR [requests+eax],1910
 mov ecx,DWORD PTR [rbp+16]
 mov DWORD PTR [requests+eax+4],ecx
 mov ecx,DWORD PTR [rbp+24]
 mov DWORD PTR [requests+eax+8],ecx
 mov ecx,DWORD PTR [rbp+32]
 mov DWORD PTR [requests+eax+12],ecx
 inc DWORD PTR [request_count]
 pop rdx
 pop rcx
 pop rax
 popfq
 pop rbp
 ret
bad_trace:
 mov edi,91
 jmp finish
bad_pointer:
 mov edi,92
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
 mov edx,1094
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,1094
 jne read_more
 cld
 mov edi,OFFSET FLAT:body_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:bank_before
 mov ecx,86644+32
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+80
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 movzx eax,BYTE PTR [body+0x56]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 mov DWORD PTR [parent_address],eax
 mov edi,eax
 mov esi,OFFSET FLAT:input+418
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_copy
 mov ecx,86644
 rep movsb
 mov edi,OFFSET FLAT:output
 mov ecx,1214
 xor eax,eax
 rep stosb
 mov edi,OFFSET FLAT:boundary_body
 mov ecx,338+64+32+16
 rep stosb
 mov DWORD PTR [trace_count],eax
 mov DWORD PTR [request_count],eax
 mov DWORD PTR [boundary_called],eax
 mov DWORD PTR [response_applied],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_009155],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_008867],eax
 mov eax,DWORD PTR [input+12]
 mov BYTE PTR [DATA_008870],al
 mov eax,DWORD PTR [input+16]
 mov BYTE PTR [DATA_008871],al
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [DATA_008918],eax
 mov eax,DWORD PTR [input+24]
 mov BYTE PTR [DATA_009046],al
 mov eax,DWORD PTR [input+28]
 mov DWORD PTR [DATA_008839],eax
 mov eax,DWORD PTR [input+32]
 mov DWORD PTR [DATA_008840],eax
 mov eax,DWORD PTR [input+36]
 mov DWORD PTR [DATA_008841],eax
 mov eax,DWORD PTR [input+40]
 mov BYTE PTR [DATA_007692],al
 mov eax,DWORD PTR [input+44]
 mov BYTE PTR [DATA_007694],al
 mov eax,DWORD PTR [input+48]
 mov DWORD PTR [DATA_008708],eax
 mov eax,DWORD PTR [input+52]
 mov DWORD PTR [DATA_008709],eax
 mov eax,DWORD PTR [input+56]
 mov DWORD PTR [DATA_008710],eax
 mov eax,DWORD PTR [input+60]
 mov DWORD PTR [DATA_008857],eax
 mov eax,DWORD PTR [input+64]
 mov WORD PTR [DATA_008933],ax
 mov eax,DWORD PTR [input+68]
 mov DWORD PTR [DATA_008868],eax
 mov eax,DWORD PTR [input+72]
 mov DWORD PTR [DATA_008869],eax
 push OFFSET FLAT:body
 cmp DWORD PTR [input],0
 je operation1041
 cmp DWORD PTR [input],1
 je operation1043
 cmp DWORD PTR [input],2
 je operation1044
 cmp DWORD PTR [input],3
 jne bad_trace
 call FUNC_001045
 jmp operation_done
operation1041:
 call FUNC_001041
 jmp operation_done
operation1043:
 call FUNC_001043
 jmp operation_done
operation1044:
 call FUNC_001044
operation_done:
 add rsp,8
 mov DWORD PTR [output],0x50444f53
 mov eax,DWORD PTR [trace_count]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [request_count]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [boundary_called]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [response_applied]
 mov DWORD PTR [output+16],eax
 movsx eax,WORD PTR [DATA_008933]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [DATA_008708]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [DATA_008709]
 mov DWORD PTR [output+32],eax
 mov eax,DWORD PTR [DATA_008710]
 mov DWORD PTR [output+36],eax
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+40
 mov ecx,338
 rep movsb
 mov esi,DWORD PTR [parent_address]
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:boundary_body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:trace_codes
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:requests
 mov ecx,32
 rep movsb
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_copy
 mov ecx,86644
 repe cmpsb
 sete al
 xor al,1
 movzx eax,al
 mov DWORD PTR [output+20],eax
 mov esi,OFFSET FLAT:output
 mov edx,1214
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
DATA_006143: .quad FUNC_000585
DATA_006151: .quad FUNC_000599
DATA_006153: .quad FUNC_000603
DATA_006154: .quad FUNC_000606
DATA_006155: .quad FUNC_000607
DATA_006157: .quad FUNC_000609
DATA_006159: .byte 18,3,3,3
DATA_006160: .byte 5,2,1,1
DATA_006161: .byte 1,1,0,0
DATA_007719: .quad FUNC_001520
DATA_007722: .quad FUNC_001496
DATA_007731: .quad FUNC_001483
DATA_007738: .quad FUNC_001502
DATA_007744: .quad FUNC_001512
DATA_007747: .quad FUNC_001515
DATA_007748: .quad FUNC_001516
DATA_007754: .quad FUNC_001532
DATA_009133: .long bank
.section .bss
.balign 16
input: .zero 1094
body_before: .zero 16
body: .zero 338
body_after: .zero 16
bank_before: .zero 16
bank: .zero 86644
bank_after: .zero 16
bank_copy: .zero 86644
output: .zero 1214
parent_address: .zero 4
boundary_body: .zero 338
trace_codes: .zero 64
requests: .zero 32
trace_count: .zero 4
request_count: .zero 4
boundary_called: .zero 4
response_applied: .zero 4
DATA_007692: .zero 1
DATA_007694: .zero 1
.balign 4
DATA_008708: .zero 4
DATA_008709: .zero 4
DATA_008710: .zero 4
DATA_008839: .zero 4
DATA_008840: .zero 4
DATA_008841: .zero 4
DATA_008857: .zero 4
DATA_008867: .zero 4
DATA_008868: .zero 4
DATA_008869: .zero 4
DATA_008870: .zero 1
DATA_008871: .zero 1
.balign 4
DATA_008918: .zero 4
DATA_008933: .zero 2
DATA_009046: .zero 1
.balign 4
DATA_009155: .zero 4
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
