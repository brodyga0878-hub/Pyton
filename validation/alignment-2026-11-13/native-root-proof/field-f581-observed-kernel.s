.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000576:
push rbp
mov rbp,rsp
add rsp,-48
push rbx
push rsi
push rdi
mov esi,[rbp+16]
mov BYTE PTR [DATA_008697],0x0
mov eax,[esi+0x82]
push rax
mov eax,DWORD PTR [DATA_007756]
call rax
pop rcx
mov edx,0x17
sub edx,[eax+0x14]
mov [rbp-0xc],edx
mov eax,[eax+0x34]
mov [rbp-0x4],eax
mov ebx,[esi+0x140]
mov eax,[rbp+32]
push rsi
mov esi,eax
lea edi,[rbp-0x24]
mov ecx,0x6
rep movsd
pop rsi
JUMP_002433:
push rbx
lea eax,[rbp-0x24]
push rax
mov eax,[rbp+24]
push rax
push rsi
lea eax,[rbp-0x5]
push rax
call FUNC_000579
add rsp,40
test al,al
jng JUMP_002434
or BYTE PTR [DATA_008697],0x80
JUMP_002434:
mov dl,[DATA_008697]
test dl,dl
jz JUMP_002435
mov ecx,[rbp+24]
mov cl,[ecx+0x86]
mov [DATA_008698],cl
mov ecx,[rbp+24]
mov [DATA_008702],ecx
mov [DATA_008696],dl
mov dl,[rbp-0x5]
mov [DATA_008701],dl
JUMP_002435:
test al,al
jl JUMP_002436
xor eax,eax
jmp JUMP_002445
JUMP_002436:
cmp BYTE PTR [esi+0x14c],0x0
jl JUMP_002437
or eax,-0x1
jmp JUMP_002445
JUMP_002437:
sub DWORD PTR [rbp-0x4],+0x2
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax]
test eax,eax
jnz JUMP_002438
or eax,-0x1
jmp JUMP_002445
JUMP_002438:
sub DWORD PTR [rbp-0x4],+0x2
mov edx,[rbp-0x4]
movsx ebx,WORD PTR [edx]
mov edx,ebx
and edx,+0x6
sub edx,+0x1
jc JUMP_002439
dec edx
jz JUMP_002440
sub edx,+0x2
jz JUMP_002441
jmp JUMP_002442
JUMP_002439:
mov edx,[esi]
mov [rbp-0x30],edx
mov edx,[esi+0x4]
mov [rbp-0x2c],edx
mov edx,[esi+0x8]
mov [rbp-0x28],edx
jmp JUMP_002442
JUMP_002440:
mov edx,[esi+0xc]
mov [rbp-0x30],edx
mov edx,[esi+0x10]
mov [rbp-0x2c],edx
mov edx,[esi+0x14]
mov [rbp-0x28],edx
jmp JUMP_002442
JUMP_002441:
mov edx,[esi+0x18]
mov [rbp-0x30],edx
mov edx,[esi+0x1c]
mov [rbp-0x2c],edx
mov edx,[esi+0x20]
mov [rbp-0x28],edx
JUMP_002442:
test bl,0x1
jz JUMP_002443
neg DWORD PTR [rbp-0x30]
neg DWORD PTR [rbp-0x2c]
neg DWORD PTR [rbp-0x28]
JUMP_002443:
mov edx,[rbp-0x30]
sar edx,0x10
imul edx,eax
mov [rbp-0x30],edx
mov edx,[rbp-0x2c]
sar edx,0x10
imul edx,eax
mov [rbp-0x2c],edx
mov edx,[rbp-0x28]
sar edx,0x10
imul edx,eax
mov [rbp-0x28],edx
and ebx,0xfff8
shl ebx,0xf
cmp DWORD PTR [rbp-0xc],+0x0
jz JUMP_002444
mov ecx,[rbp-0xc]
sar DWORD PTR [rbp-0x30],cl
mov ecx,[rbp-0xc]
sar DWORD PTR [rbp-0x2c],cl
mov ecx,[rbp-0xc]
sar DWORD PTR [rbp-0x28],cl
mov ecx,[rbp-0xc]
sar ebx,cl
JUMP_002444:
mov eax,[rbp-0x30]
push rax
mov eax,[rbp+32]
push QWORD PTR [rax+0x4]
push QWORD PTR [rax]
lea eax,[rbp-0x24]
push rax
call FUNC_001334
add rsp,32
mov eax,[rbp-0x2c]
push rax
mov eax,[rbp+32]
push QWORD PTR [rax+0xc]
push QWORD PTR [rax+0x8]
lea eax,[rbp-0x1c]
push rax
call FUNC_001334
add rsp,32
mov eax,[rbp-0x28]
push rax
mov eax,[rbp+32]
push QWORD PTR [rax+0x14]
push QWORD PTR [rax+0x10]
lea eax,[rbp-0x14]
push rax
call FUNC_001334
add rsp,32
jmp JUMP_002433
JUMP_002445:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
OriginalF579:
push rbp
mov rbp,rsp
add rsp,-28
push rbx
push rsi
push rdi
mov esi,[rbp+40]
mov edi,[rbp+32]
mov eax,[edi+0x82]
push rax
mov eax,DWORD PTR [DATA_007756]
call rax
pop rcx
mov ebx,eax
mov eax,[ebx+0xc]
mov [rbp-0x10],eax
mov eax,[ebx+0x4]
mov [rbp-0xc],eax
mov eax,[ebx+0x14]
add eax,[ebx+0x18]
mov [rbp-0x8],eax
push +0x1c
push rsi
call FUNC_001658
add rsp,16
mov edx,[esi]
mov [rbp-0x1c],edx
mov edx,[esi+0x8]
mov [rbp-0x18],edx
mov edx,[esi+0x10]
mov [rbp-0x14],edx
mov [rbp-0x4],eax
mov edx,[rbp-0x8]
add edx,-0x17
sub eax,edx
test eax,eax
jnl JUMP_002458
neg eax
add [rbp-0x4],eax
mov ecx,eax
sar DWORD PTR [rbp-0x1c],cl
mov ecx,eax
sar DWORD PTR [rbp-0x18],cl
mov ecx,eax
sar DWORD PTR [rbp-0x14],cl
JUMP_002458:
mov eax,[rbp-0x4]
test eax,eax
jnl JUMP_002459
mov ecx,eax
neg ecx
shl DWORD PTR [rbp+48],cl
jmp JUMP_002460
JUMP_002459:
test eax,eax
jng JUMP_002460
mov ecx,eax
sar DWORD PTR [rbp+48],cl
JUMP_002460:
mov eax,[rbp+24]
cmp BYTE PTR [eax+0x57],0x0
jz JUMP_002461
mov eax,[rbp+24]
mov al,[eax+0x56]
cmp al,[edi+0x86]
jz JUMP_002462
JUMP_002461:
push rdi
lea eax,[rbp-0x1c]
push rax
lea eax,[rbp-0x1c]
push rax
call FUNC_001670
add rsp,24
JUMP_002462:
mov eax,[rbp+48]
push rax
push rdi
mov eax,[ebx+0x34]
push rax
lea eax,[rbp-0x1c]
push rax
mov eax,[rbp+16]
push rax
call FUNC_000582
add rsp,40
movsx eax,al
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
RootOriginalF581:
push rbp
mov rbp,rsp
add rsp,-144
push rbx
push rsi
push rdi
mov eax,[rbp+24]
movzx eax,BYTE PTR [eax]
mov edx,[rbp+24]
movzx edx,BYTE PTR [edx+0x1]
mov ecx,[rbp+24]
xor ebx,ebx
mov bl,[ecx+0x2]
mov ecx,[rbp+24]
movzx ecx,BYTE PTR [ecx+0x3]
mov [rbp-0x4],ecx
mov ecx,[rbp+24]
movzx ecx,BYTE PTR [ecx+0x5]
shl ecx,0x8
mov esi,[rbp+24]
movzx esi,BYTE PTR [esi+0x4]
or ecx,esi
mov [rbp-0x8],ecx
mov BYTE PTR [DATA_008707],0xff
mov ecx,eax
sar ecx,1
lea ecx,[ecx+ecx*2]
mov esi,[rbp+48]
mov esi,[esi+0x10]
mov edi,[esi+ecx*2]
mov [rbp-0x10],edi
mov di,[esi+ecx*2+0x4]
mov [rbp-0xc],di
test al,0x1
jz JUMP_002478
movsx eax,BYTE PTR [rbp-0xe]
neg eax
mov [rbp-0x30],eax
jmp JUMP_002479
JUMP_002478:
movsx eax,BYTE PTR [rbp-0xe]
mov [rbp-0x30],eax
JUMP_002479:
movsx eax,BYTE PTR [rbp-0xd]
mov [rbp-0x2c],eax
movsx eax,BYTE PTR [rbp-0xc]
mov [rbp-0x28],eax
mov eax,edx
sar eax,1
lea eax,[eax+eax*2]
mov ecx,[rbp+48]
mov ecx,[ecx+0x10]
mov esi,[ecx+eax*2]
mov [rbp-0x10],esi
mov si,[ecx+eax*2+0x4]
mov [rbp-0xc],si
test dl,0x1
jz JUMP_002480
movsx eax,BYTE PTR [rbp-0xe]
neg eax
mov [rbp-0x78],eax
jmp JUMP_002481
JUMP_002480:
movsx eax,BYTE PTR [rbp-0xe]
mov [rbp-0x78],eax
JUMP_002481:
movsx eax,BYTE PTR [rbp-0xd]
mov [rbp-0x74],eax
movsx eax,BYTE PTR [rbp-0xc]
mov [rbp-0x70],eax
mov eax,ebx
sar eax,1
lea eax,[eax+eax*2]
mov edx,[rbp+48]
mov edx,[edx+0x10]
mov ecx,[edx+eax*2]
mov [rbp-0x10],ecx
mov cx,[edx+eax*2+0x4]
mov [rbp-0xc],cx
test bl,0x1
jz JUMP_002482
movsx eax,BYTE PTR [rbp-0xe]
neg eax
mov [rbp-0x6c],eax
jmp JUMP_002483
JUMP_002482:
movsx eax,BYTE PTR [rbp-0xe]
mov [rbp-0x6c],eax
JUMP_002483:
movsx eax,BYTE PTR [rbp-0xd]
mov [rbp-0x68],eax
movsx eax,BYTE PTR [rbp-0xc]
mov [rbp-0x64],eax
mov eax,[rbp-0x4]
sar eax,1
lea eax,[eax+eax*2]
mov edx,[rbp+48]
mov edx,[edx+0x10]
mov ecx,[edx+eax*2]
mov [rbp-0x10],ecx
mov cx,[edx+eax*2+0x4]
mov [rbp-0xc],cx
test BYTE PTR [rbp-0x4],0x1
jz JUMP_002484
movsx eax,BYTE PTR [rbp-0xe]
neg eax
mov [rbp-0x60],eax
jmp JUMP_002485
JUMP_002484:
movsx eax,BYTE PTR [rbp-0xe]
mov [rbp-0x60],eax
JUMP_002485:
movsx eax,BYTE PTR [rbp-0xd]
mov [rbp-0x5c],eax
movsx eax,BYTE PTR [rbp-0xc]
mov [rbp-0x58],eax
mov eax,[rbp+48]
mov eax,[eax+0x14]
mov edx,[rbp+48]
sub eax,[edx+0x18]
test eax,eax
jnl JUMP_002486
neg eax
mov ecx,eax
sar DWORD PTR [rbp-0x30],cl
mov ecx,eax
sar DWORD PTR [rbp-0x2c],cl
mov ecx,eax
sar DWORD PTR [rbp-0x28],cl
mov ecx,eax
sar DWORD PTR [rbp-0x78],cl
mov ecx,eax
sar DWORD PTR [rbp-0x74],cl
mov ecx,eax
sar DWORD PTR [rbp-0x70],cl
mov ecx,eax
sar DWORD PTR [rbp-0x6c],cl
mov ecx,eax
sar DWORD PTR [rbp-0x68],cl
mov ecx,eax
sar DWORD PTR [rbp-0x64],cl
mov ecx,eax
sar DWORD PTR [rbp-0x60],cl
mov ecx,eax
sar DWORD PTR [rbp-0x5c],cl
mov ecx,eax
sar DWORD PTR [rbp-0x58],cl
jmp JUMP_002487
JUMP_002486:
mov ecx,eax
shl DWORD PTR [rbp-0x30],cl
mov ecx,eax
shl DWORD PTR [rbp-0x2c],cl
mov ecx,eax
shl DWORD PTR [rbp-0x28],cl
mov ecx,eax
shl DWORD PTR [rbp-0x78],cl
mov ecx,eax
shl DWORD PTR [rbp-0x74],cl
mov ecx,eax
shl DWORD PTR [rbp-0x70],cl
mov ecx,eax
shl DWORD PTR [rbp-0x6c],cl
mov ecx,eax
shl DWORD PTR [rbp-0x68],cl
mov ecx,eax
shl DWORD PTR [rbp-0x64],cl
mov ecx,eax
shl DWORD PTR [rbp-0x60],cl
mov ecx,eax
shl DWORD PTR [rbp-0x5c],cl
mov ecx,eax
shl DWORD PTR [rbp-0x58],cl
JUMP_002487:
mov eax,[rbp-0x30]
neg eax
add [rbp-0x78],eax
mov edx,[rbp-0x2c]
neg edx
add [rbp-0x74],edx
mov ecx,[rbp-0x28]
neg ecx
add [rbp-0x70],ecx
mov ebx,[rbp-0x30]
neg ebx
add [rbp-0x6c],eax
mov ebx,[rbp-0x2c]
neg ebx
add [rbp-0x68],edx
mov ebx,[rbp-0x28]
neg ebx
add [rbp-0x64],ecx
mov ebx,[rbp-0x30]
neg ebx
add [rbp-0x60],eax
mov eax,[rbp-0x2c]
neg eax
add [rbp-0x5c],edx
mov eax,[rbp-0x28]
neg eax
add [rbp-0x58],ecx
mov eax,[rbp+48]
mov eax,[eax]
sub [rbp-0x30],eax
mov eax,[rbp+48]
mov eax,[eax+0x4]
sub [rbp-0x2c],eax
mov eax,[rbp+48]
mov eax,[eax+0x8]
sub [rbp-0x28],eax
lea eax,[rbp-0x30]
push rax
call FUNC_001466
pop rcx
mov [rbp-0x14],eax
mov eax,[rbp+32]
mov edx,[eax+0x138]
mov [rbp-0x20],edx
mov edx,[eax+0x13c]
mov [rbp-0x1c],edx
mov eax,[rbp+48]
mov eax,[eax+0x18]
neg eax
push rax
lea eax,[rbp-0x20]
push rax
call FUNC_001341
add rsp,16
mov eax,[rbp-0x14]
sub eax,[rbp-0x20]
cmp eax,[rbp+40]
jl JUMP_002488
mov eax,[rbp+16]
mov DWORD PTR [eax],0xffffffff
mov BYTE PTR [DATA_008707],0x0
mov eax,[rbp+24]
add eax,+0x6
push rax
call FUNC_001822
pop rcx
jmp JUMP_002508
JUMP_002488:
mov eax,[rbp+32]
mov edx,[eax+0x140]
mov [rbp-0x20],edx
mov edx,[eax+0x144]
mov [rbp-0x1c],edx
mov eax,[rbp+48]
mov eax,[eax+0x18]
neg eax
push rax
lea eax,[rbp-0x20]
push rax
call FUNC_001341
add rsp,16
mov eax,[rbp-0x14]
sub eax,[rbp-0x20]
cmp eax,[rbp+40]
jg JUMP_002489
mov eax,[rbp+16]
xor edx,edx
mov [eax],edx
mov BYTE PTR [DATA_008707],0x1
mov eax,[rbp+24]
add eax,+0x6
push rax
call FUNC_001822
pop rcx
jmp JUMP_002508
JUMP_002489:
mov eax,[rbp-0x30]
test eax,eax
jz JUMP_002496
mov [rbp-0x84],eax
mov eax,[rbp-0x2c]
mov [rbp-0x80],eax
xor eax,eax
mov [rbp-0x7c],eax
lea eax,[rbp-0x84]
push rax
call FUNC_001466
pop rcx
mov edi,eax
mov ebx,[rbp-0x84]
test ebx,ebx
jnl JUMP_002491
push rdi
neg ebx
push rbx
call FUNC_001523
add rsp,16
mov ebx,eax
test ebx,ebx
jnl JUMP_002490
mov ebx,0x7fffffff
JUMP_002490:
neg ebx
jmp JUMP_002492
JUMP_002491:
push rdi
mov eax,[rbp-0x84]
push rax
call FUNC_001523
add rsp,16
mov ebx,eax
test ebx,ebx
jnl JUMP_002492
mov ebx,0x7fffffff
JUMP_002492:
mov esi,[rbp-0x80]
test esi,esi
jnl JUMP_002494
push rdi
neg esi
push rsi
call FUNC_001523
add rsp,16
mov esi,eax
test esi,esi
jnl JUMP_002493
mov esi,0x7fffffff
JUMP_002493:
neg esi
jmp JUMP_002495
JUMP_002494:
push rdi
mov eax,[rbp-0x80]
push rax
call FUNC_001523
add rsp,16
mov esi,eax
test esi,esi
jnl JUMP_002495
mov esi,0x7fffffff
JUMP_002495:
mov [rbp-0x54],esi
mov [rbp-0x50],ebx
xor eax,eax
mov [rbp-0x4c],eax
neg ebx
mov [rbp-0x48],ebx
mov [rbp-0x44],esi
xor eax,eax
mov [rbp-0x40],eax
xor eax,eax
mov [rbp-0x3c],eax
xor eax,eax
mov [rbp-0x38],eax
mov DWORD PTR [rbp-0x34],0x7fffffff
mov [rbp-0x2c],edi
jmp JUMP_002497
JUMP_002496:
mov DWORD PTR [rbp-0x54],0x7fffffff
xor eax,eax
mov [rbp-0x50],eax
xor eax,eax
mov [rbp-0x4c],eax
xor eax,eax
mov [rbp-0x48],eax
mov DWORD PTR [rbp-0x44],0x7fffffff
xor eax,eax
mov [rbp-0x40],eax
xor eax,eax
mov [rbp-0x3c],eax
xor eax,eax
mov [rbp-0x38],eax
mov DWORD PTR [rbp-0x34],0x7fffffff
JUMP_002497:
mov eax,[rbp-0x2c]
test eax,eax
jz JUMP_002504
xor edx,edx
mov [rbp-0x90],edx
mov [rbp-0x8c],eax
mov eax,[rbp-0x28]
mov [rbp-0x88],eax
lea eax,[rbp-0x90]
push rax
call FUNC_001466
pop rcx
mov edi,eax
mov ebx,[rbp-0x8c]
test ebx,ebx
jnl JUMP_002499
push rdi
neg ebx
push rbx
call FUNC_001523
add rsp,16
mov ebx,eax
test ebx,ebx
jnl JUMP_002498
mov ebx,0x7fffffff
JUMP_002498:
neg ebx
jmp JUMP_002500
JUMP_002499:
push rdi
mov eax,[rbp-0x8c]
push rax
call FUNC_001523
add rsp,16
mov ebx,eax
test ebx,ebx
jnl JUMP_002500
mov ebx,0x7fffffff
JUMP_002500:
mov esi,[rbp-0x88]
test esi,esi
jnl JUMP_002502
push rdi
neg esi
push rsi
call FUNC_001523
add rsp,16
mov esi,eax
test esi,esi
jnl JUMP_002501
mov esi,0x7fffffff
JUMP_002501:
neg esi
jmp JUMP_002503
JUMP_002502:
push rdi
mov eax,[rbp-0x88]
push rax
call FUNC_001523
add rsp,16
mov esi,eax
test esi,esi
jnl JUMP_002503
mov esi,0x7fffffff
JUMP_002503:
push rbx
mov eax,[rbp-0x50]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x4c],eax
push rsi
mov eax,[rbp-0x50]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x50],eax
push rbx
mov eax,[rbp-0x44]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x40],eax
push rsi
mov eax,[rbp-0x44]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x44],eax
neg ebx
mov [rbp-0x38],ebx
mov [rbp-0x34],esi
JUMP_002504:
xor eax,eax
mov [rbp-0x30],eax
xor eax,eax
mov [rbp-0x2c],eax
mov eax,[rbp-0x14]
mov [rbp-0x28],eax
lea eax,[rbp-0x54]
push rax
lea eax,[rbp-0x78]
push rax
lea eax,[rbp-0x78]
push rax
call FUNC_001669
add rsp,24
lea eax,[rbp-0x54]
push rax
lea eax,[rbp-0x6c]
push rax
lea eax,[rbp-0x6c]
push rax
call FUNC_001669
add rsp,24
lea eax,[rbp-0x54]
push rax
lea eax,[rbp-0x60]
push rax
lea eax,[rbp-0x60]
push rax
call FUNC_001669
add rsp,24
push +0x1
push +0x0
push +0x0
push +0x0
mov eax,[rbp-0x8]
push rax
lea eax,[rbp-0x78]
push rax
lea eax,[rbp-0x30]
push rax
mov eax,[rbp+24]
add eax,+0x6
push rax
push +0x0
mov eax,[rbp+32]
push rax
mov eax,[rbp+48]
mov ecx,[eax+0x18]
mov eax,0x77359400
sar eax,cl
push rax
lea eax,[rbp-0x18]
push rax
call FUNC_001876
add rsp,96
mov [rbp+24],eax
xor eax,eax
mov edx,[rbp+40]
sar edx,0x10
cmp edx,[rbp-0x18]
jg JUMP_002505
dec eax
JUMP_002505:
mov edx,[rbp+16]
mov [edx],eax
mov eax,[rbp+48]
mov eax,[eax+0x18]
mov ecx,eax
mov edx,0x77359400
sar edx,cl
cmp edx,[rbp-0x18]
jng JUMP_002506
mov edx,[rbp-0x18]
mov [DATA_008703],edx
mov edx,[rbp-0x18]
sar edx,0x1f
mov [DATA_008704],edx
push rax
push OFFSET FLAT:DATA_008703
call FUNC_001341
add rsp,16
JUMP_002506:
mov eax,[DATA_008703]
mov [DATA_008705],eax
mov eax,[DATA_008704]
mov [DATA_008706],eax
mov eax,[rbp+16]
cmp DWORD PTR [eax],+0x0
jnz JUMP_002507
xor eax,eax
mov [DATA_008703],eax
xor eax,eax
mov [DATA_008704],eax
mov BYTE PTR [DATA_008707],0x1
JUMP_002507:
mov eax,[rbp+24]
JUMP_002508:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000582:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+32]
mov bl,[esi]
inc esi
test bl,bl
jz JUMP_002531
JUMP_002509:
xor eax,eax
mov al,[esi]
mov [rbp-0x4],eax
inc esi
test bl,0x20
jz JUMP_002516
mov al,[esi]
inc esi
and eax,0xff
mov edx,[rbp+40]
movzx edx,WORD PTR [edx+eax*2+0x9c]
mov al,[esi]
inc esi
movsx ecx,al
and ecx,+0x1f
shr edx,cl
movsx eax,al
sar eax,0x7
xor edx,eax
test dl,0x1
jz JUMP_002516
and ebx,0xc0
sub ebx,+0x1
jc JUMP_002510
sub ebx,+0x3f
jz JUMP_002513
sub ebx,+0x40
jz JUMP_002514
sub ebx,+0x40
jz JUMP_002515
jmp JUMP_002530
JUMP_002510:
movzx edi,BYTE PTR [esi]
inc esi
cmp edi,0xff
jnz JUMP_002511
add esi,+0x6
push rsi
call FUNC_001822
pop rcx
mov esi,eax
jmp JUMP_002530
JUMP_002511:
test edi,edi
jz JUMP_002530
JUMP_002512:
movzx edi,BYTE PTR [esi]
inc esi
test edi,edi
jnz JUMP_002512
jmp JUMP_002530
JUMP_002513:
movzx edi,BYTE PTR [esi]
inc esi
test edi,edi
jnz JUMP_002513
jmp JUMP_002530
JUMP_002514:
add esi,+0x4
jmp JUMP_002530
JUMP_002515:
movzx edi,BYTE PTR [esi]
inc esi
test edi,edi
jnz JUMP_002515
jmp JUMP_002530
JUMP_002516:
mov eax,ebx
and eax,0xc0
sub eax,+0x1
jc JUMP_002517
sub eax,+0x3f
jz JUMP_002522
sub eax,+0x40
jz JUMP_002525
sub eax,+0x40
jz JUMP_002527
jmp JUMP_002530
JUMP_002517:
movzx edi,BYTE PTR [esi]
inc esi
cmp edi,0xff
jnz JUMP_002519
mov eax,[rbp+24]
push rax
mov eax,[rbp+48]
push rax
mov eax,[rbp+40]
push rax
push rsi
lea eax,[rbp-0x8]
push rax
call FUNC_000581
add rsp,40
mov esi,eax
cmp DWORD PTR [rbp-0x8],+0x0
jnz JUMP_002518
mov al,[rbp-0x4]
or [DATA_008697],al
mov eax,[rbp+16]
mov [eax],bl
xor eax,eax
jmp JUMP_002532
JUMP_002518:
mov al,[rbp-0x4]
and al,0x7f
or [DATA_008697],al
jmp JUMP_002530
JUMP_002519:
test edi,edi
jz JUMP_002530
JUMP_002520:
mov eax,[rbp+24]
push rax
push rdi
mov eax,[rbp+48]
push rax
call FUNC_000583
add rsp,24
test eax,eax
jz JUMP_002521
mov al,[rbp-0x4]
and al,0x7f
or [DATA_008697],al
mov eax,[rbp+16]
mov [eax],bl
or eax,-0x1
jmp JUMP_002532
JUMP_002521:
inc esi
movzx edi,BYTE PTR [esi-0x1]
test edi,edi
jnz JUMP_002520
jmp JUMP_002530
JUMP_002522:
movzx edi,BYTE PTR [esi]
inc esi
test edi,edi
jnz JUMP_002523
mov al,[rbp-0x4]
and al,0x7f
or [DATA_008697],al
mov eax,[rbp+16]
mov [eax],bl
or eax,-0x1
jmp JUMP_002532
JUMP_002523:
mov eax,[rbp+24]
push rax
push rdi
mov eax,[rbp+48]
push rax
call FUNC_000583
add rsp,24
test eax,eax
jnz JUMP_002522
JUMP_002524:
mov al,[esi]
inc esi
test al,al
jnz JUMP_002524
jmp JUMP_002530
JUMP_002525:
movzx edi,BYTE PTR [esi]
shl edi,0x8
inc esi
xor eax,eax
mov al,[esi]
or edi,eax
inc esi
mov dl,[esi]
inc esi
mov al,[esi]
inc esi
mov ecx,[rbp+40]
push rcx
mov ecx,[rbp+48]
push rcx
push rdx
push rax
push rdi
mov eax,[rbp+24]
push rax
mov eax,[rbp+16]
push rax
call FUNC_000580
add rsp,56
mov edx,[rbp+16]
mov dl,[edx]
or [DATA_008701],dl
test eax,eax
jnl JUMP_002526
mov al,[rbp-0x4]
and al,0x7f
or [DATA_008697],al
mov eax,[rbp+16]
mov [eax],bl
or eax,-0x1
jmp JUMP_002532
JUMP_002526:
test eax,eax
jg JUMP_002530
mov al,[rbp-0x4]
or [DATA_008697],al
test BYTE PTR [rbp-0x4],0x80
jz JUMP_002530
mov eax,[rbp+16]
mov [eax],bl
xor eax,eax
jmp JUMP_002532
JUMP_002527:
movzx edi,BYTE PTR [esi]
inc esi
test edi,edi
jnz JUMP_002528
mov al,[rbp-0x4]
or [DATA_008697],al
test BYTE PTR [rbp-0x4],0x80
jz JUMP_002528
mov eax,[rbp+16]
mov [eax],bl
xor eax,eax
jmp JUMP_002532
JUMP_002528:
mov eax,[rbp+24]
push rax
push rdi
mov eax,[rbp+48]
push rax
call FUNC_000583
add rsp,24
test eax,eax
jz JUMP_002527
JUMP_002529:
mov bl,[esi]
inc esi
test bl,bl
jnz JUMP_002529
JUMP_002530:
mov bl,[esi]
inc esi
test bl,bl
jnz JUMP_002509
JUMP_002531:
mov eax,[rbp+16]
mov BYTE PTR [eax],0x0
mov al,0x1
JUMP_002532:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_001334:
push rbp
mov rbp,rsp
push rcx
mov ecx,[rbp+16]
mov eax,[rbp+40]
cdq
add eax,[rbp+24]
mov [ecx],eax
adc edx,[rbp+32]
mov [ecx+0x4],edx
pop rcx
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
FUNC_001339:
push rbp
mov rbp,rsp
push rcx
mov eax,[rbp+24]
imul DWORD PTR [rbp+32]
mov ecx,[rbp+16]
mov [ecx],eax
mov [ecx+0x4],edx
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
FUNC_001465:
push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
mov eax,[ebx]
imul DWORD PTR [ebx]
mov edx,[ebx+0x4]
imul edx,[ebx+0x4]
add eax,edx
mov edx,[ebx+0x8]
imul edx,[ebx+0x8]
add eax,edx
push rax
call FUNC_001467
pop rcx
pop rbx
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
mov eax,DWORD PTR [DATA_007738]
call rax
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
mov eax,DWORD PTR [DATA_007738]
call rax
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
FUNC_001467:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp eax,0x4000000
jnc JUMP_005498
cmp eax,0x400000
jc JUMP_005494
shr eax,0xf
movzx eax,WORD PTR [eax*2+DATA_007977]
sar eax,0x3
pop rbp
ret
JUMP_005494:
cmp eax,0x40000
jc JUMP_005495
shr eax,0xb
movzx eax,WORD PTR [eax*2+DATA_007977]
sar eax,0x5
pop rbp
ret
JUMP_005495:
cmp eax,0x4000
jc JUMP_005496
shr eax,0x7
movzx eax,WORD PTR [eax*2+DATA_007977]
sar eax,0x7
pop rbp
ret
JUMP_005496:
cmp eax,0x400
jc JUMP_005497
shr eax,0x3
movzx eax,WORD PTR [eax*2+DATA_007977]
sar eax,0x9
pop rbp
ret
JUMP_005497:
add eax,eax
movzx eax,WORD PTR [eax*2+DATA_007977]
sar eax,0xb
pop rbp
ret
JUMP_005498:
cmp eax,0x40000000
jc JUMP_005499
shr eax,0x15
movzx eax,WORD PTR [eax*2+DATA_007977]
pop rbp
ret
JUMP_005499:
cmp eax,0x10000000
jc JUMP_005500
shr eax,0x13
movzx eax,WORD PTR [eax*2+DATA_007977]
sar eax,1
pop rbp
ret
JUMP_005500:
shr eax,0x11
movzx eax,WORD PTR [eax*2+DATA_007977]
sar eax,0x2
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
mov eax,DWORD PTR [DATA_007734]
call rax
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
mov eax,DWORD PTR [DATA_007734]
call rax
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
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov eax,[eax*4+DATA_004681]
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
FUNC_001816:
push rbx
push rsi
push rdi
mov ecx,OFFSET FLAT:DATA_009274
mov ebx,OFFSET FLAT:DATA_009277
cmp DWORD PTR [DATA_009272],+0x0
jnz JUMP_006975
mov [DATA_009272],ecx
xor eax,eax
mov edx,ecx
JUMP_006973:
mov esi,eax
shl esi,0x3
lea esi,[esi+esi*8]
lea edi,[ecx+0x48]
add esi,edi
mov [edx],esi
inc eax
add edx,+0x48
cmp eax,0x5db
jl JUMP_006973
xor eax,eax
mov [ecx+0x1a598],eax
mov [DATA_009275],ebx
xor eax,eax
mov edx,ebx
JUMP_006974:
mov ecx,eax
shl ecx,0x4
lea esi,[ebx+0x10]
add ecx,esi
mov [edx],ecx
inc eax
add edx,+0x10
cmp eax,0xbb7
jl JUMP_006974
xor eax,eax
mov [ebx+0xbb70],eax
xor eax,eax
mov [DATA_009273],eax
xor eax,eax
mov [DATA_009276],eax
JUMP_006975:
pop rdi
pop rsi
pop rbx
ret
FUNC_001817:
xor eax,eax
mov [DATA_009272],eax
ret
FUNC_001818:
push rbx
mov ebx,[DATA_009272]
inc DWORD PTR [DATA_009273]
cmp DWORD PTR [DATA_009273],0x5dc
jl JUMP_006976
push +0x1
push OFFSET FLAT:DATA_009271
call _LongJmp
add rsp,16
JUMP_006976:
mov eax,[DATA_009272]
mov eax,[eax]
mov [DATA_009272],eax
mov eax,ebx
pop rbx
ret
FUNC_001819:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
dec DWORD PTR [DATA_009273]
mov edx,[DATA_009272]
mov [eax],edx
mov [DATA_009272],eax
pop rbp
ret
FUNC_001820:
push rbx
mov eax,[DATA_009275]
mov ebx,eax
mov eax,[eax]
mov [DATA_009275],eax
inc DWORD PTR [DATA_009276]
cmp DWORD PTR [DATA_009276],0xbb8
jl JUMP_006977
push +0x2
push OFFSET FLAT:DATA_009271
call _LongJmp
add rsp,16
JUMP_006977:
xor eax,eax
mov [ebx+0x4],eax
xor eax,eax
mov [ebx+0xc],eax
xor eax,eax
mov [ebx+0x8],eax
mov eax,ebx
pop rbx
ret
nop
FUNC_001821:
push rbp
mov rbp,rsp
push rbx
mov ebx,[rbp+16]
JUMP_006978:
mov eax,[ebx+0x4]
test eax,eax
jz JUMP_006979
push rax
call FUNC_001821
pop rcx
JUMP_006979:
mov eax,[ebx+0x8]
test eax,eax
jz JUMP_006980
push rax
call FUNC_001819
pop rcx
JUMP_006980:
dec DWORD PTR [DATA_009276]
mov eax,[DATA_009275]
mov [ebx],eax
mov [DATA_009275],ebx
mov ebx,[ebx+0xc]
test ebx,ebx
jnz JUMP_006978
pop rbx
pop rbp
ret
FUNC_001822:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
movsx edx,WORD PTR [eax]
test edx,edx
jz JUMP_006982
JUMP_006981:
add eax,+0x10
movsx edx,WORD PTR [eax]
test edx,edx
jnz JUMP_006981
JUMP_006982:
add eax,+0x2
pop rbp
ret
FUNC_001823:
push rbp
mov rbp,rsp
add rsp,-28
push rbx
push rsi
mov DWORD PTR [rbp-0x10],0x58
mov DWORD PTR [rbp-0x14],OFFSET FLAT:DATA_009258
xor edx,edx
mov eax,[rbp-0x14]
add eax,+0x8
JUMP_006983:
xor ecx,ecx
mov [eax],ecx
inc edx
add eax,+0x4
cmp edx,+0x14
jl JUMP_006983
xor edx,edx
mov eax,[rbp-0x14]
JUMP_006984:
xor ecx,ecx
mov [eax],ecx
inc edx
add eax,+0x4
cmp edx,+0x2
jl JUMP_006984
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov [rbp-0x4],eax
cmp DWORD PTR [rbp-0x4],+0x0
jz JUMP_006998
JUMP_006985:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov [rbp-0xc],eax
mov eax,[rbp-0x4]
push rax
call FUNC_001656
pop rcx
mov [rbp-0x18],eax
mov ecx,0x10
sub ecx,[rbp-0x18]
mov eax,[rbp-0x4]
shl eax,cl
and eax,0xffff
mov [rbp-0x4],eax
mov ebx,[rbp-0x14]
mov eax,[rbp-0x18]
add eax,-0x3
sar eax,1
jns JUMP_006986
adc eax,+0x0
JUMP_006986:
mov [rbp-0x18],eax
cmp DWORD PTR [rbp-0x18],+0x0
jng JUMP_006994
JUMP_006987:
mov eax,[rbp-0x4]
shr eax,0xb
mov [rbp-0x8],eax
mov [rbp-0x1c],ebx
mov eax,[rbp-0x1c]
mov edx,[rbp-0x8]
mov ebx,[eax+edx*4+0x8]
test ebx,ebx
jnz JUMP_006993
mov ebx,OFFSET FLAT:DATA_009258
add ebx,[rbp-0x10]
mov eax,[rbp-0x10]
add eax,+0x18
mov [rbp-0x10],eax
xor edx,edx
lea eax,[ebx+0x8]
JUMP_006988:
xor ecx,ecx
mov [eax],ecx
inc edx
add eax,+0x4
cmp edx,+0x4
jl JUMP_006988
xor edx,edx
mov ecx,ebx
mov eax,[rbp-0x1c]
JUMP_006989:
mov esi,[eax]
test esi,esi
jng JUMP_006990
lea esi,[esi+esi*2]
mov esi,[esi*4+DATA_007842]
dec esi
neg esi
mov [ecx],esi
jmp JUMP_006992
JUMP_006990:
mov esi,[eax]
test esi,esi
jnl JUMP_006991
inc esi
mov [ecx],esi
jmp JUMP_006992
JUMP_006991:
xor esi,esi
mov [ecx],esi
JUMP_006992:
inc edx
add ecx,+0x4
add eax,+0x4
cmp edx,+0x2
jl JUMP_006989
mov eax,[rbp-0x1c]
mov edx,[rbp-0x8]
mov [eax+edx*4+0x8],ebx
JUMP_006993:
mov eax,[rbp-0x4]
shl eax,0x2
and eax,0x1fff
mov [rbp-0x4],eax
dec DWORD PTR [rbp-0x18]
cmp DWORD PTR [rbp-0x18],+0x0
jg JUMP_006987
JUMP_006994:
xor edx,edx
mov eax,ebx
JUMP_006995:
cmp DWORD PTR [eax],+0x0
jz JUMP_006996
inc edx
add eax,+0x4
cmp edx,+0x2
jl JUMP_006995
JUMP_006996:
cmp edx,+0x2
jnl JUMP_006997
mov eax,OFFSET FLAT:DATA_009258
add eax,[rbp-0x10]
mov ecx,[rbp-0x10]
add ecx,+0x10
mov [rbp-0x10],ecx
mov [ebx+edx*4],eax
mov edx,[rbp-0xc]
mov [eax],edx
mov edx,[rbp+24]
mov dx,[edx+0x4]
mov [eax+0x4],dx
mov edx,[rbp+24]
mov dx,[edx+0x6]
mov [eax+0x6],dx
mov edx,[rbp+24]
mov dx,[edx+0x8]
mov [eax+0x8],dx
mov edx,[rbp+24]
mov dx,[edx+0xa]
mov [eax+0xa],dx
mov edx,[rbp+24]
mov dx,[edx+0xc]
mov [eax+0xc],dx
mov edx,[rbp+24]
mov dx,[edx+0xe]
mov [eax+0xe],dx
JUMP_006997:
add DWORD PTR [rbp+24],+0x10
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov [rbp-0x4],eax
cmp DWORD PTR [rbp-0x4],+0x0
jnz JUMP_006985
JUMP_006998:
mov eax,[rbp+16]
mov edx,[rbp-0x14]
mov [eax],edx
mov eax,[rbp+24]
add eax,+0x2
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001824:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,eax
shr edx,0x1b
mov ecx,eax
shl ecx,0x5
or edx,ecx
add edx,eax
mov ecx,edx
shr ecx,0x10
shl edx,0x10
or ecx,edx
add eax,ecx
pop rbp
ret
FUNC_001825:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp DWORD PTR [eax],+0x0
jnl JUMP_006999
mov edx,[eax]
neg edx
jmp JUMP_007000
JUMP_006999:
mov edx,[eax]
JUMP_007000:
cmp DWORD PTR [eax+0x4],+0x0
jnl JUMP_007001
mov ecx,[eax+0x4]
neg ecx
jmp JUMP_007002
JUMP_007001:
mov ecx,[eax+0x4]
JUMP_007002:
or edx,ecx
cmp DWORD PTR [eax+0x8],+0x0
jnl JUMP_007003
mov ecx,[eax+0x8]
neg ecx
jmp JUMP_007004
JUMP_007003:
mov ecx,[eax+0x8]
JUMP_007004:
or edx,ecx
push rdx
call FUNC_001656
pop rcx
pop rbp
ret
FUNC_001826:
push rbp
mov rbp,rsp
push rbx
push rsi
mov ebx,[rbp+24]
mov esi,[rbp+16]
cmp DWORD PTR [ebx],+0x0
jnl JUMP_007005
mov eax,[ebx]
neg eax
jmp JUMP_007006
JUMP_007005:
mov eax,[ebx]
JUMP_007006:
cmp DWORD PTR [ebx+0x4],+0x0
jnl JUMP_007007
mov edx,[ebx+0x4]
neg edx
jmp JUMP_007008
JUMP_007007:
mov edx,[ebx+0x4]
JUMP_007008:
or eax,edx
cmp DWORD PTR [ebx+0x8],+0x0
jnl JUMP_007009
mov edx,[ebx+0x8]
neg edx
jmp JUMP_007010
JUMP_007009:
mov edx,[ebx+0x8]
JUMP_007010:
or eax,edx
push rax
call FUNC_001656
pop rcx
add eax,-0xd
test eax,eax
jl JUMP_007011
mov ecx,eax
mov edx,[ebx]
sar edx,cl
mov [esi],edx
mov ecx,eax
mov edx,[ebx+0x4]
sar edx,cl
mov [esi+0x4],edx
mov ecx,eax
mov eax,[ebx+0x8]
sar eax,cl
mov [esi+0x8],eax
jmp JUMP_007012
JUMP_007011:
mov eax,[ebx]
mov [esi],eax
mov eax,[ebx+0x4]
mov [esi+0x4],eax
mov eax,[ebx+0x8]
mov [esi+0x8],eax
JUMP_007012:
pop rsi
pop rbx
pop rbp
ret
FUNC_001827:
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
push rdi
mov ecx,[rbp+40]
mov edx,[rbp+32]
mov eax,[rbp+24]
mov ebx,[rbp+16]
mov esi,[edx]
mov edi,[eax]
neg edi
add esi,edi
mov [rbp-0xc],esi
mov esi,[edx+0x4]
mov edi,[eax+0x4]
neg edi
add esi,edi
mov [rbp-0x8],esi
mov edx,[edx+0x8]
mov esi,[eax+0x8]
neg esi
add edx,esi
mov [rbp-0x4],edx
mov edx,[ecx]
mov esi,[eax]
neg esi
add edx,esi
mov [rbp-0x18],edx
mov edx,[ecx+0x4]
mov esi,[eax+0x4]
neg esi
add edx,esi
mov [rbp-0x14],edx
mov edx,[ecx+0x8]
mov eax,[eax+0x8]
neg eax
add edx,eax
mov [rbp-0x10],edx
lea eax,[rbp-0xc]
push rax
call FUNC_001825
pop rcx
add eax,-0x6
test eax,eax
jng JUMP_007013
mov ecx,eax
sar DWORD PTR [rbp-0xc],cl
mov ecx,eax
sar DWORD PTR [rbp-0x8],cl
mov ecx,eax
sar DWORD PTR [rbp-0x4],cl
JUMP_007013:
lea eax,[rbp-0x18]
push rax
call FUNC_001825
pop rcx
add eax,-0x6
test eax,eax
jng JUMP_007014
mov ecx,eax
sar DWORD PTR [rbp-0x18],cl
mov ecx,eax
sar DWORD PTR [rbp-0x14],cl
mov ecx,eax
sar DWORD PTR [rbp-0x10],cl
JUMP_007014:
mov eax,[rbp-0x8]
imul DWORD PTR [rbp-0x10]
mov edx,[rbp-0x4]
imul edx,[rbp-0x14]
sub eax,edx
mov [ebx],eax
mov eax,[rbp-0x4]
imul DWORD PTR [rbp-0x18]
mov edx,[rbp-0xc]
imul edx,[rbp-0x10]
sub eax,edx
mov [ebx+0x4],eax
mov eax,[rbp-0xc]
imul DWORD PTR [rbp-0x14]
mov edx,[rbp-0x8]
imul edx,[rbp-0x18]
sub eax,edx
mov [ebx+0x8],eax
push rbx
mov eax,DWORD PTR [DATA_007724]
call rax
pop rcx
mov ecx,eax
inc ecx
mov eax,[ebx]
shl eax,0xf
cdq
idiv ecx
mov [ebx],eax
mov eax,[ebx+0x4]
shl eax,0xf
cdq
idiv ecx
mov [ebx+0x4],eax
mov eax,[ebx+0x8]
shl eax,0xf
cdq
idiv ecx
mov [ebx+0x8],eax
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001829:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov esi,[ebx+0xc]
cmp esi,0x400
jnl JUMP_007017
mov esi,0x400
JUMP_007017:
push rsi
call FUNC_001656
pop rcx
mov edi,[DATA_009269]
sub edi,eax
mov [ebx+0x44],edi
dec edi
jnl JUMP_007018
mov DWORD PTR [ebx+0x44],0x1
JUMP_007018:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_001831:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp eax,0xffff8002
jnz JUMP_007034
mov eax,0x8
pop rbp
ret
JUMP_007034:
cmp eax,0xa0
jnz JUMP_007035
mov eax,0x2
pop rbp
ret
JUMP_007035:
mov edx,0x1
cmp eax,0xa0
jl JUMP_007036
add edx,+0x3
JUMP_007036:
mov eax,edx
pop rbp
ret
FUNC_001832:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp eax,0xffff8002
jnz JUMP_007037
mov eax,0x8
pop rbp
ret
JUMP_007037:
cmp eax,+0x4f
jnz JUMP_007038
mov eax,0x2
pop rbp
ret
JUMP_007038:
mov edx,0x1
cmp eax,+0x4f
jl JUMP_007039
add edx,+0x3
JUMP_007039:
mov eax,edx
pop rbp
ret
FUNC_001833:
push rbp
mov rbp,rsp
push rbx
push rsi
mov esi,[rbp+16]
mov ebx,[rbp+32]
shl ebx,0x4
lea ebx,[ebx+ebx*2]
add ebx,OFFSET FLAT:DATA_007843
cmp DWORD PTR [rbp+40],+0x0
jz JUMP_007040
mov DWORD PTR [DATA_009280],OFFSET FLAT:FUNC_001831
mov DWORD PTR [DATA_009281],OFFSET FLAT:FUNC_001832
mov DWORD PTR [DATA_009282],OFFSET FLAT:FUNC_001848
jmp JUMP_007041
JUMP_007040:
mov DWORD PTR [DATA_009280],OFFSET FLAT:FUNC_001715
mov DWORD PTR [DATA_009281],OFFSET FLAT:FUNC_001716
mov DWORD PTR [DATA_009282],OFFSET FLAT:FUNC_001847
JUMP_007041:
test esi,esi
jz JUMP_007042
mov ecx,[esi+0x130]
jmp JUMP_007043
JUMP_007042:
xor ecx,ecx
JUMP_007043:
mov eax,0x1dcd6500
sar eax,cl
mov [DATA_009264],eax
mov eax,[ebx]
mov [DATA_009270],eax
push rbx
mov eax,DWORD PTR [ebx+0x4]
call rax
pop rcx
mov [DATA_009261],esi
mov eax,[ebx+0x8]
pop rsi
pop rbx
pop rbp
ret
FUNC_001834:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov eax,[rbp+56]
mov edi,[rbp+32]
mov esi,[rbp+24]
mov ebx,[rbp+16]
cmp DWORD PTR [rbp+40],+0x0
jz JUMP_007044
add eax,+0x8
JUMP_007044:
cmp DWORD PTR [rbp+48],+0x0
jnz JUMP_007045
add eax,+0x2
JUMP_007045:
mov edx,[eax*4+DATA_007844]
mov [DATA_009279],edx
mov eax,[eax*4+DATA_007845]
mov [DATA_009278],eax
push rbx
call FUNC_001829
pop rcx
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
push rsi
call FUNC_001829
pop rcx
movsx eax,WORD PTR [esi]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [esi+0x24],ax
movsx eax,WORD PTR [esi+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [esi+0x26],ax
push rdi
call FUNC_001829
pop rcx
movsx eax,WORD PTR [edi]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [edi+0x24],ax
movsx eax,WORD PTR [edi+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [edi+0x26],ax
cmp DWORD PTR [rbp+40],+0x0
jz JUMP_007053
xor eax,eax
mov [rbp-0x4],eax
mov eax,[rbp+40]
mov [rbp-0x10],eax
JUMP_007046:
mov eax,[rbp-0x10]
cmp DWORD PTR [eax],+0x0
jng JUMP_007052
mov eax,[rbp-0x10]
mov eax,[eax]
mov edx,[eax]
shl edx,0x2
lea edx,[edx+edx*2]
add edx,OFFSET FLAT:DATA_007841
mov [rbp-0xc],edx
add eax,+0x4
movsx edx,WORD PTR [eax]
cmp edx,0x80
jnc JUMP_007048
movsx edx,WORD PTR [eax+0x2]
cmp edx,0x80
jnc JUMP_007048
movsx edx,WORD PTR [eax]
movsx ecx,WORD PTR [eax+0x2]
shl ecx,0x7
add edx,ecx
mov [rbp-0x8],edx
sar DWORD PTR [ebx+0x3c],0x7
mov edx,[rbp-0xc]
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007047
mov edx,[rbp-0xc]
mov edx,[edx+0x4]
mov ecx,[rbp-0x8]
movzx edx,BYTE PTR [edx+ecx]
imul edx,[ebx+0x3c]
mov [ebx+0x3c],edx
JUMP_007047:
mov edx,[rbp-0xc]
mov edx,[edx]
mov ecx,[rbp-0x8]
movsx edx,BYTE PTR [edx+ecx]
shl edx,0x15
add [ebx+0x3c],edx
JUMP_007048:
movsx edx,WORD PTR [eax+0x4]
cmp edx,0x80
jnc JUMP_007050
movsx edx,WORD PTR [eax+0x6]
cmp edx,0x80
jnc JUMP_007050
movsx edx,WORD PTR [eax+0x4]
movsx ecx,WORD PTR [eax+0x6]
shl ecx,0x7
add edx,ecx
mov [rbp-0x8],edx
sar DWORD PTR [esi+0x3c],0x7
mov edx,[rbp-0xc]
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007049
mov edx,[rbp-0xc]
mov edx,[edx+0x4]
mov ecx,[rbp-0x8]
movzx edx,BYTE PTR [edx+ecx]
imul edx,[esi+0x3c]
mov [esi+0x3c],edx
JUMP_007049:
mov edx,[rbp-0xc]
mov edx,[edx]
mov ecx,[rbp-0x8]
movsx edx,BYTE PTR [edx+ecx]
shl edx,0x15
add [esi+0x3c],edx
JUMP_007050:
movsx edx,WORD PTR [eax+0x8]
cmp edx,0x80
jnc JUMP_007052
movsx edx,WORD PTR [eax+0xa]
cmp edx,0x80
jnc JUMP_007052
movsx edx,WORD PTR [eax+0x8]
movsx eax,WORD PTR [eax+0xa]
shl eax,0x7
add edx,eax
mov [rbp-0x8],edx
sar DWORD PTR [edi+0x3c],0x7
mov eax,[rbp-0xc]
mov eax,[eax+0x4]
test eax,eax
jz JUMP_007051
mov edx,[rbp-0x8]
movzx eax,BYTE PTR [eax+edx]
imul eax,[edi+0x3c]
mov [edi+0x3c],eax
JUMP_007051:
mov eax,[rbp-0xc]
mov eax,[eax]
mov edx,[rbp-0x8]
movsx eax,BYTE PTR [eax+edx]
shl eax,0x15
add [edi+0x3c],eax
JUMP_007052:
inc DWORD PTR [rbp-0x4]
add DWORD PTR [rbp-0x10],+0x4
cmp DWORD PTR [rbp-0x4],+0x2
jl JUMP_007046
JUMP_007053:
cmp DWORD PTR [ebx+0x3c],+0x0
jnl JUMP_007054
xor eax,eax
jmp JUMP_007055
JUMP_007054:
mov eax,[ebx+0x3c]
JUMP_007055:
mov [ebx+0x40],eax
cmp DWORD PTR [esi+0x3c],+0x0
jnl JUMP_007056
xor eax,eax
jmp JUMP_007057
JUMP_007056:
mov eax,[esi+0x3c]
JUMP_007057:
mov [esi+0x40],eax
cmp DWORD PTR [edi+0x3c],+0x0
jnl JUMP_007058
xor eax,eax
jmp JUMP_007059
JUMP_007058:
mov eax,[edi+0x3c]
JUMP_007059:
mov [edi+0x40],eax
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001836:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
pop rbp
ret
FUNC_001841:
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
xor eax,eax
mov [rbp-0x4],eax
mov edx,OFFSET FLAT:DATA_007848
mov eax,OFFSET FLAT:DATA_007850
JUMP_007115:
mov ecx,[eax]
mov ecx,[ebx+ecx*4+0xc]
imul ecx,[eax+0x4]
mov esi,[eax+0x8]
mov esi,[ebx+esi*4+0xc]
imul esi,[eax+0xc]
add ecx,esi
sar ecx,0x4
and ecx,0xf0f0f
mov [edx],ecx
inc DWORD PTR [rbp-0x4]
add edx,+0x4
add eax,+0x10
cmp DWORD PTR [rbp-0x4],+0x16
jl JUMP_007115
xor eax,eax
mov [rbp-0x4],eax
mov DWORD PTR [rbp-0x14],OFFSET FLAT:DATA_007851
mov DWORD PTR [rbp-0x10],OFFSET FLAT:DATA_007849
JUMP_007116:
xor ecx,ecx
mov eax,[rbp-0x10]
mov edx,eax
mov eax,[rbp-0x14]
JUMP_007117:
mov esi,[eax]
mov esi,[ebx+esi*4+0xc]
imul esi,[eax+0x4]
mov edi,[eax+0x8]
mov edi,[ebx+edi*4+0xc]
imul edi,[eax+0xc]
add esi,edi
sar esi,0x4
and esi,0xf0f0f
mov [edx],esi
inc ecx
add edx,+0x4
add eax,+0x10
cmp ecx,+0x7
jl JUMP_007117
inc DWORD PTR [rbp-0x4]
add DWORD PTR [rbp-0x14],+0x70
add DWORD PTR [rbp-0x10],+0x1c
cmp DWORD PTR [rbp-0x4],+0x15
jl JUMP_007116
xor eax,eax
mov [rbp-0x4],eax
mov DWORD PTR [rbp-0x18],OFFSET FLAT:DATA_007846
JUMP_007118:
mov eax,[rbp-0x4]
shl eax,0x2
inc eax
mov ecx,0x3
cdq
idiv ecx
mov edx,0x4
sub edx,eax
mov ecx,edx
imul ecx,[ebx+0xc]
mov esi,[ebx+0x10]
imul esi,eax
add ecx,esi
sar ecx,0x2
and ecx,0xf0f0f
mov [rbp-0x8],ecx
imul edx,[ebx+0x14]
mov ecx,[ebx+0x18]
imul ecx,eax
add edx,ecx
sar edx,0x2
and edx,0xf0f0f
mov [rbp-0xc],edx
xor ecx,ecx
mov eax,[rbp-0x18]
mov esi,eax
JUMP_007119:
mov eax,ecx
shl eax,0x3
add eax,+0x3
mov edi,0x6
cdq
idiv edi
mov edx,0x8
sub edx,eax
imul edx,[rbp-0x8]
mov edi,[rbp-0xc]
imul edi,eax
add edx,edi
sar edx,0x3
and edx,0xf0f0f
mov [esi],edx
inc ecx
add esi,+0x4
cmp ecx,+0x7
jl JUMP_007119
inc DWORD PTR [rbp-0x4]
add DWORD PTR [rbp-0x18],+0x20
cmp DWORD PTR [rbp-0x4],+0x4
jl JUMP_007118
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
nop
FUNC_001843:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor ecx,ecx
mov edx,OFFSET FLAT:DATA_007852
mov eax,OFFSET FLAT:DATA_007853
JUMP_007128:
mov ebx,[rbp+16]
mov esi,[eax]
mov ebx,[ebx+esi*4+0xc]
imul ebx,[eax+0x4]
mov esi,[rbp+16]
mov edi,[eax+0x8]
mov esi,[esi+edi*4+0xc]
imul esi,[eax+0xc]
add ebx,esi
sar ebx,0x4
and ebx,0xf0f0f
mov [edx],ebx
inc ecx
add edx,+0x4
add eax,+0x10
cmp ecx,+0x20
jl JUMP_007128
pop rdi
pop rsi
pop rbx
pop rbp
ret
nop
FUNC_001846:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov edi,[rbp+24]
mov esi,[rbp+16]
cmp DWORD PTR [rbp+32],+0x1
jg JUMP_007132
xor esi,edi
push rsi
call FUNC_001824
pop rcx
sar eax,0x4
jmp JUMP_007134
JUMP_007132:
mov ebx,esi
sub ebx,edi
test ebx,ebx
jnl JUMP_007133
neg ebx
JUMP_007133:
push rbx
xor esi,edi
push rsi
call FUNC_001824
pop rcx
push rax
call FUNC_001521
add rsp,16
sar eax,1
JUMP_007134:
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_001848:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp DWORD PTR [eax+0x4],+0x0
jnz JUMP_007145
mov WORD PTR [eax+0x24],0x2
jmp JUMP_007147
JUMP_007145:
mov dx,0x1
cmp DWORD PTR [eax+0x4],+0x0
jl JUMP_007146
add edx,+0x3
JUMP_007146:
mov [eax+0x24],dx
JUMP_007147:
cmp DWORD PTR [eax+0x8],+0x0
jnz JUMP_007148
mov WORD PTR [eax+0x26],0x2
pop rbp
ret
JUMP_007148:
mov dx,0x1
cmp DWORD PTR [eax+0x8],+0x0
jl JUMP_007149
add edx,+0x3
JUMP_007149:
mov [eax+0x26],dx
pop rbp
ret
nop
nop
FUNC_001849:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007157
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007150
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007151
JUMP_007150:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007151:
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x30],eax
mov eax,[rbp+48]
mov edi,[eax*4+DATA_007839]
mov eax,[rbp+48]
cmp eax,[esi+0x44]
jng JUMP_007155
mov eax,[rbp+48]
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007155
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007152
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007153
JUMP_007152:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007156
JUMP_007153:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007154
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x4],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x4]
shl edx,0x4
lea ecx,[edx+DATA_007854]
mov esi,[rbp-0x8]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007855
mov ecx,[rbp-0x8]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007154:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007156
JUMP_007155:
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007156:
push rbx
call FUNC_001829
pop rcx
JUMP_007157:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
nop
nop
nop
FUNC_001850:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007165
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007158
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007159
JUMP_007158:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007159:
mov eax,[esi+0x28]
mov [ebx+0x28],eax
mov eax,[esi+0x2c]
mov [ebx+0x2c],eax
mov eax,[esi+0x30]
mov [ebx+0x30],eax
xor edi,edi
mov eax,[rbp+48]
cmp eax,[esi+0x44]
jng JUMP_007163
mov eax,[rbp+48]
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007163
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007160
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007161
JUMP_007160:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007164
JUMP_007161:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007162
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0xc],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x8]
shl edx,0x4
lea ecx,[edx+DATA_007856]
mov esi,[rbp-0xc]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007857
mov ecx,[rbp-0xc]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007162:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007164
JUMP_007163:
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [rbp-0x4],eax
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
add eax,[rbp-0x4]
mov [ebx+0x3c],eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007164:
push rbx
call FUNC_001829
pop rcx
JUMP_007165:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
FUNC_001851:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007175
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007166
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007167
JUMP_007166:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007167:
mov eax,[esi+0x28]
mov [ebx+0x28],eax
mov eax,[esi+0x2c]
mov [ebx+0x2c],eax
mov eax,[esi+0x30]
mov [ebx+0x30],eax
xor edi,edi
mov eax,[esi+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007168
mov eax,[rbp+48]
dec eax
jmp JUMP_007169
JUMP_007168:
mov eax,[rbp+48]
JUMP_007169:
cmp eax,[esi+0x44]
jng JUMP_007173
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007173
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007170
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007171
JUMP_007170:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007174
JUMP_007171:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007172
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x4],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x4]
shl edx,0x4
lea ecx,[edx+DATA_007858]
mov esi,[rbp-0x8]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007859
mov ecx,[rbp-0x8]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007172:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007174
JUMP_007173:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
mov edx,[esi+0x3c]
mov ecx,[rbp+32]
add edx,[ecx+0x3c]
sar edx,1
add eax,edx
mov [ebx+0x3c],eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007174:
push rbx
call FUNC_001829
pop rcx
JUMP_007175:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
nop
nop
nop
FUNC_001852:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007183
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007176
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007177
JUMP_007176:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007177:
mov eax,[esi+0x28]
mov [ebx+0x28],eax
mov eax,[esi+0x2c]
mov [ebx+0x2c],eax
mov eax,[esi+0x30]
mov [ebx+0x30],eax
xor eax,eax
mov [rbp-0x4],eax
mov eax,[rbp+48]
cmp eax,[esi+0x44]
jng JUMP_007181
mov eax,[rbp+48]
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007181
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007178
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007179
JUMP_007178:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007182
JUMP_007179:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007180
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0xc],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x8]
shl edx,0x4
lea ecx,[edx+DATA_007860]
mov esi,[rbp-0xc]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007861
mov ecx,[rbp-0xc]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007180:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007182
JUMP_007181:
mov edi,[esi+0x3c]
mov eax,[rbp+32]
add edi,[eax+0x3c]
sar edi,1
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
add eax,edi
mov [ebx+0x3c],eax
mov eax,[ebx+0x3c]
sub eax,edi
sar eax,0x3
add eax,[rbp-0x4]
mov edi,eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007182:
push rbx
call FUNC_001829
pop rcx
JUMP_007183:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
FUNC_001853:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007198
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007184
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007185
JUMP_007184:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007185:
mov eax,[esi+0x28]
mov [ebx+0x28],eax
mov eax,[esi+0x2c]
mov [ebx+0x2c],eax
mov eax,[esi+0x30]
mov [ebx+0x30],eax
xor edi,edi
mov eax,[esi+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007186
mov eax,[rbp+48]
dec eax
jmp JUMP_007187
JUMP_007186:
mov eax,[rbp+48]
JUMP_007187:
cmp eax,[esi+0x44]
jng JUMP_007194
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007194
mov eax,[esi+0x40]
test eax,eax
jnz JUMP_007188
mov edx,[rbp+32]
cmp DWORD PTR [edx+0x40],+0x0
jz JUMP_007189
JUMP_007188:
mov edx,[rbp+32]
add eax,[edx+0x40]
sar eax,1
mov [ebx+0x40],eax
mov [ebx+0x3c],eax
jmp JUMP_007190
JUMP_007189:
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
xor eax,eax
mov [ebx+0x40],eax
JUMP_007190:
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007191
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007192
JUMP_007191:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007197
JUMP_007192:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007193
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x4],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x4]
shl edx,0x4
lea ecx,[edx+DATA_007862]
mov esi,[rbp-0x8]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007863
mov ecx,[rbp-0x8]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007193:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007197
JUMP_007194:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
mov edx,[esi+0x3c]
mov ecx,[rbp+32]
add edx,[ecx+0x3c]
sar edx,1
add eax,edx
mov [ebx+0x3c],eax
cmp DWORD PTR [ebx+0x3c],+0x0
jl JUMP_007195
mov eax,[ebx+0x3c]
jmp JUMP_007196
JUMP_007195:
xor eax,eax
JUMP_007196:
mov [ebx+0x40],eax
mov edx,[esi+0x40]
mov ecx,[rbp+32]
add edx,[ecx+0x40]
sar edx,1
sub eax,edx
sar eax,0x3
add edi,eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007197:
push rbx
call FUNC_001829
pop rcx
JUMP_007198:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_001854:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov edi,[rbp+48]
mov esi,[rbp+24]
mov eax,[rbp+16]
mov eax,[eax+0x8]
test eax,eax
jnz JUMP_007206
call FUNC_001818
mov edx,[rbp+16]
mov [edx+0x8],eax
mov ebx,eax
mov eax,[rbp+16]
cmp esi,[eax]
jnz JUMP_007199
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0x4],eax
mov [eax],esi
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007200
JUMP_007199:
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0xc],eax
mov [eax],esi
JUMP_007200:
mov eax,[edi*4+DATA_007840]
push rax
mov eax,[esi+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x28],eax
mov eax,[edi*4+DATA_007840]
push rax
mov eax,[esi+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x2c],eax
mov eax,[edi*4+DATA_007840]
push rax
mov eax,[esi+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x30],eax
mov eax,[edi*4+DATA_007839]
mov [rbp-0x4],eax
cmp edi,[esi+0x44]
jng JUMP_007204
mov eax,[rbp+32]
cmp edi,[eax+0x44]
jng JUMP_007204
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007201
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007202
JUMP_007201:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007205
JUMP_007202:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007203
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0xc],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x10],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0xc]
shl edx,0x4
lea ecx,[edx+DATA_007864]
mov esi,[rbp-0x10]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007865
mov ecx,[rbp-0x10]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007203:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007205
JUMP_007204:
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [rbp-0x8],eax
push rdi
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
add eax,[rbp-0x8]
mov [ebx+0x3c],eax
mov eax,[rbp-0x4]
push rax
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
mov eax,[rbp-0x4]
push rax
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
mov eax,[rbp-0x4]
push rax
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007205:
push rbx
call FUNC_001829
pop rcx
JUMP_007206:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001855:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007216
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007207
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007208
JUMP_007207:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007208:
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x30],eax
mov eax,[rbp+48]
mov edi,[eax*4+DATA_007839]
mov eax,[esi+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007209
mov eax,[rbp+48]
dec eax
jmp JUMP_007210
JUMP_007209:
mov eax,[rbp+48]
JUMP_007210:
cmp eax,[esi+0x44]
jng JUMP_007214
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007214
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007211
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007212
JUMP_007211:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007215
JUMP_007212:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007213
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x4],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x4]
shl edx,0x4
lea ecx,[edx+DATA_007866]
mov esi,[rbp-0x8]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007867
mov ecx,[rbp-0x8]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007213:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007215
JUMP_007214:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
mov edx,[esi+0x3c]
mov ecx,[rbp+32]
add edx,[ecx+0x3c]
sar edx,1
add eax,edx
mov [ebx+0x3c],eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007215:
push rbx
call FUNC_001829
pop rcx
JUMP_007216:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
nop
FUNC_001856:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov edi,[rbp+48]
mov esi,[rbp+24]
mov eax,[rbp+16]
mov eax,[eax+0x8]
test eax,eax
jnz JUMP_007224
call FUNC_001818
mov edx,[rbp+16]
mov [edx+0x8],eax
mov ebx,eax
mov eax,[rbp+16]
cmp esi,[eax]
jnz JUMP_007217
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0x4],eax
mov [eax],esi
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007218
JUMP_007217:
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov edx,[rbp+16]
mov [edx+0xc],eax
mov [eax],esi
JUMP_007218:
mov eax,[edi*4+DATA_007840]
push rax
mov eax,[esi+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x28],eax
mov eax,[edi*4+DATA_007840]
push rax
mov eax,[esi+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x2c],eax
mov eax,[edi*4+DATA_007840]
push rax
mov eax,[esi+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x30],eax
mov eax,[edi*4+DATA_007839]
mov [rbp-0x4],eax
cmp edi,[esi+0x44]
jng JUMP_007222
mov eax,[rbp+32]
cmp edi,[eax+0x44]
jng JUMP_007222
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007219
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007220
JUMP_007219:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007223
JUMP_007220:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007221
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0xc],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x10],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0xc]
shl edx,0x4
lea ecx,[edx+DATA_007868]
mov esi,[rbp-0x10]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007869
mov ecx,[rbp-0x10]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007221:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007223
JUMP_007222:
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [rbp-0x8],eax
push rdi
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
add eax,[rbp-0x8]
mov [ebx+0x3c],eax
mov eax,[ebx+0x3c]
sub eax,[rbp-0x8]
sar eax,0x3
add eax,[rbp-0x4]
mov [rbp-0x8],eax
mov eax,[rbp-0x8]
push rax
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
mov eax,[rbp-0x8]
push rax
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
mov eax,[rbp-0x8]
push rax
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007223:
push rbx
call FUNC_001829
pop rcx
JUMP_007224:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001857:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007239
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007225
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007226
JUMP_007225:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007226:
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x30],eax
mov eax,[rbp+48]
mov edi,[eax*4+DATA_007839]
mov eax,[esi+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007227
mov eax,[rbp+48]
dec eax
jmp JUMP_007228
JUMP_007227:
mov eax,[rbp+48]
JUMP_007228:
cmp eax,[esi+0x44]
jng JUMP_007235
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007235
mov eax,[esi+0x40]
test eax,eax
jnz JUMP_007229
mov edx,[rbp+32]
cmp DWORD PTR [edx+0x40],+0x0
jz JUMP_007230
JUMP_007229:
mov edx,[rbp+32]
add eax,[edx+0x40]
sar eax,1
mov [ebx+0x40],eax
mov [ebx+0x3c],eax
jmp JUMP_007231
JUMP_007230:
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
xor eax,eax
mov [ebx+0x40],eax
JUMP_007231:
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007232
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007233
JUMP_007232:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007238
JUMP_007233:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007234
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x4],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x4]
shl edx,0x4
lea ecx,[edx+DATA_007870]
mov esi,[rbp-0x8]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007871
mov ecx,[rbp-0x8]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007234:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007238
JUMP_007235:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov eax,[eax+0x3c]
push rax
mov eax,[esi+0x3c]
push rax
call FUNC_001846
add rsp,24
mov edx,[esi+0x3c]
mov ecx,[rbp+32]
add edx,[ecx+0x3c]
sar edx,1
add eax,edx
mov [ebx+0x3c],eax
cmp DWORD PTR [ebx+0x3c],+0x0
jl JUMP_007236
mov eax,[ebx+0x3c]
jmp JUMP_007237
JUMP_007236:
xor eax,eax
JUMP_007237:
mov [ebx+0x40],eax
mov edx,[esi+0x40]
mov ecx,[rbp+32]
add edx,[ecx+0x40]
sar edx,1
sub eax,edx
sar eax,0x3
add edi,eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007238:
push rbx
call FUNC_001829
pop rcx
JUMP_007239:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
nop
nop
FUNC_001858:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov eax,[ebx+0x8]
test eax,eax
jz JUMP_007242
mov [rbp-0x4],eax
xor esi,esi
mov eax,[rbp-0x4]
lea ecx,[eax+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0xc],ebx
JUMP_007240:
mov ebx,[rbp-0xc]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007241
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007241:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0xc],0x100
cmp esi,+0x2
jl JUMP_007240
jmp JUMP_007255
JUMP_007242:
call FUNC_001818
mov [ebx+0x8],eax
mov [rbp-0x4],eax
mov eax,[ebx]
cmp eax,[rbp+24]
jnz JUMP_007243
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007244
JUMP_007243:
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007244:
xor esi,esi
mov eax,[rbp-0x4]
lea edx,[eax+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007245:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007246
movsx ebx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ebx,edi
sar ebx,1
mov [edx],bx
movsx ebx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ebx,edi
sar ebx,1
mov [edx+0x2],bx
JUMP_007246:
inc esi
add edx,+0x4
add eax,+0x4
add ecx,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007245
mov eax,[rbp+24]
mov edx,[rbp-0x4]
mov ecx,[eax+0x28]
mov [edx+0x28],ecx
mov ecx,[eax+0x2c]
mov [edx+0x2c],ecx
mov ecx,[eax+0x30]
mov [edx+0x30],ecx
xor eax,eax
mov [rbp-0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007250
mov eax,[rbp+32]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007250
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x3c],eax
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007247
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007248
JUMP_007247:
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007254
JUMP_007248:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007249
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx]
mov ebx,[rbp+24]
movsx ebx,WORD PTR [ebx]
sub ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ebx,esi
imul ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ebx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ebx,esi
cmp ecx,ebx
setg cl
and ecx,+0x1
mov ebx,eax
shl ebx,0x4
add ebx,OFFSET FLAT:DATA_007872
lea ebx,[ebx+edx*8]
mov bx,[ebx+ecx*4]
mov esi,[rbp-0x4]
add [esi],bx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007873
lea eax,[eax+edx*8]
mov ax,[eax+ecx*4]
mov edx,[rbp-0x4]
add [edx+0x2],ax
JUMP_007249:
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x24],ax
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x26],ax
jmp JUMP_007254
JUMP_007250:
mov eax,[rbp+24]
mov ebx,[eax+0x3c]
mov edi,ebx
mov eax,[rbp+32]
mov esi,[eax+0x3c]
add edi,esi
sar edi,1
mov eax,[rbp+48]
push rax
push rsi
push rbx
call FUNC_001846
add rsp,24
add edi,eax
mov eax,[rbp-0x4]
mov [eax+0x3c],edi
xor esi,esi
mov eax,[rbp-0x4]
add eax,+0x34
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007251:
cmp DWORD PTR [edx],+0x0
jz JUMP_007253
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007253
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007253
mov ecx,[rbp-0x4]
sar DWORD PTR [ecx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx ebx,WORD PTR [eax+0x2]
shl ebx,0x7
add ecx,ebx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007252
mov ebx,[edx+0x4]
movzx ebx,BYTE PTR [ebx+ecx]
mov edi,[rbp-0x4]
imul ebx,[edi+0x3c]
mov [edi+0x3c],ebx
JUMP_007252:
mov ebx,[edx]
movsx ecx,BYTE PTR [ebx+ecx]
shl ecx,0x15
mov ebx,[rbp-0x4]
add [ebx+0x3c],ecx
JUMP_007253:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007251
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007254:
mov eax,[rbp-0x4]
push rax
call FUNC_001829
pop rcx
JUMP_007255:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
FUNC_001859:
push rbp
mov rbp,rsp
add rsp,-20
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov eax,[ebx+0x8]
test eax,eax
jz JUMP_007258
mov [rbp-0x4],eax
xor esi,esi
mov eax,[rbp-0x4]
lea ecx,[eax+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007256:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007257
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007257:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007256
jmp JUMP_007273
JUMP_007258:
call FUNC_001818
mov [ebx+0x8],eax
mov [rbp-0x4],eax
mov eax,[ebx]
cmp eax,[rbp+24]
jnz JUMP_007259
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007260
JUMP_007259:
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007260:
xor esi,esi
mov eax,[rbp-0x4]
lea edx,[eax+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x14],ebx
JUMP_007261:
mov ebx,[rbp-0x14]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007262
movsx ebx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ebx,edi
sar ebx,1
mov [edx],bx
movsx ebx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ebx,edi
sar ebx,1
mov [edx+0x2],bx
JUMP_007262:
inc esi
add edx,+0x4
add eax,+0x4
add ecx,+0x4
add DWORD PTR [rbp-0x14],0x100
cmp esi,+0x2
jl JUMP_007261
mov eax,[rbp+24]
mov edx,[rbp-0x4]
mov ecx,[eax+0x28]
mov [edx+0x28],ecx
mov ecx,[eax+0x2c]
mov [edx+0x2c],ecx
mov ecx,[eax+0x30]
mov [edx+0x30],ecx
xor eax,eax
mov [rbp-0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007263
mov eax,[rbp+48]
dec eax
jmp JUMP_007264
JUMP_007263:
mov eax,[rbp+48]
JUMP_007264:
mov edx,[rbp+24]
cmp eax,[edx+0x44]
jng JUMP_007268
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007268
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x3c],eax
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007265
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007266
JUMP_007265:
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007272
JUMP_007266:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007267
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx]
mov ebx,[rbp+24]
movsx ebx,WORD PTR [ebx]
sub ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ebx,esi
imul ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ebx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ebx,esi
cmp ecx,ebx
setg cl
and ecx,+0x1
mov ebx,eax
shl ebx,0x4
add ebx,OFFSET FLAT:DATA_007874
lea ebx,[ebx+edx*8]
mov bx,[ebx+ecx*4]
mov esi,[rbp-0x4]
add [esi],bx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007875
lea eax,[eax+edx*8]
mov ax,[eax+ecx*4]
mov edx,[rbp-0x4]
add [edx+0x2],ax
JUMP_007267:
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x24],ax
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x26],ax
jmp JUMP_007272
JUMP_007268:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov edi,[eax+0x3c]
push rdi
mov eax,[rbp+24]
mov esi,[eax+0x3c]
push rsi
call FUNC_001846
add rsp,24
add esi,edi
sar esi,1
add eax,esi
mov edx,[rbp-0x4]
mov [edx+0x3c],eax
xor esi,esi
mov eax,[rbp-0x4]
add eax,+0x34
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007269:
cmp DWORD PTR [edx],+0x0
jz JUMP_007271
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007271
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007271
mov ecx,[rbp-0x4]
sar DWORD PTR [ecx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx ebx,WORD PTR [eax+0x2]
shl ebx,0x7
add ecx,ebx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007270
mov ebx,[edx+0x4]
movzx ebx,BYTE PTR [ebx+ecx]
mov edi,[rbp-0x4]
imul ebx,[edi+0x3c]
mov [edi+0x3c],ebx
JUMP_007270:
mov ebx,[edx]
movsx ecx,BYTE PTR [ebx+ecx]
shl ecx,0x15
mov ebx,[rbp-0x4]
add [ebx+0x3c],ecx
JUMP_007271:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007269
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007272:
mov eax,[rbp-0x4]
push rax
call FUNC_001829
pop rcx
JUMP_007273:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
nop
FUNC_001860:
push rbp
mov rbp,rsp
add rsp,-20
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov eax,[ebx+0x8]
test eax,eax
jz JUMP_007276
mov [rbp-0x8],eax
xor esi,esi
mov eax,[rbp-0x8]
lea ecx,[eax+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007274:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007275
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007275:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007274
jmp JUMP_007289
JUMP_007276:
call FUNC_001818
mov [ebx+0x8],eax
mov [rbp-0x8],eax
mov eax,[ebx]
cmp eax,[rbp+24]
jnz JUMP_007277
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007278
JUMP_007277:
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007278:
xor esi,esi
mov eax,[rbp-0x8]
lea edx,[eax+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x14],ebx
JUMP_007279:
mov ebx,[rbp-0x14]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007280
movsx ebx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ebx,edi
sar ebx,1
mov [edx],bx
movsx ebx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ebx,edi
sar ebx,1
mov [edx+0x2],bx
JUMP_007280:
inc esi
add edx,+0x4
add eax,+0x4
add ecx,+0x4
add DWORD PTR [rbp-0x14],0x100
cmp esi,+0x2
jl JUMP_007279
mov eax,[rbp+24]
mov edx,[rbp-0x8]
mov ecx,[eax+0x28]
mov [edx+0x28],ecx
mov ecx,[eax+0x2c]
mov [edx+0x2c],ecx
mov ecx,[eax+0x30]
mov [edx+0x30],ecx
xor eax,eax
mov [rbp-0xc],eax
mov eax,[rbp+24]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007284
mov eax,[rbp+32]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007284
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x3c],eax
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007281
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007282
JUMP_007281:
mov eax,[rbp-0x8]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007288
JUMP_007282:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov edx,[rbp-0x8]
mov [edx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007283
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx]
mov ebx,[rbp+24]
movsx ebx,WORD PTR [ebx]
sub ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ebx,esi
imul ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ebx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ebx,esi
cmp ecx,ebx
setg cl
and ecx,+0x1
mov ebx,eax
shl ebx,0x4
add ebx,OFFSET FLAT:DATA_007876
lea ebx,[ebx+edx*8]
mov bx,[ebx+ecx*4]
mov esi,[rbp-0x8]
add [esi],bx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007877
lea eax,[eax+edx*8]
mov ax,[eax+ecx*4]
mov edx,[rbp-0x8]
add [edx+0x2],ax
JUMP_007283:
mov eax,[rbp-0x8]
movsx eax,WORD PTR [eax]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov edx,[rbp-0x8]
mov [edx+0x24],ax
mov eax,[rbp-0x8]
movsx eax,WORD PTR [eax+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov edx,[rbp-0x8]
mov [edx+0x26],ax
jmp JUMP_007288
JUMP_007284:
mov eax,[rbp+24]
mov esi,[eax+0x3c]
mov ebx,esi
mov eax,[rbp+32]
mov edi,[eax+0x3c]
add ebx,edi
sar ebx,1
mov eax,[rbp+48]
push rax
push rdi
push rsi
call FUNC_001846
add rsp,24
add eax,ebx
mov edx,[rbp-0x8]
mov [edx+0x3c],eax
xor esi,esi
mov eax,[rbp-0x8]
add eax,+0x34
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007285:
cmp DWORD PTR [edx],+0x0
jz JUMP_007287
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007287
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007287
mov ecx,[rbp-0x8]
sar DWORD PTR [ecx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx edi,WORD PTR [eax+0x2]
shl edi,0x7
add ecx,edi
mov [rbp-0x4],ecx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007286
mov ecx,[edx+0x4]
mov edi,[rbp-0x4]
movzx ecx,BYTE PTR [ecx+edi]
mov edi,[rbp-0x8]
imul ecx,[edi+0x3c]
mov [edi+0x3c],ecx
JUMP_007286:
mov ecx,[edx]
mov edi,[rbp-0x4]
movsx ecx,BYTE PTR [ecx+edi]
shl ecx,0x15
mov edi,[rbp-0x8]
add [edi+0x3c],ecx
JUMP_007287:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007285
mov eax,[rbp-0x8]
mov eax,[eax+0x3c]
sub eax,ebx
sar eax,0x3
add eax,[rbp-0xc]
mov ebx,eax
push rbx
mov eax,[rbp-0x8]
mov eax,[eax+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov edx,[rbp-0x8]
mov [edx+0x4],eax
push rbx
mov eax,[rbp-0x8]
mov eax,[eax+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov edx,[rbp-0x8]
mov [edx+0x8],eax
push rbx
mov eax,[rbp-0x8]
mov eax,[eax+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov edx,[rbp-0x8]
mov [edx+0xc],eax
mov eax,[rbp-0x8]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007288:
mov eax,[rbp-0x8]
push rax
call FUNC_001829
pop rcx
JUMP_007289:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
FUNC_001861:
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
push rdi
mov esi,[rbp+16]
mov eax,[esi+0x8]
test eax,eax
jz JUMP_007292
mov ebx,eax
xor esi,esi
lea ecx,[ebx+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007290:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007291
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007291:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007290
jmp JUMP_007312
JUMP_007292:
call FUNC_001818
mov [esi+0x8],eax
mov ebx,eax
mov eax,[esi]
cmp eax,[rbp+24]
jnz JUMP_007293
call FUNC_001820
mov [esi+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [esi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007294
JUMP_007293:
call FUNC_001820
mov [esi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [esi+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007294:
xor esi,esi
lea edx,[ebx+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov [rbp-0x18],ecx
mov ecx,[rbp+48]
lea ecx,[ecx*8+DATA_009260]
mov [rbp-0x14],ecx
JUMP_007295:
mov ecx,[rbp-0x14]
cmp DWORD PTR [ecx],+0x0
jz JUMP_007296
mov ecx,[rbp-0x18]
movsx ecx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ecx,edi
sar ecx,1
mov [edx],cx
mov ecx,[rbp-0x18]
movsx ecx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ecx,edi
sar ecx,1
mov [edx+0x2],cx
JUMP_007296:
inc esi
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x18],+0x4
add DWORD PTR [rbp-0x14],0x100
cmp esi,+0x2
jl JUMP_007295
mov eax,[rbp+24]
mov edx,[eax+0x28]
mov [ebx+0x28],edx
mov edx,[eax+0x2c]
mov [ebx+0x2c],edx
mov edx,[eax+0x30]
mov [ebx+0x30],edx
xor eax,eax
mov [rbp-0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007297
mov eax,[rbp+48]
dec eax
jmp JUMP_007298
JUMP_007297:
mov eax,[rbp+48]
JUMP_007298:
mov edx,[rbp+24]
cmp eax,[edx+0x44]
jng JUMP_007305
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007305
mov eax,[rbp+24]
mov eax,[eax+0x40]
test eax,eax
jnz JUMP_007299
mov edx,[rbp+32]
cmp DWORD PTR [edx+0x40],+0x0
jz JUMP_007300
JUMP_007299:
mov edx,[rbp+32]
add eax,[edx+0x40]
sar eax,1
mov [ebx+0x40],eax
mov [ebx+0x3c],eax
jmp JUMP_007301
JUMP_007300:
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
xor eax,eax
mov [ebx+0x40],eax
JUMP_007301:
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007302
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007303
JUMP_007302:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007311
JUMP_007303:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007304
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov [rbp-0xc],edx
mov edx,[rbp+40]
movsx edx,WORD PTR [edx]
mov ecx,[rbp+24]
movsx ecx,WORD PTR [ecx]
sub edx,ecx
mov ecx,[rbp+32]
movsx ecx,WORD PTR [ecx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
mov ecx,[rbp+32]
movsx ecx,WORD PTR [ecx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ecx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ecx,esi
cmp edx,ecx
setg dl
and edx,+0x1
mov ecx,eax
shl ecx,0x4
add ecx,OFFSET FLAT:DATA_007878
mov esi,[rbp-0xc]
lea ecx,[ecx+esi*8]
mov cx,[ecx+edx*4]
add [ebx],cx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007879
mov ecx,[rbp-0xc]
lea eax,[eax+ecx*8]
mov ax,[eax+edx*4]
add [ebx+0x2],ax
JUMP_007304:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007311
JUMP_007305:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov edi,[eax+0x3c]
push rdi
mov eax,[rbp+24]
mov esi,[eax+0x3c]
push rsi
call FUNC_001846
add rsp,24
add esi,edi
sar esi,1
add eax,esi
mov [ebx+0x3c],eax
xor esi,esi
lea eax,[ebx+0x34]
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007306:
cmp DWORD PTR [edx],+0x0
jz JUMP_007308
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007308
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007308
sar DWORD PTR [ebx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx edi,WORD PTR [eax+0x2]
shl edi,0x7
add ecx,edi
mov [rbp-0x4],ecx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007307
mov ecx,[edx+0x4]
mov edi,[rbp-0x4]
movzx ecx,BYTE PTR [ecx+edi]
imul ecx,[ebx+0x3c]
mov [ebx+0x3c],ecx
JUMP_007307:
mov ecx,[edx]
mov edi,[rbp-0x4]
movsx ecx,BYTE PTR [ecx+edi]
shl ecx,0x15
add [ebx+0x3c],ecx
JUMP_007308:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007306
cmp DWORD PTR [ebx+0x3c],+0x0
jl JUMP_007309
mov eax,[ebx+0x3c]
jmp JUMP_007310
JUMP_007309:
xor eax,eax
JUMP_007310:
mov [ebx+0x40],eax
mov edx,[rbp+24]
mov edx,[edx+0x40]
mov ecx,[rbp+32]
add edx,[ecx+0x40]
sar edx,1
mov esi,eax
sub esi,edx
sar esi,0x3
add esi,[rbp-0x8]
push rsi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rsi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rsi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007311:
push rbx
call FUNC_001829
pop rcx
JUMP_007312:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001862:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov eax,[ebx+0x8]
test eax,eax
jz JUMP_007315
mov [rbp-0x4],eax
xor esi,esi
mov eax,[rbp-0x4]
lea ecx,[eax+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0xc],ebx
JUMP_007313:
mov ebx,[rbp-0xc]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007314
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007314:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0xc],0x100
cmp esi,+0x2
jl JUMP_007313
jmp JUMP_007328
JUMP_007315:
call FUNC_001818
mov [ebx+0x8],eax
mov [rbp-0x4],eax
mov eax,[ebx]
cmp eax,[rbp+24]
jnz JUMP_007316
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007317
JUMP_007316:
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007317:
xor esi,esi
mov eax,[rbp-0x4]
lea edx,[eax+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007318:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007319
movsx ebx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ebx,edi
sar ebx,1
mov [edx],bx
movsx ebx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ebx,edi
sar ebx,1
mov [edx+0x2],bx
JUMP_007319:
inc esi
add edx,+0x4
add eax,+0x4
add ecx,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007318
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x4]
mov [edx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x4]
mov [edx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x4]
mov [edx+0x30],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007839]
mov [rbp-0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007323
mov eax,[rbp+32]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007323
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x3c],eax
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007320
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007321
JUMP_007320:
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007327
JUMP_007321:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007322
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx]
mov ebx,[rbp+24]
movsx ebx,WORD PTR [ebx]
sub ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ebx,esi
imul ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ebx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ebx,esi
cmp ecx,ebx
setg cl
and ecx,+0x1
mov ebx,eax
shl ebx,0x4
add ebx,OFFSET FLAT:DATA_007880
lea ebx,[ebx+edx*8]
mov bx,[ebx+ecx*4]
mov esi,[rbp-0x4]
add [esi],bx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007881
lea eax,[eax+edx*8]
mov ax,[eax+ecx*4]
mov edx,[rbp-0x4]
add [edx+0x2],ax
JUMP_007322:
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x24],ax
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x26],ax
jmp JUMP_007327
JUMP_007323:
mov eax,[rbp+24]
mov ebx,[eax+0x3c]
mov edi,ebx
mov eax,[rbp+32]
mov esi,[eax+0x3c]
add edi,esi
sar edi,1
mov eax,[rbp+48]
push rax
push rsi
push rbx
call FUNC_001846
add rsp,24
add edi,eax
mov eax,[rbp-0x4]
mov [eax+0x3c],edi
xor esi,esi
mov eax,[rbp-0x4]
add eax,+0x34
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007324:
cmp DWORD PTR [edx],+0x0
jz JUMP_007326
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007326
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007326
mov ecx,[rbp-0x4]
sar DWORD PTR [ecx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx ebx,WORD PTR [eax+0x2]
shl ebx,0x7
add ecx,ebx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007325
mov ebx,[edx+0x4]
movzx ebx,BYTE PTR [ebx+ecx]
mov edi,[rbp-0x4]
imul ebx,[edi+0x3c]
mov [edi+0x3c],ebx
JUMP_007325:
mov ebx,[edx]
movsx ecx,BYTE PTR [ebx+ecx]
shl ecx,0x15
mov ebx,[rbp-0x4]
add [ebx+0x3c],ecx
JUMP_007326:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007324
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007327:
mov eax,[rbp-0x4]
push rax
call FUNC_001829
pop rcx
JUMP_007328:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
nop
nop
FUNC_001863:
push rbp
mov rbp,rsp
add rsp,-20
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov eax,[ebx+0x8]
test eax,eax
jz JUMP_007331
mov [rbp-0x4],eax
xor esi,esi
mov eax,[rbp-0x4]
lea ecx,[eax+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007329:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007330
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007330:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007329
jmp JUMP_007346
JUMP_007331:
call FUNC_001818
mov [ebx+0x8],eax
mov [rbp-0x4],eax
mov eax,[ebx]
cmp eax,[rbp+24]
jnz JUMP_007332
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007333
JUMP_007332:
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007333:
xor esi,esi
mov eax,[rbp-0x4]
lea edx,[eax+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x14],ebx
JUMP_007334:
mov ebx,[rbp-0x14]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007335
movsx ebx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ebx,edi
sar ebx,1
mov [edx],bx
movsx ebx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ebx,edi
sar ebx,1
mov [edx+0x2],bx
JUMP_007335:
inc esi
add edx,+0x4
add eax,+0x4
add ecx,+0x4
add DWORD PTR [rbp-0x14],0x100
cmp esi,+0x2
jl JUMP_007334
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x4]
mov [edx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x4]
mov [edx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x4]
mov [edx+0x30],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007839]
mov [rbp-0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007336
mov eax,[rbp+48]
dec eax
jmp JUMP_007337
JUMP_007336:
mov eax,[rbp+48]
JUMP_007337:
mov edx,[rbp+24]
cmp eax,[edx+0x44]
jng JUMP_007341
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007341
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x3c],eax
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007338
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007339
JUMP_007338:
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007345
JUMP_007339:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov edx,[rbp-0x4]
mov [edx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007340
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx]
mov ebx,[rbp+24]
movsx ebx,WORD PTR [ebx]
sub ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ebx,esi
imul ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ebx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ebx,esi
cmp ecx,ebx
setg cl
and ecx,+0x1
mov ebx,eax
shl ebx,0x4
add ebx,OFFSET FLAT:DATA_007882
lea ebx,[ebx+edx*8]
mov bx,[ebx+ecx*4]
mov esi,[rbp-0x4]
add [esi],bx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007883
lea eax,[eax+edx*8]
mov ax,[eax+ecx*4]
mov edx,[rbp-0x4]
add [edx+0x2],ax
JUMP_007340:
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x24],ax
mov eax,[rbp-0x4]
movsx eax,WORD PTR [eax+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov edx,[rbp-0x4]
mov [edx+0x26],ax
jmp JUMP_007345
JUMP_007341:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov edi,[eax+0x3c]
push rdi
mov eax,[rbp+24]
mov esi,[eax+0x3c]
push rsi
call FUNC_001846
add rsp,24
add esi,edi
sar esi,1
add eax,esi
mov edx,[rbp-0x4]
mov [edx+0x3c],eax
xor esi,esi
mov eax,[rbp-0x4]
add eax,+0x34
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007342:
cmp DWORD PTR [edx],+0x0
jz JUMP_007344
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007344
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007344
mov ecx,[rbp-0x4]
sar DWORD PTR [ecx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx ebx,WORD PTR [eax+0x2]
shl ebx,0x7
add ecx,ebx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007343
mov ebx,[edx+0x4]
movzx ebx,BYTE PTR [ebx+ecx]
mov edi,[rbp-0x4]
imul ebx,[edi+0x3c]
mov [edi+0x3c],ebx
JUMP_007343:
mov ebx,[edx]
movsx ecx,BYTE PTR [ebx+ecx]
shl ecx,0x15
mov ebx,[rbp-0x4]
add [ebx+0x3c],ecx
JUMP_007344:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007342
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x4],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0x8],eax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x4]
mov eax,[eax+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov edx,[rbp-0x4]
mov [edx+0xc],eax
mov eax,[rbp-0x4]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007345:
mov eax,[rbp-0x4]
push rax
call FUNC_001829
pop rcx
JUMP_007346:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001864:
push rbp
mov rbp,rsp
add rsp,-20
push rbx
push rsi
push rdi
mov ebx,[rbp+16]
mov eax,[ebx+0x8]
test eax,eax
jz JUMP_007349
mov [rbp-0x8],eax
xor esi,esi
mov eax,[rbp-0x8]
lea ecx,[eax+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007347:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007348
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007348:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007347
jmp JUMP_007362
JUMP_007349:
call FUNC_001818
mov [ebx+0x8],eax
mov [rbp-0x8],eax
mov eax,[ebx]
cmp eax,[rbp+24]
jnz JUMP_007350
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007351
JUMP_007350:
call FUNC_001820
mov [ebx+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [ebx+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007351:
xor esi,esi
mov eax,[rbp-0x8]
lea edx,[eax+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x14],ebx
JUMP_007352:
mov ebx,[rbp-0x14]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007353
movsx ebx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ebx,edi
sar ebx,1
mov [edx],bx
movsx ebx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ebx,edi
sar ebx,1
mov [edx+0x2],bx
JUMP_007353:
inc esi
add edx,+0x4
add eax,+0x4
add ecx,+0x4
add DWORD PTR [rbp-0x14],0x100
cmp esi,+0x2
jl JUMP_007352
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x8]
mov [edx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x8]
mov [edx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp-0x8]
mov [edx+0x30],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007839]
mov [rbp-0xc],eax
mov eax,[rbp+24]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007357
mov eax,[rbp+32]
mov eax,[eax+0x44]
cmp eax,[rbp+48]
jnl JUMP_007357
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x3c],eax
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007354
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007355
JUMP_007354:
mov eax,[rbp-0x8]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007361
JUMP_007355:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov edx,[rbp-0x8]
mov [edx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov edx,[rbp-0x8]
mov [edx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007356
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx]
mov ebx,[rbp+24]
movsx ebx,WORD PTR [ebx]
sub ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ebx,esi
imul ecx,ebx
mov ebx,[rbp+32]
movsx ebx,WORD PTR [ebx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ebx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ebx,esi
cmp ecx,ebx
setg cl
and ecx,+0x1
mov ebx,eax
shl ebx,0x4
add ebx,OFFSET FLAT:DATA_007884
lea ebx,[ebx+edx*8]
mov bx,[ebx+ecx*4]
mov esi,[rbp-0x8]
add [esi],bx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007885
lea eax,[eax+edx*8]
mov ax,[eax+ecx*4]
mov edx,[rbp-0x8]
add [edx+0x2],ax
JUMP_007356:
mov eax,[rbp-0x8]
movsx eax,WORD PTR [eax]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov edx,[rbp-0x8]
mov [edx+0x24],ax
mov eax,[rbp-0x8]
movsx eax,WORD PTR [eax+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov edx,[rbp-0x8]
mov [edx+0x26],ax
jmp JUMP_007361
JUMP_007357:
mov eax,[rbp+24]
mov esi,[eax+0x3c]
mov ebx,esi
mov eax,[rbp+32]
mov edi,[eax+0x3c]
add ebx,edi
sar ebx,1
mov eax,[rbp+48]
push rax
push rdi
push rsi
call FUNC_001846
add rsp,24
add eax,ebx
mov edx,[rbp-0x8]
mov [edx+0x3c],eax
xor esi,esi
mov eax,[rbp-0x8]
add eax,+0x34
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007358:
cmp DWORD PTR [edx],+0x0
jz JUMP_007360
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007360
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007360
mov ecx,[rbp-0x8]
sar DWORD PTR [ecx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx edi,WORD PTR [eax+0x2]
shl edi,0x7
add ecx,edi
mov [rbp-0x4],ecx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007359
mov ecx,[edx+0x4]
mov edi,[rbp-0x4]
movzx ecx,BYTE PTR [ecx+edi]
mov edi,[rbp-0x8]
imul ecx,[edi+0x3c]
mov [edi+0x3c],ecx
JUMP_007359:
mov ecx,[edx]
mov edi,[rbp-0x4]
movsx ecx,BYTE PTR [ecx+edi]
shl ecx,0x15
mov edi,[rbp-0x8]
add [edi+0x3c],ecx
JUMP_007360:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007358
mov eax,[rbp-0x8]
mov eax,[eax+0x3c]
sub eax,ebx
sar eax,0x3
add eax,[rbp-0xc]
mov ebx,eax
push rbx
mov eax,[rbp-0x8]
mov eax,[eax+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov edx,[rbp-0x8]
mov [edx+0x4],eax
push rbx
mov eax,[rbp-0x8]
mov eax,[eax+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov edx,[rbp-0x8]
mov [edx+0x8],eax
push rbx
mov eax,[rbp-0x8]
mov eax,[eax+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov edx,[rbp-0x8]
mov [edx+0xc],eax
mov eax,[rbp-0x8]
push rax
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007361:
mov eax,[rbp-0x8]
push rax
call FUNC_001829
pop rcx
JUMP_007362:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
nop
nop
nop
FUNC_001865:
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
push rdi
mov esi,[rbp+16]
mov eax,[esi+0x8]
test eax,eax
jz JUMP_007365
mov ebx,eax
xor esi,esi
lea ecx,[ebx+0x34]
mov eax,[rbp+32]
lea edx,[eax+0x34]
mov eax,[rbp+24]
add eax,+0x34
mov ebx,[rbp+48]
lea ebx,[ebx*8+DATA_009260]
mov [rbp-0x10],ebx
JUMP_007363:
mov ebx,[rbp-0x10]
cmp DWORD PTR [ebx],+0x0
jz JUMP_007364
movsx ebx,WORD PTR [eax]
movsx edi,WORD PTR [edx]
add ebx,edi
sar ebx,1
mov [ecx],bx
movsx ebx,WORD PTR [eax+0x2]
movsx edi,WORD PTR [edx+0x2]
add ebx,edi
sar ebx,1
mov [ecx+0x2],bx
JUMP_007364:
inc esi
add ecx,+0x4
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x10],0x100
cmp esi,+0x2
jl JUMP_007363
jmp JUMP_007385
JUMP_007365:
call FUNC_001818
mov [esi+0x8],eax
mov ebx,eax
mov eax,[esi]
cmp eax,[rbp+24]
jnz JUMP_007366
call FUNC_001820
mov [esi+0x4],eax
mov edx,[rbp+24]
mov [eax],edx
call FUNC_001820
mov [esi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007367
JUMP_007366:
call FUNC_001820
mov [esi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [esi+0xc],eax
mov edx,[rbp+24]
mov [eax],edx
JUMP_007367:
xor esi,esi
lea edx,[ebx+0x34]
mov eax,[rbp+32]
add eax,+0x34
mov ecx,[rbp+24]
add ecx,+0x34
mov [rbp-0x18],ecx
mov ecx,[rbp+48]
lea ecx,[ecx*8+DATA_009260]
mov [rbp-0x14],ecx
JUMP_007368:
mov ecx,[rbp-0x14]
cmp DWORD PTR [ecx],+0x0
jz JUMP_007369
mov ecx,[rbp-0x18]
movsx ecx,WORD PTR [ecx]
movsx edi,WORD PTR [eax]
add ecx,edi
sar ecx,1
mov [edx],cx
mov ecx,[rbp-0x18]
movsx ecx,WORD PTR [ecx+0x2]
movsx edi,WORD PTR [eax+0x2]
add ecx,edi
sar ecx,1
mov [edx+0x2],cx
JUMP_007369:
inc esi
add edx,+0x4
add eax,+0x4
add DWORD PTR [rbp-0x18],+0x4
add DWORD PTR [rbp-0x14],0x100
cmp esi,+0x2
jl JUMP_007368
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[rbp+24]
mov eax,[eax+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x30],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007839]
mov [rbp-0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0x3c]
dec eax
mov edx,[rbp+32]
mov edx,[edx+0x3c]
dec edx
xor eax,edx
jnl JUMP_007370
mov eax,[rbp+48]
dec eax
jmp JUMP_007371
JUMP_007370:
mov eax,[rbp+48]
JUMP_007371:
mov edx,[rbp+24]
cmp eax,[edx+0x44]
jng JUMP_007378
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007378
mov eax,[rbp+24]
mov eax,[eax+0x40]
test eax,eax
jnz JUMP_007372
mov edx,[rbp+32]
cmp DWORD PTR [edx+0x40],+0x0
jz JUMP_007373
JUMP_007372:
mov edx,[rbp+32]
add eax,[edx+0x40]
sar eax,1
mov [ebx+0x40],eax
mov [ebx+0x3c],eax
jmp JUMP_007374
JUMP_007373:
mov eax,[rbp+24]
mov eax,[eax+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
xor eax,eax
mov [ebx+0x40],eax
JUMP_007374:
mov eax,[rbp+24]
mov eax,[eax+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[rbp+24]
mov eax,[eax+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[rbp+24]
mov eax,[eax+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
mov eax,[rbp+24]
cmp DWORD PTR [eax+0xc],+0x40
jl JUMP_007375
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007376
JUMP_007375:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007384
JUMP_007376:
mov eax,[rbp+24]
movsx eax,WORD PTR [eax]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
mov eax,[rbp+24]
movsx eax,WORD PTR [eax+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007377
mov eax,[rbp+24]
mov ax,[eax+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov edx,[rbp+24]
mov dx,[edx]
mov ecx,[rbp+32]
cmp dx,[ecx]
setg dl
and edx,+0x1
mov [rbp-0xc],edx
mov edx,[rbp+40]
movsx edx,WORD PTR [edx]
mov ecx,[rbp+24]
movsx ecx,WORD PTR [ecx]
sub edx,ecx
mov ecx,[rbp+32]
movsx ecx,WORD PTR [ecx+0x2]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
mov ecx,[rbp+32]
movsx ecx,WORD PTR [ecx]
mov esi,[rbp+24]
movsx esi,WORD PTR [esi]
sub ecx,esi
mov esi,[rbp+40]
movsx esi,WORD PTR [esi+0x2]
mov edi,[rbp+24]
movsx edi,WORD PTR [edi+0x2]
sub esi,edi
imul ecx,esi
cmp edx,ecx
setg dl
and edx,+0x1
mov ecx,eax
shl ecx,0x4
add ecx,OFFSET FLAT:DATA_007886
mov esi,[rbp-0xc]
lea ecx,[ecx+esi*8]
mov cx,[ecx+edx*4]
add [ebx],cx
shl eax,0x4
add eax,OFFSET FLAT:DATA_007887
mov ecx,[rbp-0xc]
lea eax,[eax+ecx*8]
mov ax,[eax+edx*4]
add [ebx+0x2],ax
JUMP_007377:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007384
JUMP_007378:
mov eax,[rbp+48]
push rax
mov eax,[rbp+32]
mov edi,[eax+0x3c]
push rdi
mov eax,[rbp+24]
mov esi,[eax+0x3c]
push rsi
call FUNC_001846
add rsp,24
add esi,edi
sar esi,1
add eax,esi
mov [ebx+0x3c],eax
xor esi,esi
lea eax,[ebx+0x34]
mov edx,[rbp+48]
lea edx,[edx*8+DATA_009260]
JUMP_007379:
cmp DWORD PTR [edx],+0x0
jz JUMP_007381
movsx ecx,WORD PTR [eax]
cmp ecx,0x80
jnc JUMP_007381
movsx ecx,WORD PTR [eax+0x2]
cmp ecx,0x80
jnc JUMP_007381
sar DWORD PTR [ebx+0x3c],0x7
movsx ecx,WORD PTR [eax]
movsx edi,WORD PTR [eax+0x2]
shl edi,0x7
add ecx,edi
mov [rbp-0x4],ecx
cmp DWORD PTR [edx+0x4],+0x0
jz JUMP_007380
mov ecx,[edx+0x4]
mov edi,[rbp-0x4]
movzx ecx,BYTE PTR [ecx+edi]
imul ecx,[ebx+0x3c]
mov [ebx+0x3c],ecx
JUMP_007380:
mov ecx,[edx]
mov edi,[rbp-0x4]
movsx ecx,BYTE PTR [ecx+edi]
shl ecx,0x15
add [ebx+0x3c],ecx
JUMP_007381:
inc esi
add eax,+0x4
add edx,0x100
cmp esi,+0x2
jl JUMP_007379
cmp DWORD PTR [ebx+0x3c],+0x0
jl JUMP_007382
mov eax,[ebx+0x3c]
jmp JUMP_007383
JUMP_007382:
xor eax,eax
JUMP_007383:
mov [ebx+0x40],eax
mov edx,[rbp+24]
mov edx,[edx+0x40]
mov ecx,[rbp+32]
add edx,[ecx+0x40]
sar edx,1
mov esi,eax
sub esi,edx
sar esi,0x3
add esi,[rbp-0x8]
push rsi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rsi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rsi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[rbp+24]
mov edx,[edx+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007384:
push rbx
call FUNC_001829
pop rcx
JUMP_007385:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001866:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007393
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007386
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007387
JUMP_007386:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007387:
mov eax,[esi+0x28]
mov [ebx+0x28],eax
mov eax,[esi+0x2c]
mov [ebx+0x2c],eax
mov eax,[esi+0x30]
mov [ebx+0x30],eax
xor edi,edi
mov eax,[rbp+48]
cmp eax,[esi+0x44]
jng JUMP_007391
mov eax,[rbp+48]
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007391
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007388
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007389
JUMP_007388:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007392
JUMP_007389:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007390
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x4],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x4]
shl edx,0x4
lea ecx,[edx+DATA_007888]
mov esi,[rbp-0x8]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007889
mov ecx,[rbp-0x8]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007390:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007392
JUMP_007391:
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007392:
push rbx
call FUNC_001829
pop rcx
JUMP_007393:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
nop
FUNC_001867:
push rbp
mov rbp,rsp
add rsp,-16
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov edi,[rbp+16]
mov eax,[edi+0x8]
test eax,eax
jnz JUMP_007401
call FUNC_001818
mov [edi+0x8],eax
mov ebx,eax
cmp esi,[edi]
jnz JUMP_007394
call FUNC_001820
mov [edi+0x4],eax
mov [eax],esi
call FUNC_001820
mov [edi+0xc],eax
mov edx,[rbp+32]
mov [eax],edx
jmp JUMP_007395
JUMP_007394:
call FUNC_001820
mov [edi+0x4],eax
mov edx,[rbp+32]
mov [eax],edx
call FUNC_001820
mov [edi+0xc],eax
mov [eax],esi
JUMP_007395:
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x28]
mov edx,[rbp+32]
add eax,[edx+0x28]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x28],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x2c]
mov edx,[rbp+32]
add eax,[edx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x2c],eax
mov eax,[rbp+48]
mov eax,[eax*4+DATA_007840]
push rax
mov eax,[esi+0x30]
mov edx,[rbp+32]
add eax,[edx+0x30]
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x30],eax
mov eax,[rbp+48]
mov edi,[eax*4+DATA_007839]
mov eax,[rbp+48]
cmp eax,[esi+0x44]
jng JUMP_007399
mov eax,[rbp+48]
mov edx,[rbp+32]
cmp eax,[edx+0x44]
jng JUMP_007399
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
mov eax,[esi+0x4]
mov edx,[rbp+32]
add eax,[edx+0x4]
sar eax,1
mov [ebx+0x4],eax
mov eax,[esi+0x8]
mov edx,[rbp+32]
add eax,[edx+0x8]
sar eax,1
mov [ebx+0x8],eax
mov eax,[esi+0xc]
mov edx,[rbp+32]
add eax,[edx+0xc]
sar eax,1
mov [ebx+0xc],eax
cmp DWORD PTR [esi+0xc],+0x40
jl JUMP_007396
mov eax,[rbp+32]
cmp DWORD PTR [eax+0xc],+0x40
jnl JUMP_007397
JUMP_007396:
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
jmp JUMP_007400
JUMP_007397:
movsx eax,WORD PTR [esi]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
add eax,edx
sar eax,1
mov [ebx],ax
movsx eax,WORD PTR [esi+0x2]
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
add eax,edx
sar eax,1
mov [ebx+0x2],ax
mov eax,[rbp+40]
cmp DWORD PTR [eax+0xc],+0x40
jng JUMP_007398
mov ax,[esi+0x2]
mov edx,[rbp+32]
cmp ax,[edx+0x2]
setg al
and eax,+0x1
mov [rbp-0x4],eax
mov ax,[esi]
mov edx,[rbp+32]
cmp ax,[edx]
setg al
and eax,+0x1
mov [rbp-0x8],eax
mov eax,[rbp+40]
movsx eax,WORD PTR [eax]
movsx edx,WORD PTR [esi]
sub eax,edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx+0x2]
movsx ecx,WORD PTR [esi+0x2]
sub edx,ecx
imul edx
mov edx,[rbp+32]
movsx edx,WORD PTR [edx]
movsx ecx,WORD PTR [esi]
sub edx,ecx
mov ecx,[rbp+40]
movsx ecx,WORD PTR [ecx+0x2]
movsx esi,WORD PTR [esi+0x2]
sub ecx,esi
imul edx,ecx
cmp eax,edx
setg al
and eax,+0x1
mov edx,[rbp-0x4]
shl edx,0x4
lea ecx,[edx+DATA_007890]
mov esi,[rbp-0x8]
lea ecx,[ecx+esi*8]
mov cx,[ecx+eax*4]
add [ebx],cx
add edx,OFFSET FLAT:DATA_007891
mov ecx,[rbp-0x8]
lea edx,[edx+ecx*8]
mov ax,[edx+eax*4]
add [ebx+0x2],ax
JUMP_007398:
movsx eax,WORD PTR [ebx]
push rax
mov eax,DWORD PTR [DATA_009280]
call rax
pop rcx
mov [ebx+0x24],ax
movsx eax,WORD PTR [ebx+0x2]
push rax
mov eax,DWORD PTR [DATA_009281]
call rax
pop rcx
mov [ebx+0x26],ax
jmp JUMP_007400
JUMP_007399:
mov eax,[esi+0x3c]
mov edx,[rbp+32]
add eax,[edx+0x3c]
sar eax,1
mov [ebx+0x3c],eax
push rdi
mov eax,[ebx+0x28]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x4]
mov ecx,[rbp+32]
add edx,[ecx+0x4]
sar edx,1
add eax,edx
mov [ebx+0x4],eax
push rdi
mov eax,[ebx+0x2c]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0x8]
mov ecx,[rbp+32]
add edx,[ecx+0x8]
sar edx,1
add eax,edx
mov [ebx+0x8],eax
push rdi
mov eax,[ebx+0x30]
push rax
call FUNC_001521
add rsp,16
mov edx,[esi+0xc]
mov ecx,[rbp+32]
add edx,[ecx+0xc]
sar edx,1
add eax,edx
mov [ebx+0xc],eax
push rbx
mov eax,DWORD PTR [DATA_009282]
call rax
pop rcx
JUMP_007400:
push rbx
call FUNC_001829
pop rcx
JUMP_007401:
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
nop
nop
nop
FUNC_001875:
push rbp
mov rbp,rsp
add rsp,-24
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
mov eax,[esi+0x4]
push rax
mov eax,[ebx]
push rax
lea eax,[rbp-0x8]
push rax
call FUNC_001339
add rsp,24
mov eax,[esi]
push rax
mov eax,[ebx+0x4]
push rax
lea eax,[rbp-0x10]
push rax
call FUNC_001339
add rsp,24
push QWORD PTR [rbp-0xc]
push QWORD PTR [rbp-0x10]
push QWORD PTR [rbp-0x4]
push QWORD PTR [rbp-0x8]
lea eax,[rbp-0x18]
push rax
call FUNC_001335
add rsp,40
mov eax,[rbp-0x14]
sar eax,0x1f
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001876:
pushfq
inc DWORD PTR [query_count_full]
popfq
push rbp
mov rbp,rsp
add rsp,-2472
push rbx
push rsi
push rdi
mov esi,OFFSET FLAT:DATA_007893
lea edi,[rbp-0x27c]
mov ecx,0x78
rep movsd
mov esi,OFFSET FLAT:DATA_007894
lea edi,[rbp-0x90c]
mov ecx,0x3c
rep movsd
mov eax,[rbp+32]
mov eax,[eax+0xa0]
mov [rbp-0x4],eax
cmp DWORD PTR [rbp+104],+0x0
jz JUMP_007953
mov DWORD PTR [DATA_009283],0x7fffffff
mov eax,[rbp+24]
mov [DATA_009285],eax
mov DWORD PTR [DATA_009284],0x4000
jmp JUMP_007956
JUMP_007953:
mov eax,[rbp+40]
mov eax,[eax+0x148]
add eax,-0x8
mov [rbp-0x10],eax
cmp DWORD PTR [rbp-0x10],+0x0
jnl JUMP_007954
mov ecx,[rbp-0x10]
neg ecx
sar DWORD PTR [rbp+80],cl
jmp JUMP_007955
JUMP_007954:
mov ecx,[rbp-0x10]
shl DWORD PTR [rbp+80],cl
JUMP_007955:
mov eax,[rbp+96]
push rax
lea eax,[rbp-0x30]
push rax
call FUNC_001692
add rsp,16
lea eax,[rbp-0x30]
push QWORD PTR [rax+0xc]
push QWORD PTR [rax+0x8]
push QWORD PTR [rax+0x4]
push QWORD PTR [rax]
push OFFSET FLAT:DATA_009259
call FUNC_001691
add rsp,40
mov eax,[rbp+80]
push rax
mov eax,[rbp+88]
push rax
mov eax,[DATA_009259]
push rax
mov eax,[rbp+64]
push rax
mov eax,[rbp+56]
push rax
mov eax,[rbp+40]
push rax
call FUNC_001877
add rsp,48
JUMP_007956:
mov eax,[rbp+64]
push rax
call FUNC_001825
pop rcx
add eax,-0xe
mov [rbp-0x10],eax
cmp DWORD PTR [rbp-0x10],+0x0
jng JUMP_007957
mov ecx,[rbp-0x10]
mov eax,[rbp+64]
mov eax,[eax]
sar eax,cl
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx]
sar edx,cl
imul edx
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0x4]
sar edx,cl
mov ecx,[rbp-0x10]
mov ebx,[rbp+64]
mov ebx,[ebx+0x4]
sar ebx,cl
imul edx,ebx
add eax,edx
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0x8]
sar edx,cl
mov ecx,[rbp-0x10]
mov ebx,[rbp+64]
mov ebx,[ebx+0x8]
sar ebx,cl
imul edx,ebx
add eax,edx
push rax
mov eax,DWORD PTR [DATA_007723]
call rax
pop rcx
mov ecx,[rbp-0x10]
shl eax,cl
mov [rbp-0xc],eax
jmp JUMP_007958
JUMP_007957:
mov eax,[rbp+64]
mov eax,[eax]
mov edx,[rbp+64]
imul DWORD PTR [edx]
mov edx,[rbp+64]
mov edx,[edx+0x4]
mov ecx,[rbp+64]
imul edx,[ecx+0x4]
add eax,edx
mov edx,[rbp+64]
mov edx,[edx+0x8]
mov ecx,[rbp+64]
imul edx,[ecx+0x8]
add eax,edx
push rax
mov eax,DWORD PTR [DATA_007723]
call rax
pop rcx
mov [rbp-0xc],eax
JUMP_007958:
mov eax,[rbp+64]
add eax,+0xc
push rax
call FUNC_001825
pop rcx
add eax,-0xe
mov [rbp-0x10],eax
cmp DWORD PTR [rbp-0x10],+0x0
jng JUMP_007959
mov ecx,[rbp-0x10]
mov eax,[rbp+64]
mov eax,[eax+0xc]
sar eax,cl
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0xc]
sar edx,cl
imul edx
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0x10]
sar edx,cl
mov ecx,[rbp-0x10]
mov ebx,[rbp+64]
mov ebx,[ebx+0x10]
sar ebx,cl
imul edx,ebx
add eax,edx
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0x14]
sar edx,cl
mov ecx,[rbp-0x10]
mov ebx,[rbp+64]
mov ebx,[ebx+0x14]
sar ebx,cl
imul edx,ebx
add eax,edx
push rax
mov eax,DWORD PTR [DATA_007723]
call rax
pop rcx
mov ecx,[rbp-0x10]
shl eax,cl
mov [rbp-0x8],eax
jmp JUMP_007960
JUMP_007959:
mov eax,[rbp+64]
mov eax,[eax+0xc]
mov edx,[rbp+64]
imul DWORD PTR [edx+0xc]
mov edx,[rbp+64]
mov edx,[edx+0x10]
mov ecx,[rbp+64]
imul edx,[ecx+0x10]
add eax,edx
mov edx,[rbp+64]
mov edx,[edx+0x14]
mov ecx,[rbp+64]
imul edx,[ecx+0x14]
add eax,edx
push rax
mov eax,DWORD PTR [DATA_007723]
call rax
pop rcx
mov [rbp-0x8],eax
JUMP_007960:
mov eax,[rbp-0x8]
cmp eax,[rbp-0xc]
jng JUMP_007961
mov eax,[rbp-0x8]
mov [rbp-0xc],eax
JUMP_007961:
mov eax,[rbp+64]
add eax,+0x18
push rax
call FUNC_001825
pop rcx
add eax,-0xe
mov [rbp-0x10],eax
cmp DWORD PTR [rbp-0x10],+0x0
jng JUMP_007962
mov ecx,[rbp-0x10]
mov eax,[rbp+64]
mov eax,[eax+0x18]
sar eax,cl
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0x18]
sar edx,cl
imul edx
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0x1c]
sar edx,cl
mov ecx,[rbp-0x10]
mov ebx,[rbp+64]
mov ebx,[ebx+0x1c]
sar ebx,cl
imul edx,ebx
add eax,edx
mov ecx,[rbp-0x10]
mov edx,[rbp+64]
mov edx,[edx+0x20]
sar edx,cl
mov ecx,[rbp-0x10]
mov ebx,[rbp+64]
mov ebx,[ebx+0x20]
sar ebx,cl
imul edx,ebx
add eax,edx
push rax
mov eax,DWORD PTR [DATA_007723]
call rax
pop rcx
mov ecx,[rbp-0x10]
shl eax,cl
mov [rbp-0x8],eax
jmp JUMP_007963
JUMP_007962:
mov eax,[rbp+64]
mov eax,[eax+0x18]
mov edx,[rbp+64]
imul DWORD PTR [edx+0x18]
mov edx,[rbp+64]
mov edx,[edx+0x1c]
mov ecx,[rbp+64]
imul edx,[ecx+0x1c]
add eax,edx
mov edx,[rbp+64]
mov edx,[edx+0x20]
mov ecx,[rbp+64]
imul edx,[ecx+0x20]
add eax,edx
push rax
mov eax,DWORD PTR [DATA_007723]
call rax
pop rcx
mov [rbp-0x8],eax
JUMP_007963:
mov eax,[rbp-0x8]
cmp eax,[rbp-0xc]
jng JUMP_007964
mov eax,[rbp-0x8]
mov [rbp-0xc],eax
JUMP_007964:
push 0x54000000
mov eax,[rbp-0xc]
push rax
call FUNC_001521
add rsp,16
add eax,eax
mov [rbp-0x8],eax
cmp DWORD PTR [rbp+104],+0x0
jnz JUMP_007966
mov eax,[DATA_008812]
dec eax
mov [DATA_007837],eax
mov eax,[rbp+56]
push rax
call FUNC_001825
pop rcx
add eax,-0xe
mov [rbp-0x38],eax
cmp DWORD PTR [rbp-0x38],+0x0
jnl JUMP_007965
xor eax,eax
mov [rbp-0x38],eax
JUMP_007965:
mov ecx,[rbp-0x38]
mov eax,[rbp+56]
mov eax,[eax]
sar eax,cl
mov ecx,[rbp-0x38]
mov edx,[rbp+56]
mov edx,[edx]
sar edx,cl
imul edx
mov ecx,[rbp-0x38]
mov edx,[rbp+56]
mov edx,[edx+0x4]
sar edx,cl
mov ecx,[rbp-0x38]
mov ebx,[rbp+56]
mov ebx,[ebx+0x4]
sar ebx,cl
imul edx,ebx
add eax,edx
mov ecx,[rbp-0x38]
mov edx,[rbp+56]
mov edx,[edx+0x8]
sar edx,cl
mov ecx,[rbp-0x38]
mov ebx,[rbp+56]
mov ebx,[ebx+0x8]
sar ebx,cl
imul edx,ebx
add eax,edx
push rax
mov eax,DWORD PTR [DATA_007723]
call rax
pop rcx
mov ecx,[rbp-0x38]
shl eax,cl
mov [rbp-0x34],eax
mov eax,[rbp-0xc]
sar eax,0x4
add eax,[rbp-0xc]
cmp eax,[rbp-0x34]
jnc JUMP_007967
inc DWORD PTR [DATA_007837]
mov eax,[rbp-0xc]
sar eax,0x3
add eax,[rbp-0xc]
cmp eax,[rbp-0x34]
jnc JUMP_007967
inc DWORD PTR [DATA_007837]
jmp JUMP_007967
JUMP_007966:
mov eax,[DATA_008812]
dec eax
mov [DATA_007837],eax
JUMP_007967:
mov eax,[rbp-0x8]
push rax
call FUNC_001656
pop rcx
add eax,[DATA_007837]
mov [DATA_009269],eax
xor ebx,ebx
lea edi,[rbp-0x818]
mov esi,OFFSET FLAT:DATA_007892
JUMP_007968:
mov eax,[rbp+64]
mov eax,[eax]
push rax
mov eax,[esi]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[rbp+64]
mov eax,[eax+0xc]
push rax
mov eax,[esi+0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
push rdx
mov eax,[rbp+64]
mov eax,[eax+0x18]
push rax
mov eax,[esi+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [edi],edx
mov eax,[rbp+64]
mov eax,[eax+0x4]
push rax
mov eax,[esi]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[rbp+64]
mov eax,[eax+0x10]
push rax
mov eax,[esi+0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
push rdx
mov eax,[rbp+64]
mov eax,[eax+0x1c]
push rax
mov eax,[esi+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [edi+0x4],edx
mov eax,[rbp+64]
mov eax,[eax+0x8]
push rax
mov eax,[esi]
push rax
call FUNC_001521
add rsp,16
push rax
mov eax,[rbp+64]
mov eax,[eax+0x14]
push rax
mov eax,[esi+0x4]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
push rdx
mov eax,[rbp+64]
mov eax,[eax+0x20]
push rax
mov eax,[esi+0x8]
push rax
call FUNC_001521
add rsp,16
pop rdx
add edx,eax
mov [edi+0x8],edx
mov eax,[edi]
mov [edi+0x24],eax
mov eax,[edi+0x4]
mov [edi+0x28],eax
mov eax,[edi+0x8]
mov [edi+0x2c],eax
mov eax,[rbp+56]
mov eax,[eax]
add [edi],eax
mov eax,[rbp+56]
mov eax,[eax+0x4]
add [edi+0x4],eax
mov eax,[rbp+56]
mov eax,[eax+0x8]
add [edi+0x8],eax
cmp DWORD PTR [rbp+104],+0x1
jz JUMP_007969
mov eax,ebx
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x818]
add eax,edx
push rax
mov eax,ebx
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
push rax
call FUNC_001479
add rsp,16
JUMP_007969:
mov eax,[rbp-0x4]
push rax
call FUNC_001824
pop rcx
mov [rbp-0x4],eax
mov eax,[rbp+72]
add eax,eax
lea eax,[eax+eax*2]
mov eax,[eax*8+DATA_007843]
cmp eax,OFFSET FLAT:FUNC_001842
jz JUMP_007970
mov eax,[rbp-0x4]
sar eax,0x4
mov [edi+0x38],eax
jmp JUMP_007971
JUMP_007970:
mov eax,[esi+0x4]
sar eax,0x5
add eax,0x4000000
mov [edi+0x38],eax
JUMP_007971:
inc ebx
add edi,+0x48
add esi,+0xc
cmp ebx,+0xc
jl JUMP_007968
mov eax,[rbp+48]
push rax
lea eax,[rbp-0x14]
push rax
call FUNC_001823
add rsp,16
mov [rbp+48],eax
mov eax,[rbp+56]
mov eax,[eax+0x8]
mov edx,[rbp-0xc]
add edx,edx
cmp eax,edx
jng JUMP_007972
mov DWORD PTR [rbp-0x18],0x1
jmp JUMP_007973
JUMP_007972:
xor eax,eax
mov [rbp-0x18],eax
JUMP_007973:
push OFFSET FLAT:DATA_009271
call _SetJmp
pop rcx
mov [rbp-0x20],eax
test eax,eax
jz JUMP_007974
call FUNC_001817
mov eax,[rbp+48]
jmp JUMP_008044
JUMP_007974:
call FUNC_001816
xor ebx,ebx
lea esi,[rbp-0x90c]
lea edi,[rbp-0x984]
JUMP_007975:
call FUNC_001820
mov [edi],eax
mov eax,[esi]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
mov edx,[edi]
mov [edx],eax
inc ebx
add esi,+0x8
add edi,+0x4
cmp ebx,+0x1e
jl JUMP_007975
mov eax,[rbp+104]
push rax
mov eax,[rbp+72]
push rax
mov eax,[rbp-0x8]
push rax
mov eax,[rbp+40]
push rax
call FUNC_001833
add rsp,32
mov [rbp-0x1c],eax
cmp DWORD PTR [rbp+104],+0x1
jnz JUMP_008038
xor ebx,ebx
JUMP_007976:
mov eax,[rbp-0x14]
mov eax,[eax+ebx*4+0x8]
mov [rbp-0x60],eax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x60]
push rax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x274]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
push rax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x278]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
push rax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x27c]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
push rax
call FUNC_001834
add rsp,48
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x27c]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x818]
mov edx,[rbp+56]
mov edx,[edx]
neg edx
add eax,edx
mov [rbp-0x990],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x27c]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x814]
mov edx,[rbp+56]
mov edx,[edx+0x4]
neg edx
add eax,edx
mov [rbp-0x98c],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x27c]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x810]
mov edx,[rbp+56]
mov edx,[edx+0x8]
neg edx
add eax,edx
mov [rbp-0x988],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x278]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x818]
mov edx,[rbp+56]
mov edx,[edx]
neg edx
add eax,edx
mov [rbp-0x99c],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x278]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x814]
mov edx,[rbp+56]
mov edx,[edx+0x4]
neg edx
add eax,edx
mov [rbp-0x998],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x278]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x810]
mov edx,[rbp+56]
mov edx,[edx+0x8]
neg edx
add eax,edx
mov [rbp-0x994],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x274]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x818]
mov edx,[rbp+56]
mov edx,[edx]
neg edx
add eax,edx
mov [rbp-0x9a8],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x274]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x814]
mov edx,[rbp+56]
mov edx,[edx+0x4]
neg edx
add eax,edx
mov [rbp-0x9a4],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x274]
lea eax,[eax+eax*8]
mov eax,[rbp+rax*8-0x810]
mov edx,[rbp+56]
mov edx,[edx+0x8]
neg edx
add eax,edx
mov [rbp-0x9a0],eax
lea eax,[rbp-0x99c]
push rax
lea eax,[rbp-0x990]
push rax
call FUNC_001875
add rsp,16
mov [rbp-0x3c],eax
lea eax,[rbp-0x9a8]
push rax
lea eax,[rbp-0x99c]
push rax
call FUNC_001875
add rsp,16
mov [rbp-0x40],eax
lea eax,[rbp-0x990]
push rax
lea eax,[rbp-0x9a8]
push rax
call FUNC_001875
add rsp,16
mov [rbp-0x44],eax
cmp DWORD PTR [rbp-0x3c],+0x0
jl JUMP_008037
cmp DWORD PTR [rbp-0x40],+0x0
jl JUMP_008037
cmp DWORD PTR [rbp-0x44],+0x0
jl JUMP_008037
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x27c]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
mov [rbp-0x48],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x278]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
mov [rbp-0x4c],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x274]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
mov [rbp-0x50],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x270]
mov eax,[rbp+rax*4-0x984]
mov [rbp-0x54],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x26c]
mov eax,[rbp+rax*4-0x984]
mov [rbp-0x58],eax
lea eax,[ebx+ebx*2]
mov eax,[rbp+rax*8-0x268]
mov eax,[rbp+rax*4-0x984]
mov [rbp-0x5c],eax
xor eax,eax
mov [rbp-0x10],eax
jmp JUMP_008001
JUMP_007977:
cmp DWORD PTR [rbp-0x60],+0x0
jz JUMP_007982
xor ebx,ebx
mov eax,[rbp-0x50]
add eax,+0x34
mov [rbp-0x9c],eax
mov eax,[rbp-0x4c]
add eax,+0x34
mov [rbp-0x98],eax
mov eax,[rbp-0x48]
add eax,+0x34
mov [rbp-0x94],eax
mov DWORD PTR [rbp-0x90],OFFSET FLAT:DATA_009260
mov eax,[rbp-0x60]
mov [rbp-0x8c],eax
JUMP_007978:
mov eax,[rbp-0x8c]
cmp DWORD PTR [eax],+0x0
jng JUMP_007981
mov eax,[rbp-0x8c]
mov eax,[eax]
mov [rbp-0x68],eax
mov eax,[rbp-0x68]
mov ecx,[eax]
shl ecx,0x2
lea ecx,[ecx+ecx*2]
add ecx,OFFSET FLAT:DATA_007841
mov eax,[ecx+0x8]
add eax,[rbp-0x10]
dec eax
mov edx,[rbp-0x90]
lea edx,[edx+eax*8]
cmp eax,[rbp-0x10]
jl JUMP_007980
JUMP_007979:
mov esi,[ecx]
mov [edx],esi
mov esi,[ecx+0x4]
mov [edx+0x4],esi
dec eax
add edx,-0x8
cmp eax,[rbp-0x10]
jnl JUMP_007979
JUMP_007980:
mov eax,[rbp-0x68]
mov eax,[eax+0x4]
mov edx,[rbp-0x94]
mov [edx],eax
mov eax,[rbp-0x68]
mov eax,[eax+0x8]
mov edx,[rbp-0x98]
mov [edx],eax
mov eax,[rbp-0x68]
mov eax,[eax+0xc]
mov edx,[rbp-0x9c]
mov [edx],eax
JUMP_007981:
inc ebx
add DWORD PTR [rbp-0x9c],+0x4
add DWORD PTR [rbp-0x98],+0x4
add DWORD PTR [rbp-0x94],+0x4
add DWORD PTR [rbp-0x90],0x100
add DWORD PTR [rbp-0x8c],+0x4
cmp ebx,+0x2
jl JUMP_007978
JUMP_007982:
cmp DWORD PTR [rbp-0x10],+0x5
jnl JUMP_007983
mov eax,[rbp-0x10]
push rax
mov eax,[rbp-0x48]
push rax
mov eax,[rbp-0x50]
push rax
mov eax,[rbp-0x4c]
push rax
mov eax,[rbp-0x58]
push rax
mov eax,DWORD PTR [DATA_009278]
call rax
add rsp,40
mov eax,[rbp-0x10]
push rax
mov eax,[rbp-0x4c]
push rax
mov eax,[rbp-0x48]
push rax
mov eax,[rbp-0x50]
push rax
mov eax,[rbp-0x5c]
push rax
mov eax,DWORD PTR [DATA_009278]
call rax
add rsp,40
mov eax,[rbp-0x10]
push rax
mov eax,[rbp-0x50]
push rax
mov eax,[rbp-0x4c]
push rax
mov eax,[rbp-0x48]
push rax
mov eax,[rbp-0x54]
push rax
mov eax,DWORD PTR [DATA_009278]
call rax
add rsp,40
jmp JUMP_007984
JUMP_007983:
mov eax,[rbp-0x10]
push rax
mov eax,[rbp-0x48]
push rax
mov eax,[rbp-0x50]
push rax
mov eax,[rbp-0x4c]
push rax
mov eax,[rbp-0x58]
push rax
mov eax,DWORD PTR [DATA_009279]
call rax
add rsp,40
mov eax,[rbp-0x10]
push rax
mov eax,[rbp-0x4c]
push rax
mov eax,[rbp-0x48]
push rax
mov eax,[rbp-0x50]
push rax
mov eax,[rbp-0x5c]
push rax
mov eax,DWORD PTR [DATA_009279]
call rax
add rsp,40
mov eax,[rbp-0x10]
push rax
mov eax,[rbp-0x50]
push rax
mov eax,[rbp-0x4c]
push rax
mov eax,[rbp-0x48]
push rax
mov eax,[rbp-0x54]
push rax
mov eax,DWORD PTR [DATA_009279]
call rax
add rsp,40
JUMP_007984:
mov eax,[rbp-0x58]
mov eax,[eax+0x8]
mov ecx,[eax+0x4]
mov edx,[rbp+56]
mov edx,[edx]
neg edx
add ecx,edx
mov [rbp-0x990],ecx
mov ebx,[eax+0x8]
mov ecx,[rbp+56]
mov ecx,[ecx+0x4]
neg ecx
add ebx,ecx
mov [rbp-0x98c],ebx
mov eax,[eax+0xc]
mov ebx,[rbp+56]
mov ebx,[ebx+0x8]
neg ebx
add eax,ebx
mov [rbp-0x988],eax
mov eax,[rbp-0x5c]
mov eax,[eax+0x8]
mov ebx,[eax+0x4]
mov esi,[rbp+56]
mov esi,[esi]
neg esi
add ebx,edx
mov [rbp-0x99c],ebx
mov ebx,[eax+0x8]
mov esi,[rbp+56]
mov esi,[esi+0x4]
neg esi
add ebx,ecx
mov [rbp-0x998],ebx
mov eax,[eax+0xc]
mov ebx,[rbp+56]
mov ebx,[ebx+0x8]
neg ebx
add eax,ebx
mov [rbp-0x994],eax
mov eax,[rbp-0x54]
mov eax,[eax+0x8]
mov eax,[eax+0x4]
mov ebx,[rbp+56]
mov ebx,[ebx]
neg ebx
add eax,edx
mov [rbp-0x9a8],eax
mov eax,[rbp-0x54]
mov eax,[eax+0x8]
mov eax,[eax+0x8]
mov edx,[rbp+56]
mov edx,[edx+0x4]
neg edx
add eax,ecx
mov [rbp-0x9a4],eax
mov eax,[rbp-0x54]
mov eax,[eax+0x8]
mov eax,[eax+0xc]
mov edx,[rbp+56]
mov edx,[edx+0x8]
neg edx
add eax,edx
mov [rbp-0x9a0],eax
lea eax,[rbp-0x99c]
push rax
lea eax,[rbp-0x9a8]
push rax
call FUNC_001875
add rsp,16
test eax,eax
jl JUMP_007989
mov eax,[rbp-0x54]
mov eax,[eax]
cmp eax,[rbp-0x48]
jnz JUMP_007985
mov eax,[rbp-0x54]
mov esi,[eax+0x4]
jmp JUMP_007986
JUMP_007985:
mov eax,[rbp-0x54]
mov esi,[eax+0xc]
JUMP_007986:
call FUNC_001820
mov ebx,eax
mov eax,[rbp-0x54]
mov eax,[eax+0x8]
mov [ebx],eax
mov eax,[rbp-0x5c]
mov eax,[eax]
cmp eax,[rbp-0x48]
jnz JUMP_007987
mov eax,[rbp-0x5c]
mov eax,[eax+0x4]
jmp JUMP_007988
JUMP_007987:
mov eax,[rbp-0x5c]
mov eax,[eax+0xc]
JUMP_007988:
mov edx,[rbp-0x48]
mov [rbp-0x48],edx
mov edx,[rbp-0x54]
mov edx,[edx+0x8]
mov [rbp-0x4c],edx
mov edx,[rbp-0x5c]
mov edx,[edx+0x8]
mov [rbp-0x50],edx
cmp DWORD PTR [rbp-0x60],+0x0
jz JUMP_008000
mov edx,[rbp-0x60]
mov edx,[edx+0x8]
mov [rbp-0x60],edx
jmp JUMP_008000
JUMP_007989:
lea eax,[rbp-0x9a8]
push rax
lea eax,[rbp-0x990]
push rax
call FUNC_001875
add rsp,16
test eax,eax
jl JUMP_007994
mov eax,[rbp-0x58]
mov eax,[eax]
cmp eax,[rbp-0x4c]
jnz JUMP_007990
mov eax,[rbp-0x58]
mov esi,[eax+0x4]
jmp JUMP_007991
JUMP_007990:
mov eax,[rbp-0x58]
mov esi,[eax+0xc]
JUMP_007991:
call FUNC_001820
mov ebx,eax
mov eax,[rbp-0x58]
mov eax,[eax+0x8]
mov [ebx],eax
mov eax,[rbp-0x54]
mov eax,[eax]
cmp eax,[rbp-0x4c]
jnz JUMP_007992
mov eax,[rbp-0x54]
mov eax,[eax+0x4]
jmp JUMP_007993
JUMP_007992:
mov eax,[rbp-0x54]
mov eax,[eax+0xc]
JUMP_007993:
mov edx,[rbp-0x4c]
mov [rbp-0x48],edx
mov edx,[rbp-0x58]
mov edx,[edx+0x8]
mov [rbp-0x4c],edx
mov edx,[rbp-0x54]
mov edx,[edx+0x8]
mov [rbp-0x50],edx
cmp DWORD PTR [rbp-0x60],+0x0
jz JUMP_008000
mov edx,[rbp-0x60]
mov edx,[edx+0xc]
mov [rbp-0x60],edx
jmp JUMP_008000
JUMP_007994:
lea eax,[rbp-0x990]
push rax
lea eax,[rbp-0x99c]
push rax
call FUNC_001875
add rsp,16
test eax,eax
jl JUMP_007999
mov eax,[rbp-0x5c]
mov eax,[eax]
cmp eax,[rbp-0x50]
jnz JUMP_007995
mov eax,[rbp-0x5c]
mov esi,[eax+0x4]
jmp JUMP_007996
JUMP_007995:
mov eax,[rbp-0x5c]
mov esi,[eax+0xc]
JUMP_007996:
call FUNC_001820
mov ebx,eax
mov eax,[rbp-0x5c]
mov eax,[eax+0x8]
mov [ebx],eax
mov eax,[rbp-0x58]
mov eax,[eax]
cmp eax,[rbp-0x50]
jnz JUMP_007997
mov eax,[rbp-0x58]
mov eax,[eax+0x4]
jmp JUMP_007998
JUMP_007997:
mov eax,[rbp-0x58]
mov eax,[eax+0xc]
JUMP_007998:
mov edx,[rbp-0x50]
mov [rbp-0x48],edx
mov edx,[rbp-0x5c]
mov edx,[edx+0x8]
mov [rbp-0x4c],edx
mov edx,[rbp-0x58]
mov edx,[edx+0x8]
mov [rbp-0x50],edx
cmp DWORD PTR [rbp-0x60],+0x0
jz JUMP_008000
mov edx,[rbp-0x60]
mov edx,[edx+0x10]
mov [rbp-0x60],edx
jmp JUMP_008000
JUMP_007999:
call FUNC_001820
mov esi,eax
mov eax,[rbp-0x5c]
mov eax,[eax+0x8]
mov [esi],eax
call FUNC_001820
mov ebx,eax
mov eax,[rbp-0x54]
mov eax,[eax+0x8]
mov [ebx],eax
call FUNC_001820
mov edx,[rbp-0x58]
mov edx,[edx+0x8]
mov [eax],edx
mov edx,[rbp-0x58]
mov edx,[edx+0x8]
mov [rbp-0x48],edx
mov edx,[rbp-0x5c]
mov edx,[edx+0x8]
mov [rbp-0x4c],edx
mov edx,[rbp-0x54]
mov edx,[edx+0x8]
mov [rbp-0x50],edx
cmp DWORD PTR [rbp-0x60],+0x0
jz JUMP_008000
mov edx,[rbp-0x60]
mov edx,[edx+0x14]
mov [rbp-0x60],edx
JUMP_008000:
mov [rbp-0x54],esi
mov [rbp-0x58],ebx
mov [rbp-0x5c],eax
inc DWORD PTR [rbp-0x10]
JUMP_008001:
cmp DWORD PTR [rbp-0x10],+0x9
jg JUMP_008002
mov eax,[rbp-0x48]
mov eax,[eax+0x44]
cmp eax,[rbp-0x10]
jnl JUMP_007977
mov eax,[rbp-0x4c]
mov eax,[eax+0x44]
cmp eax,[rbp-0x10]
jnl JUMP_007977
mov eax,[rbp-0x50]
mov eax,[eax+0x44]
cmp eax,[rbp-0x10]
jnl JUMP_007977
JUMP_008002:
mov eax,[rbp-0x48]
cmp DWORD PTR [eax+0x4],+0x0
jnl JUMP_008003
mov eax,[rbp-0x48]
mov eax,[eax+0x4]
neg eax
jmp JUMP_008004
JUMP_008003:
mov eax,[rbp-0x48]
mov eax,[eax+0x4]
JUMP_008004:
mov edx,[rbp-0x48]
cmp DWORD PTR [edx+0x8],+0x0
jnl JUMP_008005
mov edx,[rbp-0x48]
mov edx,[edx+0x8]
neg edx
jmp JUMP_008006
JUMP_008005:
mov edx,[rbp-0x48]
mov edx,[edx+0x8]
JUMP_008006:
or eax,edx
mov edx,[rbp-0x48]
cmp DWORD PTR [edx+0xc],+0x0
jnl JUMP_008007
mov edx,[rbp-0x48]
mov edx,[edx+0xc]
neg edx
jmp JUMP_008008
JUMP_008007:
mov edx,[rbp-0x48]
mov edx,[edx+0xc]
JUMP_008008:
or eax,edx
mov edx,[rbp-0x4c]
cmp DWORD PTR [edx+0x4],+0x0
jnl JUMP_008009
mov edx,[rbp-0x4c]
mov edx,[edx+0x4]
neg edx
jmp JUMP_008010
JUMP_008009:
mov edx,[rbp-0x4c]
mov edx,[edx+0x4]
JUMP_008010:
or eax,edx
mov edx,[rbp-0x4c]
cmp DWORD PTR [edx+0x8],+0x0
jnl JUMP_008011
mov edx,[rbp-0x4c]
mov edx,[edx+0x8]
neg edx
jmp JUMP_008012
JUMP_008011:
mov edx,[rbp-0x4c]
mov edx,[edx+0x8]
JUMP_008012:
or eax,edx
mov edx,[rbp-0x4c]
cmp DWORD PTR [edx+0xc],+0x0
jnl JUMP_008013
mov edx,[rbp-0x4c]
mov edx,[edx+0xc]
neg edx
jmp JUMP_008014
JUMP_008013:
mov edx,[rbp-0x4c]
mov edx,[edx+0xc]
JUMP_008014:
or eax,edx
mov edx,[rbp-0x50]
cmp DWORD PTR [edx+0x4],+0x0
jnl JUMP_008015
mov edx,[rbp-0x50]
mov edx,[edx+0x4]
neg edx
jmp JUMP_008016
JUMP_008015:
mov edx,[rbp-0x50]
mov edx,[edx+0x4]
JUMP_008016:
or eax,edx
mov edx,[rbp-0x50]
cmp DWORD PTR [edx+0x8],+0x0
jnl JUMP_008017
mov edx,[rbp-0x50]
mov edx,[edx+0x8]
neg edx
jmp JUMP_008018
JUMP_008017:
mov edx,[rbp-0x50]
mov edx,[edx+0x8]
JUMP_008018:
or eax,edx
mov edx,[rbp-0x50]
cmp DWORD PTR [edx+0xc],+0x0
jnl JUMP_008019
mov edx,[rbp-0x50]
mov edx,[edx+0xc]
neg edx
jmp JUMP_008020
JUMP_008019:
mov edx,[rbp-0x50]
mov edx,[edx+0xc]
JUMP_008020:
or eax,edx
push rax
call FUNC_001656
pop rcx
add eax,-0xd
mov [rbp-0x6c],eax
cmp DWORD PTR [rbp-0x6c],+0x0
jng JUMP_008021
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x48]
mov eax,[eax+0x4]
sar eax,cl
mov [rbp-0x990],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x48]
mov eax,[eax+0x8]
sar eax,cl
mov [rbp-0x98c],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x48]
mov eax,[eax+0xc]
sar eax,cl
mov [rbp-0x988],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x4c]
mov eax,[eax+0x4]
sar eax,cl
mov [rbp-0x99c],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x4c]
mov eax,[eax+0x8]
sar eax,cl
mov [rbp-0x998],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x4c]
mov eax,[eax+0xc]
sar eax,cl
mov [rbp-0x994],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x50]
mov eax,[eax+0x4]
sar eax,cl
mov [rbp-0x9a8],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x50]
mov eax,[eax+0x8]
sar eax,cl
mov [rbp-0x9a4],eax
mov ecx,[rbp-0x6c]
mov eax,[rbp-0x50]
mov eax,[eax+0xc]
sar eax,cl
mov [rbp-0x9a0],eax
jmp JUMP_008022
JUMP_008021:
mov eax,[rbp-0x48]
mov edx,[eax+0x4]
mov [rbp-0x990],edx
mov edx,[eax+0x8]
mov [rbp-0x98c],edx
mov edx,[eax+0xc]
mov [rbp-0x988],edx
mov eax,[rbp-0x4c]
mov edx,[eax+0x4]
mov [rbp-0x99c],edx
mov edx,[eax+0x8]
mov [rbp-0x998],edx
mov edx,[eax+0xc]
mov [rbp-0x994],edx
mov eax,[rbp-0x50]
mov edx,[eax+0x4]
mov [rbp-0x9a8],edx
mov edx,[eax+0x8]
mov [rbp-0x9a4],edx
mov edx,[eax+0xc]
mov [rbp-0x9a0],edx
xor eax,eax
mov [rbp-0x6c],eax
JUMP_008022:
mov eax,[rbp-0x990]
sub eax,[rbp-0x9a8]
imul DWORD PTR [rbp-0x998]
mov edx,[rbp-0x99c]
sub edx,[rbp-0x990]
imul edx,[rbp-0x9a4]
add eax,edx
mov edx,[rbp-0x9a8]
sub edx,[rbp-0x99c]
imul edx,[rbp-0x98c]
add eax,edx
mov [rbp-0x70],eax
mov eax,[rbp-0x990]
sub eax,[rbp-0x99c]
imul DWORD PTR [rbp-0x9a4]
mov edx,[rbp-0x9a8]
sub edx,[rbp-0x990]
imul edx,[rbp-0x998]
add eax,edx
mov edx,[rbp-0x99c]
sub edx,[rbp-0x9a8]
imul edx,[rbp-0x98c]
add eax,edx
mov [rbp-0x74],eax
mov eax,[rbp-0x990]
imul DWORD PTR [rbp-0x998]
mov edx,[rbp-0x99c]
imul edx,[rbp-0x98c]
sub eax,edx
mov [rbp-0x78],eax
mov eax,[rbp-0x990]
imul DWORD PTR [rbp-0x9a4]
mov edx,[rbp-0x9a8]
imul edx,[rbp-0x98c]
sub eax,edx
mov [rbp-0x7c],eax
cmp DWORD PTR [rbp-0x7c],+0x0
jnl JUMP_008023
mov eax,[rbp-0x7c]
neg eax
jmp JUMP_008024
JUMP_008023:
mov eax,[rbp-0x7c]
JUMP_008024:
push rax
call FUNC_001656
pop rcx
mov ebx,0x1e
sub ebx,eax
test ebx,ebx
jnl JUMP_008025
xor ebx,ebx
JUMP_008025:
cmp ebx,+0xf
jng JUMP_008026
mov ebx,0xf
JUMP_008026:
cmp ebx,+0xf
jnl JUMP_008027
mov ecx,0xf
sub ecx,ebx
sar DWORD PTR [rbp-0x74],cl
cmp DWORD PTR [rbp-0x74],+0x0
jnz JUMP_008027
mov DWORD PTR [rbp-0x74],0x1
JUMP_008027:
mov ecx,ebx
mov eax,[rbp-0x7c]
shl eax,cl
cdq
idiv DWORD PTR [rbp-0x74]
mov [rbp-0x80],eax
cmp DWORD PTR [rbp-0x78],+0x0
jnl JUMP_008028
mov eax,[rbp-0x78]
neg eax
jmp JUMP_008029
JUMP_008028:
mov eax,[rbp-0x78]
JUMP_008029:
push rax
call FUNC_001656
pop rcx
mov ebx,0x1e
sub ebx,eax
test ebx,ebx
jnl JUMP_008030
xor ebx,ebx
JUMP_008030:
cmp ebx,+0xf
jng JUMP_008031
mov ebx,0xf
JUMP_008031:
cmp ebx,+0xf
jnl JUMP_008032
mov ecx,0xf
sub ecx,ebx
sar DWORD PTR [rbp-0x70],cl
cmp DWORD PTR [rbp-0x70],+0x0
jnz JUMP_008032
mov DWORD PTR [rbp-0x70],0x1
JUMP_008032:
mov ecx,ebx
mov eax,[rbp-0x78]
shl eax,cl
cdq
idiv DWORD PTR [rbp-0x70]
mov [rbp-0x84],eax
cmp DWORD PTR [rbp-0x6c],+0xf
jnl JUMP_008033
mov ecx,0xf
sub ecx,[rbp-0x6c]
mov eax,[rbp-0x994]
sub eax,[rbp-0x988]
imul DWORD PTR [rbp-0x80]
mov edx,[rbp-0x9a0]
sub edx,[rbp-0x988]
imul edx,[rbp-0x84]
add eax,edx
sar eax,cl
mov edx,[rbp-0x48]
add eax,[edx+0xc]
mov [rbp-0x88],eax
jmp JUMP_008034
JUMP_008033:
mov ecx,[rbp-0x6c]
add ecx,-0xf
mov eax,[rbp-0x994]
sub eax,[rbp-0x988]
imul DWORD PTR [rbp-0x80]
mov edx,[rbp-0x9a0]
sub edx,[rbp-0x988]
imul edx,[rbp-0x84]
add eax,edx
shl eax,cl
mov edx,[rbp-0x48]
add eax,[edx+0xc]
mov [rbp-0x88],eax
JUMP_008034:
mov eax,[rbp-0x88]
mov [DATA_009283],eax
xor eax,eax
mov [DATA_009284],eax
xor ebx,ebx
mov DWORD PTR [rbp-0x9c],OFFSET FLAT:DATA_009260
JUMP_008035:
xor eax,eax
mov edx,[rbp-0x9c]
JUMP_008036:
xor ecx,ecx
mov [edx],ecx
xor ecx,ecx
mov [edx+0x4],ecx
inc eax
add edx,+0x8
cmp eax,+0x20
jl JUMP_008036
inc ebx
add DWORD PTR [rbp-0x9c],0x100
cmp ebx,+0x2
jl JUMP_008035
jmp JUMP_008040
JUMP_008037:
inc ebx
cmp ebx,+0x14
jl JUMP_007976
jmp JUMP_008040
JUMP_008038:
xor ebx,ebx
lea esi,[rbp-0x27c]
JUMP_008039:
mov eax,[rbp+104]
push rax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
mov eax,[eax+ebx*4+0x8]
push rax
mov eax,[rbp-0x8]
push rax
mov eax,[esi+0x14]
mov eax,[rbp+rax*4-0x984]
push rax
mov eax,[esi+0x10]
mov eax,[rbp+rax*4-0x984]
push rax
mov eax,[esi+0xc]
mov eax,[rbp+rax*4-0x984]
push rax
mov eax,[esi+0x8]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
push rax
mov eax,[esi+0x4]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
push rax
mov eax,[esi]
shl eax,0x3
lea eax,[eax+eax*8]
lea edx,[rbp-0x81c]
add eax,edx
push rax
call FUNC_001835
add rsp,88
inc ebx
add esi,+0x18
cmp ebx,+0x14
jl JUMP_008039
JUMP_008040:
call FUNC_001817
cmp DWORD PTR [rbp+104],+0x0
jz JUMP_008043
cmp DWORD PTR [DATA_009283],0x7fffffff
jz JUMP_008041
mov eax,[DATA_009283]
cmp eax,[rbp+24]
jng JUMP_008042
JUMP_008041:
mov eax,[rbp+16]
mov edx,[rbp+24]
mov [eax],edx
jmp JUMP_008043
JUMP_008042:
mov eax,[rbp+16]
mov edx,[DATA_009283]
mov [eax],edx
JUMP_008043:
mov eax,[rbp+48]
JUMP_008044:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
.section .data
DATA_007835:
.byte 0x0, 0x2, 0x2, 0x3, 0x4, 0x6, 0x7, 0x8
.byte 0x9
DATA_007836:
.byte 0x2, 0x3, 0x5, 0x5, 0x6, 0x7, 0x8, 0x9
.byte 0xa, 0x0, 0x0
DATA_007837:
.byte 0x1, 0x0, 0x0, 0x0
DATA_007838:
.byte 0x0, 0x0, 0x0, 0x0, 0xff, 0xff, 0xff, 0xff
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0xff, 0xff, 0xff, 0xff, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
DATA_007839:
.byte 0xee, 0xdf, 0x1d, 0x13, 0x39, 0x34, 0xdf, 0x4
.byte 0x7a, 0x4c, 0x39, 0x1, 0x24, 0x6b, 0x4e, 0x0
.byte 0x49, 0x9c, 0x13, 0x0, 0x2a, 0xe7, 0x4, 0x0
.byte 0xcc, 0x39, 0x1, 0x0, 0x73, 0x4e, 0x0, 0x0
.byte 0x9c, 0x13, 0x0, 0x0, 0xe7, 0x4, 0x0, 0x0
.byte 0x39, 0x1, 0x0, 0x0, 0x4e, 0x0, 0x0, 0x0
.byte 0x13, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
DATA_007840:
.byte 0x24, 0x8c, 0x3c, 0x4b, 0xc6, 0x46, 0x88, 0x42
.byte 0x5c, 0x29, 0x9e, 0x40, 0xa6, 0x4d, 0x27, 0x40
.byte 0xa5, 0xcf, 0x9, 0x40, 0xad, 0x73, 0x2, 0x40
.byte 0xe7, 0x9c, 0x0, 0x40, 0x39, 0x27, 0x0, 0x40
.byte 0xce, 0x9, 0x0, 0x40, 0x73, 0x2, 0x0, 0x40
.byte 0x9c, 0x0, 0x0, 0x40, 0x27, 0x0, 0x0, 0x40
.byte 0x9, 0x0, 0x0, 0x40, 0x2, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
.byte 0x0, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0, 0x40
DATA_007841:
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
DATA_007842:
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.long DATA_007638
.byte 0x6, 0x0, 0x0, 0x0
.long DATA_007637
.long DATA_007638
.byte 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.long DATA_007638
.byte 0x6, 0x0, 0x0, 0x0
DATA_007843:
.long FUNC_001840
.long FUNC_001841
.byte 0x9, 0x0, 0x0, 0x0, 0x0, 0x0, 0x5, 0x0
.byte 0x1, 0x2, 0x7, 0x0, 0x6, 0x6, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x6, 0x4, 0x0
.byte 0x8, 0x8, 0x3, 0x0, 0x2, 0x8, 0x3, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x8, 0x8, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x8, 0x0, 0x0, 0x0, 0x0, 0x0, 0x5, 0x0
.byte 0x1, 0x2, 0x7, 0x0, 0x6, 0x6, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x6, 0x4, 0x0
.byte 0x8, 0x8, 0x3, 0x0, 0x2, 0x8, 0x3, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x8, 0x8, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x8, 0x0, 0x0, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x3, 0x3, 0x3, 0x0
.byte 0x5, 0x5, 0x5, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x1, 0x1, 0x1, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x7, 0x7, 0x7, 0x0
.long FUNC_001842
.long FUNC_001843
.byte 0x18, 0x0, 0x0, 0x0, 0x7, 0x2, 0x0, 0x0
.byte 0x7, 0x6, 0x6, 0x0, 0x6, 0x4, 0x4, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x9, 0x0, 0x0, 0x0, 0x2, 0x1, 0x1, 0x0
.byte 0x4, 0x2, 0x2, 0x0, 0x4, 0x4, 0x4, 0x0
.byte 0x0, 0x8, 0x8, 0x0, 0x0, 0x6, 0x4, 0x0
.byte 0x0, 0x8, 0x3, 0x0, 0x8, 0x8, 0x3, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x8, 0x8, 0x8, 0x0
.long FUNC_001842
.long FUNC_001843
.byte 0x18, 0x0, 0x0, 0x0, 0x8, 0x8, 0x6, 0x0
.byte 0x7, 0x7, 0x4, 0x0, 0x8, 0x8, 0x5, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.long FUNC_001842
.long FUNC_001843
.byte 0x18, 0x0, 0x0, 0x0, 0x2, 0x2, 0x4, 0x0
.byte 0x1, 0x1, 0x3, 0x0, 0x2, 0x2, 0x5, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x8, 0x0, 0x0, 0x0, 0x7, 0x4, 0x0, 0x0
.byte 0x6, 0x3, 0x0, 0x0, 0x5, 0x2, 0x0, 0x0
.byte 0x7, 0x3, 0x0, 0x0, 0x4, 0x2, 0x0, 0x0
.byte 0x6, 0x3, 0x0, 0x0, 0x7, 0x4, 0x0, 0x0
.byte 0x5, 0x2, 0x0, 0x0, 0x6, 0x3, 0x0, 0x0
.long FUNC_001844
.long FUNC_001836
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.long FUNC_001845
.long FUNC_001836
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x9, 0x0, 0x0, 0x0, 0x2, 0x6, 0x8, 0x0
.byte 0x5, 0x7, 0x8, 0x0, 0x6, 0x8, 0x8, 0x0
.byte 0x7, 0x8, 0x8, 0x0, 0x4, 0x6, 0x6, 0x0
.byte 0x5, 0x5, 0x8, 0x0, 0x3, 0x7, 0x8, 0x0
.byte 0x0, 0x5, 0x6, 0x0, 0x7, 0x8, 0x8, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x9, 0x0, 0x0, 0x0, 0x6, 0x5, 0x2, 0x0
.byte 0x7, 0x7, 0x3, 0x0, 0x8, 0x8, 0x6, 0x0
.byte 0x8, 0x6, 0x4, 0x0, 0x4, 0x2, 0x0, 0x0
.byte 0x6, 0x3, 0x0, 0x0, 0x7, 0x4, 0x0, 0x0
.byte 0x5, 0x2, 0x0, 0x0, 0x6, 0x3, 0x0, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x9, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x7, 0x2, 0x1, 0x0, 0x8, 0x6, 0x6, 0x0
.byte 0x8, 0x6, 0x7, 0x0, 0x4, 0x2, 0x3, 0x0
.byte 0x6, 0x3, 0x5, 0x0, 0x7, 0x4, 0x6, 0x0
.byte 0x5, 0x2, 0x4, 0x0, 0x6, 0x3, 0x2, 0x0
.long FUNC_001840
.long FUNC_001841
.byte 0x9, 0x0, 0x0, 0x0, 0x0, 0x0, 0x5, 0x0
.byte 0x1, 0x2, 0x7, 0x0, 0x6, 0x6, 0x8, 0x0
.byte 0x7, 0x7, 0x5, 0x0, 0x5, 0x7, 0x4, 0x0
.byte 0x4, 0x8, 0x3, 0x0, 0x4, 0x6, 0x2, 0x0
.byte 0x3, 0x5, 0x4, 0x0, 0x2, 0x4, 0x3, 0x0
DATA_007844:
.long FUNC_001849
.long FUNC_001849
.long FUNC_001849
.long FUNC_001849
DATA_007845:
.long FUNC_001849
.long FUNC_001849
.long FUNC_001849
.long FUNC_001849
.long FUNC_001850
.long FUNC_001851
.long FUNC_001852
.long FUNC_001853
.long FUNC_001854
.long FUNC_001855
.long FUNC_001856
.long FUNC_001857
.long FUNC_001858
.long FUNC_001859
.long FUNC_001860
.long FUNC_001861
.long FUNC_001862
.long FUNC_001863
.long FUNC_001864
.long FUNC_001865
.long FUNC_001866
.long FUNC_001866
.long FUNC_001866
.long FUNC_001866
.long FUNC_001867
.long FUNC_001867
.long FUNC_001867
.long FUNC_001867
DATA_007846:
.byte 0x0, 0x0, 0x5, 0x0, 0x1, 0x1, 0x5, 0x0
.byte 0x2, 0x2, 0x5, 0x0, 0x3, 0x3, 0x6, 0x0
.byte 0x4, 0x4, 0x7, 0x0, 0x5, 0x5, 0x8, 0x0
.byte 0x6, 0x6, 0x8, 0x0, 0x21, 0x1, 0x0, 0x0
.byte 0x0, 0x0, 0x6, 0x0, 0x1, 0x1, 0x6, 0x0
.byte 0x2, 0x2, 0x6, 0x0, 0x3, 0x3, 0x6, 0x0
.byte 0x4, 0x4, 0x7, 0x0, 0x5, 0x5, 0x8, 0x0
.byte 0x6, 0x6, 0x8, 0x0, 0x21, 0x1, 0x0, 0x0
.byte 0x0, 0x1, 0x6, 0x0, 0x1, 0x2, 0x6, 0x0
.byte 0x2, 0x3, 0x6, 0x0, 0x3, 0x4, 0x6, 0x0
.byte 0x4, 0x5, 0x7, 0x0, 0x5, 0x6, 0x8, 0x0
.byte 0x6, 0x7, 0x8, 0x0, 0x21, 0x1, 0x0, 0x0
DATA_007847:
.byte 0x1, 0x2, 0x7, 0x0, 0x2, 0x3, 0x7, 0x0
.byte 0x3, 0x4, 0x7, 0x0, 0x4, 0x5, 0x7, 0x0
.byte 0x5, 0x6, 0x8, 0x0, 0x6, 0x7, 0x8, 0x0
.byte 0x7, 0x8, 0x8, 0x0, 0x21, 0x1, 0x0, 0x0
.byte 0x1, 0x5, 0x1, 0x0, 0x2, 0x6, 0x2, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x0, 0x5, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x2, 0x6, 0x1, 0x0
.byte 0x1, 0x5, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x0, 0x5, 0x0, 0x0, 0x2, 0x6, 0x2, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x0, 0x4, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x2, 0x6, 0x1, 0x0
.byte 0x1, 0x5, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x0, 0x5, 0x0, 0x0, 0x2, 0x6, 0x2, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x0, 0x4, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x2, 0x6, 0x1, 0x0
.byte 0x1, 0x5, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x1, 0x5, 0x1, 0x0
.byte 0x0, 0x5, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0
.byte 0x0, 0x3, 0x0, 0x0, 0x1, 0x5, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x1, 0x5, 0x1, 0x0
.byte 0x0, 0x5, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0
.byte 0x0, 0x3, 0x0, 0x0, 0x1, 0x5, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x0, 0x5, 0x0, 0x0, 0x2, 0x6, 0x2, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x0, 0x4, 0x0, 0x0
.byte 0x0, 0x3, 0x0, 0x0, 0x1, 0x5, 0x0, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x1, 0x5, 0x1, 0x0, 0x3, 0x7, 0x3, 0x0
.byte 0x2, 0x6, 0x2, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x4, 0x6, 0x3, 0x0
.byte 0x3, 0x6, 0x2, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x3, 0x5, 0x3, 0x0, 0x5, 0x7, 0x5, 0x0
.byte 0x4, 0x6, 0x4, 0x0, 0x2, 0x4, 0x2, 0x0
.byte 0x1, 0x3, 0x1, 0x0, 0x4, 0x5, 0x3, 0x0
.byte 0x3, 0x5, 0x2, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x4, 0x5, 0x4, 0x0, 0x6, 0x7, 0x6, 0x0
.byte 0x5, 0x6, 0x5, 0x0, 0x3, 0x4, 0x3, 0x0
.byte 0x2, 0x3, 0x2, 0x0, 0x5, 0x6, 0x4, 0x0
.byte 0x4, 0x5, 0x3, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x6, 0x6, 0x6, 0x0
.byte 0x5, 0x5, 0x5, 0x0, 0x3, 0x3, 0x3, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x5, 0x5, 0x4, 0x0
.byte 0x5, 0x4, 0x4, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x5, 0x5, 0x5, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x1, 0x1, 0x1, 0x0, 0x4, 0x4, 0x3, 0x0
.byte 0x4, 0x3, 0x3, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x4, 0x4, 0x4, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x1, 0x1, 0x1, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x3, 0x2, 0x2, 0x0
.byte 0x2, 0x1, 0x1, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x4, 0x4, 0x4, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x1, 0x1, 0x1, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x3, 0x2, 0x2, 0x0
.byte 0x2, 0x1, 0x1, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x6, 0x6, 0x6, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x5, 0x5, 0x5, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x6, 0x6, 0x6, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x7, 0x7, 0x7, 0x0, 0x5, 0x5, 0x5, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x6, 0x6, 0x6, 0x0
.byte 0x5, 0x5, 0x5, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x7, 0x7, 0x7, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x6, 0x6, 0x6, 0x0
.byte 0x5, 0x5, 0x5, 0x0, 0x7, 0x7, 0x7, 0x0
.byte 0x6, 0x6, 0x6, 0x0, 0x40, 0x0, 0x0, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x7, 0x7, 0x7, 0x0
.byte 0x6, 0x6, 0x6, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x7, 0x7, 0x7, 0x0, 0x40, 0x0, 0x0, 0x0
DATA_007848:
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x6, 0x4, 0x0
.byte 0x8, 0x8, 0x3, 0x0, 0x7, 0x8, 0x3, 0x0
.byte 0x5, 0x8, 0x3, 0x0, 0x4, 0x8, 0x3, 0x0
.byte 0x2, 0x8, 0x3, 0x0, 0x1, 0x7, 0x3, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x1, 0x5, 0x1, 0x0
.byte 0x1, 0x4, 0x1, 0x0, 0x1, 0x3, 0x1, 0x0
.byte 0x1, 0x2, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x1, 0x1, 0x1, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x4, 0x4, 0x4, 0x0
.byte 0x5, 0x5, 0x5, 0x0, 0x6, 0x6, 0x6, 0x0
.byte 0x7, 0x7, 0x7, 0x0, 0x8, 0x8, 0x8, 0x0
DATA_007849:
.byte 0x2, 0x8, 0x3, 0x0, 0x2, 0x8, 0x1, 0x0
.byte 0x2, 0x8, 0x2, 0x0, 0x3, 0x8, 0x3, 0x0
.byte 0x3, 0x8, 0x4, 0x0, 0x7, 0x8, 0x3, 0x0
.byte 0x5, 0x8, 0x3, 0x0, 0x3, 0x8, 0x3, 0x0
.byte 0x7, 0x8, 0x3, 0x0, 0x4, 0x8, 0x2, 0x0
.byte 0x3, 0x8, 0x3, 0x0, 0x4, 0x8, 0x3, 0x0
.byte 0x0, 0x7, 0x2, 0x0, 0x0, 0x6, 0x0, 0x0
.byte 0x3, 0x8, 0x3, 0x0, 0x2, 0x6, 0x0, 0x0
.byte 0x2, 0x7, 0x5, 0x0, 0x4, 0x8, 0x3, 0x0
.byte 0x1, 0x7, 0x4, 0x0, 0x4, 0x8, 0x5, 0x0
.byte 0x3, 0x6, 0x0, 0x0, 0x0, 0x6, 0x3, 0x0
.byte 0x0, 0x6, 0x0, 0x0, 0x5, 0x8, 0x3, 0x0
.byte 0x4, 0x8, 0x3, 0x0, 0x2, 0x5, 0x2, 0x0
.byte 0x2, 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0
.byte 0x4, 0x8, 0x2, 0x0, 0x1, 0x6, 0x1, 0x0
.byte 0x0, 0x6, 0x0, 0x0, 0x1, 0x5, 0x0, 0x0
.byte 0x4, 0x8, 0x4, 0x0, 0x3, 0x5, 0x1, 0x0
.byte 0x2, 0x7, 0x0, 0x0, 0x1, 0x7, 0x3, 0x0
.byte 0x1, 0x7, 0x1, 0x0, 0x1, 0x6, 0x1, 0x0
.byte 0x1, 0x5, 0x1, 0x0, 0x0, 0x5, 0x0, 0x0
.byte 0x2, 0x7, 0x2, 0x0, 0x1, 0x7, 0x3, 0x0
.byte 0x1, 0x7, 0x3, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x1, 0x5, 0x1, 0x0
.byte 0x0, 0x5, 0x0, 0x0, 0x2, 0x7, 0x2, 0x0
.byte 0x1, 0x7, 0x3, 0x0, 0x1, 0x7, 0x3, 0x0
.byte 0x1, 0x4, 0x1, 0x0, 0x1, 0x6, 0x1, 0x0
.byte 0x1, 0x5, 0x1, 0x0, 0x0, 0x5, 0x0, 0x0
.byte 0x2, 0x7, 0x2, 0x0, 0x1, 0x7, 0x3, 0x0
.byte 0x1, 0x5, 0x1, 0x0, 0x0, 0x6, 0x0, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x1, 0x5, 0x1, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x1, 0x5, 0x1, 0x0
.byte 0x1, 0x6, 0x3, 0x0, 0x0, 0x5, 0x0, 0x0
.byte 0x1, 0x6, 0x1, 0x0, 0x1, 0x5, 0x1, 0x0
.byte 0x1, 0x4, 0x1, 0x0, 0x1, 0x3, 0x1, 0x0
.byte 0x0, 0x4, 0x0, 0x0, 0x1, 0x4, 0x2, 0x0
.byte 0x1, 0x3, 0x1, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x1, 0x5, 0x1, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x1, 0x3, 0x1, 0x0, 0x0, 0x3, 0x0, 0x0
.byte 0x0, 0x4, 0x1, 0x0, 0x1, 0x3, 0x1, 0x0
.byte 0x1, 0x4, 0x1, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x1, 0x4, 0x1, 0x0, 0x1, 0x3, 0x1, 0x0
.byte 0x1, 0x3, 0x1, 0x0, 0x0, 0x4, 0x1, 0x0
.byte 0x1, 0x3, 0x1, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x1, 0x2, 0x1, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x1, 0x3, 0x1, 0x0, 0x1, 0x3, 0x1, 0x0
.byte 0x0, 0x4, 0x1, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x3, 0x3, 0x3, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x1, 0x4, 0x1, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x3, 0x3, 0x3, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x1, 0x1, 0x1, 0x0
.byte 0x1, 0x1, 0x1, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x3, 0x3, 0x3, 0x0, 0x1, 0x1, 0x1, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x1, 0x1, 0x1, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x5, 0x5, 0x5, 0x0
.byte 0x6, 0x6, 0x6, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x6, 0x6, 0x6, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x2, 0x2, 0x2, 0x0, 0x2, 0x2, 0x2, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x4, 0x4, 0x4, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x6, 0x6, 0x6, 0x0
.byte 0x4, 0x4, 0x4, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x7, 0x7, 0x7, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0
.byte 0x7, 0x7, 0x7, 0x0
DATA_007850:
.byte 0x3, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x3, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xd, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xd, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
DATA_007851:
.byte 0x6, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xd, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
DATA_007852:
.byte 0x8, 0x5, 0x4, 0x0, 0x8, 0x6, 0x5, 0x0
.byte 0x8, 0x7, 0x6, 0x0, 0x8, 0x8, 0x7, 0x0
.byte 0x8, 0x8, 0x8, 0x0, 0x8, 0x6, 0x5, 0x0
.byte 0x8, 0x4, 0x3, 0x0, 0x8, 0x2, 0x0, 0x0
.byte 0x8, 0x2, 0x1, 0x0, 0x8, 0x3, 0x2, 0x0
.byte 0x8, 0x4, 0x3, 0x0, 0x8, 0x2, 0x0, 0x0
.byte 0x8, 0x2, 0x1, 0x0, 0x8, 0x3, 0x2, 0x0
.byte 0x8, 0x4, 0x3, 0x0, 0x8, 0x2, 0x0, 0x0
.byte 0x8, 0x2, 0x0, 0x0, 0x8, 0x2, 0x1, 0x0
.byte 0x8, 0x3, 0x2, 0x0, 0x8, 0x4, 0x3, 0x0
.byte 0x8, 0x2, 0x0, 0x0, 0x7, 0x2, 0x0, 0x0
.byte 0x6, 0x2, 0x0, 0x0, 0x5, 0x2, 0x0, 0x0
.byte 0x4, 0x2, 0x0, 0x0, 0x3, 0x1, 0x0, 0x0
.byte 0x2, 0x1, 0x1, 0x0, 0x1, 0x1, 0x1, 0x0
.byte 0x3, 0x1, 0x0, 0x0, 0x5, 0x1, 0x0, 0x0
.byte 0x7, 0x2, 0x0, 0x0, 0x8, 0x2, 0x0, 0x0
DATA_007853:
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0xd, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
DATA_007854:
.byte 0x1, 0x0
DATA_007855:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007856:
.byte 0x1, 0x0
DATA_007857:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007858:
.byte 0x1, 0x0
DATA_007859:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007860:
.byte 0x1, 0x0
DATA_007861:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007862:
.byte 0x1, 0x0
DATA_007863:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007864:
.byte 0x1, 0x0
DATA_007865:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007866:
.byte 0x1, 0x0
DATA_007867:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007868:
.byte 0x1, 0x0
DATA_007869:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007870:
.byte 0x1, 0x0
DATA_007871:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007872:
.byte 0x1, 0x0
DATA_007873:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007874:
.byte 0x1, 0x0
DATA_007875:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007876:
.byte 0x1, 0x0
DATA_007877:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007878:
.byte 0x1, 0x0
DATA_007879:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007880:
.byte 0x1, 0x0
DATA_007881:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007882:
.byte 0x1, 0x0
DATA_007883:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007884:
.byte 0x1, 0x0
DATA_007885:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007886:
.byte 0x1, 0x0
DATA_007887:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007888:
.byte 0x1, 0x0
DATA_007889:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007890:
.byte 0x1, 0x0
DATA_007891:
.byte 0xff, 0xff, 0xff, 0xff, 0x1, 0x0, 0x1, 0x0
.byte 0x1, 0x0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
.byte 0xff, 0xff, 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
.byte 0x1, 0x0, 0x1, 0x0, 0xff, 0xff
DATA_007892:
.byte 0x0, 0x0, 0x0, 0x0, 0xff, 0xff, 0xff, 0x7f
.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x80, 0x0, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x8a, 0x46, 0x3e, 0x39
.byte 0x14, 0x97, 0x7c, 0x72, 0x35, 0x28, 0x4b, 0x43
.byte 0x76, 0xb9, 0xc1, 0xc6, 0xc4, 0x25, 0x9f, 0x5c
.byte 0xcb, 0xd7, 0xb4, 0xbc, 0x76, 0xb9, 0xc1, 0xc6
.byte 0xc4, 0x25, 0x9f, 0x5c, 0x2b, 0x20, 0xe2, 0x6c
.byte 0x8a, 0x46, 0x3e, 0x39, 0x39, 0xda, 0x60, 0x23
.byte 0xd5, 0xdf, 0x1d, 0x93, 0x8a, 0x46, 0x3e, 0x39
.byte 0x39, 0xda, 0x60, 0x23, 0x2b, 0x20, 0xe2, 0x6c
.byte 0x76, 0xb9, 0xc1, 0xc6, 0xc7, 0x25, 0x9f, 0xdc
.byte 0xd5, 0xdf, 0x1d, 0x93, 0x76, 0xb9, 0xc1, 0xc6
.byte 0xc7, 0x25, 0x9f, 0xdc, 0x35, 0x28, 0x4b, 0x43
.byte 0x8a, 0x46, 0x3e, 0x39, 0x3c, 0xda, 0x60, 0xa3
.byte 0xcb, 0xd7, 0xb4, 0xbc, 0x8a, 0x46, 0x3e, 0x39
.byte 0x3c, 0xda, 0x60, 0xa3, 0x0, 0x0, 0x0, 0x0
.byte 0x76, 0xb9, 0xc1, 0xc6, 0xec, 0x68, 0x83, 0x8d
DATA_007893:
.byte 0x0, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x9, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x9, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0xa, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x9, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x9, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0xa, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0xc, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0xd, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0xa, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0x10, 0x0, 0x0, 0x0, 0xd, 0x0, 0x0, 0x0
.byte 0x0, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0xe, 0x0, 0x0, 0x0
.byte 0x11, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x12, 0x0, 0x0, 0x0
.byte 0x13, 0x0, 0x0, 0x0, 0x11, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x14, 0x0, 0x0, 0x0
.byte 0x15, 0x0, 0x0, 0x0, 0x16, 0x0, 0x0, 0x0
.byte 0x3, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x13, 0x0, 0x0, 0x0, 0x15, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x16, 0x0, 0x0, 0x0
.byte 0x17, 0x0, 0x0, 0x0, 0x18, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x12, 0x0, 0x0, 0x0
.byte 0x10, 0x0, 0x0, 0x0, 0x17, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0xb, 0x0, 0x0, 0x0, 0x18, 0x0, 0x0, 0x0
.byte 0x19, 0x0, 0x0, 0x0, 0x1a, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0xb, 0x0, 0x0, 0x0, 0xf, 0x0, 0x0, 0x0
.byte 0xc, 0x0, 0x0, 0x0, 0x19, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1a, 0x0, 0x0, 0x0
.byte 0x1b, 0x0, 0x0, 0x0, 0x1c, 0x0, 0x0, 0x0
.byte 0xb, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x1b, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x3, 0x0, 0x0, 0x0, 0x1c, 0x0, 0x0, 0x0
.byte 0x1d, 0x0, 0x0, 0x0, 0x14, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x3, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x1d, 0x0, 0x0, 0x0
DATA_007894:
.byte 0x0, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x2, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x3, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x9, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x5, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x9, 0x0, 0x0, 0x0
.byte 0x9, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0xa, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0x9, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0xb, 0x0, 0x0, 0x0, 0xa, 0x0, 0x0, 0x0
.byte 0xa, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
.byte 0xa, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x6, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x6, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0
.byte 0x1, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
.byte 0x3, 0x0, 0x0, 0x0, 0x4, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x4, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x8, 0x0, 0x0, 0x0, 0xb, 0x0, 0x0, 0x0
.byte 0xb, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0xb, 0x0, 0x0, 0x0, 0x7, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0
.byte 0x7, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x0
DATA_007637:
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1
.byte 1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1
.byte 1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DATA_007638:
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,127,126,126,125,125,124,124,124,124,124
.byte 124,124,124,124,124,124,125,125,126,126,127,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,126,125,124,123,123,122,122,121,121,120,120,120,120,120
.byte 120,120,120,120,120,120,121,121,122,122,123,123,124,125,126,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,126,125,124,123,122,121,120,120,119,118,118,117,117,116,116,116,116,116
.byte 116,116,116,116,116,116,117,117,118,118,119,120,120,121,122,123,124,125,126,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,126,125,123,122,121,120,119,118,117,116,116,115,114,114,113,113,112,112,112,112,112
.byte 112,112,112,112,112,112,113,113,114,114,115,116,116,117,118,119,120,121,122,123,125,126,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,124,122,121,120,118,117,116,115,114,113,112,112,111,110,110,109,109,108,108,108,108,108
.byte 108,108,108,108,108,108,109,109,110,110,111,112,112,113,114,115,116,117,118,120,121,122,124,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,123,121,120,118,117,116,115,113,112,111,110,109,108,108,107,106,106,105,105,104,104,104,104,104
.byte 104,104,104,104,104,104,105,105,106,106,107,108,108,109,110,111,112,113,115,116,117,118,120,121,123,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,122,121,119,118,116,115,113,112,111,110,108,107,106,105,105,104,103,102,102,101,101,100,100,100,100,100
.byte 100,100,100,100,100,100,101,101,102,102,103,104,105,105,106,107,108,110,111,112,113,115,116,118,119,121,122,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,122,121,119,117,116,114,112,111,110,108,107,106,105,104,103,102,101,100,99,98,98,97,97,96,96,96,96,96
.byte 96,96,96,96,96,96,97,97,98,98,99,100,101,102,103,104,105,106,107,108,110,111,112,114,116,117,119,121,122,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,123,121,119,117,115,114,112,110,109,107,106,104,103,102,101,100,99,98,97,96,95,94,94,93,93,92,92,92,92,92
.byte 92,92,92,92,92,92,93,93,94,94,95,96,97,98,99,100,101,102,103,104,106,107,109,110,112,114,115,117,119,121,123,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,123,121,119,117,115,113,112,110,108,107,105,104,102,101,99,98,97,96,95,94,93,92,91,91,90,89,89,88,88,88,88,88
.byte 88,88,88,88,88,88,89,89,90,91,91,92,93,94,95,96,97,98,99,101,102,104,105,107,108,110,112,113,115,117,119,121,123,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,122,120,118,116,114,112,110,108,106,105,103,101,100,98,97,96,94,93,92,91,90,89,88,87,87,86,85,85,84,84,84,84,84
.byte 84,84,84,84,84,84,85,85,86,87,87,88,89,90,91,92,93,94,96,97,98,100,101,103,105,106,108,110,112,114,116,118,120,122,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,123,121,118,116,114,112,110,108,106,104,103,101,99,98,96,95,93,92,91,89,88,87,86,85,84,83,83,82,81,81,80,80,80,80,80
.byte 80,80,80,80,80,80,81,81,82,83,83,84,85,86,87,88,89,91,92,93,95,96,98,99,101,103,104,106,108,110,112,114,116,118,121,123,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,120,117,115,113,111,109,107,105,103,101,99,97,96,94,92,91,89,88,87,85,84,83,82,81,80,79,79,78,77,77,76,76,76,76,76
.byte 76,76,76,76,76,76,77,77,78,79,79,80,81,82,83,84,85,87,88,89,91,92,94,96,97,99,101,103,105,107,109,111,113,115,117,120,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,121,119,116,114,112,110,107,105,103,101,99,97,96,94,92,90,89,87,86,84,83,82,80,79,78,77,76,76,75,74,73,73,73,72,72,72,72
.byte 72,72,72,72,72,73,73,73,74,75,76,76,77,78,79,80,82,83,84,86,87,89,90,92,94,96,97,99,101,103,105,107,110,112,114,116,119,121,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,123,120,118,116,113,111,108,106,104,102,100,98,96,94,92,90,88,87,85,84,82,81,79,78,77,76,74,73,72,72,71,70,70,69,69,68,68,68,68
.byte 68,68,68,68,68,69,69,70,70,71,72,72,73,74,76,77,78,79,81,82,84,85,87,88,90,92,94,96,98,100,102,104,106,108,111,113,116,118,120,123,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,120,117,115,112,110,108,105,103,101,99,96,94,92,90,88,87,85,83,81,80,78,77,75,74,73,72,71,70,69,68,67,66,66,65,65,64,64,64,64
.byte 64,64,64,64,64,65,65,66,66,67,68,69,70,71,72,73,74,75,77,78,80,81,83,85,87,88,90,92,94,96,99,101,103,105,108,110,112,115,117,120,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,122,119,117,114,112,109,107,104,102,100,97,95,93,91,89,87,85,83,81,79,78,76,75,73,72,70,69,68,67,66,65,64,63,62,62,61,61,60,60,60,60
.byte 60,60,60,60,60,61,61,62,62,63,64,65,66,67,68,69,70,72,73,75,76,78,79,81,83,85,87,89,91,93,95,97,100,102,104,107,109,112,114,117,119,122,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,119,116,114,111,109,106,104,101,99,96,94,92,90,88,85,83,81,80,78,76,74,72,71,69,68,67,65,64,63,62,61,60,59,58,58,57,57,56,56,56,56
.byte 56,56,56,56,56,57,57,58,58,59,60,61,62,63,64,65,67,68,69,71,72,74,76,78,80,81,83,85,88,90,92,94,96,99,101,104,106,109,111,114,116,119,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,119,116,113,111,108,105,103,100,98,96,93,91,89,86,84,82,80,78,76,74,72,71,69,67,66,64,63,61,60,59,58,57,56,55,54,54,53,53,52,52,52,52
.byte 52,52,52,52,52,53,53,54,54,55,56,57,58,59,60,61,63,64,66,67,69,71,72,74,76,78,80,82,84,86,89,91,93,96,98,100,103,105,108,111,113,116,119,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,119,116,113,110,108,105,102,100,97,95,92,90,88,85,83,81,79,76,74,72,71,69,67,65,64,62,60,59,58,56,55,54,53,52,51,50,50,49,49,48,48,48,48
.byte 48,48,48,48,48,49,49,50,50,51,52,53,54,55,56,58,59,60,62,64,65,67,69,71,72,74,76,79,81,83,85,88,90,92,95,97,100,102,105,108,110,113,116,119,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,113,110,108,105,102,99,97,94,92,89,87,84,82,80,77,75,73,71,69,67,65,63,62,60,58,57,55,54,53,51,50,49,48,47,47,46,45,45,44,44,44,44
.byte 44,44,44,44,44,45,45,46,47,47,48,49,50,51,53,54,55,57,58,60,62,63,65,67,69,71,73,75,77,80,82,84,87,89,92,94,97,99,102,105,108,110,113,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,113,110,107,105,102,99,96,94,91,89,86,84,81,79,76,74,72,70,68,66,64,62,60,58,56,55,53,52,50,49,48,46,45,44,43,43,42,41,41,40,40,40,40
.byte 40,40,40,40,40,41,41,42,43,43,44,45,46,48,49,50,52,53,55,56,58,60,62,64,66,68,70,72,74,76,79,81,84,86,89,91,94,96,99,102,105,107,110,113,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,113,110,108,105,102,99,96,93,91,88,85,83,80,78,76,73,71,69,66,64,62,60,58,56,54,53,51,49,48,46,45,44,43,41,40,40,39,38,37,37,36,36,36,36
.byte 36,36,36,36,36,37,37,38,39,40,40,41,43,44,45,46,48,49,51,53,54,56,58,60,62,64,66,69,71,73,76,78,80,83,85,88,91,93,96,99,102,105,108,110,113,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,123,120,117,114,111,108,105,102,99,96,93,91,88,85,82,80,77,75,72,70,68,65,63,61,59,57,55,53,51,49,47,46,44,43,41,40,39,38,37,36,35,34,33,33,32,32,32,32
.byte 32,32,32,32,32,33,33,34,35,36,37,38,39,40,41,43,44,46,47,49,51,53,55,57,59,61,63,65,68,70,72,75,77,80,82,85,88,91,93,96,99,102,105,108,111,114,117,120,123,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,120,117,114,111,108,105,102,99,96,93,90,88,85,82,79,77,74,72,69,67,64,62,60,57,55,53,51,49,47,45,44,42,40,39,37,36,35,34,33,32,31,30,29,29,28,28,28,28
.byte 28,28,28,28,28,29,29,30,31,32,33,34,35,36,37,39,40,42,44,45,47,49,51,53,55,57,60,62,64,67,69,72,74,77,79,82,85,88,90,93,96,99,102,105,108,111,114,117,120,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,124,121,118,115,112,109,105,102,99,96,93,91,88,85,82,79,76,74,71,69,66,64,61,59,56,54,52,50,48,46,44,42,40,38,37,35,34,32,31,30,29,28,27,26,25,25,24,24,24,24
.byte 24,24,24,24,24,25,25,26,27,28,29,30,31,32,34,35,37,38,40,42,44,46,48,50,52,54,56,59,61,64,66,69,71,74,76,79,82,85,88,91,93,96,99,102,105,109,112,115,118,121,124,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,112,109,106,103,100,97,94,91,88,85,82,79,76,74,71,68,66,63,60,58,56,53,51,49,46,44,42,40,38,36,35,33,32,30,29,27,26,25,24,23,22,21,21,20,20,20,20
.byte 20,20,20,20,20,21,21,22,23,24,25,26,27,29,30,32,33,35,36,38,40,42,44,46,49,51,53,56,58,60,63,66,68,71,74,76,79,82,85,88,91,94,97,100,103,106,109,112,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,126,123,120,116,113,110,107,104,100,97,94,91,88,85,82,79,76,73,71,68,65,63,60,57,55,52,50,48,45,43,41,39,37,35,33,31,29,28,26,25,24,22,21,20,19,18,18,17,16,16,16,16
.byte 16,16,16,16,16,17,18,18,19,20,21,22,24,25,26,28,29,31,33,35,37,39,41,43,45,48,50,52,55,57,60,63,65,68,71,73,76,79,82,85,88,91,94,97,100,104,107,110,113,116,120,123,126,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,127,124,121,117,114,111,108,104,101,98,95,92,89,85,82,79,76,74,71,68,65,62,60,57,54,52,49,47,44,42,40,37,35,33,31,29,28,26,24,23,21,20,18,17,16,15,14,14,13,12,12,12,12
.byte 12,12,12,12,12,13,14,14,15,16,17,18,20,21,23,24,26,28,29,31,33,35,37,40,42,44,47,49,52,54,57,60,62,65,68,71,74,76,79,82,85,89,92,95,98,101,104,108,111,114,117,121,124,127,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,125,122,118,115,112,108,105,102,99,96,92,89,86,83,80,77,74,71,68,65,62,59,57,54,51,49,46,44,41,39,36,34,32,30,28,26,24,22,20,19,17,16,15,13,12,11,10,10,9,8,8,8,8
.byte 8,8,8,8,8,9,10,10,11,12,13,15,16,17,19,20,22,24,26,28,30,32,34,36,39,41,44,46,49,51,54,57,59,62,65,68,71,74,77,80,83,86,89,92,96,99,102,105,108,112,115,118,122,125,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,127,123,120,116,113,110,106,103,100,96,93,90,87,84,80,77,74,71,68,65,62,59,57,54,51,48,46,43,40,38,36,33,31,29,26,24,22,20,19,17,15,14,12,11,10,8,7,7,6,5,4,4,4,4
.byte 4,4,4,4,4,5,6,7,7,8,10,11,12,14,15,17,19,20,22,24,26,29,31,33,36,38,40,43,46,48,51,54,57,59,62,65,68,71,74,77,80,84,87,90,93,96,100,103,106,110,113,116,120,123,127,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,125,121,118,114,111,107,104,101,97,94,91,88,84,81,78,75,72,69,66,63,60,57,54,51,48,45,43,40,37,35,32,30,28,25,23,21,19,17,15,13,12,10,8,7,6,5,4,3,2,1,1,0,0,0
.byte 0,0,0,0,1,1,2,3,4,5,6,7,8,10,12,13,15,17,19,21,23,25,28,30,32,35,37,40,43,45,48,51,54,57,60,63,66,69,72,75,78,81,84,88,91,94,97,101,104,107,111,114,118,121,125,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,126,123,119,116,112,109,105,102,99,95,92,89,85,82,79,76,72,69,66,63,60,57,54,51,48,45,42,40,37,34,32,29,27,24,22,20,18,15,13,12,10,8,6,5,3,2,1,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,1,2,3,5,6,8,10,12,13,15,18,20,22,24,27,29,32,34,37,40,42,45,48,51,54,57,60,63,66,69,72,76,79,82,85,89,92,95,99,102,105,109,112,116,119,123,126,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,124,121,117,114,110,107,103,100,96,93,90,86,83,80,76,73,70,67,64,60,57,54,51,48,45,42,40,37,34,31,29,26,24,21,19,16,14,12,10,8,6,4,3,1,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,1,3,4,6,8,10,12,14,16,19,21,24,26,29,31,34,37,40,42,45,48,51,54,57,60,64,67,70,73,76,80,83,86,90,93,96,100,103,107,110,114,117,121,124,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,126,122,119,115,112,108,105,101,98,94,91,88,84,81,77,74,71,68,64,61,58,55,52,49,46,43,40,37,34,31,28,26,23,20,18,16,13,11,9,7,4,3,1,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,4,7,9,11,13,16,18,20,23,26,28,31,34,37,40,43,46,49,52,55,58,61,64,68,71,74,77,81,84,88,91,94,98,101,105,108,112,115,119,122,126,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,124,121,117,113,110,106,103,99,96,92,89,85,82,79,75,72,69,65,62,59,56,52,49,46,43,40,37,34,31,28,25,23,20,17,15,12,10,8,5,3,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,5,8,10,12,15,17,20,23,25,28,31,34,37,40,43,46,49,52,56,59,62,65,69,72,75,79,82,85,89,92,96,99,103,106,110,113,117,121,124,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,126,122,119,115,112,108,104,101,97,94,90,87,83,80,76,73,70,66,63,60,56,53,50,47,44,40,37,34,31,28,25,23,20,17,14,12,9,7,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,4,7,9,12,14,17,20,23,25,28,31,34,37,40,44,47,50,53,56,60,63,66,70,73,76,80,83,87,90,94,97,101,104,108,112,115,119,122,126,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,124,121,117,114,110,106,103,99,96,92,88,85,81,78,74,71,68,64,61,57,54,51,48,44,41,38,35,32,29,26,23,20,17,14,11,9,6,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,6,9,11,14,17,20,23,26,29,32,35,38,41,44,48,51,54,57,61,64,68,71,74,78,81,85,88,92,96,99,103,106,110,114,117,121,124,128,128,128,128,128,128
.byte 128,128,128,128,128,128,127,123,119,116,112,108,105,101,97,94,90,87,83,80,76,72,69,66,62,59,55,52,49,45,42,39,36,32,29,26,23,20,17,14,11,8,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,8,11,14,17,20,23,26,29,32,36,39,42,45,49,52,55,59,62,66,69,72,76,80,83,87,90,94,97,101,105,108,112,116,119,123,127,128,128,128,128,128
.byte 128,128,128,128,128,128,125,121,118,114,110,107,103,99,96,92,88,85,81,78,74,71,67,64,60,57,53,50,46,43,40,36,33,30,27,24,20,17,14,11,8,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,8,11,14,17,20,24,27,30,33,36,40,43,46,50,53,57,60,64,67,71,74,78,81,85,88,92,96,99,103,107,110,114,118,121,125,128,128,128,128,128
.byte 128,128,128,128,128,127,124,120,116,112,109,105,101,98,94,90,87,83,79,76,72,69,65,62,58,55,51,48,44,41,37,34,31,28,24,21,18,15,12,9,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,9,12,15,18,21,24,28,31,34,37,41,44,48,51,55,58,62,65,69,72,76,79,83,87,90,94,98,101,105,109,112,116,120,124,127,128,128,128,128
.byte 128,128,128,128,128,126,122,118,115,111,107,104,100,96,92,89,85,81,78,74,71,67,63,60,56,53,49,46,42,39,35,32,29,25,22,19,16,12,9,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,9,12,16,19,22,25,29,32,35,39,42,46,49,53,56,60,63,67,71,74,78,81,85,89,92,96,100,104,107,111,115,118,122,126,128,128,128,128
.byte 128,128,128,128,128,125,121,117,113,110,106,102,98,95,91,87,84,80,76,72,69,65,62,58,54,51,47,44,40,37,33,30,26,23,20,16,13,10,7,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,7,10,13,16,20,23,26,30,33,37,40,44,47,51,54,58,62,65,69,72,76,80,84,87,91,95,98,102,106,110,113,117,121,125,128,128,128,128
.byte 128,128,128,128,127,123,120,116,112,108,104,101,97,93,89,86,82,78,75,71,67,64,60,56,53,49,45,42,38,35,31,28,24,21,18,14,11,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,11,14,18,21,24,28,31,35,38,42,45,49,53,56,60,64,67,71,75,78,82,86,89,93,97,101,104,108,112,116,120,123,127,128,128,128
.byte 128,128,128,128,126,122,118,115,111,107,103,99,96,92,88,84,81,77,73,69,66,62,58,55,51,47,44,40,36,33,29,26,22,19,15,12,9,5,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,5,9,12,15,19,22,26,29,33,36,40,44,47,51,55,58,62,66,69,73,77,81,84,88,92,96,99,103,107,111,115,118,122,126,128,128,128
.byte 128,128,128,128,125,121,117,113,110,106,102,98,94,91,87,83,79,75,72,68,64,60,57,53,49,46,42,38,35,31,28,24,20,17,13,10,7,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,10,13,17,20,24,28,31,35,38,42,46,49,53,57,60,64,68,72,75,79,83,87,91,94,98,102,106,110,113,117,121,125,128,128,128
.byte 128,128,128,128,124,120,116,112,108,105,101,97,93,89,85,82,78,74,70,67,63,59,55,52,48,44,40,37,33,29,26,22,19,15,12,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,12,15,19,22,26,29,33,37,40,44,48,52,55,59,63,67,70,74,78,82,85,89,93,97,101,105,108,112,116,120,124,128,128,128
.byte 128,128,128,127,123,119,115,111,107,104,100,96,92,88,84,80,77,73,69,65,61,58,54,50,46,43,39,35,32,28,24,20,17,13,10,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,10,13,17,20,24,28,32,35,39,43,46,50,54,58,61,65,69,73,77,80,84,88,92,96,100,104,107,111,115,119,123,127,128,128
.byte 128,128,128,126,122,118,114,110,106,103,99,95,91,87,83,79,76,72,68,64,60,56,53,49,45,41,37,34,30,26,23,19,15,12,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,12,15,19,23,26,30,34,37,41,45,49,53,56,60,64,68,72,76,79,83,87,91,95,99,103,106,110,114,118,122,126,128,128
.byte 128,128,128,125,121,117,113,109,105,102,98,94,90,86,82,78,74,71,67,63,59,55,51,48,44,40,36,32,29,25,21,17,14,10,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,10,14,17,21,25,29,32,36,40,44,48,51,55,59,63,67,71,74,78,82,86,90,94,98,102,105,109,113,117,121,125,128,128
.byte 128,128,128,124,120,116,112,108,105,101,97,93,89,85,81,77,73,70,66,62,58,54,50,46,43,39,35,31,27,24,20,16,12,8,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,8,12,16,20,24,27,31,35,39,43,46,50,54,58,62,66,70,73,77,81,85,89,93,97,101,105,108,112,116,120,124,128,128
.byte 128,128,127,123,120,116,112,108,104,100,96,92,88,84,80,76,72,69,65,61,57,53,49,45,41,38,34,30,26,22,18,15,11,7,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,11,15,18,22,26,30,34,38,41,45,49,53,57,61,65,69,72,76,80,84,88,92,96,100,104,108,112,116,120,123,127,128
.byte 128,128,127,123,119,115,111,107,103,99,95,91,87,83,79,76,72,68,64,60,56,52,48,44,40,37,33,29,25,21,17,13,10,6,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,6,10,13,17,21,25,29,33,37,40,44,48,52,56,60,64,68,72,76,79,83,87,91,95,99,103,107,111,115,119,123,127,128
.byte 128,128,126,122,118,114,110,106,102,98,94,91,87,83,79,75,71,67,63,59,55,51,47,43,40,36,32,28,24,20,16,12,8,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,8,12,16,20,24,28,32,36,40,43,47,51,55,59,63,67,71,75,79,83,87,91,94,98,102,106,110,114,118,122,126,128
.byte 128,128,126,122,118,114,110,106,102,98,94,90,86,82,78,74,70,66,62,58,54,50,47,43,39,35,31,27,23,19,15,11,7,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,7,11,15,19,23,27,31,35,39,43,47,50,54,58,62,66,70,74,78,82,86,90,94,98,102,106,110,114,118,122,126,128
.byte 128,128,125,121,117,113,109,105,101,97,93,89,85,81,77,73,70,66,62,58,54,50,46,42,38,34,30,26,22,18,14,10,7,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,10,14,18,22,26,30,34,38,42,46,50,54,58,62,66,70,73,77,81,85,89,93,97,101,105,109,113,117,121,125,128
.byte 128,128,125,121,117,113,109,105,101,97,93,89,85,81,77,73,69,65,61,57,53,49,45,41,37,33,29,25,21,18,14,10,6,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,6,10,14,18,21,25,29,33,37,41,45,49,53,57,61,65,69,73,77,81,85,89,93,97,101,105,109,113,117,121,125,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,73,69,65,61,57,53,49,45,41,37,33,29,25,21,17,13,9,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61,65,69,73,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,72,68,64,60,56,52,48,44,40,36,32,28,24,20,16,12,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,124,120,116,112,108,104,100,96,92,88,84,80,76,73,69,65,61,57,53,49,45,41,37,33,29,25,21,17,13,9,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61,65,69,73,76,80,84,88,92,96,100,104,108,112,116,120,124,128
.byte 128,128,125,121,117,113,109,105,101,97,93,89,85,81,77,73,69,65,61,57,53,49,45,41,37,33,29,25,21,18,14,10,6,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,6,10,14,18,21,25,29,33,37,41,45,49,53,57,61,65,69,73,77,81,85,89,93,97,101,105,109,113,117,121,125,128
.byte 128,128,125,121,117,113,109,105,101,97,93,89,85,81,77,73,70,66,62,58,54,50,46,42,38,34,30,26,22,18,14,10,7,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,10,14,18,22,26,30,34,38,42,46,50,54,58,62,66,70,73,77,81,85,89,93,97,101,105,109,113,117,121,125,128
.byte 128,128,126,122,118,114,110,106,102,98,94,90,86,82,78,74,70,66,62,58,54,50,47,43,39,35,31,27,23,19,15,11,7,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,7,11,15,19,23,27,31,35,39,43,47,50,54,58,62,66,70,74,78,82,86,90,94,98,102,106,110,114,118,122,126,128
.byte 128,128,126,122,118,114,110,106,102,98,94,91,87,83,79,75,71,67,63,59,55,51,47,43,40,36,32,28,24,20,16,12,8,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,8,12,16,20,24,28,32,36,40,43,47,51,55,59,63,67,71,75,79,83,87,91,94,98,102,106,110,114,118,122,126,128
.byte 128,128,127,123,119,115,111,107,103,99,95,91,87,83,79,76,72,68,64,60,56,52,48,44,40,37,33,29,25,21,17,13,10,6,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,6,10,13,17,21,25,29,33,37,40,44,48,52,56,60,64,68,72,76,79,83,87,91,95,99,103,107,111,115,119,123,127,128
.byte 128,128,127,123,120,116,112,108,104,100,96,92,88,84,80,76,72,69,65,61,57,53,49,45,41,38,34,30,26,22,18,15,11,7,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,11,15,18,22,26,30,34,38,41,45,49,53,57,61,65,69,72,76,80,84,88,92,96,100,104,108,112,116,120,123,127,128
.byte 128,128,128,124,120,116,112,108,105,101,97,93,89,85,81,77,73,70,66,62,58,54,50,46,43,39,35,31,27,24,20,16,12,8,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,8,12,16,20,24,27,31,35,39,43,46,50,54,58,62,66,70,73,77,81,85,89,93,97,101,105,108,112,116,120,124,128,128
.byte 128,128,128,125,121,117,113,109,105,102,98,94,90,86,82,78,74,71,67,63,59,55,51,48,44,40,36,32,29,25,21,17,14,10,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,10,14,17,21,25,29,32,36,40,44,48,51,55,59,63,67,71,74,78,82,86,90,94,98,102,105,109,113,117,121,125,128,128
.byte 128,128,128,126,122,118,114,110,106,103,99,95,91,87,83,79,76,72,68,64,60,56,53,49,45,41,37,34,30,26,23,19,15,12,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,12,15,19,23,26,30,34,37,41,45,49,53,56,60,64,68,72,76,79,83,87,91,95,99,103,106,110,114,118,122,126,128,128
.byte 128,128,128,127,123,119,115,111,107,104,100,96,92,88,84,80,77,73,69,65,61,58,54,50,46,43,39,35,32,28,24,20,17,13,10,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,10,13,17,20,24,28,32,35,39,43,46,50,54,58,61,65,69,73,77,80,84,88,92,96,100,104,107,111,115,119,123,127,128,128
.byte 128,128,128,128,124,120,116,112,108,105,101,97,93,89,85,82,78,74,70,67,63,59,55,52,48,44,40,37,33,29,26,22,19,15,12,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,12,15,19,22,26,29,33,37,40,44,48,52,55,59,63,67,70,74,78,82,85,89,93,97,101,105,108,112,116,120,124,128,128,128
.byte 128,128,128,128,125,121,117,113,110,106,102,98,94,91,87,83,79,75,72,68,64,60,57,53,49,46,42,38,35,31,28,24,20,17,13,10,7,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,10,13,17,20,24,28,31,35,38,42,46,49,53,57,60,64,68,72,75,79,83,87,91,94,98,102,106,110,113,117,121,125,128,128,128
.byte 128,128,128,128,126,122,118,115,111,107,103,99,96,92,88,84,81,77,73,69,66,62,58,55,51,47,44,40,36,33,29,26,22,19,15,12,9,5,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,5,9,12,15,19,22,26,29,33,36,40,44,47,51,55,58,62,66,69,73,77,81,84,88,92,96,99,103,107,111,115,118,122,126,128,128,128
.byte 128,128,128,128,127,123,120,116,112,108,104,101,97,93,89,86,82,78,75,71,67,64,60,56,53,49,45,42,38,35,31,28,24,21,18,14,11,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,8,11,14,18,21,24,28,31,35,38,42,45,49,53,56,60,64,67,71,75,78,82,86,89,93,97,101,104,108,112,116,120,123,127,128,128,128
.byte 128,128,128,128,128,125,121,117,113,110,106,102,98,95,91,87,84,80,76,72,69,65,62,58,54,51,47,44,40,37,33,30,26,23,20,16,13,10,7,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,7,10,13,16,20,23,26,30,33,37,40,44,47,51,54,58,62,65,69,72,76,80,84,87,91,95,98,102,106,110,113,117,121,125,128,128,128,128
.byte 128,128,128,128,128,126,122,118,115,111,107,104,100,96,92,89,85,81,78,74,71,67,63,60,56,53,49,46,42,39,35,32,29,25,22,19,16,12,9,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,9,12,16,19,22,25,29,32,35,39,42,46,49,53,56,60,63,67,71,74,78,81,85,89,92,96,100,104,107,111,115,118,122,126,128,128,128,128
.byte 128,128,128,128,128,127,124,120,116,112,109,105,101,98,94,90,87,83,79,76,72,69,65,62,58,55,51,48,44,41,37,34,31,28,24,21,18,15,12,9,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,9,12,15,18,21,24,28,31,34,37,41,44,48,51,55,58,62,65,69,72,76,79,83,87,90,94,98,101,105,109,112,116,120,124,127,128,128,128,128
.byte 128,128,128,128,128,128,125,121,118,114,110,107,103,99,96,92,88,85,81,78,74,71,67,64,60,57,53,50,46,43,40,36,33,30,27,24,20,17,14,11,8,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,8,11,14,17,20,24,27,30,33,36,40,43,46,50,53,57,60,64,67,71,74,78,81,85,88,92,96,99,103,107,110,114,118,121,125,128,128,128,128,128
.byte 128,128,128,128,128,128,127,123,119,116,112,108,105,101,97,94,90,87,83,80,76,72,69,66,62,59,55,52,49,45,42,39,36,32,29,26,23,20,17,14,11,8,6,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,6,8,11,14,17,20,23,26,29,32,36,39,42,45,49,52,55,59,62,66,69,72,76,80,83,87,90,94,97,101,105,108,112,116,119,123,127,128,128,128,128,128
.byte 128,128,128,128,128,128,128,124,121,117,114,110,106,103,99,96,92,88,85,81,78,74,71,68,64,61,57,54,51,48,44,41,38,35,32,29,26,23,20,17,14,11,9,6,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,6,9,11,14,17,20,23,26,29,32,35,38,41,44,48,51,54,57,61,64,68,71,74,78,81,85,88,92,96,99,103,106,110,114,117,121,124,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,126,122,119,115,112,108,104,101,97,94,90,87,83,80,76,73,70,66,63,60,56,53,50,47,44,40,37,34,31,28,25,23,20,17,14,12,9,7,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,4,7,9,12,14,17,20,23,25,28,31,34,37,40,44,47,50,53,56,60,63,66,70,73,76,80,83,87,90,94,97,101,104,108,112,115,119,122,126,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,124,121,117,113,110,106,103,99,96,92,89,85,82,79,75,72,69,65,62,59,56,52,49,46,43,40,37,34,31,28,25,23,20,17,15,12,10,8,5,3,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,5,8,10,12,15,17,20,23,25,28,31,34,37,40,43,46,49,52,56,59,62,65,69,72,75,79,82,85,89,92,96,99,103,106,110,113,117,121,124,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,126,122,119,115,112,108,105,101,98,94,91,88,84,81,77,74,71,68,64,61,58,55,52,49,46,43,40,37,34,31,28,26,23,20,18,16,13,11,9,7,4,3,1,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,4,7,9,11,13,16,18,20,23,26,28,31,34,37,40,43,46,49,52,55,58,61,64,68,71,74,77,81,84,88,91,94,98,101,105,108,112,115,119,122,126,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,124,121,117,114,110,107,103,100,96,93,90,86,83,80,76,73,70,67,64,60,57,54,51,48,45,42,40,37,34,31,29,26,24,21,19,16,14,12,10,8,6,4,3,1,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,1,3,4,6,8,10,12,14,16,19,21,24,26,29,31,34,37,40,42,45,48,51,54,57,60,64,67,70,73,76,80,83,86,90,93,96,100,103,107,110,114,117,121,124,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,126,123,119,116,112,109,105,102,99,95,92,89,85,82,79,76,72,69,66,63,60,57,54,51,48,45,42,40,37,34,32,29,27,24,22,20,18,15,13,12,10,8,6,5,3,2,1,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,1,2,3,5,6,8,10,12,13,15,18,20,22,24,27,29,32,34,37,40,42,45,48,51,54,57,60,63,66,69,72,76,79,82,85,89,92,95,99,102,105,109,112,116,119,123,126,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,125,121,118,114,111,107,104,101,97,94,91,88,84,81,78,75,72,69,66,63,60,57,54,51,48,45,43,40,37,35,32,30,28,25,23,21,19,17,15,13,12,10,8,7,6,5,4,3,2,1,1,0,0,0
.byte 0,0,0,0,1,1,2,3,4,5,6,7,8,10,12,13,15,17,19,21,23,25,28,30,32,35,37,40,43,45,48,51,54,57,60,63,66,69,72,75,78,81,84,88,91,94,97,101,104,107,111,114,118,121,125,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,127,123,120,116,113,110,106,103,100,96,93,90,87,84,80,77,74,71,68,65,62,59,57,54,51,48,46,43,40,38,36,33,31,29,26,24,22,20,19,17,15,14,12,11,10,8,7,7,6,5,4,4,4,4
.byte 4,4,4,4,4,5,6,7,7,8,10,11,12,14,15,17,19,20,22,24,26,29,31,33,36,38,40,43,46,48,51,54,57,59,62,65,68,71,74,77,80,84,87,90,93,96,100,103,106,110,113,116,120,123,127,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,125,122,118,115,112,108,105,102,99,96,92,89,86,83,80,77,74,71,68,65,62,59,57,54,51,49,46,44,41,39,36,34,32,30,28,26,24,22,20,19,17,16,15,13,12,11,10,10,9,8,8,8,8
.byte 8,8,8,8,8,9,10,10,11,12,13,15,16,17,19,20,22,24,26,28,30,32,34,36,39,41,44,46,49,51,54,57,59,62,65,68,71,74,77,80,83,86,89,92,96,99,102,105,108,112,115,118,122,125,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,127,124,121,117,114,111,108,104,101,98,95,92,89,85,82,79,76,74,71,68,65,62,60,57,54,52,49,47,44,42,40,37,35,33,31,29,28,26,24,23,21,20,18,17,16,15,14,14,13,12,12,12,12
.byte 12,12,12,12,12,13,14,14,15,16,17,18,20,21,23,24,26,28,29,31,33,35,37,40,42,44,47,49,52,54,57,60,62,65,68,71,74,76,79,82,85,89,92,95,98,101,104,108,111,114,117,121,124,127,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,126,123,120,116,113,110,107,104,100,97,94,91,88,85,82,79,76,73,71,68,65,63,60,57,55,52,50,48,45,43,41,39,37,35,33,31,29,28,26,25,24,22,21,20,19,18,18,17,16,16,16,16
.byte 16,16,16,16,16,17,18,18,19,20,21,22,24,25,26,28,29,31,33,35,37,39,41,43,45,48,50,52,55,57,60,63,65,68,71,73,76,79,82,85,88,91,94,97,100,104,107,110,113,116,120,123,126,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,112,109,106,103,100,97,94,91,88,85,82,79,76,74,71,68,66,63,60,58,56,53,51,49,46,44,42,40,38,36,35,33,32,30,29,27,26,25,24,23,22,21,21,20,20,20,20
.byte 20,20,20,20,20,21,21,22,23,24,25,26,27,29,30,32,33,35,36,38,40,42,44,46,49,51,53,56,58,60,63,66,68,71,74,76,79,82,85,88,91,94,97,100,103,106,109,112,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,124,121,118,115,112,109,105,102,99,96,93,91,88,85,82,79,76,74,71,69,66,64,61,59,56,54,52,50,48,46,44,42,40,38,37,35,34,32,31,30,29,28,27,26,25,25,24,24,24,24
.byte 24,24,24,24,24,25,25,26,27,28,29,30,31,32,34,35,37,38,40,42,44,46,48,50,52,54,56,59,61,64,66,69,71,74,76,79,82,85,88,91,93,96,99,102,105,109,112,115,118,121,124,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,120,117,114,111,108,105,102,99,96,93,90,88,85,82,79,77,74,72,69,67,64,62,60,57,55,53,51,49,47,45,44,42,40,39,37,36,35,34,33,32,31,30,29,29,28,28,28,28
.byte 28,28,28,28,28,29,29,30,31,32,33,34,35,36,37,39,40,42,44,45,47,49,51,53,55,57,60,62,64,67,69,72,74,77,79,82,85,88,90,93,96,99,102,105,108,111,114,117,120,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,123,120,117,114,111,108,105,102,99,96,93,91,88,85,82,80,77,75,72,70,68,65,63,61,59,57,55,53,51,49,47,46,44,43,41,40,39,38,37,36,35,34,33,33,32,32,32,32
.byte 32,32,32,32,32,33,33,34,35,36,37,38,39,40,41,43,44,46,47,49,51,53,55,57,59,61,63,65,68,70,72,75,77,80,82,85,88,91,93,96,99,102,105,108,111,114,117,120,123,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,113,110,108,105,102,99,96,93,91,88,85,83,80,78,76,73,71,69,66,64,62,60,58,56,54,53,51,49,48,46,45,44,43,41,40,40,39,38,37,37,36,36,36,36
.byte 36,36,36,36,36,37,37,38,39,40,40,41,43,44,45,46,48,49,51,53,54,56,58,60,62,64,66,69,71,73,76,78,80,83,85,88,91,93,96,99,102,105,108,110,113,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,113,110,107,105,102,99,96,94,91,89,86,84,81,79,76,74,72,70,68,66,64,62,60,58,56,55,53,52,50,49,48,46,45,44,43,43,42,41,41,40,40,40,40
.byte 40,40,40,40,40,41,41,42,43,43,44,45,46,48,49,50,52,53,55,56,58,60,62,64,66,68,70,72,74,76,79,81,84,86,89,91,94,96,99,102,105,107,110,113,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,119,116,113,110,108,105,102,99,97,94,92,89,87,84,82,80,77,75,73,71,69,67,65,63,62,60,58,57,55,54,53,51,50,49,48,47,47,46,45,45,44,44,44,44
.byte 44,44,44,44,44,45,45,46,47,47,48,49,50,51,53,54,55,57,58,60,62,63,65,67,69,71,73,75,77,80,82,84,87,89,92,94,97,99,102,105,108,110,113,116,119,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,119,116,113,110,108,105,102,100,97,95,92,90,88,85,83,81,79,76,74,72,71,69,67,65,64,62,60,59,58,56,55,54,53,52,51,50,50,49,49,48,48,48,48
.byte 48,48,48,48,48,49,49,50,50,51,52,53,54,55,56,58,59,60,62,64,65,67,69,71,72,74,76,79,81,83,85,88,90,92,95,97,100,102,105,108,110,113,116,119,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,119,116,113,111,108,105,103,100,98,96,93,91,89,86,84,82,80,78,76,74,72,71,69,67,66,64,63,61,60,59,58,57,56,55,54,54,53,53,52,52,52,52
.byte 52,52,52,52,52,53,53,54,54,55,56,57,58,59,60,61,63,64,66,67,69,71,72,74,76,78,80,82,84,86,89,91,93,96,98,100,103,105,108,111,113,116,119,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,119,116,114,111,109,106,104,101,99,96,94,92,90,88,85,83,81,80,78,76,74,72,71,69,68,67,65,64,63,62,61,60,59,58,58,57,57,56,56,56,56
.byte 56,56,56,56,56,57,57,58,58,59,60,61,62,63,64,65,67,68,69,71,72,74,76,78,80,81,83,85,88,90,92,94,96,99,101,104,106,109,111,114,116,119,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,122,119,117,114,112,109,107,104,102,100,97,95,93,91,89,87,85,83,81,79,78,76,75,73,72,70,69,68,67,66,65,64,63,62,62,61,61,60,60,60,60
.byte 60,60,60,60,60,61,61,62,62,63,64,65,66,67,68,69,70,72,73,75,76,78,79,81,83,85,87,89,91,93,95,97,100,102,104,107,109,112,114,117,119,122,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,122,120,117,115,112,110,108,105,103,101,99,96,94,92,90,88,87,85,83,81,80,78,77,75,74,73,72,71,70,69,68,67,66,66,65,65,64,64,64,64
.byte 64,64,64,64,64,65,65,66,66,67,68,69,70,71,72,73,74,75,77,78,80,81,83,85,87,88,90,92,94,96,99,101,103,105,108,110,112,115,117,120,122,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,123,120,118,116,113,111,108,106,104,102,100,98,96,94,92,90,88,87,85,84,82,81,79,78,77,76,74,73,72,72,71,70,70,69,69,68,68,68,68
.byte 68,68,68,68,68,69,69,70,70,71,72,72,73,74,76,77,78,79,81,82,84,85,87,88,90,92,94,96,98,100,102,104,106,108,111,113,116,118,120,123,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,121,119,116,114,112,110,107,105,103,101,99,97,96,94,92,90,89,87,86,84,83,82,80,79,78,77,76,76,75,74,73,73,73,72,72,72,72
.byte 72,72,72,72,72,73,73,73,74,75,76,76,77,78,79,80,82,83,84,86,87,89,90,92,94,96,97,99,101,103,105,107,110,112,114,116,119,121,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,124,122,120,117,115,113,111,109,107,105,103,101,99,97,96,94,92,91,89,88,87,85,84,83,82,81,80,79,79,78,77,77,76,76,76,76,76
.byte 76,76,76,76,76,76,77,77,78,79,79,80,81,82,83,84,85,87,88,89,91,92,94,96,97,99,101,103,105,107,109,111,113,115,117,120,122,124,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,125,123,121,118,116,114,112,110,108,106,104,103,101,99,98,96,95,93,92,91,89,88,87,86,85,84,83,83,82,81,81,80,80,80,80,80
.byte 80,80,80,80,80,80,81,81,82,83,83,84,85,86,87,88,89,91,92,93,95,96,98,99,101,103,104,106,108,110,112,114,116,118,121,123,125,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,122,120,118,116,114,112,110,108,106,105,103,101,100,98,97,96,94,93,92,91,90,89,88,87,87,86,85,85,84,84,84,84,84
.byte 84,84,84,84,84,84,85,85,86,87,87,88,89,90,91,92,93,94,96,97,98,100,101,103,105,106,108,110,112,114,116,118,120,122,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,123,121,119,117,115,113,112,110,108,107,105,104,102,101,99,98,97,96,95,94,93,92,91,91,90,89,89,88,88,88,88,88
.byte 88,88,88,88,88,88,89,89,90,91,91,92,93,94,95,96,97,98,99,101,102,104,105,107,108,110,112,113,115,117,119,121,123,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,123,121,119,117,115,114,112,110,109,107,106,104,103,102,101,100,99,98,97,96,95,94,94,93,93,92,92,92,92,92
.byte 92,92,92,92,92,92,93,93,94,94,95,96,97,98,99,100,101,102,103,104,106,107,109,110,112,114,115,117,119,121,123,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,122,121,119,117,116,114,112,111,110,108,107,106,105,104,103,102,101,100,99,98,98,97,97,96,96,96,96,96
.byte 96,96,96,96,96,96,97,97,98,98,99,100,101,102,103,104,105,106,107,108,110,111,112,114,116,117,119,121,122,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,122,121,119,118,116,115,113,112,111,110,108,107,106,105,105,104,103,102,102,101,101,100,100,100,100,100
.byte 100,100,100,100,100,100,101,101,102,102,103,104,105,105,106,107,108,110,111,112,113,115,116,118,119,121,122,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,126,124,123,121,120,118,117,116,115,113,112,111,110,109,108,108,107,106,106,105,105,104,104,104,104,104
.byte 104,104,104,104,104,104,105,105,106,106,107,108,108,109,110,111,112,113,115,116,117,118,120,121,123,124,126,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,125,124,122,121,120,118,117,116,115,114,113,112,112,111,110,110,109,109,108,108,108,108,108
.byte 108,108,108,108,108,108,109,109,110,110,111,112,112,113,114,115,116,117,118,120,121,122,124,125,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,126,125,123,122,121,120,119,118,117,116,116,115,114,114,113,113,112,112,112,112,112
.byte 112,112,112,112,112,112,113,113,114,114,115,116,116,117,118,119,120,121,122,123,125,126,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,126,125,124,123,122,121,120,120,119,118,118,117,117,116,116,116,116,116
.byte 116,116,116,116,116,116,117,117,118,118,119,120,120,121,122,123,124,125,126,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,126,125,124,123,123,122,122,121,121,120,120,120,120,120
.byte 120,120,120,120,120,120,121,121,122,122,123,123,124,125,126,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,127,127,126,126,125,125,124,124,124,124,124
.byte 124,124,124,124,124,124,125,125,126,126,127,127,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
.byte 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
DATA_007723: .quad FUNC_001467
DATA_007724: .quad FUNC_001465
DATA_007977:
.short 0
.short 1448
.short 2048
.short 2508
.short 2896
.short 3238
.short 3547
.short 3831
.short 4096
.short 4344
.short 4579
.short 4802
.short 5016
.short 5221
.short 5418
.short 5608
.short 5792
.short 5970
.short 6144
.short 6312
.short 6476
.short 6636
.short 6792
.short 6945
.short 7094
.short 7240
.short 7384
.short 7524
.short 7662
.short 7798
.short 7931
.short 8062
.short 8192
.short 8319
.short 8444
.short 8567
.short 8688
.short 8808
.short 8927
.short 9043
.short 9158
.short 9272
.short 9385
.short 9496
.short 9605
.short 9714
.short 9821
.short 9928
.short 10033
.short 10137
.short 10240
.short 10341
.short 10442
.short 10542
.short 10641
.short 10739
.short 10836
.short 10933
.short 11028
.short 11123
.short 11217
.short 11310
.short 11402
.short 11494
.short 11585
.short 11675
.short 11764
.short 11853
.short 11941
.short 12029
.short 12116
.short 12202
.short 12288
.short 12373
.short 12457
.short 12541
.short 12624
.short 12707
.short 12789
.short 12871
.short 12952
.short 13033
.short 13113
.short 13193
.short 13272
.short 13351
.short 13429
.short 13507
.short 13584
.short 13661
.short 13738
.short 13814
.short 13890
.short 13965
.short 14040
.short 14114
.short 14188
.short 14262
.short 14336
.short 14408
.short 14481
.short 14553
.short 14625
.short 14697
.short 14768
.short 14839
.short 14909
.short 14979
.short 15049
.short 15119
.short 15188
.short 15257
.short 15325
.short 15394
.short 15462
.short 15529
.short 15597
.short 15664
.short 15730
.short 15797
.short 15863
.short 15929
.short 15995
.short 16060
.short 16125
.short 16190
.short 16255
.short 16319
.short 16384
.short 16447
.short 16511
.short 16574
.short 16638
.short 16700
.short 16763
.short 16826
.short 16888
.short 16950
.short 17011
.short 17073
.short 17134
.short 17195
.short 17256
.short 17317
.short 17377
.short 17438
.short 17498
.short 17557
.short 17617
.short 17676
.short 17736
.short 17795
.short 17854
.short 17912
.short 17971
.short 18029
.short 18087
.short 18145
.short 18203
.short 18260
.short 18317
.short 18375
.short 18432
.short 18488
.short 18545
.short 18601
.short 18658
.short 18714
.short 18770
.short 18826
.short 18881
.short 18937
.short 18992
.short 19047
.short 19102
.short 19157
.short 19211
.short 19266
.short 19320
.short 19374
.short 19429
.short 19482
.short 19536
.short 19590
.short 19643
.short 19697
.short 19750
.short 19803
.short 19856
.short 19908
.short 19961
.short 20013
.short 20066
.short 20118
.short 20170
.short 20222
.short 20274
.short 20325
.short 20377
.short 20428
.short 20480
.short 20531
.short 20582
.short 20633
.short 20683
.short 20734
.short 20784
.short 20835
.short 20885
.short 20935
.short 20985
.short 21035
.short 21085
.short 21135
.short 21184
.short 21234
.short 21283
.short 21332
.short 21381
.short 21430
.short 21479
.short 21528
.short 21577
.short 21625
.short 21673
.short 21722
.short 21770
.short 21818
.short 21866
.short 21914
.short 21962
.short 22010
.short 22057
.short 22105
.short 22152
.short 22199
.short 22246
.short 22294
.short 22341
.short 22387
.short 22434
.short 22481
.short 22528
.short 22574
.short 22620
.short 22667
.short 22713
.short 22759
.short 22805
.short 22851
.short 22897
.short 22943
.short 22988
.short 23034
.short 23079
.short 23125
.short 23170
.short 23215
.short 23260
.short 23305
.short 23350
.short 23395
.short 23440
.short 23485
.short 23529
.short 23574
.short 23618
.short 23663
.short 23707
.short 23751
.short 23795
.short 23839
.short 23883
.short 23927
.short 23971
.short 24014
.short 24058
.short 24102
.short 24145
.short 24188
.short 24232
.short 24275
.short 24318
.short 24361
.short 24404
.short 24447
.short 24490
.short 24533
.short 24576
.short 24618
.short 24661
.short 24703
.short 24746
.short 24788
.short 24830
.short 24872
.short 24914
.short 24957
.short 24999
.short 25040
.short 25082
.short 25124
.short 25166
.short 25207
.short 25249
.short 25290
.short 25332
.short 25373
.short 25415
.short 25456
.short 25497
.short 25538
.short 25579
.short 25620
.short 25661
.short 25702
.short 25742
.short 25783
.short 25824
.short 25864
.short 25905
.short 25945
.short 25986
.short 26026
.short 26066
.short 26106
.short 26147
.short 26187
.short 26227
.short 26267
.short 26307
.short 26346
.short 26386
.short 26426
.short 26465
.short 26505
.short 26545
.short 26584
.short 26624
.short 26663
.short 26702
.short 26741
.short 26781
.short 26820
.short 26859
.short 26898
.short 26937
.short 26976
.short 27014
.short 27053
.short 27092
.short 27131
.short 27169
.short 27208
.short 27246
.short 27285
.short 27323
.short 27362
.short 27400
.short 27438
.short 27476
.short 27514
.short 27553
.short 27591
.short 27629
.short 27666
.short 27704
.short 27742
.short 27780
.short 27818
.short 27855
.short 27893
.short 27930
.short 27968
.short 28005
.short 28043
.short 28080
.short 28118
.short 28155
.short 28192
.short 28229
.short 28266
.short 28303
.short 28340
.short 28377
.short 28414
.short 28451
.short 28488
.short 28525
.short 28562
.short 28598
.short 28635
.short 28672
.short 28708
.short 28745
.short 28781
.short 28817
.short 28854
.short 28890
.short 28926
.short 28963
.short 28999
.short 29035
.short 29071
.short 29107
.short 29143
.short 29179
.short 29215
.short 29251
.short 29287
.short 29322
.short 29358
.short 29394
.short 29429
.short 29465
.short 29501
.short 29536
.short 29572
.short 29607
.short 29642
.short 29678
.short 29713
.short 29748
.short 29784
.short 29819
.short 29854
.short 29889
.short 29924
.short 29959
.short 29994
.short 30029
.short 30064
.short 30099
.short 30134
.short 30168
.short 30203
.short 30238
.short 30273
.short 30307
.short 30342
.short 30376
.short 30411
.short 30445
.short 30480
.short 30514
.short 30548
.short 30583
.short 30617
.short 30651
.short 30685
.short 30720
.short 30754
.short 30788
.short 30822
.short 30856
.short 30890
.short 30924
.short 30958
.short 30991
.short 31025
.short 31059
.short 31093
.short 31126
.short 31160
.short 31194
.short 31227
.short 31261
.short 31294
.short 31328
.short 31361
.short 31395
.short 31428
.short 31461
.short 31495
.short 31528
.short 31561
.short 31595
.short 31628
.short 31661
.short 31694
.short 31727
.short 31760
.short 31793
.short 31826
.short 31859
.short 31892
.short 31925
.short 31957
.short 31990
.short 32023
.short 32056
.short 32088
.short 32121
.short 32154
.short 32186
.short 32219
.short 32251
.short 32284
.short 32316
.short 32349
.short 32381
.short 32414
.short 32446
.short 32478
.short 32510
.short 32543
.short 32575
.short 32607
.short 32639
.short 32671
.short 32703
.short 32735
.short 32768
.short 32799
.short 32831
.short 32863
.short 32895
.short 32927
.short 32959
.short 32991
.short 33023
.short 33054
.short 33086
.short 33118
.short 33149
.short 33181
.short 33212
.short 33244
.short 33276
.short 33307
.short 33339
.short 33370
.short 33401
.short 33433
.short 33464
.short 33495
.short 33527
.short 33558
.short 33589
.short 33620
.short 33652
.short 33683
.short 33714
.short 33745
.short 33776
.short 33807
.short 33838
.short 33869
.short 33900
.short 33931
.short 33962
.short 33993
.short 34023
.short 34054
.short 34085
.short 34116
.short 34146
.short 34177
.short 34208
.short 34238
.short 34269
.short 34300
.short 34330
.short 34361
.short 34391
.short 34422
.short 34452
.short 34483
.short 34513
.short 34543
.short 34574
.short 34604
.short 34634
.short 34665
.short 34695
.short 34725
.short 34755
.short 34785
.short 34816
.short 34846
.short 34876
.short 34906
.short 34936
.short 34966
.short 34996
.short 35026
.short 35056
.short 35086
.short 35115
.short 35145
.short 35175
.short 35205
.short 35235
.short 35264
.short 35294
.short 35324
.short 35353
.short 35383
.short 35413
.short 35442
.short 35472
.short 35501
.short 35531
.short 35560
.short 35590
.short 35619
.short 35649
.short 35678
.short 35708
.short 35737
.short 35766
.short 35796
.short 35825
.short 35854
.short 35883
.short 35913
.short 35942
.short 35971
.short 36000
.short 36029
.short 36058
.short 36087
.short 36116
.short 36145
.short 36174
.short 36203
.short 36232
.short 36261
.short 36290
.short 36319
.short 36348
.short 36377
.short 36406
.short 36434
.short 36463
.short 36492
.short 36521
.short 36549
.short 36578
.short 36607
.short 36635
.short 36664
.short 36692
.short 36721
.short 36750
.short 36778
.short 36807
.short 36835
.short 36864
.short 36892
.short 36920
.short 36949
.short 36977
.short 37005
.short 37034
.short 37062
.short 37090
.short 37119
.short 37147
.short 37175
.short 37203
.short 37231
.short 37260
.short 37288
.short 37316
.short 37344
.short 37372
.short 37400
.short 37428
.short 37456
.short 37484
.short 37512
.short 37540
.short 37568
.short 37596
.short 37624
.short 37652
.short 37679
.short 37707
.short 37735
.short 37763
.short 37791
.short 37818
.short 37846
.short 37874
.short 37901
.short 37929
.short 37957
.short 37984
.short 38012
.short 38039
.short 38067
.short 38095
.short 38122
.short 38150
.short 38177
.short 38204
.short 38232
.short 38259
.short 38287
.short 38314
.short 38341
.short 38369
.short 38396
.short 38423
.short 38451
.short 38478
.short 38505
.short 38532
.short 38560
.short 38587
.short 38614
.short 38641
.short 38668
.short 38695
.short 38722
.short 38749
.short 38777
.short 38804
.short 38831
.short 38858
.short 38885
.short 38912
.short 38938
.short 38965
.short 38992
.short 39019
.short 39046
.short 39073
.short 39100
.short 39126
.short 39153
.short 39180
.short 39207
.short 39234
.short 39260
.short 39287
.short 39314
.short 39340
.short 39367
.short 39394
.short 39420
.short 39447
.short 39473
.short 39500
.short 39526
.short 39553
.short 39579
.short 39606
.short 39632
.short 39659
.short 39685
.short 39712
.short 39738
.short 39764
.short 39791
.short 39817
.short 39843
.short 39870
.short 39896
.short 39922
.short 39949
.short 39975
.short 40001
.short 40027
.short 40053
.short 40080
.short 40106
.short 40132
.short 40158
.short 40184
.short 40210
.short 40236
.short 40262
.short 40288
.short 40314
.short 40340
.short 40366
.short 40392
.short 40418
.short 40444
.short 40470
.short 40496
.short 40522
.short 40548
.short 40574
.short 40600
.short 40625
.short 40651
.short 40677
.short 40703
.short 40728
.short 40754
.short 40780
.short 40806
.short 40831
.short 40857
.short 40883
.short 40908
.short 40934
.short 40960
.short 40985
.short 41011
.short 41036
.short 41062
.short 41087
.short 41113
.short 41138
.short 41164
.short 41189
.short 41215
.short 41240
.short 41266
.short 41291
.short 41316
.short 41342
.short 41367
.short 41392
.short 41418
.short 41443
.short 41468
.short 41494
.short 41519
.short 41544
.short 41569
.short 41595
.short 41620
.short 41645
.short 41670
.short 41695
.short 41720
.short 41746
.short 41771
.short 41796
.short 41821
.short 41846
.short 41871
.short 41896
.short 41921
.short 41946
.short 41971
.short 41996
.short 42021
.short 42046
.short 42071
.short 42096
.short 42121
.short 42146
.short 42170
.short 42195
.short 42220
.short 42245
.short 42270
.short 42295
.short 42319
.short 42344
.short 42369
.short 42394
.short 42418
.short 42443
.short 42468
.short 42492
.short 42517
.short 42542
.short 42566
.short 42591
.short 42616
.short 42640
.short 42665
.short 42689
.short 42714
.short 42738
.short 42763
.short 42788
.short 42812
.short 42836
.short 42861
.short 42885
.short 42910
.short 42934
.short 42959
.short 42983
.short 43008
.short 43032
.short 43056
.short 43081
.short 43105
.short 43129
.short 43154
.short 43178
.short 43202
.short 43226
.short 43251
.short 43275
.short 43299
.short 43323
.short 43347
.short 43372
.short 43396
.short 43420
.short 43444
.short 43468
.short 43492
.short 43516
.short 43541
.short 43565
.short 43589
.short 43613
.short 43637
.short 43661
.short 43685
.short 43709
.short 43733
.short 43757
.short 43781
.short 43805
.short 43829
.short 43853
.short 43876
.short 43900
.short 43924
.short 43948
.short 43972
.short 43996
.short 44020
.short 44043
.short 44067
.short 44091
.short 44115
.short 44139
.short 44162
.short 44186
.short 44210
.short 44233
.short 44257
.short 44281
.short 44305
.short 44328
.short 44352
.short 44375
.short 44399
.short 44423
.short 44446
.short 44470
.short 44493
.short 44517
.short 44541
.short 44564
.short 44588
.short 44611
.short 44635
.short 44658
.short 44682
.short 44705
.short 44728
.short 44752
.short 44775
.short 44799
.short 44822
.short 44846
.short 44869
.short 44892
.short 44916
.short 44939
.short 44962
.short 44986
.short 45009
.short 45032
.short 45056
.short 45079
.short 45102
.short 45125
.short 45148
.short 45172
.short 45195
.short 45218
.short 45241
.short 45264
.short 45288
.short 45311
.short 45334
.short 45357
.short 45380
.short 45403
.short 45426
.short 45449
.short 45472
.short 45496
.short 45519
.short 45542
.short 45565
.short 45588
.short 45611
.short 45634
.short 45657
.short 45680
.short 45702
.short 45725
.short 45748
.short 45771
.short 45794
.short 45817
.short 45840
.short 45863
.short 45886
.short 45909
.short 45931
.short 45954
.short 45977
.short 46000
.short 46023
.short 46045
.short 46068
.short 46091
.short 46114
.short 46136
.short 46159
.short 46182
.short 46204
.short 46227
.short 46250
.short 46273
.short 46295
.short 46318
.short 46340
.short 46363
.short 46386
.short 46408
.short 46431
.short 46453
.short 46476
.short 46499
.short 46521
.short 46544
.short 46566
.short 46589
.short 46611
.short 46634
.short 46656
.short 46679
.short 46701
.short 46724
.short 46746
.short 46768
.short 46791
.short 46813
.short 46836
.short 46858
.short 46880
.short 46903
.short 46925
.short 46947
.short 46970
.short 46992
.short 47014
.short 47037
.short 47059
.short 47081
.short 47104
.short 47126
.short 47148
.short 47170
.short 47192
.short 47215
.short 47237
.short 47259
.short 47281
.short 47303
.short 47326
.short 47348
.short 47370
.short 47392
.short 47414
.short 47436
.short 47458
.short 47480
.short 47503
.short 47525
.short 47547
.short 47569
.short 47591
.short 47613
.short 47635
.short 47657
.short 47679
.short 47701
.short 47723
.short 47745
.short 47767
.short 47789
.short 47811
.short 47832
.short 47854
.short 47876
.short 47898
.short 47920
.short 47942
.short 47964
.short 47986
.short 48008
.short 48029
.short 48051
.short 48073
.short 48095
.short 48117
.short 48138
.short 48160
.short 48182
.short 48204
.short 48225
.short 48247
.short 48269
.short 48291
.short 48312
.short 48334
.short 48356
.short 48377
.short 48399
.short 48421
.short 48442
.short 48464
.short 48486
.short 48507
.short 48529
.short 48550
.short 48572
.short 48594
.short 48615
.short 48637
.short 48658
.short 48680
.short 48701
.short 48723
.short 48744
.short 48766
.short 48787
.short 48809
.short 48830
.short 48852
.short 48873
.short 48895
.short 48916
.short 48938
.short 48959
.short 48981
.short 49002
.short 49023
.short 49045
.short 49066
.short 49087
.short 49109
.short 49130
.short 49152
.short 49173
.short 49194
.short 49215
.short 49237
.short 49258
.short 49279
.short 49301
.short 49322
.short 49343
.short 49364
.short 49386
.short 49407
.short 49428
.short 49449
.short 49470
.short 49492
.short 49513
.short 49534
.short 49555
.short 49576
.short 49597
.short 49619
.short 49640
.short 49661
.short 49682
.short 49703
.short 49724
.short 49745
.short 49766
.short 49787
.short 49808
.short 49829
.short 49851
.short 49872
.short 49893
.short 49914
.short 49935
.short 49956
.short 49977
.short 49998
.short 50019
.short 50039
.short 50060
.short 50081
.short 50102
.short 50123
.short 50144
.short 50165
.short 50186
.short 50207
.short 50228
.short 50249
.short 50269
.short 50290
.short 50311
.short 50332
.short 50353
.short 50374
.short 50394
.short 50415
.short 50436
.short 50457
.short 50478
.short 50498
.short 50519
.short 50540
.short 50561
.short 50581
.short 50602
.short 50623
.short 50644
.short 50664
.short 50685
.short 50706
.short 50726
.short 50747
.short 50768
.short 50788
.short 50809
.short 50830
.short 50850
.short 50871
.short 50891
.short 50912
.short 50933
.short 50953
.short 50974
.short 50994
.short 51015
.short 51035
.short 51056
.short 51076
.short 51097
.short 51118
.short 51138
.short 51159
.short 51179
.short 51200
.short 51220
.short 51240
.short 51261
.short 51281
.short 51302
.short 51322
.short 51343
.short 51363
.short 51383
.short 51404
.short 51424
.short 51445
.short 51465
.short 51485
.short 51506
.short 51526
.short 51546
.short 51567
.short 51587
.short 51607
.short 51628
.short 51648
.short 51668
.short 51689
.short 51709
.short 51729
.short 51750
.short 51770
.short 51790
.short 51810
.short 51830
.short 51851
.short 51871
.short 51891
.short 51911
.short 51932
.short 51952
.short 51972
.short 51992
.short 52012
.short 52032
.short 52053
.short 52073
.short 52093
.short 52113
.short 52133
.short 52153
.short 52173
.short 52193
.short 52213
.short 52234
.short 52254
.short 52274
.short 52294
.short 52314
.short 52334
.short 52354
.short 52374
.short 52394
.short 52414
.short 52434
.short 52454
.short 52474
.short 52494
.short 52514
.short 52534
.short 52554
.short 52574
.short 52594
.short 52614
.short 52633
.short 52653
.short 52673
.short 52693
.short 52713
.short 52733
.short 52753
.short 52773
.short 52793
.short 52812
.short 52832
.short 52852
.short 52872
.short 52892
.short 52912
.short 52931
.short 52951
.short 52971
.short 52991
.short 53011
.short 53030
.short 53050
.short 53070
.short 53090
.short 53109
.short 53129
.short 53149
.short 53169
.short 53188
.short 53208
.short 53228
.short 53248
.short 53267
.short 53287
.short 53307
.short 53326
.short 53346
.short 53366
.short 53385
.short 53405
.short 53424
.short 53444
.short 53464
.short 53483
.short 53503
.short 53522
.short 53542
.short 53562
.short 53581
.short 53601
.short 53620
.short 53640
.short 53659
.short 53679
.short 53699
.short 53718
.short 53738
.short 53757
.short 53777
.short 53796
.short 53816
.short 53835
.short 53855
.short 53874
.short 53893
.short 53913
.short 53932
.short 53952
.short 53971
.short 53991
.short 54010
.short 54029
.short 54049
.short 54068
.short 54088
.short 54107
.short 54126
.short 54146
.short 54165
.short 54184
.short 54204
.short 54223
.short 54243
.short 54262
.short 54281
.short 54300
.short 54320
.short 54339
.short 54358
.short 54378
.short 54397
.short 54416
.short 54435
.short 54455
.short 54474
.short 54493
.short 54512
.short 54532
.short 54551
.short 54570
.short 54589
.short 54609
.short 54628
.short 54647
.short 54666
.short 54685
.short 54704
.short 54724
.short 54743
.short 54762
.short 54781
.short 54800
.short 54819
.short 54839
.short 54858
.short 54877
.short 54896
.short 54915
.short 54934
.short 54953
.short 54972
.short 54991
.short 55010
.short 55029
.short 55048
.short 55067
.short 55087
.short 55106
.short 55125
.short 55144
.short 55163
.short 55182
.short 55201
.short 55220
.short 55239
.short 55258
.short 55277
.short 55296
.short 55314
.short 55333
.short 55352
.short 55371
.short 55390
.short 55409
.short 55428
.short 55447
.short 55466
.short 55485
.short 55504
.short 55523
.short 55541
.short 55560
.short 55579
.short 55598
.short 55617
.short 55636
.short 55655
.short 55673
.short 55692
.short 55711
.short 55730
.short 55749
.short 55768
.short 55786
.short 55805
.short 55824
.short 55843
.short 55861
.short 55880
.short 55899
.short 55918
.short 55937
.short 55955
.short 55974
.short 55993
.short 56011
.short 56030
.short 56049
.short 56068
.short 56086
.short 56105
.short 56124
.short 56142
.short 56161
.short 56180
.short 56198
.short 56217
.short 56236
.short 56254
.short 56273
.short 56292
.short 56310
.short 56329
.short 56347
.short 56366
.short 56385
.short 56403
.short 56422
.short 56440
.short 56459
.short 56478
.short 56496
.short 56515
.short 56533
.short 56552
.short 56570
.short 56589
.short 56607
.short 56626
.short 56644
.short 56663
.short 56681
.short 56700
.short 56718
.short 56737
.short 56755
.short 56774
.short 56792
.short 56811
.short 56829
.short 56848
.short 56866
.short 56885
.short 56903
.short 56921
.short 56940
.short 56958
.short 56977
.short 56995
.short 57013
.short 57032
.short 57050
.short 57069
.short 57087
.short 57105
.short 57124
.short 57142
.short 57160
.short 57179
.short 57197
.short 57215
.short 57234
.short 57252
.short 57270
.short 57289
.short 57307
.short 57325
.short 57344
.short 57362
.short 57380
.short 57398
.short 57417
.short 57435
.short 57453
.short 57471
.short 57490
.short 57508
.short 57526
.short 57544
.short 57563
.short 57581
.short 57599
.short 57617
.short 57635
.short 57654
.short 57672
.short 57690
.short 57708
.short 57726
.short 57744
.short 57763
.short 57781
.short 57799
.short 57817
.short 57835
.short 57853
.short 57871
.short 57889
.short 57908
.short 57926
.short 57944
.short 57962
.short 57980
.short 57998
.short 58016
.short 58034
.short 58052
.short 58070
.short 58088
.short 58106
.short 58124
.short 58143
.short 58161
.short 58179
.short 58197
.short 58215
.short 58233
.short 58251
.short 58269
.short 58287
.short 58305
.short 58323
.short 58341
.short 58359
.short 58376
.short 58394
.short 58412
.short 58430
.short 58448
.short 58466
.short 58484
.short 58502
.short 58520
.short 58538
.short 58556
.short 58574
.short 58592
.short 58610
.short 58627
.short 58645
.short 58663
.short 58681
.short 58699
.short 58717
.short 58735
.short 58752
.short 58770
.short 58788
.short 58806
.short 58824
.short 58842
.short 58859
.short 58877
.short 58895
.short 58913
.short 58931
.short 58948
.short 58966
.short 58984
.short 59002
.short 59020
.short 59037
.short 59055
.short 59073
.short 59091
.short 59108
.short 59126
.short 59144
.short 59162
.short 59179
.short 59197
.short 59215
.short 59232
.short 59250
.short 59268
.short 59285
.short 59303
.short 59321
.short 59339
.short 59356
.short 59374
.short 59392
.short 59409
.short 59427
.short 59444
.short 59462
.short 59480
.short 59497
.short 59515
.short 59533
.short 59550
.short 59568
.short 59585
.short 59603
.short 59621
.short 59638
.short 59656
.short 59673
.short 59691
.short 59708
.short 59726
.short 59744
.short 59761
.short 59779
.short 59796
.short 59814
.short 59831
.short 59849
.short 59866
.short 59884
.short 59901
.short 59919
.short 59936
.short 59954
.short 59971
.short 59989
.short 60006
.short 60024
.short 60041
.short 60059
.short 60076
.short 60094
.short 60111
.short 60128
.short 60146
.short 60163
.short 60181
.short 60198
.short 60216
.short 60233
.short 60250
.short 60268
.short 60285
.short 60303
.short 60320
.short 60337
.short 60355
.short 60372
.short 60389
.short 60407
.short 60424
.short 60442
.short 60459
.short 60476
.short 60494
.short 60511
.short 60528
.short 60546
.short 60563
.short 60580
.short 60597
.short 60615
.short 60632
.short 60649
.short 60667
.short 60684
.short 60701
.short 60718
.short 60736
.short 60753
.short 60770
.short 60788
.short 60805
.short 60822
.short 60839
.short 60856
.short 60874
.short 60891
.short 60908
.short 60925
.short 60943
.short 60960
.short 60977
.short 60994
.short 61011
.short 61029
.short 61046
.short 61063
.short 61080
.short 61097
.short 61114
.short 61132
.short 61149
.short 61166
.short 61183
.short 61200
.short 61217
.short 61234
.short 61251
.short 61269
.short 61286
.short 61303
.short 61320
.short 61337
.short 61354
.short 61371
.short 61388
.short 61405
.short 61422
.short 61440
.short 61457
.short 61474
.short 61491
.short 61508
.short 61525
.short 61542
.short 61559
.short 61576
.short 61593
.short 61610
.short 61627
.short 61644
.short 61661
.short 61678
.short 61695
.short 61712
.short 61729
.short 61746
.short 61763
.short 61780
.short 61797
.short 61814
.short 61831
.short 61848
.short 61865
.short 61882
.short 61899
.short 61916
.short 61932
.short 61949
.short 61966
.short 61983
.short 62000
.short 62017
.short 62034
.short 62051
.short 62068
.short 62085
.short 62102
.short 62118
.short 62135
.short 62152
.short 62169
.short 62186
.short 62203
.short 62220
.short 62236
.short 62253
.short 62270
.short 62287
.short 62304
.short 62321
.short 62337
.short 62354
.short 62371
.short 62388
.short 62405
.short 62422
.short 62438
.short 62455
.short 62472
.short 62489
.short 62505
.short 62522
.short 62539
.short 62556
.short 62573
.short 62589
.short 62606
.short 62623
.short 62640
.short 62656
.short 62673
.short 62690
.short 62706
.short 62723
.short 62740
.short 62757
.short 62773
.short 62790
.short 62807
.short 62823
.short 62840
.short 62857
.short 62873
.short 62890
.short 62907
.short 62923
.short 62940
.short 62957
.short 62973
.short 62990
.short 63007
.short 63023
.short 63040
.short 63057
.short 63073
.short 63090
.short 63106
.short 63123
.short 63140
.short 63156
.short 63173
.short 63190
.short 63206
.short 63223
.short 63239
.short 63256
.short 63272
.short 63289
.short 63306
.short 63322
.short 63339
.short 63355
.short 63372
.short 63388
.short 63405
.short 63421
.short 63438
.short 63454
.short 63471
.short 63488
.short 63504
.short 63521
.short 63537
.short 63554
.short 63570
.short 63587
.short 63603
.short 63619
.short 63636
.short 63652
.short 63669
.short 63685
.short 63702
.short 63718
.short 63735
.short 63751
.short 63768
.short 63784
.short 63801
.short 63817
.short 63833
.short 63850
.short 63866
.short 63883
.short 63899
.short 63915
.short 63932
.short 63948
.short 63965
.short 63981
.short 63997
.short 64014
.short 64030
.short 64047
.short 64063
.short 64079
.short 64096
.short 64112
.short 64128
.short 64145
.short 64161
.short 64177
.short 64194
.short 64210
.short 64226
.short 64243
.short 64259
.short 64275
.short 64292
.short 64308
.short 64324
.short 64341
.short 64357
.short 64373
.short 64389
.short 64406
.short 64422
.short 64438
.short 64455
.short 64471
.short 64487
.short 64503
.short 64520
.short 64536
.short 64552
.short 64568
.short 64585
.short 64601
.short 64617
.short 64633
.short 64650
.short 64666
.short 64682
.short 64698
.short 64714
.short 64731
.short 64747
.short 64763
.short 64779
.short 64795
.short 64812
.short 64828
.short 64844
.short 64860
.short 64876
.short 64892
.short 64909
.short 64925
.short 64941
.short 64957
.short 64973
.short 64989
.short 65005
.short 65021
.short 65038
.short 65054
.short 65070
.short 65086
.short 65102
.short 65118
.short 65134
.short 65150
.short 65166
.short 65183
.short 65199
.short 65215
.short 65231
.short 65247
.short 65263
.short 65279
.short 65295
.short 65311
.short 65327
.short 65343
.short 65359
.short 65375
.short 65391
.short 65407
.short 65423
.short 65439
.short 65455
.short 65471
.short 65487
.short 65503
.short 65519

.section .text
_SetJmp:
 xor eax,eax
 ret
_LongJmp:
 mov eax,60
 mov edi,96
 syscall
_start:
 mov esp,OFFSET FLAT:stack_end
 cld
next_full:
 xor r8d,r8d
read_full:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input_full
 add rsi,r8
 mov edx,800
 sub edx,r8d
 syscall
 test eax,eax
 jle finish_full
 add r8d,eax
 cmp r8d,800
 jne read_full
 mov rax,0x4e41545552414c32
 mov QWORD PTR [output_guard_before],rax
 mov QWORD PTR [output_guard_after],rax
 mov QWORD PTR [player_guard_before],rax
 mov QWORD PTR [player_guard_after],rax
 mov QWORD PTR [parent_guard_before],rax
 mov QWORD PTR [parent_guard_after],rax
 mov QWORD PTR [relative_guard_before],rax
 mov QWORD PTR [relative_guard_after],rax
 mov esi,OFFSET FLAT:input_full+64
 mov edi,OFFSET FLAT:player
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov edi,OFFSET FLAT:output_full
 xor eax,eax
 mov ecx,256
 rep stosd
 mov DWORD PTR [query_count_full],0
 mov DWORD PTR [volume_count],0
 mov DWORD PTR [DATA_008702],0
mov eax,DWORD PTR [input_full+52]
mov DWORD PTR [DATA_009283],eax
mov eax,DWORD PTR [input_full+56]
mov DWORD PTR [DATA_009284],eax
mov eax,DWORD PTR [input_full+8]
mov BYTE PTR [DATA_008696],al
mov eax,DWORD PTR [input_full+12]
mov BYTE PTR [DATA_008697],al
mov eax,DWORD PTR [input_full+16]
mov BYTE PTR [DATA_008698],al
mov eax,DWORD PTR [input_full+20]
mov BYTE PTR [DATA_008699],al
mov eax,DWORD PTR [input_full+24]
mov BYTE PTR [DATA_008700],al
mov eax,DWORD PTR [input_full+28]
mov BYTE PTR [DATA_008701],al
mov eax,DWORD PTR [input_full+32]
mov DWORD PTR [DATA_008703],eax
mov eax,DWORD PTR [input_full+36]
mov DWORD PTR [DATA_008704],eax
mov eax,DWORD PTR [input_full+40]
mov DWORD PTR [DATA_008705],eax
mov eax,DWORD PTR [input_full+44]
mov DWORD PTR [DATA_008706],eax
mov eax,DWORD PTR [input_full+48]
mov BYTE PTR [DATA_008707],al
 mov eax,DWORD PTR [input_full+4]
 mov DWORD PTR [DATA_008812],eax
 test DWORD PTR [input_full],1
 jz classify_full
 mov eax,DWORD PTR [player+0x82]
 push rax
 push OFFSET FLAT:player
 push OFFSET FLAT:player
 call FUNC_001533
 add rsp,24
 mov eax,DWORD PTR [parent+0x82]
 push rax
 push OFFSET FLAT:parent
 push OFFSET FLAT:parent
 call FUNC_001533
 add rsp,24
 xor eax,eax
 jmp capture_full
classify_full:
 push OFFSET FLAT:relative
 push OFFSET FLAT:parent
 push OFFSET FLAT:player
 call FUNC_000576
 add rsp,24
capture_full:
 mov DWORD PTR [output_full],eax
 mov eax,DWORD PTR [query_count_full]
 mov DWORD PTR [output_full+4],eax
 mov eax,DWORD PTR [volume_count]
 mov DWORD PTR [output_full+8],eax
 mov eax,DWORD PTR [DATA_008702]
 cmp eax,OFFSET FLAT:parent
 sete al
 movzx eax,al
 mov DWORD PTR [output_full+12],eax
mov eax,DWORD PTR [DATA_009283]
mov DWORD PTR [output_full+60],eax
mov eax,DWORD PTR [DATA_009284]
mov DWORD PTR [output_full+764],eax
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [output_full+16],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [output_full+20],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [output_full+24],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [output_full+28],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [output_full+32],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [output_full+36],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [output_full+40],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [output_full+44],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [output_full+48],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [output_full+52],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [output_full+56],eax
 mov esi,OFFSET FLAT:player
 mov edi,OFFSET FLAT:output_full+64
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov rax,0x4e41545552414c32
 mov QWORD PTR [output_full+1008],rax
 mov QWORD PTR [output_full+1016],rax
 cmp QWORD PTR [output_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [output_guard_after],rax
 jne invalid_canary
 cmp QWORD PTR [player_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [player_guard_after],rax
 jne invalid_canary
 cmp QWORD PTR [parent_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [parent_guard_after],rax
 jne invalid_canary
 cmp QWORD PTR [relative_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [relative_guard_after],rax
 jne invalid_canary
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output_full
 mov edx,1024
 syscall
 jmp next_full
invalid_canary:
 mov eax,60
 mov edi,94
 syscall
finish_full:
 mov eax,60
 xor edi,edi
 syscall
.section .bss
input: .zero 56
object: .zero 512
center: .zero 12
patches: .zero 256
result: .zero 4
output: .zero 24
.balign 16
stack: .zero 8388608
stack_end:


.section .text
FUNC_000579:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 pushfq
 mov ebx,DWORD PTR [volume_count]
 cmp ebx,3
 jae invalid_trace
 shl ebx,6
 add ebx,OFFSET FLAT:output_full+768
 mov eax,DWORD PTR [rbp+48]
 mov DWORD PTR [rbx],eax
 mov esi,DWORD PTR [rbp+40]
 lea edi,[rbx+4]
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [query_count_full]
 mov DWORD PTR [rbx+56],eax
 popfq
 push QWORD PTR [rbp+48]
 push QWORD PTR [rbp+40]
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call OriginalF579
 lea rsp,[rsp+40]
 pushfq
 push rax
 push rcx
 mov DWORD PTR [rbx+52],eax
 mov esi,DWORD PTR [rbp+40]
 lea edi,[rbx+28]
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [query_count_full]
 sub eax,DWORD PTR [rbx+56]
 mov DWORD PTR [rbx+56],eax
 inc DWORD PTR [volume_count]
 pop rcx
 pop rax
 popfq
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
invalid_trace:
 mov eax,60
 mov edi,95
 syscall

.section .data
DATA_007754: .long FUNC_001532
DATA_007756: .long FUNC_001538
DATA_007734: .long FUNC_001495
DATA_007738: .long FUNC_001502
DATA_007210: .byte 0,0,0,0,4,0,0,0,10,0,0,0,25,0,0,0,45,0,0,0,80,0,0,0,150,0,0,0,250,0,0,0,144,1,0,0,88,2,0,0,6,0,0,0,12,0,0,0,24,0,0,0,36,0,0,0,0,0,0,0
.section .data
vertices_15:
.byte 1,0,31,25,50,0,1,0,31,25,188,0,1,0,37,0,75,0,1,0,37,0,181,0
collision_before_15:
.byte 0,0,132,12,128,62
collision_15:
.byte 16,128,2,4,6,7,8,10,12,13,14,16,0,0,1,0,31,25,50,0,1,0,31,25,188,0,1,0,37,0,75,0,1,0,37,0,181,0,1,0,31,244,68,0,1,0,31,244,188,0,1,0,28,23,51,0,1,0,32,8,66,0,1,0
physical_15:
.byte 165,10,157,249,0,0,8,0,4,0,14,0,40,0,11,64,1,0,0,0,1,128,0,1,144,1,100,0,224,1,100,0
descriptor_15:
.long 4845770
.long vertices_15
.long 32
.long 4846174
.long 22
.long 6
.long 0
.long 75
.long 17
.long 394758
.long 8
.long 19200
.long 7680
.long collision_15
.long physical_15
.long 0
.long 0
vertices_24:
.byte 1,0,0,0,0,0,156,59,124,247,1,0,28,0,22,0,41,0,55,0,21,64,1,0
collision_before_24:
.byte 0,0
collision_24:
.byte 128,128,0,23,0,0,0,0,1,0,0,0,0,0,156,59,124,247,1,0,28,0,22,0,41,0,55,0,21,64,1,0,2,0,2,11,0,1,220,5,50,0,12,254,250,0,20,5,0,0,32,3,0,0,36,0,30,0,64,0,34,0,160,6
physical_24:
.byte 156,59,124,247,1,0,28,0,22,0,41,0,55,0,21,64,1,0,2,0,2,11,0,1,220,5,50,0,12,254,250,0
descriptor_24:
.long 4851360
.long vertices_24
.long 2
.long 0
.long 2
.long 8
.long 0
.long 125
.long 19
.long 394758
.long 10
.long 10400
.long 5200
.long collision_24
.long physical_24
.long 0
.long 0
vertices_38:
.byte 1,0,12,0,29,0,1,0,46,255,0,0,1,0,49,253,241,0,1,0,34,6,241,0
collision_before_38:
.byte 0,0,120,5,144,51,121,5,144,51
collision_38:
.byte 160,128,23,141,0,195,0,76,16,128,2,16,12,4,5,6,7,8,9,10,11,14,15,0,0,0,1,0,12,0,29,0,1,0,46,255,0,0,1,0,49,253,241,0,1,0,34,6,241,0,1,0,0,10,241,0,1,0,0,10,9,0,1,0
physical_38:
.byte 148,42,25,241,2,1,100,0,80,0,124,0,150,0,35,64,1,0,4,0,3,12,2,0,214,6,200,0,232,3,244,1
descriptor_38:
.long 4864564
.long vertices_38
.long 92
.long 4865484
.long 18
.long 9
.long 0
.long 109
.long 23
.long 394758
.long 11
.long 18000
.long 4800
.long collision_38
.long physical_38
.long 0
.long 0
vertices_117:
.byte 1,0,14,0,0,0,1,0,0,0,71,0,1,0,0,23,0,0,1,0,0,0,0,0
collision_before_117:
.byte 0,0
collision_117:
.byte 16,130,255,6,2,4,0,2,0,0,0,80,128,0,0,0
descriptor_117:
.long 4922656
.long vertices_117
.long 8
.long 0
.long 2
.long 22
.long 1
.long 71
.long 37
.long 328965
.long 22
.long 6713
.long 4272
.long collision_117
.long 0
.long 0
.long 0
vertices_118:
.byte 1,0,66,0,0,0,1,0,0,0,66,0,1,0,0,66,0,0,1,0,0,0,0,0
collision_before_118:
.byte 0,0
collision_118:
.byte 16,130,255,6,2,4,0,2,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_118:
.long 4922782
.long vertices_118
.long 8
.long 0
.long 2
.long 22
.long 3
.long 73
.long 38
.long 394758
.long 24
.long 18798
.long 11962
.long collision_118
.long 0
.long 0
.long 0
vertices_119:
.byte 1,0,89,0,0,0,1,0,0,0,89,0,1,0,0,89,0,0,1,0,0,0,0,0
collision_before_119:
.byte 0,0
collision_119:
.byte 16,131,255,6,2,4,0,2,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_119:
.long 4923420
.long vertices_119
.long 8
.long 0
.long 2
.long 22
.long 2
.long 98
.long 39
.long 394758
.long 23
.long 25177
.long 16021
.long collision_119
.long 0
.long 0
.long 0
vertices_120:
.byte 1,0,59,0,0,0,1,0,0,0,59,0,1,0,0,59,0,0,1,0,0,0,0,0
collision_before_120:
.byte 0,0
collision_120:
.byte 16,130,255,6,2,4,0,2,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_120:
.long 4924058
.long vertices_120
.long 8
.long 0
.long 2
.long 22
.long 4
.long 65
.long 39
.long 394758
.long 25
.long 16784
.long 10681
.long collision_120
.long 0
.long 0
.long 0
vertices_121:
.byte 1,0,74,0,0,0,1,0,0,0,74,0,1,0,0,74,0,0,1,0,0,0,0,0
collision_before_121:
.byte 0,0
collision_121:
.byte 16,130,255,6,2,4,0,7,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_121:
.long 4924696
.long vertices_121
.long 8
.long 0
.long 2
.long 22
.long 4
.long 81
.long 39
.long 394758
.long 25
.long 20980
.long 13351
.long collision_121
.long 0
.long 0
.long 0
vertices_122:
.byte 1,0,108,0,0,0,1,0,0,0,108,0,1,0,0,108,0,0,1,0,0,0,0,0
collision_before_122:
.byte 0,0
collision_122:
.byte 16,131,255,6,2,4,0,7,0,0,0,80,128,0,0,0
descriptor_122:
.long 4925334
.long vertices_122
.long 8
.long 0
.long 2
.long 22
.long 2
.long 119
.long 37
.long 393730
.long 23
.long 30548
.long 19439
.long collision_122
.long 0
.long 0
.long 0
vertices_123:
.byte 1,0,90,0,0,0,1,0,0,0,90,0,1,0,0,90,0,0,1,0,0,0,0,0
collision_before_123:
.byte 0,0
collision_123:
.byte 16,131,255,6,2,4,0,7,0,0,0,80,128,0,0,0
descriptor_123:
.long 4925460
.long vertices_123
.long 8
.long 0
.long 2
.long 22
.long 4
.long 99
.long 39
.long 395272
.long 25
.long 25386
.long 16155
.long collision_123
.long 0
.long 0
.long 0
vertices_124:
.byte 1,0,90,0,0,0,1,0,0,0,90,0,1,0,0,90,0,0,1,0,0,0,0,0
collision_before_124:
.byte 0,0
collision_124:
.byte 16,130,255,6,2,4,0,7,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_124:
.long 4925586
.long vertices_124
.long 8
.long 0
.long 2
.long 22
.long 3
.long 99
.long 36
.long 263688
.long 24
.long 25386
.long 16155
.long collision_124
.long 0
.long 0
.long 0
vertices_125:
.byte 1,0,101,0,0,0,1,0,0,0,101,0,1,0,0,101,0,0,1,0,0,0,0,0
collision_before_125:
.byte 0,0
collision_125:
.byte 16,131,255,6,2,4,0,0,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_125:
.long 4926224
.long vertices_125
.long 8
.long 0
.long 2
.long 22
.long 3
.long 111
.long 38
.long 394758
.long 24
.long 28533
.long 18157
.long collision_125
.long 0
.long 0
.long 0
vertices_126:
.byte 1,0,90,0,0,0,1,0,0,0,90,0,1,0,0,90,0,0,1,0,0,0,0,0
collision_before_126:
.byte 0,0
collision_126:
.byte 16,131,255,6,2,4,0,0,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_126:
.long 4926862
.long vertices_126
.long 8
.long 0
.long 2
.long 22
.long 4
.long 99
.long 40
.long 263688
.long 25
.long 25596
.long 16288
.long collision_126
.long 0
.long 0
.long 0
vertices_127:
.byte 1,0,93,0,0,0,1,0,0,0,93,0,1,0,0,93,0,0,1,0,0,0,0,0
collision_before_127:
.byte 0,0
collision_127:
.byte 16,131,255,6,2,4,0,10,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_127:
.long 4927500
.long vertices_127
.long 8
.long 0
.long 2
.long 22
.long 4
.long 103
.long 39
.long 526344
.long 25
.long 26435
.long 16822
.long collision_127
.long 0
.long 0
.long 0
vertices_128:
.byte 1,0,89,0,0,0,1,0,0,0,89,0,1,0,0,89,0,0,1,0,0,0,0,0
collision_before_128:
.byte 0,0
collision_128:
.byte 16,131,255,6,2,4,0,0,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_128:
.long 4928138
.long vertices_128
.long 8
.long 0
.long 2
.long 22
.long 4
.long 98
.long 40
.long 525830
.long 25
.long 25177
.long 16021
.long collision_128
.long 0
.long 0
.long 0
vertices_129:
.byte 1,0,105,0,0,0,1,0,0,0,105,0,1,0,0,105,0,0,1,0,0,0,0,0
collision_before_129:
.byte 0,0
collision_129:
.byte 16,131,255,6,2,4,0,4,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_129:
.long 4928776
.long vertices_129
.long 8
.long 0
.long 2
.long 22
.long 4
.long 116
.long 40
.long 394760
.long 25
.long 29792
.long 18959
.long collision_129
.long 0
.long 0
.long 0
vertices_130:
.byte 1,0,96,0,0,0,1,0,0,0,96,0,1,0,0,96,0,0,1,0,0,0,0,0
collision_before_130:
.byte 0,0
collision_130:
.byte 16,131,255,6,2,4,0,11,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_130:
.long 4929414
.long vertices_130
.long 8
.long 0
.long 2
.long 22
.long 4
.long 106
.long 40
.long 395272
.long 25
.long 27275
.long 17356
.long collision_130
.long 0
.long 0
.long 0
vertices_131:
.byte 1,0,90,0,0,0,1,0,0,0,90,0,1,0,0,90,0,0,1,0,0,0,0,0
collision_before_131:
.byte 0,0
collision_131:
.byte 16,131,255,6,2,4,0,13,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_131:
.long 4930052
.long vertices_131
.long 8
.long 0
.long 2
.long 22
.long 4
.long 99
.long 40
.long 395270
.long 25
.long 25596
.long 16288
.long collision_131
.long 0
.long 0
.long 0
vertices_132:
.byte 1,0,105,0,0,0,1,0,0,0,105,0,1,0,0,105,0,0,1,0,0,0,0,0
collision_before_132:
.byte 0,0
collision_132:
.byte 16,131,255,6,2,4,0,4,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_132:
.long 4930690
.long vertices_132
.long 8
.long 0
.long 2
.long 22
.long 4
.long 116
.long 40
.long 394760
.long 25
.long 29792
.long 18959
.long collision_132
.long 0
.long 0
.long 0
vertices_133:
.byte 1,0,81,0,0,0,1,0,0,0,81,0,1,0,0,81,0,0,1,0,0,0,0,0
collision_before_133:
.byte 0,0
collision_133:
.byte 16,131,255,6,2,4,0,12,0,7,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,125,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,227,8,12,0,64,0,244,0,179,255,255,255,206,0,255,255,47,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,170,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,186,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,204,9,12,0,64,0,244,0,179,255,255,255,206,0,255,255,72,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,79,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,121,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,189,10,12,0,64,0,244,0,179,255,255,255,206,0,255,255,86,11,12,0,64,0,244,0,179,255,255,255,206,0,255,255,64,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,124,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,174,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,217,12,12,0,64,0,244,0,179,255,255,255,206,0,255,255,0,0,80,128,0,0,0
descriptor_133:
.long 4931328
.long vertices_133
.long 8
.long 0
.long 2
.long 22
.long 4
.long 90
.long 39
.long 525832
.long 25
.long 23078
.long 14686
.long collision_133
.long 0
.long 0
.long 0
vertices_134:
.byte 1,0,14,0,0,0,1,0,0,0,14,0,1,0,0,12,0,0,1,0,0,0,0,0
collision_before_134:
.byte 0,0
collision_134:
.byte 16,131,255,6,2,4,0,3,0,0,0,80,128,0,0,0
descriptor_134:
.long 4931966
.long vertices_134
.long 8
.long 0
.long 2
.long 22
.long 10
.long 116
.long 45
.long 263688
.long 31
.long 3999
.long 2545
.long collision_134
.long 0
.long 0
.long 0
vertices_135:
.byte 1,0,113,0,0,0,1,0,0,0,113,0,1,0,0,107,0,0,1,0,0,0,0,0
collision_before_135:
.byte 0,0
collision_135:
.byte 16,131,255,6,2,4,0,6,0,0,0,80,128,0,0,0
descriptor_135:
.long 4932124
.long vertices_135
.long 8
.long 0
.long 2
.long 22
.long 6
.long 124
.long 41
.long 525830
.long 27
.long 31995
.long 20360
.long collision_135
.long 0
.long 0
.long 0
vertices_136:
.byte 1,0,28,0,0,0,1,0,0,0,28,0,1,0,0,21,0,0,1,0,0,0,0,0
collision_before_136:
.byte 0,0
collision_136:
.byte 16,131,255,6,2,4,0,5,0,0,0,80,128,0,0,0
descriptor_136:
.long 4932286
.long vertices_136
.long 8
.long 0
.long 2
.long 22
.long 10
.long 118
.long 46
.long 395272
.long 35
.long 7998
.long 5090
.long collision_136
.long 0
.long 0
.long 0
vertices_137:
.byte 1,0,28,0,0,0,1,0,0,0,28,0,1,0,0,21,0,0,1,0,0,0,0,0
collision_before_137:
.byte 0,0
collision_137:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_137:
.long 4932448
.long vertices_137
.long 8
.long 0
.long 2
.long 22
.long 11
.long 118
.long 50
.long 159
.long 34
.long 7998
.long 5090
.long collision_137
.long 0
.long 0
.long 0
vertices_138:
.byte 1,0,81,0,0,0,1,0,0,0,81,0,1,0,0,75,0,0,1,0,0,0,0,0
collision_before_138:
.byte 0,0
collision_138:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_138:
.long 4932598
.long vertices_138
.long 8
.long 0
.long 2
.long 22
.long 11
.long 89
.long 63
.long 264095
.long 32
.long 22947
.long 14603
.long collision_138
.long 0
.long 0
.long 0
vertices_139:
.byte 1,0,90,0,0,0,1,0,0,0,90,0,1,0,0,72,0,0,1,0,0,0,0,0
collision_before_139:
.byte 0,0
collision_139:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_139:
.long 4932724
.long vertices_139
.long 8
.long 0
.long 2
.long 22
.long 17
.long 100
.long 69
.long 264095
.long 38
.long 25611
.long 16298
.long collision_139
.long 0
.long 0
.long 0
vertices_140:
.byte 1,0,58,0,0,0,1,0,0,0,58,0,1,0,0,55,0,0,1,0,0,0,0,0
collision_before_140:
.byte 0,0
collision_140:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_140:
.long 4932850
.long vertices_140
.long 8
.long 0
.long 2
.long 22
.long 12
.long 64
.long 64
.long 396207
.long 33
.long 16391
.long 10430
.long collision_140
.long 0
.long 0
.long 0
vertices_141:
.byte 1,0,75,0,0,0,1,0,0,0,75,0,1,0,0,74,0,0,1,0,0,0,0,0
collision_before_141:
.byte 0,0
collision_141:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_141:
.long 4932976
.long vertices_141
.long 8
.long 0
.long 2
.long 22
.long 12
.long 83
.long 64
.long 397247
.long 33
.long 21308
.long 13560
.long collision_141
.long 0
.long 0
.long 0
vertices_142:
.byte 1,0,58,0,0,0,1,0,0,0,58,0,1,0,0,34,0,0,1,0,0,0,0,0
collision_before_142:
.byte 0,0
collision_142:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_142:
.long 4933102
.long vertices_142
.long 8
.long 0
.long 2
.long 22
.long 13
.long 64
.long 65
.long 987023
.long 34
.long 16391
.long 10430
.long collision_142
.long 0
.long 0
.long 0
vertices_143:
.byte 1,0,72,0,0,0,1,0,0,0,72,0,1,0,0,65,0,0,1,0,0,0,0,0
collision_before_143:
.byte 0,0
collision_143:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_143:
.long 4933228
.long vertices_143
.long 8
.long 0
.long 2
.long 22
.long 14
.long 80
.long 66
.long 987021
.long 35
.long 20489
.long 13038
.long collision_143
.long 0
.long 0
.long 0
vertices_144:
.byte 1,0,58,0,0,0,1,0,0,0,58,0,1,0,0,43,0,0,1,0,0,0,0,0
collision_before_144:
.byte 0,0
collision_144:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_144:
.long 4933354
.long vertices_144
.long 8
.long 0
.long 2
.long 22
.long 16
.long 64
.long 68
.long 987083
.long 37
.long 16391
.long 10430
.long collision_144
.long 0
.long 0
.long 0
vertices_145:
.byte 1,0,68,0,0,0,1,0,0,0,68,0,1,0,0,61,0,0,1,0,0,0,0,0
collision_before_145:
.byte 0,0
collision_145:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_145:
.long 4933480
.long vertices_145
.long 8
.long 0
.long 2
.long 22
.long 19
.long 75
.long 71
.long 396207
.long 40
.long 19208
.long 12223
.long collision_145
.long 0
.long 0
.long 0
vertices_146:
.byte 1,0,68,0,0,0,1,0,0,0,40,0,1,0,0,68,0,0,1,0,0,0,0,0
collision_before_146:
.byte 0,0
collision_146:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_146:
.long 4933606
.long vertices_146
.long 8
.long 0
.long 2
.long 22
.long 19
.long 75
.long 71
.long 133550
.long 40
.long 19208
.long 12223
.long collision_146
.long 0
.long 0
.long 0
vertices_147:
.byte 1,0,90,0,0,0,1,0,0,0,72,0,1,0,0,90,0,0,1,0,0,0,0,0
collision_before_147:
.byte 0,0
collision_147:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_147:
.long 4933732
.long vertices_147
.long 8
.long 0
.long 2
.long 22
.long 17
.long 100
.long 69
.long 987082
.long 38
.long 25611
.long 16298
.long collision_147
.long 0
.long 0
.long 0
vertices_148:
.byte 1,0,3,0,0,0,1,0,0,0,3,0,1,0,0,1,0,0,1,0,0,0,0,0
collision_before_148:
.byte 0,0
collision_148:
.byte 16,131,255,6,2,4,0,9,0,0,0,80,128,0,0,0
descriptor_148:
.long 4933858
.long vertices_148
.long 8
.long 0
.long 2
.long 22
.long 12
.long 118
.long 59
.long 986584
.long 36
.long 799
.long 509
.long collision_148
.long 0
.long 0
.long 0
DATA_004681:
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long descriptor_15
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long descriptor_24
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long descriptor_38
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long descriptor_117
.long descriptor_118
.long descriptor_119
.long descriptor_120
.long descriptor_121
.long descriptor_122
.long descriptor_123
.long descriptor_124
.long descriptor_125
.long descriptor_126
.long descriptor_127
.long descriptor_128
.long descriptor_129
.long descriptor_130
.long descriptor_131
.long descriptor_132
.long descriptor_133
.long descriptor_134
.long descriptor_135
.long descriptor_136
.long descriptor_137
.long descriptor_138
.long descriptor_139
.long descriptor_140
.long descriptor_141
.long descriptor_142
.long descriptor_143
.long descriptor_144
.long descriptor_145
.long descriptor_146
.long descriptor_147
.long descriptor_148
.long 0
DATA_008804: .long 0
DATA_008807: .long 0

.section .bss
.balign 16
input_full: .zero 800
output_guard_before: .zero 8
output_full: .zero 1024
output_guard_after: .zero 8
player_guard_before: .zero 8
player: .zero 338
player_guard_after: .zero 8
parent_guard_before: .zero 8
parent: .zero 338
parent_guard_after: .zero 8
relative_guard_before: .zero 8
relative: .zero 24
relative_guard_after: .zero 8
query_count_full: .zero 4
volume_count: .zero 4

.section .text
FUNC_000581:
 push rbp
 mov rbp,rsp
 push rax
 push rdx
 pushfq
 mov edx,DWORD PTR [rbp+48]
 mov eax,DWORD PTR [edx+24]
 mov DWORD PTR [output_full+960],eax
 mov eax,DWORD PTR [edx]
 mov DWORD PTR [output_full+964],eax
 mov eax,DWORD PTR [edx+4]
 mov DWORD PTR [output_full+968],eax
 mov eax,DWORD PTR [edx+8]
 mov DWORD PTR [output_full+972],eax
 popfq
 pop rdx
 pop rax
 push QWORD PTR [rbp+48]
 push QWORD PTR [rbp+40]
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call RootOriginalF581
 lea rsp,[rsp+40]
 pushfq
 push rax
 push rdx
 mov eax,DWORD PTR [DATA_009269]
 mov DWORD PTR [output_full+976],eax
 mov eax,DWORD PTR [DATA_009273]
 mov DWORD PTR [output_full+980],eax
 mov edx,DWORD PTR [rbp+16]
 mov eax,DWORD PTR [edx]
 mov DWORD PTR [output_full+984],eax
 movzx eax,BYTE PTR [DATA_008707]
 mov DWORD PTR [output_full+988],eax
 pop rdx
 pop rax
 popfq
 pop rbp
 ret
