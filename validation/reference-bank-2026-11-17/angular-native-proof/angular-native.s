.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000585:
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
 mov edx,390
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,390
 jne read_more
 cld
 mov edi,OFFSET FLAT:body_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+52
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [DATA_008857],eax
 mov ax,WORD PTR [input+20]
 mov WORD PTR [DATA_008933],ax
 mov eax,DWORD PTR [input+40]
 mov DWORD PTR [DATA_008708],eax
 mov eax,DWORD PTR [input+44]
 mov DWORD PTR [DATA_008709],eax
 mov eax,DWORD PTR [input+48]
 mov DWORD PTR [DATA_008710],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [quantized],eax
 mov DWORD PTR [quantized_shift],0
 mov eax,DWORD PTR [input]
 cmp eax,1
 je quantize
 cmp eax,2
 je rotate_pair
 cmp eax,3
 je spin_command
 cmp eax,4
 je normalize
 push QWORD PTR [input+12]
 push QWORD PTR [input+8]
 push QWORD PTR [input+4]
 push OFFSET FLAT:body
 call FUNC_000585
 add rsp,32
 jmp capture
quantize:
 push OFFSET FLAT:quantized_shift
 push OFFSET FLAT:quantized
 call FUNC_000584
 add rsp,16
 jmp capture
rotate_pair:
 mov eax,DWORD PTR [input+36]
 push rax
 mov eax,0x70
 cmp DWORD PTR [input+32],0
 je pair_flag_ready
 mov eax,0x6d
pair_flag_ready:
 push rax
 mov eax,DWORD PTR [input+28]
 add eax,OFFSET FLAT:body
 push rax
 mov eax,DWORD PTR [input+24]
 add eax,OFFSET FLAT:body
 push rax
 push OFFSET FLAT:body
 call FUNC_000611
 add rsp,40
 jmp capture
spin_command:
 push OFFSET FLAT:body
 call FUNC_000609
 add rsp,8
 jmp capture
normalize:
 push OFFSET FLAT:body
 call FUNC_001520
 add rsp,8
capture:
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output
 mov ecx,338
 rep movsb
 mov ax,WORD PTR [DATA_008933]
 mov WORD PTR [output+338],ax
 mov eax,DWORD PTR [DATA_008857]
 mov DWORD PTR [output+340],eax
 mov eax,DWORD PTR [quantized]
 mov DWORD PTR [output+344],eax
 mov eax,DWORD PTR [quantized_shift]
 mov DWORD PTR [output+348],eax
 mov edi,OFFSET FLAT:output+352
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,384
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
 mov edi,95
 jmp exit
finished:
 xor edi,edi
exit:
 mov eax,60
 syscall
.section .data
DATA_006159: .byte 18,3,3,3
DATA_006160: .byte 5,2,1,1
DATA_006161: .byte 1,1,0,0
DATA_007719: .quad FUNC_001520
DATA_007738: .quad FUNC_001502
.section .bss
.balign 16
input: .zero 390
body_before: .zero 16
body: .zero 338
body_after: .zero 16
output: .zero 384
DATA_008708: .zero 4
DATA_008709: .zero 4
DATA_008710: .zero 4
DATA_008857: .zero 4
DATA_008933: .zero 2
quantized: .zero 4
quantized_shift: .zero 4
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
