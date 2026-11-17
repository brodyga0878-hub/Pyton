.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000595:
push rbp
mov rbp,rsp
add rsp,-384
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
cmp BYTE PTR [ebx+0x87],0x1
jz JUMP_002575
mov eax,[ebx+0x8c]
mov [esi],eax
mov eax,[ebx+0x90]
mov [esi+0x4],eax
mov eax,[ebx+0x94]
mov [esi+0x8],eax
jmp JUMP_002578
JUMP_002575:
test BYTE PTR [ebx+0x14c],0x20
jz JUMP_002576
xor eax,eax
mov [esi],eax
xor eax,eax
mov [esi+0x4],eax
xor eax,eax
mov [esi+0x8],eax
jmp JUMP_002578
JUMP_002576:
push +0x0
push rbx
lea eax,[rbp-0x15c]
push rax
call QWORD PTR [DATA_007755]
add rsp,24
mov eax,[rbp-0xb4]
mov [rbp-0x8],eax
mov eax,[rbp-0xb0]
mov [rbp-0x4],eax
mov eax,[ebx+0x3e]
mov [rbp-0x174],eax
mov eax,[ebx+0x46]
mov [rbp-0x170],eax
mov eax,[ebx+0x4e]
mov [rbp-0x16c],eax
mov edx,[rbp-0x8]
mov eax,edx
add eax,0x82c00
cmp edx,eax
jna JUMP_002577
inc DWORD PTR [rbp-0x4]
JUMP_002577:
mov edx,eax
mov [rbp-0x8],edx
mov [rbp-0x180],edx
mov eax,[rbp-0x4]
mov [rbp-0x17c],eax
lea eax,[rbp-0x15c]
mov [rbp-0x178],eax
lea eax,[rbp-0x180]
push rax
call FUNC_000866
pop rcx
mov eax,[ebx+0x3e]
sub [rbp-0x174],eax
mov eax,[ebx+0x46]
sub [rbp-0x170],eax
mov eax,[ebx+0x4e]
sub [rbp-0x16c],eax
neg DWORD PTR [rbp-0x174]
neg DWORD PTR [rbp-0x170]
neg DWORD PTR [rbp-0x16c]
sar DWORD PTR [rbp-0x174],0xa
sar DWORD PTR [rbp-0x170],0xa
sar DWORD PTR [rbp-0x16c],0xa
mov eax,[rbp-0x174]
mov [esi],eax
mov eax,[rbp-0x170]
mov [esi+0x4],eax
mov eax,[rbp-0x16c]
mov [esi+0x8],eax
JUMP_002578:
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000604:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
mov al,[esi+0x56]
mov [ebx+0x56],al
push QWORD PTR [rsi+0x42]
push QWORD PTR [rsi+0x3e]
push QWORD PTR [rbx+0x42]
push QWORD PTR [rbx+0x3e]
lea eax,[ebx+0x3e]
push rax
call FUNC_001333
add rsp,40
push QWORD PTR [rsi+0x4a]
push QWORD PTR [rsi+0x46]
push QWORD PTR [rbx+0x4a]
push QWORD PTR [rbx+0x46]
lea eax,[ebx+0x46]
push rax
call FUNC_001333
add rsp,40
push QWORD PTR [rsi+0x52]
push QWORD PTR [rsi+0x4e]
push QWORD PTR [rbx+0x52]
push QWORD PTR [rbx+0x4e]
lea eax,[ebx+0x4e]
push rax
call FUNC_001333
add rsp,40
lea eax,[rbp-0xc]
push rax
push rsi
call FUNC_000595
add rsp,16
mov eax,[rbp-0xc]
add [ebx+0x8c],eax
mov eax,[rbp-0x8]
add [ebx+0x90],eax
mov eax,[rbp-0x4]
add [ebx+0x94],eax
push +0x0
push +0xb
call FUNC_000148
add rsp,16
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000605:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
mov eax,[rbp+32]
mov ebx,[rbp+16]
mov edx,eax
mov [ebx+0x56],dl
mov ecx,[rbp+24]
push rcx
movsx eax,dl
push rax
call QWORD PTR [DATA_007754]
add rsp,16
mov esi,eax
push QWORD PTR [rsi+0x42]
push QWORD PTR [rsi+0x3e]
push QWORD PTR [rbx+0x42]
push QWORD PTR [rbx+0x3e]
lea eax,[ebx+0x3e]
push rax
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0x4a]
push QWORD PTR [rsi+0x46]
push QWORD PTR [rbx+0x4a]
push QWORD PTR [rbx+0x46]
lea eax,[ebx+0x46]
push rax
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0x52]
push QWORD PTR [rsi+0x4e]
push QWORD PTR [rbx+0x52]
push QWORD PTR [rbx+0x4e]
lea eax,[ebx+0x4e]
push rax
call FUNC_001335
add rsp,40
lea eax,[rbp-0xc]
push rax
push rsi
call FUNC_000595
add rsp,16
mov eax,[rbp-0xc]
sub [ebx+0x8c],eax
mov eax,[rbp-0x8]
sub [ebx+0x90],eax
mov eax,[rbp-0x4]
sub [ebx+0x94],eax
push +0x0
push +0xb
call FUNC_000148
add rsp,16
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000606:
push rbp
mov rbp,rsp
add rsp,-36
push rbx
push rsi
push rdi
mov edi,[rbp+16]
cmp BYTE PTR [edi+0x57],0x0
jnz JUMP_002670
xor eax,eax
mov al,[edi+0x56]
mov [rbp-0x4],eax
cmp DWORD PTR [rbp-0x4],+0x0
jnz JUMP_002663
mov DWORD PTR [rbp-0xc],0x32
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_002664
JUMP_002663:
mov eax,[rbp+24]
push rax
mov eax,[rbp-0x4]
push rax
call QWORD PTR [DATA_007754]
add rsp,16
mov ebx,eax
lea eax,[rbp-0xc]
push rax
lea eax,[rbp-0x24]
push rax
push rbx
push rdi
call FUNC_000590
add rsp,32
movsx eax,WORD PTR [ebx+0xda]
sub [rbp-0xc],eax
shl DWORD PTR [rbp-0xc],0x2
add DWORD PTR [rbp-0xc],+0x20
xor eax,eax
mov al,[ebx+0x56]
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_002664
mov eax,[rbp+24]
push rax
mov eax,[rbp-0x8]
push rax
call QWORD PTR [DATA_007754]
add rsp,16
mov esi,eax
lea eax,[rbp-0x14]
push rax
lea eax,[rbp-0x24]
push rax
push rsi
push rdi
call FUNC_000590
add rsp,32
movsx eax,WORD PTR [esi+0xda]
sub [rbp-0x14],eax
add DWORD PTR [rbp-0x14],+0x28
mov eax,[rbp-0x14]
cmp eax,[rbp-0xc]
jg JUMP_002664
push rbx
push rdi
call FUNC_000604
add rsp,16
jmp JUMP_002670
JUMP_002664:
mov esi,0x72
mov eax,[rbp+24]
add eax,+0x72
mov [rbp-0x18],eax
JUMP_002665:
mov eax,[rbp-0x18]
test BYTE PTR [eax],0x10
jnz JUMP_002666
dec DWORD PTR [rbp-0x18]
dec esi
test esi,esi
jg JUMP_002665
JUMP_002666:
test esi,esi
jg JUMP_002667
xor eax,eax
mov al,[edi+0x56]
cmp eax,[rbp-0x4]
jz JUMP_002670
mov eax,[rbp-0x4]
push rax
mov eax,[rbp+24]
push rax
push rdi
call FUNC_000605
add rsp,24
jmp JUMP_002670
JUMP_002667:
mov eax,[rbp+24]
push rax
push rsi
call QWORD PTR [DATA_007754]
add rsp,16
mov ebx,eax
mov al,[ebx+0x56]
cmp al,[edi+0x56]
jnz JUMP_002668
lea eax,[rbp-0x10]
push rax
lea eax,[rbp-0x24]
push rax
push rbx
push rdi
call FUNC_000590
add rsp,32
movsx eax,WORD PTR [ebx+0xda]
sub [rbp-0x10],eax
shl DWORD PTR [rbp-0x10],0x4
mov eax,[rbp-0x10]
cmp eax,[rbp-0xc]
jnl JUMP_002669
mov [rbp-0x4],esi
mov eax,[rbp-0x10]
mov [rbp-0xc],eax
jmp JUMP_002669
JUMP_002668:
xor eax,eax
mov al,[ebx+0x56]
cmp eax,[rbp-0x8]
jnz JUMP_002669
lea eax,[rbp-0x10]
push rax
lea eax,[rbp-0x24]
push rax
push rbx
push rdi
call FUNC_000590
add rsp,32
movsx eax,WORD PTR [ebx+0xda]
sub [rbp-0x10],eax
shl DWORD PTR [rbp-0x10],0x2
add DWORD PTR [rbp-0x10],+0x20
mov eax,[rbp-0x10]
cmp eax,[rbp-0xc]
jnl JUMP_002669
mov eax,[rbp+24]
push rax
xor eax,eax
mov al,[edi+0x56]
push rax
call QWORD PTR [DATA_007754]
add rsp,16
mov ebx,eax
push rbx
push rdi
call FUNC_000604
add rsp,16
jmp JUMP_002670
JUMP_002669:
dec esi
dec DWORD PTR [rbp-0x18]
test esi,esi
jg JUMP_002665
xor eax,eax
mov al,[edi+0x56]
cmp eax,[rbp-0x4]
jz JUMP_002670
mov eax,[rbp-0x4]
push rax
mov eax,[rbp+24]
push rax
push rdi
call FUNC_000605
add rsp,24
JUMP_002670:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000590:
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
mov ebx,[rbp+32]
mov esi,[rbp+16]
push rsi
lea eax,[rbp-0x18]
push rax
call QWORD PTR [DATA_007802]
add rsp,16
push rsi
mov eax,[rbp+24]
push rax
lea eax,[rbp-0x18]
push rax
call QWORD PTR [DATA_007803]
add rsp,24
push +0xd
lea eax,[rbp-0x18]
push rax
call FUNC_001658
add rsp,16
mov edx,[rbp+40]
mov [edx],eax
mov eax,[rbp-0x18]
mov [ebx],eax
mov eax,[rbp-0x10]
mov [ebx+0x4],eax
mov eax,[rbp-0x8]
mov [ebx+0x8],eax
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
FUNC_001517:
push rbp
mov rbp,rsp
push rbx
push rsi
mov ebx,[rbp+32]
mov edx,[rbp+24]
mov eax,[rbp+16]
xor ecx,ecx
mov [eax],ecx
xor ecx,ecx
mov [eax+0x8],ecx
xor ecx,ecx
mov [eax+0x10],ecx
cmp ebx,+0x20
jl JUMP_005689
sub ebx,+0x20
mov ecx,ebx
mov esi,[edx]
shl esi,cl
mov [eax+0x4],esi
mov ecx,ebx
mov esi,[edx+0x4]
shl esi,cl
mov [eax+0xc],esi
mov ecx,ebx
mov edx,[edx+0x8]
shl edx,cl
mov [eax+0x14],edx
jmp JUMP_005690
JUMP_005689:
mov ecx,[edx]
mov [eax+0x4],ecx
mov ecx,[edx+0x4]
mov [eax+0xc],ecx
mov edx,[edx+0x8]
mov [eax+0x14],edx
mov edx,0x20
sub edx,ebx
push rdx
push rax
call FUNC_001660
add rsp,16
JUMP_005690:
pop rsi
pop rbx
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
FUNC_001531:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,eax
lea eax,[edx+eax*4]
lea eax,[edx+eax*4]
lea eax,[edx+eax*8]
add eax,eax
add eax,[DATA_007758]
add eax,+0x74
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
FUNC_001663:
push rbp
mov rbp,rsp
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
push QWORD PTR [rsi+0x4]
push QWORD PTR [rsi]
push QWORD PTR [DATA_007801]
push QWORD PTR [DATA_007800]
push rbx
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0xc]
push QWORD PTR [rsi+0x8]
push QWORD PTR [DATA_007801]
push QWORD PTR [DATA_007800]
lea eax,[ebx+0x8]
push rax
call FUNC_001335
add rsp,40
push QWORD PTR [rsi+0x14]
push QWORD PTR [rsi+0x10]
push QWORD PTR [DATA_007801]
push QWORD PTR [DATA_007800]
add ebx,+0x10
push rbx
call FUNC_001335
add rsp,40
pop rsi
pop rbx
pop rbp
ret
FUNC_001669:
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
mov eax,[esi+0xc]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
push rdx
mov eax,[esi+0x18]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [rbp-0x4],edx
mov eax,[esi+0x4]
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
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [rbp-0x8],edx
mov eax,[esi+0x8]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[esi+0x14]
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
FUNC_001677:
push rbp
mov rbp,rsp
add rsp,-40
push rbx
push rsi
push rdi
mov ebx,[rbp+24]
mov esi,[rbp+16]
cmp BYTE PTR [ebx+0x56],0x0
jz JUMP_006368
mov al,[ebx+0x25]
cmp al,[DATA_008811]
jnz JUMP_006366
push rsi
mov edi,esi
lea esi,[ebx+0x26]
mov ecx,0x6
rep movsd
pop rsi
jmp JUMP_006370
JUMP_006366:
xor eax,eax
mov al,[ebx+0x56]
push rax
call QWORD PTR [DATA_007753]
pop rcx
mov edi,eax
push rdi
push rsi
call FUNC_001677
add rsp,16
cmp BYTE PTR [ebx+0x57],0x0
jz JUMP_006367
push rsi
push rdi
lea esi,[ebx+0x3e]
lea edi,[rbp-0x1c]
mov ecx,0x6
rep movsd
pop rdi
pop rsi
push +0x1c
lea eax,[rbp-0x1c]
push rax
call FUNC_001658
add rsp,16
mov [rbp-0x4],eax
mov eax,[rbp-0x1c]
mov [rbp-0x28],eax
mov eax,[rbp-0x14]
mov [rbp-0x24],eax
mov eax,[rbp-0xc]
mov [rbp-0x20],eax
push rdi
lea eax,[rbp-0x28]
push rax
lea eax,[rbp-0x28]
push rax
call FUNC_001669
add rsp,24
mov eax,[rbp-0x4]
push rax
lea eax,[rbp-0x28]
push rax
lea eax,[rbp-0x1c]
push rax
call QWORD PTR [DATA_007749]
add rsp,24
lea eax,[rbp-0x1c]
push rax
push rsi
call FUNC_001661
add rsp,16
jmp JUMP_006369
JUMP_006367:
lea eax,[ebx+0x3e]
push rax
push rsi
call FUNC_001661
add rsp,16
jmp JUMP_006369
JUMP_006368:
push rsi
mov edi,esi
lea esi,[ebx+0x3e]
mov ecx,0x6
rep movsd
pop rsi
JUMP_006369:
push rsi
lea edi,[ebx+0x26]
mov ecx,0x6
rep movsd
pop rsi
mov al,[DATA_008811]
mov [ebx+0x25],al
JUMP_006370:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001678:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov ebx,[rbp+32]
mov eax,[rbp+24]
mov esi,[rbp+16]
mov dl,[eax+0x56]
cmp dl,[ebx+0x56]
jnz JUMP_006371
mov dl,[eax+0x57]
cmp dl,[ebx+0x57]
jnz JUMP_006372
push rsi
mov edi,esi
lea esi,[eax+0x3e]
mov ecx,0x6
rep movsd
pop rsi
add ebx,+0x3e
push rbx
push rsi
call FUNC_001662
add rsp,16
jmp JUMP_006373
JUMP_006371:
mov dl,[ebx+0x56]
cmp dl,[eax+0x86]
jnz JUMP_006372
add ebx,+0x3e
push rbx
push rsi
call FUNC_001663
add rsp,16
jmp JUMP_006373
JUMP_006372:
push rax
push rsi
call QWORD PTR [DATA_007802]
add rsp,16
add ebx,+0x26
push rbx
push rsi
call FUNC_001662
add rsp,16
JUMP_006373:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_999595:
push rbp
mov rbp,rsp
add rsp,-384
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
cmp BYTE PTR [ebx+0x87],0x1
jz JJUMP_002575
mov eax,[ebx+0x8c]
mov [esi],eax
mov eax,[ebx+0x90]
mov [esi+0x4],eax
mov eax,[ebx+0x94]
mov [esi+0x8],eax
jmp JJUMP_002578
JJUMP_002575:
test BYTE PTR [ebx+0x14c],0x20
jz JJUMP_002576
xor eax,eax
mov [esi],eax
xor eax,eax
mov [esi+0x4],eax
xor eax,eax
mov [esi+0x8],eax
jmp JJUMP_002578
JJUMP_002576:
push +0x0
push rbx
lea eax,[rbp-0x15c]
push rax
call QWORD PTR [DATA_007755]
add rsp,24
mov eax,[rbp-0xb4]
mov [rbp-0x8],eax
mov eax,[rbp-0xb0]
mov [rbp-0x4],eax
mov eax,[ebx+0x3e]
mov [rbp-0x174],eax
mov eax,[ebx+0x46]
mov [rbp-0x170],eax
mov eax,[ebx+0x4e]
mov [rbp-0x16c],eax
mov edx,[rbp-0x8]
mov eax,edx
add eax,0x82c00
cmp edx,eax
jna JJUMP_002577
inc DWORD PTR [rbp-0x4]
JJUMP_002577:
mov edx,eax
mov [rbp-0x8],edx
mov [rbp-0x180],edx
mov eax,[rbp-0x4]
mov [rbp-0x17c],eax
lea eax,[rbp-0x15c]
mov [rbp-0x178],eax
lea eax,[rbp-0x180]
push rax
call FUNC_000866
pop rcx
mov eax,[rbp-0x15c+0x3e]
sub [rbp-0x174],eax
mov eax,[rbp-0x15c+0x46]
sub [rbp-0x170],eax
mov eax,[rbp-0x15c+0x4e]
sub [rbp-0x16c],eax
neg DWORD PTR [rbp-0x174]
neg DWORD PTR [rbp-0x170]
neg DWORD PTR [rbp-0x16c]
sar DWORD PTR [rbp-0x174],0xa
sar DWORD PTR [rbp-0x170],0xa
sar DWORD PTR [rbp-0x16c],0xa
mov eax,[rbp-0x174]
mov [esi],eax
mov eax,[rbp-0x170]
mov [esi+0x4],eax
mov eax,[rbp-0x16c]
mov [esi+0x8],eax
JJUMP_002578:
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret

FUNC_001538:
FUNC_001495:
 mov edi,97
 jmp exit
_memcpy:
 push rbp
 mov rbp,rsp
 push rsi
 push rdi
 mov edi,DWORD PTR [rbp+16]
 mov esi,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov eax,edi
 cld
 rep movsb
 inc DWORD PTR [copy_calls]
 pop rdi
 pop rsi
 pop rbp
 ret
FUNC_000148:
 push rbp
 mov rbp,rsp
 cmp DWORD PTR [rbp+16],11
 jne bad_request
 cmp DWORD PTR [rbp+24],0
 jne bad_request
 inc DWORD PTR [event_calls]
 pop rbp
 ret
bad_request:
 or DWORD PTR [guard_error],1
 pop rbp
 ret
FUNC_000866:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 mov eax,DWORD PTR [rbp+16]
 mov ebx,DWORD PTR [eax+8]
 cmp ebx,OFFSET FLAT:stack
 jb bad_copy
 lea edx,[ebx+338]
 cmp edx,OFFSET FLAT:stack_end
 ja bad_copy
 cmp BYTE PTR [ebx+0x86],0
 jne bad_copy
 mov edx,DWORD PTR [eax]
 mov DWORD PTR [future_tick],edx
 mov DWORD PTR [ebx+0xa8],edx
 mov edx,DWORD PTR [eax+4]
 mov DWORD PTR [future_day],edx
 mov DWORD PTR [ebx+0xac],edx
 mov edx,DWORD PTR [input+16]
 mov DWORD PTR [ebx+0x3e],edx
 mov edx,DWORD PTR [input+20]
 mov DWORD PTR [ebx+0x46],edx
 mov edx,DWORD PTR [input+24]
 mov DWORD PTR [ebx+0x4e],edx
 inc DWORD PTR [future_calls]
 jmp future_done
bad_copy:
 or DWORD PTR [guard_error],2
future_done:
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
 mov edx,39352
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,39352
 jne read_more
 cld
 mov edi,OFFSET FLAT:body_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:bank_before
 mov ecx,38986+32
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,39452
 xor eax,eax
 rep stosb
 mov esi,OFFSET FLAT:input+28
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:bank
 mov ecx,38986
 rep movsb
 mov edi,OFFSET FLAT:event_calls
 xor eax,eax
 mov ecx,10
 rep stosd
 mov al,BYTE PTR [input+12]
 mov BYTE PTR [DATA_008811],al
 mov eax,DWORD PTR [input]
 cmp eax,0
 je parent_velocity
 cmp eax,1
 je leave_parent
 cmp eax,2
 je enter_parent
 cmp eax,3
 je compose
 cmp eax,4
 je select_parent
 cmp eax,9
 je jjffe_probe
 mov edi,96
 jmp exit
parent_velocity:
 push OFFSET FLAT:velocity_result
 call parent_pointer
 push rax
 call FUNC_000595
 add rsp,16
 jmp capture
jjffe_probe:
 push OFFSET FLAT:velocity_result
 call parent_pointer
 push rax
 call FUNC_999595
 add rsp,16
 jmp capture
leave_parent:
 call parent_pointer
 push rax
 push OFFSET FLAT:body
 call FUNC_000604
 add rsp,16
 jmp capture
enter_parent:
 mov eax,DWORD PTR [input+8]
 push rax
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_000605
 add rsp,24
 jmp capture
compose:
 call parent_pointer
 push rax
 push OFFSET FLAT:body
 call FUNC_000604
 add rsp,16
 jmp enter_parent
select_parent:
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_000606
 add rsp,16
capture:
 mov DWORD PTR [output],0x52454642
 mov esi,OFFSET FLAT:event_calls
 mov edi,OFFSET FLAT:output+4
 mov ecx,28
 rep movsb
 mov esi,OFFSET FLAT:velocity_result
 mov edi,OFFSET FLAT:output+32
 mov ecx,12
 rep movsb
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+64
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov ecx,38986
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
 mov esi,OFFSET FLAT:output
 mov edx,39452
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
parent_pointer:
 mov eax,DWORD PTR [input+4]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 ret
failed:
 mov edi,94
 jmp exit
finished:
 xor edi,edi
exit:
 mov eax,60
 syscall
.section .data
DATA_007753: .quad FUNC_001531
DATA_007754: .quad FUNC_001532
DATA_007755: .quad FUNC_001533
DATA_007749: .quad FUNC_001517
DATA_007802: .quad FUNC_001677
DATA_007803: .quad FUNC_001678
DATA_007800: .long 0
DATA_007801: .long 0
DATA_007734: .quad FUNC_001495
DATA_007758: .long bank
DATA_008811: .byte 0
DATA_008804: .long 0
DATA_008807: .long 0
DATA_007210: .zero 64
.section .bss
.balign 16
input: .zero 39352
body_before: .zero 16
body: .zero 338
body_after: .zero 16
bank_before: .zero 16
bank: .zero 38986
bank_after: .zero 16
output: .zero 39452
event_calls: .zero 4
copy_calls: .zero 4
future_calls: .zero 4
future_tick: .zero 4
future_day: .zero 4
unused: .zero 4
guard_error: .zero 4
velocity_result: .zero 12
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
