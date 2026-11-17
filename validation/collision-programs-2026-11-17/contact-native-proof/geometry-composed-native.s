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
call QWORD PTR [DATA_007756]
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
FUNC_000579:
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
call QWORD PTR [DATA_007756]
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

encode_ref:
 cmp eax,114
 jbe ref_done
 cmp eax,OFFSET FLAT:body
 je ref_body
 cmp eax,OFFSET FLAT:collider
 jne failed
 movzx eax,BYTE PTR [collider+0x86]
 ret
ref_body:
 movzx eax,BYTE PTR [body+0x86]
ref_done:
 ret
FUNC_001538:
 mov eax,DWORD PTR [rsp+8]
 cmp eax,DWORD PTR [body+0x82]
 jne parent_model
 mov eax,OFFSET FLAT:body_descriptor
 ret
parent_model:
 cmp eax,DWORD PTR [collider+0x82]
 jne failed
 mov eax,OFFSET FLAT:parent_descriptor
 ret
FUNC_000582:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [call_count]
 cmp eax,16
 jae failed
 imul ecx,eax,152
 add ecx,OFFSET FLAT:output+764
 mov QWORD PTR [current_record],rcx
 mov r8,rcx
 imul ecx,eax,56
 add ecx,OFFSET FLAT:input+1148
 mov QWORD PTR [current_script],rcx
 mov esi,DWORD PTR [rbp+24]
 lea edi,[r8]
 mov ecx,12
 rep movsb
 mov eax,DWORD PTR [rsi+8]
 mov DWORD PTR [r8+12],eax
 mov eax,DWORD PTR [rsi+12]
 mov DWORD PTR [r8+16],eax
 mov eax,DWORD PTR [rbp+48]
 mov DWORD PTR [r8+20],eax
 movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [r8+24+0],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [r8+24+4],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [r8+24+8],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [r8+24+12],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [r8+24+16],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [r8+24+20],eax
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [r8+24+24],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [r8+24+28],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [r8+24+32],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [r8+24+36],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [r8+24+40],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [r8+24+44],eax
 mov r10,QWORD PTR [current_script]
 mov eax,DWORD PTR [r10]
 mov DWORD PTR [r8+120],eax
 mov eax,DWORD PTR [r10+4]
 mov DWORD PTR [r8+124],eax
 mov edx,DWORD PTR [rbp+16]
 mov BYTE PTR [rdx],al
 lea esi,[r10+8]
 mov eax,DWORD PTR [rsi]
 mov BYTE PTR [DATA_008696],al
 mov eax,DWORD PTR [rsi+4]
 mov BYTE PTR [DATA_008697],al
 mov eax,DWORD PTR [rsi+8]
 mov BYTE PTR [DATA_008698],al
 mov eax,DWORD PTR [rsi+12]
 mov BYTE PTR [DATA_008699],al
 mov eax,DWORD PTR [rsi+16]
 mov BYTE PTR [DATA_008700],al
 mov eax,DWORD PTR [rsi+20]
 mov BYTE PTR [DATA_008701],al
 mov eax,DWORD PTR [rsi+24]
 mov DWORD PTR [DATA_008702],eax
 mov eax,DWORD PTR [rsi+28]
 mov DWORD PTR [DATA_008703],eax
 mov eax,DWORD PTR [rsi+32]
 mov DWORD PTR [DATA_008704],eax
 mov eax,DWORD PTR [rsi+36]
 mov DWORD PTR [DATA_008705],eax
 mov eax,DWORD PTR [rsi+40]
 mov DWORD PTR [DATA_008706],eax
 mov eax,DWORD PTR [rsi+44]
 mov BYTE PTR [DATA_008707],al
 movzx eax,BYTE PTR [DATA_008696]
mov DWORD PTR [r8+72+0],eax
movzx eax,BYTE PTR [DATA_008697]
mov DWORD PTR [r8+72+4],eax
movzx eax,BYTE PTR [DATA_008698]
mov DWORD PTR [r8+72+8],eax
movzx eax,BYTE PTR [DATA_008699]
mov DWORD PTR [r8+72+12],eax
movzx eax,BYTE PTR [DATA_008700]
mov DWORD PTR [r8+72+16],eax
movzx eax,BYTE PTR [DATA_008701]
mov DWORD PTR [r8+72+20],eax
mov eax,DWORD PTR [DATA_008702]
call encode_ref
mov DWORD PTR [r8+72+24],eax
mov eax,DWORD PTR [DATA_008703]
mov DWORD PTR [r8+72+28],eax
mov eax,DWORD PTR [DATA_008704]
mov DWORD PTR [r8+72+32],eax
mov eax,DWORD PTR [DATA_008705]
mov DWORD PTR [r8+72+36],eax
mov eax,DWORD PTR [DATA_008706]
mov DWORD PTR [r8+72+40],eax
movzx eax,BYTE PTR [DATA_008707]
mov DWORD PTR [r8+72+44],eax
 mov rax,QWORD PTR [rbp]
 mov esi,DWORD PTR [rax+40]
 lea edi,[r8+128]
 mov ecx,24
 rep movsb
 inc DWORD PTR [call_count]
 mov r10,QWORD PTR [current_script]
 mov eax,DWORD PTR [r10]
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
 mov edx,2048
 sub edx,r8d
 syscall
 test eax,eax
 jle finish
 add r8d,eax
 cmp r8d,2048
 jne read_more
 cld
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,3328
 rep stosb
 mov DWORD PTR [call_count],0
 mov rax,0xa5a5a5a5a5a5a5a5
 mov QWORD PTR [body_guard_a],rax
 mov QWORD PTR [body_guard_b],rax
 mov QWORD PTR [collider_guard_a],rax
 mov QWORD PTR [collider_guard_b],rax
 mov QWORD PTR [relative_guard_a],rax
 mov QWORD PTR [relative_guard_b],rax
 mov QWORD PTR [body_descriptor_guard_a],rax
 mov QWORD PTR [body_descriptor_guard_b],rax
 mov QWORD PTR [parent_descriptor_guard_a],rax
 mov QWORD PTR [parent_descriptor_guard_b],rax
 mov QWORD PTR [children_guard_a],rax
 mov QWORD PTR [children_guard_b],rax
 mov esi,OFFSET FLAT:input+56
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov edi,OFFSET FLAT:body_descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:parent_descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:children
 mov ecx,256
 rep movsb
 mov DWORD PTR [body_descriptor+0x34],OFFSET FLAT:children+256
 mov DWORD PTR [parent_descriptor+0x34],OFFSET FLAT:program
 mov DWORD PTR [parent_descriptor+4],OFFSET FLAT:program
 mov DWORD PTR [parent_descriptor+12],OFFSET FLAT:program
 mov esi,OFFSET FLAT:input+8
 mov eax,DWORD PTR [rsi]
 mov BYTE PTR [DATA_008696],al
 mov eax,DWORD PTR [rsi+4]
 mov BYTE PTR [DATA_008697],al
 mov eax,DWORD PTR [rsi+8]
 mov BYTE PTR [DATA_008698],al
 mov eax,DWORD PTR [rsi+12]
 mov BYTE PTR [DATA_008699],al
 mov eax,DWORD PTR [rsi+16]
 mov BYTE PTR [DATA_008700],al
 mov eax,DWORD PTR [rsi+20]
 mov BYTE PTR [DATA_008701],al
 mov eax,DWORD PTR [rsi+24]
 mov DWORD PTR [DATA_008702],eax
 mov eax,DWORD PTR [rsi+28]
 mov DWORD PTR [DATA_008703],eax
 mov eax,DWORD PTR [rsi+32]
 mov DWORD PTR [DATA_008704],eax
 mov eax,DWORD PTR [rsi+36]
 mov DWORD PTR [DATA_008705],eax
 mov eax,DWORD PTR [rsi+40]
 mov DWORD PTR [DATA_008706],eax
 mov eax,DWORD PTR [rsi+44]
 mov BYTE PTR [DATA_008707],al
 mov eax,OFFSET FLAT:relative
 push rax
 mov eax,OFFSET FLAT:collider
 push rax
 mov eax,OFFSET FLAT:body
 push rax
 call FUNC_000576
 add rsp,24
 mov DWORD PTR [result_value],eax
 mov DWORD PTR [output],0x47454f4d
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [call_count]
 mov DWORD PTR [output+8],eax
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+16
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov r8d,OFFSET FLAT:output+716
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
 mov rax,0xa5a5a5a5a5a5a5a5
 cmp QWORD PTR [body_guard_a],rax
 jne failed
 cmp QWORD PTR [body_guard_b],rax
 jne failed
 cmp QWORD PTR [collider_guard_a],rax
 jne failed
 cmp QWORD PTR [collider_guard_b],rax
 jne failed
 cmp QWORD PTR [relative_guard_a],rax
 jne failed
 cmp QWORD PTR [relative_guard_b],rax
 jne failed
 cmp QWORD PTR [body_descriptor_guard_a],rax
 jne failed
 cmp QWORD PTR [body_descriptor_guard_b],rax
 jne failed
 cmp QWORD PTR [parent_descriptor_guard_a],rax
 jne failed
 cmp QWORD PTR [parent_descriptor_guard_b],rax
 jne failed
 cmp QWORD PTR [children_guard_a],rax
 jne failed
 cmp QWORD PTR [children_guard_b],rax
 jne failed
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,3328
 syscall
 cmp eax,3328
 jne failed
 jmp next_case
finish:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,91
 syscall

.section .data
.balign 8
DATA_007756: .quad FUNC_001538

.section .bss
.balign 16
input: .zero 2048
output: .zero 3328
call_count: .zero 4
result_value: .zero 4
current_record: .zero 8
current_script: .zero 8
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
body_guard_a: .zero 8
body: .zero 338
body_guard_b: .zero 8
collider_guard_a: .zero 8
collider: .zero 338
collider_guard_b: .zero 8
relative_guard_a: .zero 8
relative: .zero 24
relative_guard_b: .zero 8
body_descriptor_guard_a: .zero 8
body_descriptor: .zero 68
body_descriptor_guard_b: .zero 8
parent_descriptor_guard_a: .zero 8
parent_descriptor: .zero 68
parent_descriptor_guard_b: .zero 8
children_guard_a: .zero 8
children: .zero 256
children_guard_b: .zero 8
program_guard_a: .zero 8
program: .zero 16
program_guard_b: .zero 8
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
