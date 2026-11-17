.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000571:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],571
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-12
mov eax,[rbp+16]
mov edx,[eax+0x18]
mov [rbp-0xc],edx
mov edx,[eax+0x1c]
mov [rbp-0x8],edx
mov edx,[eax+0x20]
mov [rbp-0x4],edx
mov edx,[eax+0xc]
mov [eax+0x18],edx
mov edx,[eax+0x10]
mov [eax+0x1c],edx
mov edx,[eax+0x14]
mov [eax+0x20],edx
mov edx,[rbp-0xc]
mov [eax+0xc],edx
mov edx,[rbp-0x8]
mov [eax+0x10],edx
mov edx,[rbp-0x4]
mov [eax+0x14],edx
neg DWORD PTR [eax]
neg DWORD PTR [eax+0x4]
neg DWORD PTR [eax+0x8]
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
call dos_abs
pop rcx
mov [esi],eax
push QWORD PTR [rbx+0x4]
call dos_abs
pop rcx
mov [esi+0x4],eax
push QWORD PTR [rbx+0x8]
call dos_abs
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
FUNC_001501:
push rbp
mov rbp,rsp
push rbx
mov ecx,[rbp+24]
mov ebx,[rbp+16]
mov eax,0x1
test ebx,ebx
jnl JUMP_005667
mov edx,ebx
neg edx
jmp JUMP_005668
JUMP_005667:
mov edx,ebx
JUMP_005668:
add edx,edx
add eax,eax
cmp ecx,edx
ja JUMP_005669
sub edx,ecx
inc eax
JUMP_005669:
test eax,eax
jg JUMP_005668
and eax,0x7fffffff
test ebx,ebx
jnl JUMP_005670
mov edx,eax
neg edx
jmp JUMP_005671
JUMP_005670:
mov edx,eax
JUMP_005671:
mov eax,edx
pop rbx
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
FUNC_001503:
push rbp
mov rbp,rsp
push rbx
push rsi
mov ebx,[rbp+16]
push QWORD PTR [rbx]
call QWORD PTR [DATA_007737]
pop rcx
mov esi,eax
push QWORD PTR [rbx+0x4]
call QWORD PTR [DATA_007737]
pop rcx
add esi,eax
push QWORD PTR [rbx+0x8]
call QWORD PTR [DATA_007737]
pop rcx
add esi,eax
push rsi
push QWORD PTR [rbp+24]
push rbx
call FUNC_001504
add rsp,24
pop rsi
pop rbx
pop rbp
ret
FUNC_001504:
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov esi,[rbp+32]
mov edi,[rbp+24]
mov ebx,[rbp+16]
add esi,esi
push rsi
call QWORD PTR [DATA_007738]
pop rcx
mov esi,eax
push rdi
push rsi
push QWORD PTR [rbx]
call FUNC_001501
add rsp,16
push rax
call FUNC_001521
add rsp,16
mov [ebx],eax
push rdi
push rsi
push QWORD PTR [rbx+0x4]
call FUNC_001501
add rsp,16
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x4],eax
push rdi
push rsi
push QWORD PTR [rbx+0x8]
call FUNC_001501
add rsp,16
push rax
call FUNC_001521
add rsp,16
mov [ebx+0x8],eax
pop rdi
pop rsi
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
FUNC_001520:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],1520
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

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
FUNC_001522:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
imul eax
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

push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov eax,[eax*4+DATA_004681]
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
FUNC_000575:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],575
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-212
push rbx
push rsi
push rdi
mov edi,[rbp+32]
mov ebx,[rbp+24]
mov esi,[rbp+16]
push rsi
push rdi
lea edi,[rbp-0x38]
mov ecx,0x6
rep movsd
lea eax,[rbp-0x38]
mov DWORD PTR [local_relative],eax
pop rdi
pop rsi
push rsi
push rsi
call FUNC_001664
add rsp,16
push QWORD PTR [rsi+0xc]
push QWORD PTR [rsi+0x8]
push QWORD PTR [rsi+0x4]
push QWORD PTR [rsi]
lea eax,[rbp-0x8]
push rax
call FUNC_001333
add rsp,40
push QWORD PTR [rsi+0x14]
push QWORD PTR [rsi+0x10]
push QWORD PTR [rbp-0x4]
push QWORD PTR [rbp-0x8]
lea eax,[rbp-0x8]
push rax
call FUNC_001333
add rsp,40
push -0x1
lea eax,[rbp-0x8]
push rax
call FUNC_001341
add rsp,16
push QWORD PTR [rbx+0x13c]
push QWORD PTR [rbx+0x138]
push QWORD PTR [rbp-0x4]
push QWORD PTR [rbp-0x8]
lea eax,[rbp-0x8]
push rax
call FUNC_001335
add rsp,40
cmp DWORD PTR [rbp-0x4],+0x0
jl JUMP_002404
push QWORD PTR [rdi+0x13c]
push QWORD PTR [rdi+0x138]
push QWORD PTR [rbp-0x4]
push QWORD PTR [rbp-0x8]
lea eax,[rbp-0x8]
push rax
call FUNC_001335
add rsp,40
cmp DWORD PTR [rbp-0x4],+0x0
jl JUMP_002404
xor eax,eax
jmp JUMP_002432
JUMP_002404:
mov BYTE PTR [DATA_008707],0x0
cmp BYTE PTR [edi+0x14c],0x0
jnl JUMP_002406
lea eax,[rbp-0x38]
push rax
push rdi
push rbx
call FUNC_000576
add rsp,24
test eax,eax
jnz JUMP_002405
cmp BYTE PTR [DATA_008707],0x0
jnz JUMP_002410
push rdi
push rbx
call FUNC_000578
add rsp,16
mov al,[DATA_008696]
jmp JUMP_002432
JUMP_002405:
mov al,[DATA_008696]
jmp JUMP_002432
JUMP_002406:
push rsi
lea eax,[rbp-0x38]
mov edx,0x5
JUMP_002407:
push QWORD PTR [rax+rdx*4]
dec edx
jns JUMP_002407
push rdi
push rbx
lea eax,[rbp-0xc]
push rax
call FUNC_000577
add rsp,80
test eax,eax
jnz JUMP_002409
mov al,[edi+0x86]
cmp al,[ebx+0x56]
jz JUMP_002408
push rdi
push rbx
call FUNC_000578
add rsp,16
mov al,[DATA_008696]
jmp JUMP_002432
JUMP_002408:
mov BYTE PTR [DATA_008707],0x2
jmp JUMP_002410
JUMP_002409:
mov al,[DATA_008696]
jmp JUMP_002432
JUMP_002410:
or BYTE PTR [DATA_008696],0x2
mov eax,[ebx+0x8c]
push rax
call dos_abs
pop rcx
mov esi,eax
mov eax,[ebx+0x90]
push rax
call dos_abs
pop rcx
add esi,eax
mov eax,[ebx+0x94]
push rax
call dos_abs
pop rcx
add esi,eax
mov [rbp-0x10],esi
cmp BYTE PTR [DATA_008707],0x1
jnz JUMP_002411
push rdi
lea esi,[rbp-0x38]
lea edi,[rbp-0x50]
mov ecx,0x6
rep movsd
pop rdi
push +0x1c
lea eax,[rbp-0x50]
push rax
call FUNC_001658
add rsp,16
mov eax,[rbp-0x50]
mov [rbp-0x80],eax
mov eax,[rbp-0x48]
mov [rbp-0x7c],eax
mov eax,[rbp-0x40]
mov [rbp-0x78],eax
push 0x7fffffff
lea eax,[rbp-0x80]
push rax
call FUNC_001503
add rsp,16
jmp JUMP_002412
JUMP_002411:
mov eax,[rbp-0x38]
mov [rbp-0x80],eax
mov eax,[rbp-0x30]
mov [rbp-0x7c],eax
mov eax,[rbp-0x28]
mov [rbp-0x78],eax
lea eax,[rbp-0x80]
push rax
lea eax,[rbp-0x80]
push rax
call FUNC_001519
add rsp,16
JUMP_002412:
mov eax,[rbp-0x80]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov esi,eax
mov eax,[rbp-0x7c]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add esi,eax
mov eax,[rbp-0x78]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add esi,eax
mov eax,esi
cmp DWORD PTR [rbp-0x10],0x258
jg JUMP_002413
cmp WORD PTR [ebx+0x9e],0xffff
jnz JUMP_002413
cmp eax,0x78000000
jl JUMP_002413
or BYTE PTR [DATA_008696],0x40
and BYTE PTR [DATA_008696],0x7f
mov BYTE PTR [DATA_008699],0x0
jmp JUMP_002414
JUMP_002413:
mov al,[DATA_008700]
mov [DATA_008699],al
JUMP_002414:
mov eax,[ebx+0x82]
push rax
call QWORD PTR [DATA_007756]
pop rcx
mov [rbp-0x18],eax
mov eax,[edi+0x82]
push rax
call QWORD PTR [DATA_007756]
pop rcx
mov edx,eax
cmp BYTE PTR [DATA_008707],0x1
jnz JUMP_002418
push QWORD PTR [DATA_008706]
push QWORD PTR [DATA_008705]
push QWORD PTR [rbx+0x144]
push QWORD PTR [rbx+0x140]
lea eax,[rbp-0x20]
push rax
call FUNC_001335
add rsp,40
mov eax,[rbp-0x20]
push rax
mov eax,[rbp-0x80]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x98],eax
mov eax,[rbp-0x20]
push rax
mov eax,[rbp-0x7c]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x90],eax
mov eax,[rbp-0x20]
push rax
mov eax,[rbp-0x78]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x88],eax
or eax,-0x1
cmp DWORD PTR [rbp-0x98],+0x0
jl JUMP_002415
inc eax
JUMP_002415:
mov [rbp-0x94],eax
or eax,-0x1
cmp DWORD PTR [rbp-0x90],+0x0
jl JUMP_002416
inc eax
JUMP_002416:
mov [rbp-0x8c],eax
or eax,-0x1
cmp DWORD PTR [rbp-0x88],+0x0
jl JUMP_002417
inc eax
JUMP_002417:
mov [rbp-0x84],eax
push QWORD PTR [rbp-0x94]
push QWORD PTR [rbp-0x98]
push QWORD PTR [rbx+0x42]
push QWORD PTR [rbx+0x3e]
lea eax,[ebx+0x3e]
push rax
call FUNC_001333
add rsp,40
push QWORD PTR [rbp-0x8c]
push QWORD PTR [rbp-0x90]
push QWORD PTR [rbx+0x4a]
push QWORD PTR [rbx+0x46]
lea eax,[ebx+0x46]
push rax
call FUNC_001333
add rsp,40
push QWORD PTR [rbp-0x84]
push QWORD PTR [rbp-0x88]
push QWORD PTR [rbx+0x52]
push QWORD PTR [rbx+0x4e]
lea eax,[ebx+0x4e]
push rax
call FUNC_001333
add rsp,40
jmp JUMP_002421
JUMP_002418:
mov eax,[edx+0x2c]
shl eax,0x10
mov esi,[edx+0x14]
add esi,[edx+0x18]
mov edx,[rbp-0x18]
mov edx,[edx+0x14]
mov ecx,[rbp-0x18]
add edx,[ecx+0x18]
push rdx
mov edx,esi
pop rcx
sub edx,ecx
mov ecx,[rbp-0x18]
mov ecx,[ecx+0x30]
shl ecx,0x10
mov [rbp-0x14],ecx
test edx,edx
jz JUMP_002419
mov ecx,edx
sar DWORD PTR [rbp-0x14],cl
JUMP_002419:
add eax,[rbp-0x14]
test eax,eax
jnl JUMP_002420
shr eax,1
inc DWORD PTR [rbp-0xc]
JUMP_002420:
mov edx,[rbp-0x38]
mov [rbp-0x68],edx
mov edx,[rbp-0x30]
mov [rbp-0x64],edx
mov edx,[rbp-0x28]
mov [rbp-0x60],edx
mov edx,[rbp-0xc]
push rdx
push rax
lea eax,[rbp-0x68]
push rax
call FUNC_001504
add rsp,24
sub esi,+0x37
neg esi
inc esi
mov eax,0x20
sub eax,esi
mov ecx,eax
mov edx,[rbp-0x68]
shl edx,cl
mov [ebx+0x3e],edx
mov ecx,eax
mov edx,[rbp-0x64]
shl edx,cl
mov [ebx+0x46],edx
mov ecx,eax
mov eax,[rbp-0x60]
shl eax,cl
mov [ebx+0x4e],eax
mov ecx,esi
mov eax,[rbp-0x68]
sar eax,cl
mov [ebx+0x42],eax
mov ecx,esi
mov eax,[rbp-0x64]
sar eax,cl
mov [ebx+0x4a],eax
mov ecx,esi
mov eax,[rbp-0x60]
sar eax,cl
mov [ebx+0x52],eax
JUMP_002421:
cmp BYTE PTR [DATA_008699],0x0
jz JUMP_002428
or BYTE PTR [DATA_008696],0x80
xor eax,eax
mov al,[ebx+0x86]
cmp eax,[DATA_008857]
jnz JUMP_002426
push rdi
mov esi,ebx
lea edi,[rbp-0xd4]
mov ecx,0x9
rep movsd
pop rdi
mov eax,[rbp-0x80]
mov [ebx+0xc],eax
mov eax,[rbp-0x7c]
mov [ebx+0x10],eax
mov eax,[rbp-0x78]
mov [ebx+0x14],eax
push rbx
call FUNC_000571
pop rcx
push rbx
call QWORD PTR [DATA_007719]
pop rcx
push rbx
call FUNC_000571
pop rcx
mov eax,[rbp-0x80]
push rax
mov eax,[ebx+0x8c]
push rax
call FUNC_001521
add rsp,16
mov esi,eax
mov eax,[rbp-0x7c]
push rax
mov eax,[ebx+0x90]
push rax
call FUNC_001521
add rsp,16
add esi,eax
mov eax,[rbp-0x78]
push rax
mov eax,[ebx+0x94]
push rax
call FUNC_001521
add rsp,16
add esi,eax
push rsi
mov eax,[rbp-0x80]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x68],eax
push rsi
mov eax,[rbp-0x7c]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x64],eax
push rsi
mov eax,[rbp-0x78]
push rax
call FUNC_001521
add rsp,16
mov [rbp-0x60],eax
mov eax,[ebx+0x8c]
add eax,eax
mov ecx,0x3
cdq
idiv ecx
mov ecx,eax
mov eax,[rbp-0x68]
add eax,eax
lea eax,[eax+eax*4]
mov esi,0xc
cdq
idiv esi
sub ecx,eax
mov [ebx+0x8c],ecx
mov eax,[ebx+0x90]
add eax,eax
mov ecx,0x3
cdq
idiv ecx
mov ecx,eax
mov eax,[rbp-0x64]
add eax,eax
lea eax,[eax+eax*4]
mov esi,0xc
cdq
idiv esi
sub ecx,eax
mov [ebx+0x90],ecx
mov eax,[ebx+0x94]
add eax,eax
mov ecx,0x3
cdq
idiv ecx
mov ecx,eax
mov eax,[rbp-0x60]
add eax,eax
lea eax,[eax+eax*4]
mov esi,0xc
cdq
idiv esi
sub ecx,eax
mov [ebx+0x94],ecx
mov eax,[ebx+0x8c]
mov [rbp-0x68],eax
mov eax,[ebx+0x90]
mov [rbp-0x64],eax
mov eax,[ebx+0x94]
mov [rbp-0x60],eax
mov eax,[ebx+0x8c]
push rax
mov eax,[rbp-0xbc]
push rax
call FUNC_001521
add rsp,16
mov esi,eax
mov eax,[ebx+0x90]
push rax
mov eax,[rbp-0xb8]
push rax
call FUNC_001521
add rsp,16
add esi,eax
mov eax,[ebx+0x94]
push rax
mov eax,[rbp-0xb4]
push rax
call FUNC_001521
add rsp,16
add esi,eax
test esi,esi
jnl JUMP_002422
neg DWORD PTR [rbp-0x68]
neg DWORD PTR [rbp-0x64]
neg DWORD PTR [rbp-0x60]
JUMP_002422:
mov eax,[ebx+0x8c]
push rax
call dos_abs
pop rcx
mov esi,eax
mov eax,[ebx+0x90]
push rax
call dos_abs
pop rcx
add esi,eax
mov eax,[ebx+0x94]
push rax
call dos_abs
pop rcx
add esi,eax
sub [rbp-0x10],esi
mov eax,[ebx+0x82]
push rax
call QWORD PTR [DATA_007756]
pop rcx
mov eax,[eax+0x38]
movsx ecx,WORD PTR [eax+0x6]
shl ecx,0x2
mov eax,ecx
imul DWORD PTR [rbp-0x10]
mov esi,0x708
cdq
idiv esi
mov edx,ecx
test edx,edx
jns JUMP_002423
add edx,+0x3
JUMP_002423:
sar edx,0x2
cmp eax,edx
jnl JUMP_002424
mov eax,edx
JUMP_002424:
push +0x0
push rax
push rbx
call FUNC_000953
add rsp,24
cmp DWORD PTR [rbp-0x68],+0x0
jnz JUMP_002425
cmp DWORD PTR [rbp-0x64],+0x0
jnz JUMP_002425
cmp DWORD PTR [rbp-0x60],+0x0
jnz JUMP_002425
mov eax,[rbp-0xbc]
mov [rbp-0x68],eax
mov eax,[rbp-0xb8]
mov [rbp-0x64],eax
mov eax,[rbp-0xb4]
mov [rbp-0x60],eax
JUMP_002425:
push 0x7fffffff
lea eax,[rbp-0x68]
push rax
call FUNC_001503
add rsp,16
push rdi
lea esi,[rbp-0xd4]
mov edi,ebx
mov ecx,0x9
rep movsd
pop rdi
mov eax,[rbp-0x68]
mov [ebx+0x18],eax
mov eax,[rbp-0x64]
mov [ebx+0x1c],eax
mov eax,[rbp-0x60]
mov [ebx+0x20],eax
push rbx
call QWORD PTR [DATA_007719]
pop rcx
jmp JUMP_002429
JUMP_002426:
cmp DWORD PTR [ebx+0x82],+0xd
jna JUMP_002429
mov al,[ebx+0x87]
cmp al,0xb
jz JUMP_002427
cmp al,0xe
jnz JUMP_002429
JUMP_002427:
mov eax,[rbp-0x80]
mov [ebx+0xc],eax
mov eax,[rbp-0x7c]
mov [ebx+0x10],eax
mov eax,[rbp-0x78]
mov [ebx+0x14],eax
push rbx
call FUNC_000571
pop rcx
push rbx
call QWORD PTR [DATA_007719]
pop rcx
push rbx
call FUNC_000571
pop rcx
xor eax,eax
mov [ebx+0x8c],eax
xor eax,eax
mov [ebx+0x90],eax
xor eax,eax
mov [ebx+0x94],eax
cmp BYTE PTR [DATA_008700],0x0
jz JUMP_002429
push +0x0
push -0x1
push rbx
call FUNC_000953
add rsp,24
jmp JUMP_002429
JUMP_002428:
mov eax,[rbp-0x80]
mov [ebx+0xc],eax
mov eax,[rbp-0x7c]
mov [ebx+0x10],eax
mov eax,[rbp-0x78]
mov [ebx+0x14],eax
push rbx
call FUNC_000571
pop rcx
push rbx
call QWORD PTR [DATA_007719]
pop rcx
push rbx
call FUNC_000571
pop rcx
xor eax,eax
mov [ebx+0x8c],eax
xor eax,eax
mov [ebx+0x90],eax
xor eax,eax
mov [ebx+0x94],eax
JUMP_002429:
mov eax,[edi+0x140]
cmp eax,[edi+0x138]
jz JUMP_002430
or BYTE PTR [DATA_008696],0x1
JUMP_002430:
cmp BYTE PTR [DATA_008698],0x0
jnz JUMP_002431
mov al,[edi+0x86]
mov [DATA_008698],al
mov [DATA_008702],edi
JUMP_002431:
mov al,[DATA_008696]
JUMP_002432:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000577:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],577
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
add rsp,-64
push rbx
push rsi
push rdi
mov eax,[rbp+40]
mov [rbp-0x40],eax
mov eax,[rbp+48]
mov [rbp-0x3c],eax
mov eax,[rbp+56]
mov [rbp-0x38],eax
mov eax,[rbp+64]
mov [rbp-0x34],eax
mov eax,[rbp+72]
mov [rbp-0x30],eax
mov eax,[rbp+80]
mov [rbp-0x2c],eax
mov ebx,[rbp+88]
mov esi,[rbp+32]
mov edi,[rbp+16]
mov eax,[ebx+0x4]
or eax,[ebx+0xc]
or eax,[ebx+0x14]
or eax,[esi+0x13c]
mov [rbp-0x4],eax
cmp DWORD PTR [rbp-0x4],+0x0
jz JUMP_002446
mov eax,[rbp-0x4]
push rax
call FUNC_001656
pop rcx
mov ebx,eax
add ebx,+0x3
jmp JUMP_002447
JUMP_002446:
mov eax,[ebx]
or eax,[ebx+0x8]
or eax,[ebx+0x10]
or eax,[esi+0x138]
push rax
call FUNC_001656
pop rcx
add eax,-0x1d
mov ebx,eax
JUMP_002447:
test ebx,ebx
jg JUMP_002448
neg ebx
mov ecx,ebx
mov eax,[rbp+24]
mov eax,[eax+0x140]
add eax,[esi+0x138]
shl eax,cl
mov [rbp-0x8],eax
mov ecx,ebx
shl DWORD PTR [rbp-0x40],cl
mov ecx,ebx
shl DWORD PTR [rbp-0x38],cl
mov ecx,ebx
shl DWORD PTR [rbp-0x30],cl
neg ebx
jmp JUMP_002449
JUMP_002448:
push rbx
lea eax,[rbp-0x40]
push rax
call FUNC_001660
add rsp,16
mov eax,[rbp+24]
push QWORD PTR [rax+0x13c]
push QWORD PTR [rax+0x138]
push QWORD PTR [rsi+0x13c]
push QWORD PTR [rsi+0x138]
lea eax,[rbp-0x10]
push rax
call FUNC_001333
add rsp,40
mov eax,ebx
neg eax
push rax
lea eax,[rbp-0x10]
push rax
call FUNC_001341
add rsp,16
mov eax,[rbp-0x10]
mov [rbp-0x8],eax
JUMP_002449:
mov eax,[rbp-0x40]
push rax
call QWORD PTR [DATA_007737]
pop rcx
push rax
mov eax,[rbp-0x38]
push rax
call QWORD PTR [DATA_007737]
pop rcx
pop rdx
add edx,eax
push rdx
mov eax,[rbp-0x30]
push rax
call QWORD PTR [DATA_007737]
pop rcx
pop rdx
add edx,eax
mov [edi],edx
mov eax,[rbp-0x8]
push rax
call QWORD PTR [DATA_007737]
pop rcx
cmp eax,[edi]
jna JUMP_002450
xor eax,eax
jmp JUMP_002453
JUMP_002450:
or BYTE PTR [DATA_008696],0x2
mov eax,[edi]
shr eax,1
push rax
call QWORD PTR [DATA_007738]
pop rcx
add eax,eax
mov [DATA_008703],eax
cmp DWORD PTR [DATA_008703],+0x0
jnl JUMP_002451
xor eax,eax
mov [DATA_008703],eax
JUMP_002451:
xor eax,eax
mov [DATA_008704],eax
push rbx
push OFFSET FLAT:DATA_008703
call FUNC_001341
add rsp,16
mov eax,[esi+0x140]
cmp eax,[esi+0x138]
jz JUMP_002452
or BYTE PTR [DATA_008696],0x1
JUMP_002452:
or eax,-0x1
JUMP_002453:
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000578:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],578
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

DOS_PAIR_4281b8:
push rbp
DOS_PAIR_4281b9:
mov rbp,rsp
DOS_PAIR_4281bb:
push rbx
DOS_PAIR_4281bc:
push rsi
DOS_PAIR_4281bd:
mov esi,DWORD PTR [rbp+24]
DOS_PAIR_4281c0:
mov ebx,DWORD PTR [rbp+16]
DOS_PAIR_4281c3:
or BYTE PTR [DATA_008696],0x80
DOS_PAIR_4281ca:
mov al,BYTE PTR [ebx+0x56]
DOS_PAIR_4281cd:
cmp al,BYTE PTR [esi+0x86]
DOS_PAIR_4281d3:
je DOS_PAIR_4281e2
DOS_PAIR_4281d5:
cmp BYTE PTR [esi+0x87],0x1
DOS_PAIR_4281dc:
jne DOS_PAIR_428265
DOS_PAIR_4281e2:
mov eax,DWORD PTR [ebx+0x8c]
DOS_PAIR_4281e8:
sar eax,0x2
DOS_PAIR_4281eb:
neg eax
DOS_PAIR_4281ed:
mov DWORD PTR [ebx+0x8c],eax
DOS_PAIR_4281f3:
mov eax,DWORD PTR [ebx+0x90]
DOS_PAIR_4281f9:
sar eax,0x2
DOS_PAIR_4281fc:
neg eax
DOS_PAIR_4281fe:
mov DWORD PTR [ebx+0x90],eax
DOS_PAIR_428204:
mov eax,DWORD PTR [ebx+0x94]
DOS_PAIR_42820a:
sar eax,0x2
DOS_PAIR_42820d:
neg eax
DOS_PAIR_42820f:
mov DWORD PTR [ebx+0x94],eax
DOS_PAIR_428215:
mov eax,DWORD PTR [ebx+0x8c]
DOS_PAIR_42821b:
push rax
DOS_PAIR_42821c:
call dos_abs
DOS_PAIR_428221:
pop rcx
DOS_PAIR_428222:
mov esi,eax
DOS_PAIR_428224:
mov eax,DWORD PTR [ebx+0x90]
DOS_PAIR_42822a:
push rax
DOS_PAIR_42822b:
call dos_abs
DOS_PAIR_428230:
pop rcx
DOS_PAIR_428231:
add esi,eax
DOS_PAIR_428233:
mov eax,DWORD PTR [ebx+0x94]
DOS_PAIR_428239:
push rax
DOS_PAIR_42823a:
call dos_abs
DOS_PAIR_42823f:
pop rcx
DOS_PAIR_428240:
add esi,eax
DOS_PAIR_428242:
mov eax,esi
DOS_PAIR_428244:
add eax,0xa
DOS_PAIR_428247:
cmp DWORD PTR [ebx+0x82],0xd
DOS_PAIR_42824e:
jbe DOS_PAIR_428354
DOS_PAIR_428254:
push 0x0
DOS_PAIR_428256:
push rax
DOS_PAIR_428257:
push rbx
DOS_PAIR_428258:
call FUNC_000953
DOS_PAIR_42825d:
add rsp,24
DOS_PAIR_428260:
jmp DOS_PAIR_428354
DOS_PAIR_428265:
mov eax,DWORD PTR [ebx+0x8c]
DOS_PAIR_42826b:
add eax,DWORD PTR [esi+0x8c]
DOS_PAIR_428271:
sar eax,1
DOS_PAIR_428273:
mov DWORD PTR [esi+0x8c],eax
DOS_PAIR_428279:
mov DWORD PTR [ebx+0x8c],eax
DOS_PAIR_42827f:
mov eax,DWORD PTR [ebx+0x90]
DOS_PAIR_428285:
add eax,DWORD PTR [esi+0x90]
DOS_PAIR_42828b:
sar eax,1
DOS_PAIR_42828d:
mov DWORD PTR [esi+0x90],eax
DOS_PAIR_428293:
mov DWORD PTR [ebx+0x90],eax
DOS_PAIR_428299:
mov eax,DWORD PTR [ebx+0x94]
DOS_PAIR_42829f:
add eax,DWORD PTR [esi+0x94]
DOS_PAIR_4282a5:
sar eax,1
DOS_PAIR_4282a7:
mov DWORD PTR [esi+0x94],eax
DOS_PAIR_4282ad:
mov DWORD PTR [ebx+0x94],eax
DOS_PAIR_4282b3:
cmp BYTE PTR [DATA_008700],0x0
DOS_PAIR_4282ba:
je DOS_PAIR_428354
DOS_PAIR_4282c0:
cmp DWORD PTR [ebx+0x82],0xd
DOS_PAIR_4282c7:
jbe DOS_PAIR_428354
DOS_PAIR_4282cd:
cmp DWORD PTR [esi+0x82],0xd
DOS_PAIR_4282d4:
jbe DOS_PAIR_428354
DOS_PAIR_4282d6:
mov ax,WORD PTR [esi+0xe4]
DOS_PAIR_4282dd:
cmp ax,WORD PTR [ebx+0xe4]
DOS_PAIR_4282e4:
ja DOS_PAIR_42831c
DOS_PAIR_4282e6:
xor edx,edx
DOS_PAIR_4282e8:
mov dl,BYTE PTR [ebx+0x86]
DOS_PAIR_4282ee:
push rdx
DOS_PAIR_4282ef:
movzx eax,ax
DOS_PAIR_4282f2:
add eax,eax
DOS_PAIR_4282f4:
push rax
DOS_PAIR_4282f5:
push rsi
DOS_PAIR_4282f6:
call FUNC_000953
DOS_PAIR_4282fb:
add rsp,24
DOS_PAIR_4282fe:
xor eax,eax
DOS_PAIR_428300:
mov al,BYTE PTR [esi+0x86]
DOS_PAIR_428306:
push rax
DOS_PAIR_428307:
movzx eax,WORD PTR [esi+0xe4]
DOS_PAIR_42830e:
add eax,eax
DOS_PAIR_428310:
push rax
DOS_PAIR_428311:
push rbx
DOS_PAIR_428312:
call FUNC_000953
DOS_PAIR_428317:
add rsp,24
DOS_PAIR_42831a:
jmp DOS_PAIR_428354
DOS_PAIR_42831c:
xor eax,eax
DOS_PAIR_42831e:
mov al,BYTE PTR [ebx+0x86]
DOS_PAIR_428324:
push rax
DOS_PAIR_428325:
movzx eax,WORD PTR [ebx+0xe4]
DOS_PAIR_42832c:
add eax,eax
DOS_PAIR_42832e:
push rax
DOS_PAIR_42832f:
push rsi
DOS_PAIR_428330:
call FUNC_000953
DOS_PAIR_428335:
add rsp,24
DOS_PAIR_428338:
xor eax,eax
DOS_PAIR_42833a:
mov al,BYTE PTR [esi+0x86]
DOS_PAIR_428340:
push rax
DOS_PAIR_428341:
movzx eax,WORD PTR [ebx+0xe4]
DOS_PAIR_428348:
add eax,eax
DOS_PAIR_42834a:
push rax
DOS_PAIR_42834b:
push rbx
DOS_PAIR_42834c:
call FUNC_000953
DOS_PAIR_428351:
add rsp,24
DOS_PAIR_428354:
pop rsi
DOS_PAIR_428355:
pop rbx
DOS_PAIR_428356:
pop rbp
DOS_PAIR_428357:
ret
FUNC_001332:
push rbp
mov rbp,rsp
mov eax,[rbp+16]
cmp DWORD PTR [rbp+32],+0x0
jnl JUMP_005278
push QWORD PTR [rbp+32]
push QWORD PTR [rbp+24]
push QWORD PTR [DATA_007636]
push QWORD PTR [DATA_007635]
push rax
call FUNC_001335
add rsp,40
pop rbp
ret
JUMP_005278:
mov edx,[rbp+24]
mov [eax],edx
mov edx,[rbp+32]
mov [eax+0x4],edx
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
FUNC_001664:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],1664
inc DWORD PTR [order_count]
pop rcx
pop rax
popfq

push rbp
mov rbp,rsp
push rbx
push rsi
mov esi,[rbp+24]
mov ebx,[rbp+16]
push QWORD PTR [rsi+0x4]
push QWORD PTR [rsi]
push rbx
call FUNC_001332
add rsp,24
push QWORD PTR [rsi+0xc]
push QWORD PTR [rsi+0x8]
lea eax,[ebx+0x8]
push rax
call FUNC_001332
add rsp,24
push QWORD PTR [rsi+0x14]
push QWORD PTR [rsi+0x10]
add ebx,+0x10
push rbx
call FUNC_001332
add rsp,24
pop rsi
pop rbx
pop rbp
ret
FUNC_000576:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],576
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
imul ecx,eax,104
add ecx,OFFSET FLAT:input+968
mov QWORD PTR [active_script],rcx
imul edx,eax,1576
add edx,OFFSET FLAT:output+1320
mov QWORD PTR [active_record],rdx
mov DWORD PTR [rdx],576
mov DWORD PTR [rdx+4],2
movzx eax,BYTE PTR [object+0x86]
mov DWORD PTR [rdx+8],eax
movzx eax,BYTE PTR [parent+0x86]
mov DWORD PTR [rdx+12],eax
lea rdi,[rdx+24]
mov esi,OFFSET FLAT:object
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:parent
mov ecx,338
rep movsb
mov esi,DWORD PTR [local_relative]
mov ecx,24
rep movsb
mov esi,OFFSET FLAT:relative
mov ecx,24
rep movsb
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008857]
mov DWORD PTR [rdi],eax
add rdi,4
mov r10,QWORD PTR [active_script]
test DWORD PTR [r10+4],1
jz FUNC_000576_skip_0
mov eax,DWORD PTR [r10+12]
mov BYTE PTR [DATA_008696],al
FUNC_000576_skip_0:
test DWORD PTR [r10+4],2
jz FUNC_000576_skip_1
mov eax,DWORD PTR [r10+16]
mov BYTE PTR [DATA_008697],al
FUNC_000576_skip_1:
test DWORD PTR [r10+4],4
jz FUNC_000576_skip_2
mov eax,DWORD PTR [r10+20]
mov BYTE PTR [DATA_008698],al
FUNC_000576_skip_2:
test DWORD PTR [r10+4],8
jz FUNC_000576_skip_3
mov eax,DWORD PTR [r10+24]
mov BYTE PTR [DATA_008699],al
FUNC_000576_skip_3:
test DWORD PTR [r10+4],16
jz FUNC_000576_skip_4
mov eax,DWORD PTR [r10+28]
mov BYTE PTR [DATA_008700],al
FUNC_000576_skip_4:
test DWORD PTR [r10+4],32
jz FUNC_000576_skip_5
mov eax,DWORD PTR [r10+32]
mov BYTE PTR [DATA_008701],al
FUNC_000576_skip_5:
test DWORD PTR [r10+4],64
jz FUNC_000576_skip_6
mov eax,DWORD PTR [r10+36]
call decode_ref
mov DWORD PTR [DATA_008702],eax
FUNC_000576_skip_6:
test DWORD PTR [r10+4],128
jz FUNC_000576_skip_7
mov eax,DWORD PTR [r10+40]
mov DWORD PTR [DATA_008703],eax
FUNC_000576_skip_7:
test DWORD PTR [r10+4],256
jz FUNC_000576_skip_8
mov eax,DWORD PTR [r10+44]
mov DWORD PTR [DATA_008704],eax
FUNC_000576_skip_8:
test DWORD PTR [r10+4],512
jz FUNC_000576_skip_9
mov eax,DWORD PTR [r10+48]
mov DWORD PTR [DATA_008705],eax
FUNC_000576_skip_9:
test DWORD PTR [r10+4],1024
jz FUNC_000576_skip_10
mov eax,DWORD PTR [r10+52]
mov DWORD PTR [DATA_008706],eax
FUNC_000576_skip_10:
test DWORD PTR [r10+4],2048
jz FUNC_000576_skip_11
mov eax,DWORD PTR [r10+56]
mov BYTE PTR [DATA_008707],al
FUNC_000576_skip_11:
test DWORD PTR [r10+4],4096
jz FUNC_000576_skip_12
mov eax,DWORD PTR [r10+60]
mov DWORD PTR [DATA_008857],eax
FUNC_000576_skip_12:
test DWORD PTR [r10],1
jz no_local_write
mov esi,r10d
add esi,64
mov edi,DWORD PTR [local_relative]
mov ecx,24
rep movsb
no_local_write:
test DWORD PTR [r10],2
jz FUNC_000576_object_skip
mov eax,DWORD PTR [r10+88]
cmp eax,338
jae failed
mov edx,DWORD PTR [r10+92]
xor BYTE PTR [object+rax],dl
FUNC_000576_object_skip:
test DWORD PTR [r10],4
jz FUNC_000576_parent_skip
mov eax,DWORD PTR [r10+96]
cmp eax,338
jae failed
mov edx,DWORD PTR [r10+100]
xor BYTE PTR [parent+rax],dl
FUNC_000576_parent_skip:
mov rdx,QWORD PTR [active_record]
lea rdi,[rdx+800]
mov esi,OFFSET FLAT:object
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:parent
mov ecx,338
rep movsb
mov esi,DWORD PTR [local_relative]
mov ecx,24
rep movsb
mov esi,OFFSET FLAT:relative
mov ecx,24
rep movsb
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008857]
mov DWORD PTR [rdi],eax
add rdi,4
mov r10,QWORD PTR [active_script]
mov eax,DWORD PTR [r10+8]
mov rdx,QWORD PTR [active_record]
mov DWORD PTR [rdx+20],eax
inc DWORD PTR [obs_count]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000953:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [order_count]
cmp ecx,128
jae failed
mov DWORD PTR [order+rcx*4],953
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
imul ecx,eax,104
add ecx,OFFSET FLAT:input+968
mov QWORD PTR [active_script],rcx
imul edx,eax,1576
add edx,OFFSET FLAT:output+1320
mov QWORD PTR [active_record],rdx
mov DWORD PTR [rdx],953
mov DWORD PTR [rdx+4],3
mov eax,DWORD PTR [rbp+16]
call encode_ref
mov DWORD PTR [rdx+8],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [rdx+12],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [rdx+16],eax
lea rdi,[rdx+24]
mov esi,OFFSET FLAT:object
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:parent
mov ecx,338
rep movsb
mov esi,DWORD PTR [local_relative]
mov ecx,24
rep movsb
mov esi,OFFSET FLAT:relative
mov ecx,24
rep movsb
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008857]
mov DWORD PTR [rdi],eax
add rdi,4
mov r10,QWORD PTR [active_script]
test DWORD PTR [r10+4],1
jz FUNC_000953_skip_0
mov eax,DWORD PTR [r10+12]
mov BYTE PTR [DATA_008696],al
FUNC_000953_skip_0:
test DWORD PTR [r10+4],2
jz FUNC_000953_skip_1
mov eax,DWORD PTR [r10+16]
mov BYTE PTR [DATA_008697],al
FUNC_000953_skip_1:
test DWORD PTR [r10+4],4
jz FUNC_000953_skip_2
mov eax,DWORD PTR [r10+20]
mov BYTE PTR [DATA_008698],al
FUNC_000953_skip_2:
test DWORD PTR [r10+4],8
jz FUNC_000953_skip_3
mov eax,DWORD PTR [r10+24]
mov BYTE PTR [DATA_008699],al
FUNC_000953_skip_3:
test DWORD PTR [r10+4],16
jz FUNC_000953_skip_4
mov eax,DWORD PTR [r10+28]
mov BYTE PTR [DATA_008700],al
FUNC_000953_skip_4:
test DWORD PTR [r10+4],32
jz FUNC_000953_skip_5
mov eax,DWORD PTR [r10+32]
mov BYTE PTR [DATA_008701],al
FUNC_000953_skip_5:
test DWORD PTR [r10+4],64
jz FUNC_000953_skip_6
mov eax,DWORD PTR [r10+36]
call decode_ref
mov DWORD PTR [DATA_008702],eax
FUNC_000953_skip_6:
test DWORD PTR [r10+4],128
jz FUNC_000953_skip_7
mov eax,DWORD PTR [r10+40]
mov DWORD PTR [DATA_008703],eax
FUNC_000953_skip_7:
test DWORD PTR [r10+4],256
jz FUNC_000953_skip_8
mov eax,DWORD PTR [r10+44]
mov DWORD PTR [DATA_008704],eax
FUNC_000953_skip_8:
test DWORD PTR [r10+4],512
jz FUNC_000953_skip_9
mov eax,DWORD PTR [r10+48]
mov DWORD PTR [DATA_008705],eax
FUNC_000953_skip_9:
test DWORD PTR [r10+4],1024
jz FUNC_000953_skip_10
mov eax,DWORD PTR [r10+52]
mov DWORD PTR [DATA_008706],eax
FUNC_000953_skip_10:
test DWORD PTR [r10+4],2048
jz FUNC_000953_skip_11
mov eax,DWORD PTR [r10+56]
mov BYTE PTR [DATA_008707],al
FUNC_000953_skip_11:
test DWORD PTR [r10+4],4096
jz FUNC_000953_skip_12
mov eax,DWORD PTR [r10+60]
mov DWORD PTR [DATA_008857],eax
FUNC_000953_skip_12:
test DWORD PTR [r10],2
jz FUNC_000953_object_skip
mov eax,DWORD PTR [r10+88]
cmp eax,338
jae failed
mov edx,DWORD PTR [r10+92]
xor BYTE PTR [object+rax],dl
FUNC_000953_object_skip:
test DWORD PTR [r10],4
jz FUNC_000953_parent_skip
mov eax,DWORD PTR [r10+96]
cmp eax,338
jae failed
mov edx,DWORD PTR [r10+100]
xor BYTE PTR [parent+rax],dl
FUNC_000953_parent_skip:
mov eax,DWORD PTR [obs_count]
imul esi,eax,680
add esi,OFFSET FLAT:input+2048
test DWORD PTR [esi],1
jz contact_no_body
push rsi
add esi,4
mov edi,OFFSET FLAT:object
mov ecx,338
rep movsb
pop rsi
contact_no_body:
test DWORD PTR [esi],2
jz contact_no_collider
add esi,342
mov edi,OFFSET FLAT:parent
mov ecx,338
rep movsb
contact_no_collider:
mov rdx,QWORD PTR [active_record]
lea rdi,[rdx+800]
mov esi,OFFSET FLAT:object
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:parent
mov ecx,338
rep movsb
mov esi,DWORD PTR [local_relative]
mov ecx,24
rep movsb
mov esi,OFFSET FLAT:relative
mov ecx,24
rep movsb
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008857]
mov DWORD PTR [rdi],eax
add rdi,4
mov r10,QWORD PTR [active_script]
mov eax,DWORD PTR [r10+8]
mov rdx,QWORD PTR [active_record]
mov DWORD PTR [rdx+20],eax
inc DWORD PTR [obs_count]
pop rdi
pop rsi
pop rbx
pop rbp
ret

dos_abs:
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

encode_ref:
cmp eax,114
jbe ref_done
cmp eax,OFFSET FLAT:object
je ref_object
cmp eax,OFFSET FLAT:parent
jne failed
movzx eax,BYTE PTR [parent+0x86]
ret
ref_object:
movzx eax,BYTE PTR [object+0x86]
ref_done:
ret
decode_ref:
test eax,eax
jz decode_done
movzx edx,BYTE PTR [object+0x86]
cmp eax,edx
je decode_object
movzx edx,BYTE PTR [parent+0x86]
cmp eax,edx
je decode_parent
cmp eax,114
ja failed
ret
decode_parent:
mov eax,OFFSET FLAT:parent
ret
decode_object:
mov eax,OFFSET FLAT:object
decode_done:
ret
_start:
mov esp,OFFSET FLAT:stack_end
cld
next_case:
xor r8d,r8d
read_more:
xor eax,eax
xor edi,edi
lea rsi,[input+r8]
mov edx,8192
sub edx,r8d
syscall
test eax,eax
jz finished
js failed
add r8d,eax
cmp r8d,8192
jb read_more
mov edi,OFFSET FLAT:output
xor eax,eax
mov ecx,14336
rep stosb
mov DWORD PTR [order_count],0
mov DWORD PTR [obs_count],0
mov edi,OFFSET FLAT:order
xor eax,eax
mov ecx,512
rep stosb
mov esi,OFFSET FLAT:input+84
mov edi,OFFSET FLAT:object
mov ecx,338
rep movsb
mov QWORD PTR [object_guard_a],-1
mov QWORD PTR [object_guard_b],-1
mov esi,OFFSET FLAT:input+422
mov edi,OFFSET FLAT:parent
mov ecx,338
rep movsb
mov QWORD PTR [parent_guard_a],-1
mov QWORD PTR [parent_guard_b],-1
mov esi,OFFSET FLAT:input+760
mov edi,OFFSET FLAT:relative
mov ecx,24
rep movsb
mov QWORD PTR [relative_guard_a],-1
mov QWORD PTR [relative_guard_b],-1
mov esi,OFFSET FLAT:input+784
mov edi,OFFSET FLAT:body_descriptor
mov ecx,68
rep movsb
mov QWORD PTR [body_descriptor_guard_a],-1
mov QWORD PTR [body_descriptor_guard_b],-1
mov esi,OFFSET FLAT:input+852
mov edi,OFFSET FLAT:parent_descriptor
mov ecx,68
rep movsb
mov QWORD PTR [parent_descriptor_guard_a],-1
mov QWORD PTR [parent_descriptor_guard_b],-1
mov esi,OFFSET FLAT:input+920
mov edi,OFFSET FLAT:body_spec
mov ecx,24
rep movsb
mov QWORD PTR [body_spec_guard_a],-1
mov QWORD PTR [body_spec_guard_b],-1
mov esi,OFFSET FLAT:input+944
mov edi,OFFSET FLAT:parent_spec
mov ecx,24
rep movsb
mov QWORD PTR [parent_spec_guard_a],-1
mov QWORD PTR [parent_spec_guard_b],-1
mov eax,DWORD PTR [input+32]
mov BYTE PTR [DATA_008696],al
mov eax,DWORD PTR [input+36]
mov BYTE PTR [DATA_008697],al
mov eax,DWORD PTR [input+40]
mov BYTE PTR [DATA_008698],al
mov eax,DWORD PTR [input+44]
mov BYTE PTR [DATA_008699],al
mov eax,DWORD PTR [input+48]
mov BYTE PTR [DATA_008700],al
mov eax,DWORD PTR [input+52]
mov BYTE PTR [DATA_008701],al
mov eax,DWORD PTR [input+56]
call decode_ref
mov DWORD PTR [DATA_008702],eax
mov eax,DWORD PTR [input+60]
mov DWORD PTR [DATA_008703],eax
mov eax,DWORD PTR [input+64]
mov DWORD PTR [DATA_008704],eax
mov eax,DWORD PTR [input+68]
mov DWORD PTR [DATA_008705],eax
mov eax,DWORD PTR [input+72]
mov DWORD PTR [DATA_008706],eax
mov eax,DWORD PTR [input+76]
mov BYTE PTR [DATA_008707],al
mov eax,DWORD PTR [input+80]
mov DWORD PTR [DATA_008857],eax
mov eax,DWORD PTR [object+0x82]
cmp eax,149
jae failed
mov DWORD PTR [DATA_004681+rax*4],OFFSET FLAT:body_descriptor
mov eax,DWORD PTR [parent+0x82]
cmp eax,149
jae failed
mov DWORD PTR [DATA_004681+rax*4],OFFSET FLAT:parent_descriptor
mov DWORD PTR [body_descriptor+0x38],OFFSET FLAT:body_spec
mov DWORD PTR [parent_descriptor+0x38],OFFSET FLAT:parent_spec
push OFFSET FLAT:parent
push OFFSET FLAT:object
push OFFSET FLAT:relative
call FUNC_000575
add rsp,24
movzx eax,al
mov DWORD PTR [output],eax
lea rdi,[output+32]
mov esi,OFFSET FLAT:object
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:parent
mov ecx,338
rep movsb
mov esi,DWORD PTR [local_relative]
mov ecx,24
rep movsb
mov esi,OFFSET FLAT:relative
mov ecx,24
rep movsb
movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [rdi],eax
add rdi,4
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [DATA_008857]
mov DWORD PTR [rdi],eax
add rdi,4
mov eax,DWORD PTR [obs_count]
mov DWORD PTR [output+4],eax
mov eax,DWORD PTR [order_count]
mov DWORD PTR [output+8],eax
mov esi,OFFSET FLAT:order
mov edi,OFFSET FLAT:output+808
mov ecx,512
rep movsb
cmp QWORD PTR [object_guard_a],-1
jne failed
cmp QWORD PTR [object_guard_b],-1
jne failed
cmp QWORD PTR [parent_guard_a],-1
jne failed
cmp QWORD PTR [parent_guard_b],-1
jne failed
cmp QWORD PTR [relative_guard_a],-1
jne failed
cmp QWORD PTR [relative_guard_b],-1
jne failed
cmp QWORD PTR [body_descriptor_guard_a],-1
jne failed
cmp QWORD PTR [body_descriptor_guard_b],-1
jne failed
cmp QWORD PTR [parent_descriptor_guard_a],-1
jne failed
cmp QWORD PTR [parent_descriptor_guard_b],-1
jne failed
cmp QWORD PTR [body_spec_guard_a],-1
jne failed
cmp QWORD PTR [body_spec_guard_b],-1
jne failed
cmp QWORD PTR [parent_spec_guard_a],-1
jne failed
cmp QWORD PTR [parent_spec_guard_b],-1
jne failed
mov al,BYTE PTR [body_descriptor+0]
cmp al,BYTE PTR [input+784]
jne failed
mov al,BYTE PTR [body_descriptor+1]
cmp al,BYTE PTR [input+785]
jne failed
mov al,BYTE PTR [body_descriptor+2]
cmp al,BYTE PTR [input+786]
jne failed
mov al,BYTE PTR [body_descriptor+3]
cmp al,BYTE PTR [input+787]
jne failed
mov al,BYTE PTR [body_descriptor+4]
cmp al,BYTE PTR [input+788]
jne failed
mov al,BYTE PTR [body_descriptor+5]
cmp al,BYTE PTR [input+789]
jne failed
mov al,BYTE PTR [body_descriptor+6]
cmp al,BYTE PTR [input+790]
jne failed
mov al,BYTE PTR [body_descriptor+7]
cmp al,BYTE PTR [input+791]
jne failed
mov al,BYTE PTR [body_descriptor+8]
cmp al,BYTE PTR [input+792]
jne failed
mov al,BYTE PTR [body_descriptor+9]
cmp al,BYTE PTR [input+793]
jne failed
mov al,BYTE PTR [body_descriptor+10]
cmp al,BYTE PTR [input+794]
jne failed
mov al,BYTE PTR [body_descriptor+11]
cmp al,BYTE PTR [input+795]
jne failed
mov al,BYTE PTR [body_descriptor+12]
cmp al,BYTE PTR [input+796]
jne failed
mov al,BYTE PTR [body_descriptor+13]
cmp al,BYTE PTR [input+797]
jne failed
mov al,BYTE PTR [body_descriptor+14]
cmp al,BYTE PTR [input+798]
jne failed
mov al,BYTE PTR [body_descriptor+15]
cmp al,BYTE PTR [input+799]
jne failed
mov al,BYTE PTR [body_descriptor+16]
cmp al,BYTE PTR [input+800]
jne failed
mov al,BYTE PTR [body_descriptor+17]
cmp al,BYTE PTR [input+801]
jne failed
mov al,BYTE PTR [body_descriptor+18]
cmp al,BYTE PTR [input+802]
jne failed
mov al,BYTE PTR [body_descriptor+19]
cmp al,BYTE PTR [input+803]
jne failed
mov al,BYTE PTR [body_descriptor+20]
cmp al,BYTE PTR [input+804]
jne failed
mov al,BYTE PTR [body_descriptor+21]
cmp al,BYTE PTR [input+805]
jne failed
mov al,BYTE PTR [body_descriptor+22]
cmp al,BYTE PTR [input+806]
jne failed
mov al,BYTE PTR [body_descriptor+23]
cmp al,BYTE PTR [input+807]
jne failed
mov al,BYTE PTR [body_descriptor+24]
cmp al,BYTE PTR [input+808]
jne failed
mov al,BYTE PTR [body_descriptor+25]
cmp al,BYTE PTR [input+809]
jne failed
mov al,BYTE PTR [body_descriptor+26]
cmp al,BYTE PTR [input+810]
jne failed
mov al,BYTE PTR [body_descriptor+27]
cmp al,BYTE PTR [input+811]
jne failed
mov al,BYTE PTR [body_descriptor+28]
cmp al,BYTE PTR [input+812]
jne failed
mov al,BYTE PTR [body_descriptor+29]
cmp al,BYTE PTR [input+813]
jne failed
mov al,BYTE PTR [body_descriptor+30]
cmp al,BYTE PTR [input+814]
jne failed
mov al,BYTE PTR [body_descriptor+31]
cmp al,BYTE PTR [input+815]
jne failed
mov al,BYTE PTR [body_descriptor+32]
cmp al,BYTE PTR [input+816]
jne failed
mov al,BYTE PTR [body_descriptor+33]
cmp al,BYTE PTR [input+817]
jne failed
mov al,BYTE PTR [body_descriptor+34]
cmp al,BYTE PTR [input+818]
jne failed
mov al,BYTE PTR [body_descriptor+35]
cmp al,BYTE PTR [input+819]
jne failed
mov al,BYTE PTR [body_descriptor+36]
cmp al,BYTE PTR [input+820]
jne failed
mov al,BYTE PTR [body_descriptor+37]
cmp al,BYTE PTR [input+821]
jne failed
mov al,BYTE PTR [body_descriptor+38]
cmp al,BYTE PTR [input+822]
jne failed
mov al,BYTE PTR [body_descriptor+39]
cmp al,BYTE PTR [input+823]
jne failed
mov al,BYTE PTR [body_descriptor+40]
cmp al,BYTE PTR [input+824]
jne failed
mov al,BYTE PTR [body_descriptor+41]
cmp al,BYTE PTR [input+825]
jne failed
mov al,BYTE PTR [body_descriptor+42]
cmp al,BYTE PTR [input+826]
jne failed
mov al,BYTE PTR [body_descriptor+43]
cmp al,BYTE PTR [input+827]
jne failed
mov al,BYTE PTR [body_descriptor+44]
cmp al,BYTE PTR [input+828]
jne failed
mov al,BYTE PTR [body_descriptor+45]
cmp al,BYTE PTR [input+829]
jne failed
mov al,BYTE PTR [body_descriptor+46]
cmp al,BYTE PTR [input+830]
jne failed
mov al,BYTE PTR [body_descriptor+47]
cmp al,BYTE PTR [input+831]
jne failed
mov al,BYTE PTR [body_descriptor+48]
cmp al,BYTE PTR [input+832]
jne failed
mov al,BYTE PTR [body_descriptor+49]
cmp al,BYTE PTR [input+833]
jne failed
mov al,BYTE PTR [body_descriptor+50]
cmp al,BYTE PTR [input+834]
jne failed
mov al,BYTE PTR [body_descriptor+51]
cmp al,BYTE PTR [input+835]
jne failed
mov al,BYTE PTR [body_descriptor+52]
cmp al,BYTE PTR [input+836]
jne failed
mov al,BYTE PTR [body_descriptor+53]
cmp al,BYTE PTR [input+837]
jne failed
mov al,BYTE PTR [body_descriptor+54]
cmp al,BYTE PTR [input+838]
jne failed
mov al,BYTE PTR [body_descriptor+55]
cmp al,BYTE PTR [input+839]
jne failed
mov al,BYTE PTR [body_descriptor+60]
cmp al,BYTE PTR [input+844]
jne failed
mov al,BYTE PTR [body_descriptor+61]
cmp al,BYTE PTR [input+845]
jne failed
mov al,BYTE PTR [body_descriptor+62]
cmp al,BYTE PTR [input+846]
jne failed
mov al,BYTE PTR [body_descriptor+63]
cmp al,BYTE PTR [input+847]
jne failed
mov al,BYTE PTR [body_descriptor+64]
cmp al,BYTE PTR [input+848]
jne failed
mov al,BYTE PTR [body_descriptor+65]
cmp al,BYTE PTR [input+849]
jne failed
mov al,BYTE PTR [body_descriptor+66]
cmp al,BYTE PTR [input+850]
jne failed
mov al,BYTE PTR [body_descriptor+67]
cmp al,BYTE PTR [input+851]
jne failed
mov al,BYTE PTR [parent_descriptor+0]
cmp al,BYTE PTR [input+852]
jne failed
mov al,BYTE PTR [parent_descriptor+1]
cmp al,BYTE PTR [input+853]
jne failed
mov al,BYTE PTR [parent_descriptor+2]
cmp al,BYTE PTR [input+854]
jne failed
mov al,BYTE PTR [parent_descriptor+3]
cmp al,BYTE PTR [input+855]
jne failed
mov al,BYTE PTR [parent_descriptor+4]
cmp al,BYTE PTR [input+856]
jne failed
mov al,BYTE PTR [parent_descriptor+5]
cmp al,BYTE PTR [input+857]
jne failed
mov al,BYTE PTR [parent_descriptor+6]
cmp al,BYTE PTR [input+858]
jne failed
mov al,BYTE PTR [parent_descriptor+7]
cmp al,BYTE PTR [input+859]
jne failed
mov al,BYTE PTR [parent_descriptor+8]
cmp al,BYTE PTR [input+860]
jne failed
mov al,BYTE PTR [parent_descriptor+9]
cmp al,BYTE PTR [input+861]
jne failed
mov al,BYTE PTR [parent_descriptor+10]
cmp al,BYTE PTR [input+862]
jne failed
mov al,BYTE PTR [parent_descriptor+11]
cmp al,BYTE PTR [input+863]
jne failed
mov al,BYTE PTR [parent_descriptor+12]
cmp al,BYTE PTR [input+864]
jne failed
mov al,BYTE PTR [parent_descriptor+13]
cmp al,BYTE PTR [input+865]
jne failed
mov al,BYTE PTR [parent_descriptor+14]
cmp al,BYTE PTR [input+866]
jne failed
mov al,BYTE PTR [parent_descriptor+15]
cmp al,BYTE PTR [input+867]
jne failed
mov al,BYTE PTR [parent_descriptor+16]
cmp al,BYTE PTR [input+868]
jne failed
mov al,BYTE PTR [parent_descriptor+17]
cmp al,BYTE PTR [input+869]
jne failed
mov al,BYTE PTR [parent_descriptor+18]
cmp al,BYTE PTR [input+870]
jne failed
mov al,BYTE PTR [parent_descriptor+19]
cmp al,BYTE PTR [input+871]
jne failed
mov al,BYTE PTR [parent_descriptor+20]
cmp al,BYTE PTR [input+872]
jne failed
mov al,BYTE PTR [parent_descriptor+21]
cmp al,BYTE PTR [input+873]
jne failed
mov al,BYTE PTR [parent_descriptor+22]
cmp al,BYTE PTR [input+874]
jne failed
mov al,BYTE PTR [parent_descriptor+23]
cmp al,BYTE PTR [input+875]
jne failed
mov al,BYTE PTR [parent_descriptor+24]
cmp al,BYTE PTR [input+876]
jne failed
mov al,BYTE PTR [parent_descriptor+25]
cmp al,BYTE PTR [input+877]
jne failed
mov al,BYTE PTR [parent_descriptor+26]
cmp al,BYTE PTR [input+878]
jne failed
mov al,BYTE PTR [parent_descriptor+27]
cmp al,BYTE PTR [input+879]
jne failed
mov al,BYTE PTR [parent_descriptor+28]
cmp al,BYTE PTR [input+880]
jne failed
mov al,BYTE PTR [parent_descriptor+29]
cmp al,BYTE PTR [input+881]
jne failed
mov al,BYTE PTR [parent_descriptor+30]
cmp al,BYTE PTR [input+882]
jne failed
mov al,BYTE PTR [parent_descriptor+31]
cmp al,BYTE PTR [input+883]
jne failed
mov al,BYTE PTR [parent_descriptor+32]
cmp al,BYTE PTR [input+884]
jne failed
mov al,BYTE PTR [parent_descriptor+33]
cmp al,BYTE PTR [input+885]
jne failed
mov al,BYTE PTR [parent_descriptor+34]
cmp al,BYTE PTR [input+886]
jne failed
mov al,BYTE PTR [parent_descriptor+35]
cmp al,BYTE PTR [input+887]
jne failed
mov al,BYTE PTR [parent_descriptor+36]
cmp al,BYTE PTR [input+888]
jne failed
mov al,BYTE PTR [parent_descriptor+37]
cmp al,BYTE PTR [input+889]
jne failed
mov al,BYTE PTR [parent_descriptor+38]
cmp al,BYTE PTR [input+890]
jne failed
mov al,BYTE PTR [parent_descriptor+39]
cmp al,BYTE PTR [input+891]
jne failed
mov al,BYTE PTR [parent_descriptor+40]
cmp al,BYTE PTR [input+892]
jne failed
mov al,BYTE PTR [parent_descriptor+41]
cmp al,BYTE PTR [input+893]
jne failed
mov al,BYTE PTR [parent_descriptor+42]
cmp al,BYTE PTR [input+894]
jne failed
mov al,BYTE PTR [parent_descriptor+43]
cmp al,BYTE PTR [input+895]
jne failed
mov al,BYTE PTR [parent_descriptor+44]
cmp al,BYTE PTR [input+896]
jne failed
mov al,BYTE PTR [parent_descriptor+45]
cmp al,BYTE PTR [input+897]
jne failed
mov al,BYTE PTR [parent_descriptor+46]
cmp al,BYTE PTR [input+898]
jne failed
mov al,BYTE PTR [parent_descriptor+47]
cmp al,BYTE PTR [input+899]
jne failed
mov al,BYTE PTR [parent_descriptor+48]
cmp al,BYTE PTR [input+900]
jne failed
mov al,BYTE PTR [parent_descriptor+49]
cmp al,BYTE PTR [input+901]
jne failed
mov al,BYTE PTR [parent_descriptor+50]
cmp al,BYTE PTR [input+902]
jne failed
mov al,BYTE PTR [parent_descriptor+51]
cmp al,BYTE PTR [input+903]
jne failed
mov al,BYTE PTR [parent_descriptor+52]
cmp al,BYTE PTR [input+904]
jne failed
mov al,BYTE PTR [parent_descriptor+53]
cmp al,BYTE PTR [input+905]
jne failed
mov al,BYTE PTR [parent_descriptor+54]
cmp al,BYTE PTR [input+906]
jne failed
mov al,BYTE PTR [parent_descriptor+55]
cmp al,BYTE PTR [input+907]
jne failed
mov al,BYTE PTR [parent_descriptor+60]
cmp al,BYTE PTR [input+912]
jne failed
mov al,BYTE PTR [parent_descriptor+61]
cmp al,BYTE PTR [input+913]
jne failed
mov al,BYTE PTR [parent_descriptor+62]
cmp al,BYTE PTR [input+914]
jne failed
mov al,BYTE PTR [parent_descriptor+63]
cmp al,BYTE PTR [input+915]
jne failed
mov al,BYTE PTR [parent_descriptor+64]
cmp al,BYTE PTR [input+916]
jne failed
mov al,BYTE PTR [parent_descriptor+65]
cmp al,BYTE PTR [input+917]
jne failed
mov al,BYTE PTR [parent_descriptor+66]
cmp al,BYTE PTR [input+918]
jne failed
mov al,BYTE PTR [parent_descriptor+67]
cmp al,BYTE PTR [input+919]
jne failed
mov al,BYTE PTR [body_spec+0]
cmp al,BYTE PTR [input+920]
jne failed
mov al,BYTE PTR [body_spec+1]
cmp al,BYTE PTR [input+921]
jne failed
mov al,BYTE PTR [body_spec+2]
cmp al,BYTE PTR [input+922]
jne failed
mov al,BYTE PTR [body_spec+3]
cmp al,BYTE PTR [input+923]
jne failed
mov al,BYTE PTR [body_spec+4]
cmp al,BYTE PTR [input+924]
jne failed
mov al,BYTE PTR [body_spec+5]
cmp al,BYTE PTR [input+925]
jne failed
mov al,BYTE PTR [body_spec+6]
cmp al,BYTE PTR [input+926]
jne failed
mov al,BYTE PTR [body_spec+7]
cmp al,BYTE PTR [input+927]
jne failed
mov al,BYTE PTR [body_spec+8]
cmp al,BYTE PTR [input+928]
jne failed
mov al,BYTE PTR [body_spec+9]
cmp al,BYTE PTR [input+929]
jne failed
mov al,BYTE PTR [body_spec+10]
cmp al,BYTE PTR [input+930]
jne failed
mov al,BYTE PTR [body_spec+11]
cmp al,BYTE PTR [input+931]
jne failed
mov al,BYTE PTR [body_spec+12]
cmp al,BYTE PTR [input+932]
jne failed
mov al,BYTE PTR [body_spec+13]
cmp al,BYTE PTR [input+933]
jne failed
mov al,BYTE PTR [body_spec+14]
cmp al,BYTE PTR [input+934]
jne failed
mov al,BYTE PTR [body_spec+15]
cmp al,BYTE PTR [input+935]
jne failed
mov al,BYTE PTR [body_spec+16]
cmp al,BYTE PTR [input+936]
jne failed
mov al,BYTE PTR [body_spec+17]
cmp al,BYTE PTR [input+937]
jne failed
mov al,BYTE PTR [body_spec+18]
cmp al,BYTE PTR [input+938]
jne failed
mov al,BYTE PTR [body_spec+19]
cmp al,BYTE PTR [input+939]
jne failed
mov al,BYTE PTR [body_spec+20]
cmp al,BYTE PTR [input+940]
jne failed
mov al,BYTE PTR [body_spec+21]
cmp al,BYTE PTR [input+941]
jne failed
mov al,BYTE PTR [body_spec+22]
cmp al,BYTE PTR [input+942]
jne failed
mov al,BYTE PTR [body_spec+23]
cmp al,BYTE PTR [input+943]
jne failed
mov al,BYTE PTR [parent_spec+0]
cmp al,BYTE PTR [input+944]
jne failed
mov al,BYTE PTR [parent_spec+1]
cmp al,BYTE PTR [input+945]
jne failed
mov al,BYTE PTR [parent_spec+2]
cmp al,BYTE PTR [input+946]
jne failed
mov al,BYTE PTR [parent_spec+3]
cmp al,BYTE PTR [input+947]
jne failed
mov al,BYTE PTR [parent_spec+4]
cmp al,BYTE PTR [input+948]
jne failed
mov al,BYTE PTR [parent_spec+5]
cmp al,BYTE PTR [input+949]
jne failed
mov al,BYTE PTR [parent_spec+6]
cmp al,BYTE PTR [input+950]
jne failed
mov al,BYTE PTR [parent_spec+7]
cmp al,BYTE PTR [input+951]
jne failed
mov al,BYTE PTR [parent_spec+8]
cmp al,BYTE PTR [input+952]
jne failed
mov al,BYTE PTR [parent_spec+9]
cmp al,BYTE PTR [input+953]
jne failed
mov al,BYTE PTR [parent_spec+10]
cmp al,BYTE PTR [input+954]
jne failed
mov al,BYTE PTR [parent_spec+11]
cmp al,BYTE PTR [input+955]
jne failed
mov al,BYTE PTR [parent_spec+12]
cmp al,BYTE PTR [input+956]
jne failed
mov al,BYTE PTR [parent_spec+13]
cmp al,BYTE PTR [input+957]
jne failed
mov al,BYTE PTR [parent_spec+14]
cmp al,BYTE PTR [input+958]
jne failed
mov al,BYTE PTR [parent_spec+15]
cmp al,BYTE PTR [input+959]
jne failed
mov al,BYTE PTR [parent_spec+16]
cmp al,BYTE PTR [input+960]
jne failed
mov al,BYTE PTR [parent_spec+17]
cmp al,BYTE PTR [input+961]
jne failed
mov al,BYTE PTR [parent_spec+18]
cmp al,BYTE PTR [input+962]
jne failed
mov al,BYTE PTR [parent_spec+19]
cmp al,BYTE PTR [input+963]
jne failed
mov al,BYTE PTR [parent_spec+20]
cmp al,BYTE PTR [input+964]
jne failed
mov al,BYTE PTR [parent_spec+21]
cmp al,BYTE PTR [input+965]
jne failed
mov al,BYTE PTR [parent_spec+22]
cmp al,BYTE PTR [input+966]
jne failed
mov al,BYTE PTR [parent_spec+23]
cmp al,BYTE PTR [input+967]
jne failed
mov QWORD PTR [output+14320],-1
mov QWORD PTR [output+14328],-1
xor r8d,r8d
write_more:
mov eax,1
mov edi,1
lea rsi,[output+r8]
mov edx,14336
sub edx,r8d
syscall
test eax,eax
jle failed
add r8d,eax
cmp r8d,14336
jb write_more
jmp next_case
finished:
mov eax,60
xor edi,edi
syscall
failed:
mov eax,60
mov edi,95
syscall

.section .data
.balign 8
DATA_007719: .quad FUNC_001520
DATA_007737: .quad FUNC_001522
DATA_007738: .quad FUNC_001502
DATA_007756: .quad FUNC_001538
DATA_007635: .long 0
DATA_007636: .long 0
.section .bss
.balign 16
input: .zero 8192
output: .zero 14336
order_count: .zero 4
order: .zero 512
obs_count: .zero 4
local_relative: .zero 4
return_value: .zero 4
active_script: .zero 8
active_record: .zero 8
DATA_004681: .zero 600
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
DATA_008857: .zero 4
object_guard_a: .zero 8
object: .zero 338
object_guard_b: .zero 8
parent_guard_a: .zero 8
parent: .zero 338
parent_guard_b: .zero 8
relative_guard_a: .zero 8
relative: .zero 24
relative_guard_b: .zero 8
body_descriptor_guard_a: .zero 8
body_descriptor: .zero 68
body_descriptor_guard_b: .zero 8
parent_descriptor_guard_a: .zero 8
parent_descriptor: .zero 68
parent_descriptor_guard_b: .zero 8
body_spec_guard_a: .zero 8
body_spec: .zero 24
body_spec_guard_b: .zero 8
parent_spec_guard_a: .zero 8
parent_spec: .zero 24
parent_spec_guard_b: .zero 8

.balign 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
