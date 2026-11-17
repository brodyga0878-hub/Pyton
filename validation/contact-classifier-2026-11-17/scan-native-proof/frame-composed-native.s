.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000568:
push rbp
mov rbp,rsp
mov BYTE PTR [DATA_008700],0x0
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
call QWORD PTR [DATA_007754]
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
call QWORD PTR [DATA_007754]
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
call QWORD PTR [DATA_007802]
add rsp,16
push rsi
lea eax,[rbp-0x38]
push rax
call QWORD PTR [DATA_007802]
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
FUNC_000572:
push rbp
mov rbp,rsp
add rsp,-12
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov ebx,[rbp+16]
push +0x1c
lea eax,[ebx+0x3e]
push rax
call FUNC_001658
add rsp,16
mov edi,eax
mov eax,[ebx+0x3e]
mov [rbp-0xc],eax
mov eax,[ebx+0x46]
mov [rbp-0x8],eax
mov eax,[ebx+0x4e]
mov [rbp-0x4],eax
push rsi
lea eax,[rbp-0xc]
push rax
lea eax,[rbp-0xc]
push rax
call FUNC_001670
add rsp,24
push rdi
lea eax,[rbp-0xc]
push rax
lea eax,[ebx+0x3e]
push rax
call QWORD PTR [DATA_007749]
add rsp,24
push rsi
push rbx
push rbx
call FUNC_001673
add rsp,24
mov al,[DATA_008811]
dec eax
mov [ebx+0x58],al
mov BYTE PTR [ebx+0x57],0x1
push rsi
lea eax,[ebx+0x8c]
push rax
push rax
call FUNC_001670
add rsp,24
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000573:
push rbp
mov rbp,rsp
add rsp,-36
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov ebx,[rbp+16]
push +0x1c
lea eax,[ebx+0x3e]
push rax
call FUNC_001658
add rsp,16
mov edi,eax
mov eax,[ebx+0x3e]
mov [rbp-0x24],eax
mov eax,[ebx+0x46]
mov [rbp-0x20],eax
mov eax,[ebx+0x4e]
mov [rbp-0x1c],eax
push rsi
lea eax,[rbp-0x24]
push rax
lea eax,[rbp-0x24]
push rax
call FUNC_001669
add rsp,24
push rdi
lea eax,[rbp-0x24]
push rax
lea eax,[ebx+0x3e]
push rax
call QWORD PTR [DATA_007749]
add rsp,24
push rsi
push rbx
push rbx
call FUNC_001672
add rsp,24
mov BYTE PTR [ebx+0x57],0x0
push rsi
lea eax,[ebx+0x8c]
push rax
push rax
call FUNC_001669
add rsp,24
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
FUNC_001672:
push rbp
mov rbp,rsp
add rsp,-36
push rbx
push rsi
push rdi
mov esi,[rbp+32]
mov ebx,[rbp+24]
mov eax,[esi]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0xc]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x18]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x24],edi
mov eax,[esi+0x4]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x10]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x20],edi
mov eax,[esi+0x8]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x14]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x20]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x1c],edi
mov eax,[esi]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0xc]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x18]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x18],edi
mov eax,[esi+0x4]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x10]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x14],edi
mov eax,[esi+0x8]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x14]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x20]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x10],edi
mov eax,[esi]
push rax
mov eax,[ebx+0x18]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0xc]
push rax
mov eax,[ebx+0x1c]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x18]
push rax
mov eax,[ebx+0x20]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0xc],edi
mov eax,[esi+0x4]
push rax
mov eax,[ebx+0x18]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x10]
push rax
mov eax,[ebx+0x1c]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x20]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x8],edi
mov eax,[esi+0x8]
push rax
mov eax,[ebx+0x18]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x14]
push rax
mov eax,[ebx+0x1c]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x20]
push rax
mov eax,[ebx+0x20]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x4],edi
mov eax,[rbp+16]
lea esi,[rbp-0x24]
mov edi,eax
mov ecx,0x9
rep movsd
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001673:
push rbp
mov rbp,rsp
add rsp,-36
push rbx
push rsi
push rdi
mov esi,[rbp+32]
mov ebx,[rbp+24]
mov eax,[esi]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x4]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x8]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x24],edi
mov eax,[esi+0xc]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x10]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x14]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x20],edi
mov eax,[esi+0x18]
push rax
mov eax,[ebx]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x4]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x20]
push rax
mov eax,[ebx+0x8]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x1c],edi
mov eax,[esi]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x4]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x8]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x18],edi
mov eax,[esi+0xc]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x10]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x14]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x14],edi
mov eax,[esi+0x18]
push rax
mov eax,[ebx+0xc]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x10]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x20]
push rax
mov eax,[ebx+0x14]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x10],edi
mov eax,[esi]
push rax
mov eax,[ebx+0x18]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x4]
push rax
mov eax,[ebx+0x1c]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x8]
push rax
mov eax,[ebx+0x20]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0xc],edi
mov eax,[esi+0xc]
push rax
mov eax,[ebx+0x18]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x10]
push rax
mov eax,[ebx+0x1c]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x14]
push rax
mov eax,[ebx+0x20]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x8],edi
mov eax,[esi+0x18]
push rax
mov eax,[ebx+0x18]
push rax
call FUNC_001521
add rsp,16
mov edi,eax
mov eax,[esi+0x1c]
push rax
mov eax,[ebx+0x1c]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov eax,[esi+0x20]
push rax
mov eax,[ebx+0x20]
push rax
call FUNC_001521
add rsp,16
add edi,eax
mov [rbp-0x4],edi
mov eax,[rbp+16]
lea esi,[rbp-0x24]
mov edi,eax
mov ecx,0x9
rep movsd
pop rdi
pop rsi
pop rbx
mov rsp,rbp
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


decode_ref:
 test eax,eax
 jz ref_decode_done
 movzx edx,BYTE PTR [player+0x86]
 cmp eax,edx
 je ref_decode_player
 cmp eax,114
 ja failed
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 ret
ref_decode_player:
 mov eax,OFFSET FLAT:player
ref_decode_done:
 ret
encode_ref:
 test eax,eax
 jz ref_encode_done
 cmp eax,OFFSET FLAT:player
 je ref_encode_player
 sub eax,OFFSET FLAT:bank+0x74
 xor edx,edx
 mov ecx,338
 div ecx
 test edx,edx
 jnz failed
 cmp eax,114
 ja failed
 ret
ref_encode_player:
 movzx eax,BYTE PTR [player+0x86]
ref_encode_done:
 ret
FUNC_000575:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [call_count]
 cmp eax,DWORD PTR [input+12]
 jae failed
 cmp eax,115
 jae failed
 imul eax,1488
 add eax,OFFSET FLAT:output+39404
 mov r8d,eax
 mov eax,DWORD PTR [call_count]
 imul eax,752
 add eax,OFFSET FLAT:input+39388
 mov r9d,eax
 mov esi,DWORD PTR [rbp+24]
 movzx eax,BYTE PTR [rsi+0x86]
 mov DWORD PTR [r8],eax
 mov esi,DWORD PTR [rbp+32]
 movzx eax,BYTE PTR [rsi+0x86]
 mov DWORD PTR [r8+4],eax
 mov eax,DWORD PTR [r9+52]
 and eax,255
 mov DWORD PTR [r8+8],eax
 mov DWORD PTR [r8+12],0
 movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [r8+16],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [r8+20],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [r8+24],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [r8+28],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [r8+32],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [r8+36],eax
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [r8+40],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [r8+44],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [r8+48],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [r8+52],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [r8+56],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [r8+60],eax
 mov esi,DWORD PTR [rbp+16]
 lea edi,[r8+112]
 mov ecx,24
 rep movsb
 mov esi,DWORD PTR [rbp+24]
 lea edi,[r8+136]
 mov ecx,338
 rep movsb
 mov esi,DWORD PTR [rbp+32]
 lea edi,[r8+474]
 mov ecx,338
 rep movsb
 test DWORD PTR [r9],1
jz script_global_done_0
mov eax,DWORD PTR [r9+4]
mov BYTE PTR [DATA_008696],al
script_global_done_0:
test DWORD PTR [r9],2
jz script_global_done_1
mov eax,DWORD PTR [r9+8]
mov BYTE PTR [DATA_008697],al
script_global_done_1:
test DWORD PTR [r9],4
jz script_global_done_2
mov eax,DWORD PTR [r9+12]
mov BYTE PTR [DATA_008698],al
script_global_done_2:
test DWORD PTR [r9],8
jz script_global_done_3
mov eax,DWORD PTR [r9+16]
mov BYTE PTR [DATA_008699],al
script_global_done_3:
test DWORD PTR [r9],16
jz script_global_done_4
mov eax,DWORD PTR [r9+20]
mov BYTE PTR [DATA_008700],al
script_global_done_4:
test DWORD PTR [r9],32
jz script_global_done_5
mov eax,DWORD PTR [r9+24]
mov BYTE PTR [DATA_008701],al
script_global_done_5:
test DWORD PTR [r9],64
jz script_global_done_6
mov eax,DWORD PTR [r9+28]
call decode_ref
mov DWORD PTR [DATA_008702],eax
script_global_done_6:
test DWORD PTR [r9],128
jz script_global_done_7
mov eax,DWORD PTR [r9+32]
mov DWORD PTR [DATA_008703],eax
script_global_done_7:
test DWORD PTR [r9],256
jz script_global_done_8
mov eax,DWORD PTR [r9+36]
mov DWORD PTR [DATA_008704],eax
script_global_done_8:
test DWORD PTR [r9],512
jz script_global_done_9
mov eax,DWORD PTR [r9+40]
mov DWORD PTR [DATA_008705],eax
script_global_done_9:
test DWORD PTR [r9],1024
jz script_global_done_10
mov eax,DWORD PTR [r9+44]
mov DWORD PTR [DATA_008706],eax
script_global_done_10:
test DWORD PTR [r9],2048
jz script_global_done_11
mov eax,DWORD PTR [r9+48]
mov BYTE PTR [DATA_008707],al
script_global_done_11:
 cmp DWORD PTR [r9+72],0
 je full_records_done
 mov esi,r9d
 add esi,76
 mov edi,DWORD PTR [rbp+24]
 mov ecx,338
 rep movsb
 mov esi,r9d
 add esi,414
 mov edi,DWORD PTR [rbp+32]
 mov ecx,338
 rep movsb
full_records_done:

 mov eax,DWORD PTR [r9+56]
 cmp eax,338
 jae no_subject_xor
 mov esi,DWORD PTR [rbp+24]
 mov dl,BYTE PTR [r9+60]
 xor BYTE PTR [rsi+rax],dl
no_subject_xor:
 mov eax,DWORD PTR [r9+64]
 cmp eax,338
 jae no_collider_xor
 mov esi,DWORD PTR [rbp+32]
 mov dl,BYTE PTR [r9+68]
 xor BYTE PTR [rsi+rax],dl
no_collider_xor:
 movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [r8+64],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [r8+68],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [r8+72],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [r8+76],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [r8+80],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [r8+84],eax
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [r8+88],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [r8+92],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [r8+96],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [r8+100],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [r8+104],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [r8+108],eax
 mov esi,DWORD PTR [rbp+24]
 lea edi,[r8+812]
 mov ecx,338
 rep movsb
 mov esi,DWORD PTR [rbp+32]
 lea edi,[r8+1150]
 mov ecx,338
 rep movsb
 inc DWORD PTR [call_count]
 mov eax,DWORD PTR [r8+8]
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
 add rsi,r8
 mov edx,125868
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,125868
 jne read_more
 cld
 mov edi,OFFSET FLAT:player_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:bank_before
 mov ecx,38986+32
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,210588
 xor eax,eax
 rep stosb
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:player
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:bank
 mov ecx,38986
 rep movsb
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_009155],eax
 mov eax,DWORD PTR [input+8]
 mov BYTE PTR [DATA_008811],al
 mov DWORD PTR [call_count],0
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
call decode_ref
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
 push OFFSET FLAT:out_material
 push OFFSET FLAT:out_altitude
 push OFFSET FLAT:out_reference
 push OFFSET FLAT:out_index
 push OFFSET FLAT:out_flags
 push OFFSET FLAT:bank
 push OFFSET FLAT:player
 cmp DWORD PTR [input],0
 je call_disabled
 call FUNC_000569
 jmp called
call_disabled:
 call FUNC_000568
called:
 add rsp,56
 and eax,255
 mov DWORD PTR [output+68],eax
 mov r8d,OFFSET FLAT:output
 movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [r8+0],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [r8+4],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [r8+8],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [r8+12],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [r8+16],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [r8+20],eax
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [r8+24],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [r8+28],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [r8+32],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [r8+36],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [r8+40],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [r8+44],eax
 movzx eax,BYTE PTR [out_flags]
 mov DWORD PTR [output+48],eax
 movzx eax,BYTE PTR [out_index]
 mov DWORD PTR [output+52],eax
 mov eax,DWORD PTR [out_reference]
 call encode_ref
 mov DWORD PTR [output+56],eax
 mov eax,DWORD PTR [out_altitude]
 mov DWORD PTR [output+60],eax
 movzx eax,BYTE PTR [out_material]
 mov DWORD PTR [output+64],eax
 mov eax,DWORD PTR [call_count]
 mov DWORD PTR [output+72],eax
 mov esi,OFFSET FLAT:player
 mov edi,OFFSET FLAT:output+80
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov ecx,38986
 rep movsb
 mov edi,OFFSET FLAT:output+210588-64
 mov esi,OFFSET FLAT:player_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:player_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,210588
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
DATA_007749: .quad FUNC_001517
DATA_007753: .quad FUNC_001531
DATA_007754: .quad FUNC_001532
DATA_007758: .long bank
DATA_007800: .long 0
DATA_007801: .long 0
DATA_007802: .quad FUNC_001677
.section .bss
.balign 16
input: .zero 125868
player_before: .zero 16
player: .zero 338
player_after: .zero 16
bank_before: .zero 16
bank: .zero 38986
bank_after: .zero 16
output: .zero 210588
out_flags: .zero 4
out_index: .zero 4
out_reference: .zero 4
out_altitude: .zero 4
out_material: .zero 4
call_count: .zero 4
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
DATA_008811: .zero 1
DATA_009155: .zero 4
.balign 16
stack: .zero 8388608
stack_end:
.section .note.GNU-stack,"",@progbits
