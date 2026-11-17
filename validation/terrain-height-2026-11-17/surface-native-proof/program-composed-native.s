.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000582:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],582
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
pushfq
push rax
push rdx
mov eax,DWORD PTR [depth]
cmp eax,16
jae failed
mov edx,DWORD PTR [rbp+32]
mov DWORD PTR [program_bases+rax*4],edx
inc DWORD PTR [depth]
pop rdx
pop rax
popfq
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
pushfq
push rax
push rdx
mov eax,DWORD PTR [depth]
dec eax
mov DWORD PTR [depth],eax
mov edx,esi
sub edx,DWORD PTR [program_bases+rax*4]
test eax,eax
jnz inner_cursor
mov DWORD PTR [cursor],edx
inner_cursor:
pop rdx
pop rax
popfq
pop rdi
pop rsi
pop rbx
pop rcx
pop rcx
pop rbp
ret
FUNC_001822:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],1822
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

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
FUNC_000583:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],583
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

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
setnl al
and eax,+0x1
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
FUNC_000580:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],580
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

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
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],1538
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq
mov eax,DWORD PTR [rsp+8]
cmp eax,255
ja failed
mov eax,DWORD PTR [model_table+rax*4]
test eax,eax
jz failed
ret
_abs:
push rbp
mov rbp,rsp
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

FUNC_000581:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],581
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov eax,DWORD PTR [obs_count]
cmp eax,8
jae failed
imul ecx,eax,80
add ecx,OFFSET FLAT:input+36864
mov QWORD PTR [active_script],rcx
imul edx,eax,512
add edx,OFFSET FLAT:output+1024
mov QWORD PTR [active_record],rdx
mov eax,DWORD PTR [depth]
dec eax
mov ebx,DWORD PTR [program_bases+rax*4]
mov eax,DWORD PTR [rbp+24]
sub eax,ebx
mov DWORD PTR [rdx],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [rdx+4],eax
mov eax,DWORD PTR [rcx]
mov DWORD PTR [rdx+8],eax
mov eax,DWORD PTR [rcx+4]
mov DWORD PTR [rdx+12],eax
mov DWORD PTR [rdx+16],ebx
mov esi,DWORD PTR [rbp+48]
lea edi,[rdx+20]
mov ecx,28
rep movsb
mov r8,QWORD PTR [active_record]
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [r8+48],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [r8+52],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [r8+56],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [r8+60],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [r8+64],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [r8+68],eax
mov eax,DWORD PTR [DATA_008702]
mov DWORD PTR [r8+72],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [r8+76],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [r8+80],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [r8+84],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [r8+88],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [r8+92],eax
mov r9,QWORD PTR [active_script]
test DWORD PTR [r9+8],1
jz terrain_write_done_0
mov eax,DWORD PTR [r9+16]
mov BYTE PTR [DATA_008696],al
terrain_write_done_0:
test DWORD PTR [r9+8],2
jz terrain_write_done_1
mov eax,DWORD PTR [r9+20]
mov BYTE PTR [DATA_008697],al
terrain_write_done_1:
test DWORD PTR [r9+8],4
jz terrain_write_done_2
mov eax,DWORD PTR [r9+24]
mov BYTE PTR [DATA_008698],al
terrain_write_done_2:
test DWORD PTR [r9+8],8
jz terrain_write_done_3
mov eax,DWORD PTR [r9+28]
mov BYTE PTR [DATA_008699],al
terrain_write_done_3:
test DWORD PTR [r9+8],16
jz terrain_write_done_4
mov eax,DWORD PTR [r9+32]
mov BYTE PTR [DATA_008700],al
terrain_write_done_4:
test DWORD PTR [r9+8],32
jz terrain_write_done_5
mov eax,DWORD PTR [r9+36]
mov BYTE PTR [DATA_008701],al
terrain_write_done_5:
test DWORD PTR [r9+8],64
jz terrain_write_done_6
mov eax,DWORD PTR [r9+40]
mov DWORD PTR [DATA_008702],eax
terrain_write_done_6:
test DWORD PTR [r9+8],128
jz terrain_write_done_7
mov eax,DWORD PTR [r9+44]
mov DWORD PTR [DATA_008703],eax
terrain_write_done_7:
test DWORD PTR [r9+8],256
jz terrain_write_done_8
mov eax,DWORD PTR [r9+48]
mov DWORD PTR [DATA_008704],eax
terrain_write_done_8:
test DWORD PTR [r9+8],512
jz terrain_write_done_9
mov eax,DWORD PTR [r9+52]
mov DWORD PTR [DATA_008705],eax
terrain_write_done_9:
test DWORD PTR [r9+8],1024
jz terrain_write_done_10
mov eax,DWORD PTR [r9+56]
mov DWORD PTR [DATA_008706],eax
terrain_write_done_10:
test DWORD PTR [r9+8],2048
jz terrain_write_done_11
mov eax,DWORD PTR [r9+60]
mov BYTE PTR [DATA_008707],al
terrain_write_done_11:
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [r8+96],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [r8+100],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [r8+104],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [r8+108],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [r8+112],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [r8+116],eax
mov eax,DWORD PTR [DATA_008702]
mov DWORD PTR [r8+120],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [r8+124],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [r8+128],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [r8+132],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [r8+136],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [r8+140],eax
mov esi,DWORD PTR [rbp+32]
lea edi,[r8+144]
mov ecx,338
rep movsb
mov r9,QWORD PTR [active_script]
mov edx,DWORD PTR [rbp+16]
mov eax,DWORD PTR [r9]
mov DWORD PTR [rdx],eax
mov eax,ebx
add eax,DWORD PTR [r9+4]
inc DWORD PTR [obs_count]
pop rdi
pop rsi
pop rbx
pop rbp
ret

_start:
mov esp,OFFSET FLAT:stack_end
cld
next_case:
mov esp,OFFSET FLAT:stack_end
xor r8d,r8d
read_more:
xor eax,eax
xor edi,edi
lea rsi,[input+r8]
mov edx,37888
sub edx,r8d
syscall
test eax,eax
jle finished
add r8d,eax
cmp r8d,37888
jne read_more
mov edi,OFFSET FLAT:output
mov ecx,5184
mov al,0xa5
rep stosb
mov edi,OFFSET FLAT:model_table
mov ecx,1024
xor eax,eax
rep stosb
mov DWORD PTR [order_count],0
mov DWORD PTR [depth],0
mov DWORD PTR [obs_count],0
mov eax,DWORD PTR [input+16]
mov BYTE PTR [DATA_008696],al
mov eax,DWORD PTR [input+20]
mov BYTE PTR [DATA_008697],al
mov eax,DWORD PTR [input+24]
mov BYTE PTR [DATA_008698],al
mov eax,DWORD PTR [input+28]
mov BYTE PTR [DATA_008699],al
mov eax,DWORD PTR [input+32]
mov BYTE PTR [DATA_008700],al
mov eax,DWORD PTR [input+36]
mov BYTE PTR [DATA_008701],al
mov eax,DWORD PTR [input+40]
mov DWORD PTR [DATA_008702],eax
mov eax,DWORD PTR [input+44]
mov DWORD PTR [DATA_008703],eax
mov eax,DWORD PTR [input+48]
mov DWORD PTR [DATA_008704],eax
mov eax,DWORD PTR [input+52]
mov DWORD PTR [DATA_008705],eax
mov eax,DWORD PTR [input+56]
mov DWORD PTR [DATA_008706],eax
mov eax,DWORD PTR [input+60]
mov BYTE PTR [DATA_008707],al
mov eax,DWORD PTR [input+4]
mov DWORD PTR [primitive],eax
mov esi,OFFSET FLAT:input+64
mov edi,OFFSET FLAT:body
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:input+416
mov edi,OFFSET FLAT:context
mov ecx,12
rep movsb
mov eax,DWORD PTR [input+428]
mov DWORD PTR [context+20],eax
mov eax,DWORD PTR [input+432]
mov DWORD PTR [context+24],eax
mov eax,DWORD PTR [input+436]
add eax,OFFSET FLAT:normals
mov DWORD PTR [context+12],eax
mov eax,DWORD PTR [input+440]
add eax,OFFSET FLAT:vertices
mov DWORD PTR [context+16],eax
mov esi,OFFSET FLAT:input+512
mov edi,OFFSET FLAT:program
mov ecx,512
rep movsb
mov esi,OFFSET FLAT:input+1024
mov edi,OFFSET FLAT:normals
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:input+2048
mov edi,OFFSET FLAT:vertices
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:input+4096
mov edi,OFFSET FLAT:models
mov ecx,32768
rep movsb
xor ebx,ebx
model_loop:
cmp ebx,8
jae models_ready
mov eax,ebx
shl eax,12
add eax,OFFSET FLAT:models
cmp DWORD PTR [eax+4],0
je model_next
mov ecx,DWORD PTR [eax]
cmp ecx,255
ja failed
lea edx,[eax+8]
mov DWORD PTR [model_table+rcx*4],edx
lea edx,[eax+1664]
add edx,DWORD PTR [eax+80]
mov DWORD PTR [eax+12],edx
lea edx,[eax+640]
add edx,DWORD PTR [eax+76]
mov DWORD PTR [eax+20],edx
lea edx,[eax+128]
mov DWORD PTR [eax+60],edx
model_next:
inc ebx
jmp model_loop
models_ready:
mov esi,OFFSET FLAT:readonly_begin
mov edi,OFFSET FLAT:readonly_copy
mov ecx,readonly_end-readonly_begin
rep movsb
mov eax,DWORD PTR [input]
push rax
push OFFSET FLAT:body
push OFFSET FLAT:program
push OFFSET FLAT:context
push OFFSET FLAT:primitive
call FUNC_000582
add rsp,40
and eax,255
mov DWORD PTR [output+4],eax
mov eax,DWORD PTR [primitive]
and eax,255
mov DWORD PTR [output+8],eax
mov eax,DWORD PTR [cursor]
mov DWORD PTR [output+12],eax
mov eax,DWORD PTR [obs_count]
mov DWORD PTR [output+16],eax
mov eax,DWORD PTR [order_count]
mov DWORD PTR [output+20],eax
mov DWORD PTR [output],0x50524f47
mov DWORD PTR [output+24],0
mov DWORD PTR [output+28],0
mov DWORD PTR [output+32],OFFSET FLAT:program
mov DWORD PTR [output+36],OFFSET FLAT:normals
mov DWORD PTR [output+40],OFFSET FLAT:vertices
mov DWORD PTR [output+44],OFFSET FLAT:models
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [output+64],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [output+68],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [output+72],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [output+76],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [output+80],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [output+84],eax
mov eax,DWORD PTR [DATA_008702]
mov DWORD PTR [output+88],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [output+92],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [output+96],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [output+100],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [output+104],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [output+108],eax
mov esi,OFFSET FLAT:body
mov edi,OFFSET FLAT:output+128
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:order
mov edi,OFFSET FLAT:output+512
mov ecx,DWORD PTR [order_count]
shl ecx,2
rep movsb
mov esi,OFFSET FLAT:readonly_begin
mov edi,OFFSET FLAT:readonly_copy
mov ecx,readonly_end-readonly_begin
repe cmpsb
jne failed
xor r8d,r8d
write_more:
mov eax,1
mov edi,1
lea rsi,[output+r8]
mov edx,5184
sub edx,r8d
syscall
test eax,eax
jle failed
add r8d,eax
cmp r8d,5184
jb write_more
jmp next_case
failed:
mov eax,60
mov edi,91
syscall
finished:
mov eax,60
xor edi,edi
syscall

.section .data
DATA_007756: .quad FUNC_001538
.section .bss
.balign 16
input: .zero 37888
output: .zero 5184
order_count: .zero 4
order: .zero 512
depth: .zero 4
program_bases: .zero 64
cursor: .zero 4
obs_count: .zero 4
primitive: .zero 4
returned: .zero 4
active_record: .zero 8
active_script: .zero 8
model_table: .zero 1024
DATA_008696: .zero 1
DATA_008697: .zero 1
DATA_008698: .zero 1
DATA_008699: .zero 1
DATA_008700: .zero 1
DATA_008701: .zero 1
DATA_008702: .zero 4
DATA_008703: .zero 4
DATA_008704: .zero 4
DATA_008705: .zero 4
DATA_008706: .zero 4
DATA_008707: .zero 1

.balign 16
readonly_begin:
body: .zero 338
context: .zero 28
program: .zero 512
normals: .zero 1024
vertices: .zero 1024
models: .zero 32768
readonly_end:
readonly_copy: .zero readonly_end-readonly_begin
.balign 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
