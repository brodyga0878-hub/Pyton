.intel_syntax noprefix
.code64
.section .text
FUNC_000020:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],20
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
mov edx,[rbp+16]
mov eax,[edx]
xor ecx,ecx
mov cl,[eax]
xor ebx,ebx
mov bl,[eax+0x1]
shl ebx,0x8
add ecx,ebx
xor ebx,ebx
mov bl,[eax+0x2]
shl ebx,0x10
add ecx,ebx
xor ebx,ebx
mov bl,[eax+0x3]
shl ebx,0x18
add ecx,ebx
add eax,+0x4
mov [edx],eax
mov eax,ecx
pop rbx
pop rbp
ret
FUNC_000023:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],23
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov ecx,0x15180
xor edx,edx
div ecx
add eax,0x121cf7
pop rbp
ret
FUNC_000024:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],24
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov ecx,0x15180
xor edx,edx
div ecx
imul eax,edx,0xc22e
pop rbp
ret
FUNC_000041:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],41
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
add rsp,-156
push rbx
push rsi
push rdi
push rax
push rcx
push rsi
push rdi
mov esi,OFFSET FLAT:s_seed
lea edi,[rbp-156]
mov DWORD PTR [s_frame],edi
mov ecx,156
rep movsb
pop rdi
pop rsi
pop rcx
pop rax
mov esi,[rbp+24]
mov ebx,[rbp+16]
xor edi,edi
jmp JUMP_000450
JUMP_000359:
pushfq
inc DWORD PTR [s_steps]
cmp DWORD PTR [s_steps],4096
jbe s_budget_ok
and rsp,-16
call s_budget_abort
s_budget_ok:
popfq

mov eax,[ebx]
inc DWORD PTR [ebx]
movzx eax,BYTE PTR [eax]
pushfq
inc DWORD PTR [s_opcodes+rax*4]
popfq
cmp eax,+0x3c
ja JUMP_000450
mov r11d,DWORD PTR [rax*4+DATA_000005]
jmp r11
.section .rodata
DATA_000005:
.long JUMP_000360
.long JUMP_000361
.long JUMP_000362
.long JUMP_000364
.long JUMP_000365
.long JUMP_000368
.long JUMP_000369
.long JUMP_000370
.long JUMP_000371
.long JUMP_000372
.long JUMP_000373
.long JUMP_000374
.long JUMP_000375
.long JUMP_000376
.long JUMP_000377
.long JUMP_000378
.long JUMP_000379
.long JUMP_000380
.long JUMP_000381
.long JUMP_000382
.long JUMP_000385
.long JUMP_000386
.long JUMP_000387
.long JUMP_000388
.long JUMP_000389
.long JUMP_000390
.long JUMP_000391
.long JUMP_000392
.long JUMP_000393
.long JUMP_000394
.long JUMP_000395
.long JUMP_000396
.long JUMP_000397
.long JUMP_000398
.long JUMP_000399
.long JUMP_000400
.long JUMP_000401
.long JUMP_000402
.long JUMP_000403
.long JUMP_000404
.long JUMP_000407
.long JUMP_000408
.long JUMP_000411
.long JUMP_000414
.long JUMP_000417
.long JUMP_000418
.long JUMP_000419
.long JUMP_000420
.long JUMP_000421
.long JUMP_000424
.long JUMP_000425
.long JUMP_000428
.long JUMP_000429
.long JUMP_000434
.long JUMP_000436
.long JUMP_000439
.long JUMP_000440
.long JUMP_000441
.long JUMP_000442
.long JUMP_000448
.long JUMP_000449
.section .text
JUMP_000360:
mov edi,0x1
jmp JUMP_000450
JUMP_000361:
push rbx
call FUNC_000020
pop rcx
mov [rbp-0x14],eax
mov eax,[esi+0x4]
push rax
mov eax,[rbp-0x14]
push rax
push rsi
push rbx
call FUNC_000052
add rsp,32
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000362:
push rsi
push rbx
call FUNC_000031
add rsp,16
test eax,eax
jz JUMP_000363
add DWORD PTR [ebx],+0x4
jmp JUMP_000450
JUMP_000363:
push rbx
call FUNC_000020
pop rcx
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
add eax,-0x4
add [ebx],eax
jmp JUMP_000450
JUMP_000364:
push rbx
call FUNC_000020
pop rcx
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
add eax,-0x4
add [ebx],eax
jmp JUMP_000450
JUMP_000365:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x20],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x24],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x28],eax
mov eax,[rbp-0x1c]
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
mov eax,[rbp-0x28]
push rax
mov eax,[rbp-0x24]
push rax
mov eax,[rbp-0x20]
push rax
cmp DWORD PTR [rbp-0x1c],+0x0
jz JUMP_000366
lea eax,[rbp-0x88]
jmp JUMP_000367
JUMP_000366:
xor eax,eax
JUMP_000367:
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000331
add rsp,48
jmp JUMP_000450
JUMP_000368:
call FUNC_000342
jmp JUMP_000450
JUMP_000369:
call FUNC_000326
jmp JUMP_000450
JUMP_000370:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000371:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
call FUNC_000038
pop rcx
mov eax,[rbp-0x14]
cmp eax,[esi+0x4]
jnz JUMP_000450
mov edi,0x1
jmp JUMP_000450
JUMP_000372:
push rbx
call FUNC_000020
pop rcx
mov edi,eax
mov [esi+0x14],edi
mov eax,[esi+0x1c]
mov eax,[eax+edi*4+0x1c]
mov [esi+0x10],eax
mov DWORD PTR [esi],0x4
mov edi,0x1
jmp JUMP_000450
JUMP_000373:
mov eax,[ebx]
mov [rbp-0x10],eax
mov eax,[rbp-0x10]
push rax
call FUNC_999980
pop rcx
inc eax
add [ebx],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x20],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x24],eax
mov eax,[rbp-0x24]
push rax
mov eax,[rbp-0x20]
push rax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x10]
push rax
call FUNC_000101
add rsp,40
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000374:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
call FUNC_000102
pop rcx
jmp JUMP_000450
JUMP_000375:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
call FUNC_000103
pop rcx
jmp JUMP_000450
JUMP_000376:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
call FUNC_000097
pop rcx
jmp JUMP_000450
JUMP_000377:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
push +0x0
push +0x0
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000098
add rsp,40
jmp JUMP_000450
JUMP_000378:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000099
add rsp,16
jmp JUMP_000450
JUMP_000379:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000100
add rsp,24
jmp JUMP_000450
JUMP_000380:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000104
add rsp,16
jmp JUMP_000450
JUMP_000381:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
call FUNC_000105
pop rcx
jmp JUMP_000450
JUMP_000382:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
call FUNC_000772
pop rcx
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000383
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000384
JUMP_000383:
xor eax,eax
JUMP_000384:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000385:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
call FUNC_000039
pop rcx
jmp JUMP_000450
JUMP_000386:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[DATA_009133]
push rax
mov eax,[rbp-0x14]
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
push rax
call FUNC_000953
add rsp,24
jmp JUMP_000450
JUMP_000387:
mov DWORD PTR [rbp-0x70],0xffffffff
mov DWORD PTR [s_defined+44],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000349
pop rcx
jmp JUMP_000450
JUMP_000388:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000345
pop rcx
jmp JUMP_000450
JUMP_000389:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000346
pop rcx
jmp JUMP_000450
JUMP_000390:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
xor eax,eax
mov [rbp-0x70],eax
mov DWORD PTR [s_defined+44],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000360
pop rcx
jmp JUMP_000450
JUMP_000391:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
lea eax,[rbp-0x9c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[DATA_009133]
push rax
mov eax,[rbp-0x14]
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
add eax,0x124
push rax
mov r11d,DWORD PTR [DATA_007639]
call r11
add rsp,24
mov eax,[rbp-0x14]
push rax
push +0x0
push +0x12
call FUNC_000048
add rsp,24
jmp JUMP_000450
JUMP_000392:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000345
pop rcx
jmp JUMP_000450
JUMP_000393:
mov DWORD PTR [rbp-0x70],0xffffffff
mov DWORD PTR [s_defined+44],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000349
pop rcx
jmp JUMP_000450
JUMP_000394:
mov DWORD PTR [rbp-0x70],0xffffffff
mov DWORD PTR [s_defined+44],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000352
pop rcx
jmp JUMP_000450
JUMP_000395:
mov DWORD PTR [rbp-0x70],0xffffffff
mov DWORD PTR [s_defined+44],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000352
pop rcx
jmp JUMP_000450
JUMP_000396:
mov DWORD PTR [rbp-0x70],0xffffffff
mov DWORD PTR [s_defined+44],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x80],eax
mov DWORD PTR [s_defined+28],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000352
pop rcx
jmp JUMP_000450
JUMP_000397:
mov DWORD PTR [rbp-0x70],0xffffffff
mov DWORD PTR [s_defined+44],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000347
pop rcx
jmp JUMP_000450
JUMP_000398:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
imul eax,eax,0xc22e
mov [rbp-0x18],eax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000332
add rsp,16
jmp JUMP_000450
JUMP_000399:
call FUNC_000359
jmp JUMP_000450
JUMP_000400:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
lea eax,[rbp-0x9c]
push rax
mov eax,[rbp-0x14]
push rax
mov eax,[DATA_008558]
push rax
mov r11d,DWORD PTR [DATA_007639]
call r11
add rsp,24
dec eax
mov [DATA_008558],eax
jmp JUMP_000450
JUMP_000401:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x9c],eax
mov DWORD PTR [s_defined+0],0x01010101
lea eax,[rbp-0x9c]
push rax
mov eax,[rbp-0x14]
push rax
mov eax,[DATA_008558]
push rax
mov r11d,DWORD PTR [DATA_007639]
call r11
add rsp,24
dec eax
mov [DATA_008558],eax
jmp JUMP_000450
JUMP_000402:
mov eax,[DATA_008885]
push rax
push OFFSET FLAT:DATA_002244
push +0x0
push +0x0
push +0x0
push +0x0
push +0x0
push +0x0
push +0x0
push +0x0
push +0x7
call FUNC_000314
add rsp,88
mov [rbp-0x14],eax
mov eax,[rbp-0x14]
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000403:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
call FUNC_000315
pop rcx
jmp JUMP_000450
JUMP_000404:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x20],eax
mov eax,[rbp-0x20]
push rax
call FUNC_000023
pop rcx
push rax
mov eax,[rbp-0x20]
push rax
call FUNC_000024
pop rcx
push rax
mov al,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000664
add rsp,40
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000405
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000406
JUMP_000405:
xor eax,eax
JUMP_000406:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000407:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[DATA_008862]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000236
add rsp,24
jmp JUMP_000450
JUMP_000408:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000665
add rsp,16
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000409
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000410
JUMP_000409:
xor eax,eax
JUMP_000410:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000411:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000666
add rsp,16
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000412
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000413
JUMP_000412:
xor eax,eax
JUMP_000413:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000414:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000668
add rsp,16
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000415
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000416
JUMP_000415:
xor eax,eax
JUMP_000416:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000417:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000346
pop rcx
jmp JUMP_000450
JUMP_000418:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x9c],eax
mov DWORD PTR [s_defined+0],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x98],eax
mov DWORD PTR [s_defined+4],0x01010101
lea eax,[rbp-0x9c]
push rax
mov eax,[rbp-0x14]
push rax
mov eax,[DATA_008558]
push rax
mov r11d,DWORD PTR [DATA_007639]
call r11
add rsp,24
dec eax
mov [DATA_008558],eax
jmp JUMP_000450
JUMP_000419:
mov DWORD PTR [rbp-0x70],0xffffffff
mov DWORD PTR [s_defined+44],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000347
pop rcx
jmp JUMP_000450
JUMP_000420:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x9c],eax
mov DWORD PTR [s_defined+0],0x01010101
lea eax,[rbp-0x9c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[DATA_009133]
push rax
mov eax,[rbp-0x14]
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
add eax,0x124
push rax
mov r11d,DWORD PTR [DATA_007639]
call r11
add rsp,24
mov eax,[rbp-0x14]
push rax
push +0x0
push +0x12
call FUNC_000048
add rsp,24
jmp JUMP_000450
JUMP_000421:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x20],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x24],eax
mov eax,[rbp-0x24]
push rax
mov eax,[rbp-0x20]
push rax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000297
add rsp,40
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000422
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000423
JUMP_000422:
xor eax,eax
JUMP_000423:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000424:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
call FUNC_000023
pop rcx
mov [rbp-0x20],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x24],eax
mov eax,[rbp-0x24]
push rax
mov eax,[rbp-0x20]
push rax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000290
add rsp,40
jmp JUMP_000450
JUMP_000425:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x20],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x24],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x28],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x2c],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x30],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov eax,[rbp-0x30]
push rax
mov eax,[rbp-0x2c]
push rax
mov eax,[rbp-0x28]
push rax
mov eax,[rbp-0x24]
push rax
mov eax,[rbp-0x20]
push rax
mov eax,[rbp-0x1c]
push rax
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x14]
push rax
call FUNC_000040
add rsp,72
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000426
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000427
JUMP_000426:
xor eax,eax
JUMP_000427:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000428:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[DATA_009133]
push rax
mov eax,[rbp-0x14]
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000450
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x8]
push rax
call FUNC_000942
add rsp,16
jmp JUMP_000450
JUMP_000429:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[DATA_009133]
push rax
mov eax,[rbp-0x18]
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000430
mov eax,[rbp-0x8]
push rax
mov eax,[rbp-0x14]
add eax,0x8e00
push rax
call FUNC_000926
add rsp,16
jmp JUMP_000431
JUMP_000430:
xor eax,eax
JUMP_000431:
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000432
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000433
JUMP_000432:
xor eax,eax
JUMP_000433:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000434:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
cmp DWORD PTR [rbp-0x14],+0x1
jnz JUMP_000435
mov eax,[rbp-0x1c]
push rax
lea eax,[rbp-0x4]
push rax
mov al,[rbp-0x18]
push rax
call FUNC_000305
add rsp,24
jmp JUMP_000450
JUMP_000435:
cmp DWORD PTR [rbp-0x14],+0x2
jnz JUMP_000450
mov eax,[rbp-0x1c]
push rax
lea eax,[rbp-0x4]
push rax
mov al,[rbp-0x18]
push rax
call FUNC_000304
add rsp,24
jmp JUMP_000450
JUMP_000436:
mov eax,[DATA_009133]
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov [rbp-0x8],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x3c],eax
mov eax,[rbp-0x3c]
push rax
mov eax,[rbp-0x8]
push rax
call FUNC_000702
add rsp,16
cmp DWORD PTR [rbp-0x18],+0x0
jz JUMP_000438
cmp DWORD PTR [DATA_009133],+0x0
jz JUMP_000437
mov al,[rbp-0x18]
mov edx,[rbp-0x8]
mov [edx+0x56],al
jmp JUMP_000450
JUMP_000437:
mov eax,[DATA_009133]
push rax
mov eax,[rbp-0x18]
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov [rbp-0xc],eax
mov eax,[rbp-0xc]
push QWORD PTR [rax+0x42]
push QWORD PTR [rax+0x3e]
mov eax,[rbp-0x8]
push QWORD PTR [rax+0x42]
push QWORD PTR [rax+0x3e]
mov eax,[rbp-0x8]
add eax,+0x3e
push rax
call FUNC_001333
add rsp,40
mov eax,[rbp-0xc]
push QWORD PTR [rax+0x4a]
push QWORD PTR [rax+0x46]
mov eax,[rbp-0x8]
push QWORD PTR [rax+0x4a]
push QWORD PTR [rax+0x46]
mov eax,[rbp-0x8]
add eax,+0x46
push rax
call FUNC_001333
add rsp,40
mov eax,[rbp-0xc]
push QWORD PTR [rax+0x52]
push QWORD PTR [rax+0x4e]
mov eax,[rbp-0x8]
push QWORD PTR [rax+0x52]
push QWORD PTR [rax+0x4e]
mov eax,[rbp-0x8]
add eax,+0x4e
push rax
call FUNC_001333
add rsp,40
mov eax,[rbp-0xc]
mov al,[eax+0x56]
mov edx,[rbp-0x8]
mov [edx+0x56],al
jmp JUMP_000450
JUMP_000438:
mov eax,[rbp-0x8]
mov BYTE PTR [eax+0x56],0x0
jmp JUMP_000450
JUMP_000439:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x80],eax
mov DWORD PTR [s_defined+28],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000345
pop rcx
jmp JUMP_000450
JUMP_000440:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x80],eax
mov DWORD PTR [s_defined+28],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x7c],eax
mov DWORD PTR [s_defined+32],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000345
pop rcx
jmp JUMP_000450
JUMP_000441:
mov eax,[DATA_009133]
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov [rbp-0x8],eax
mov eax,[rbp-0x8]
xor edx,edx
mov [eax+0x8c],edx
mov eax,[rbp-0x8]
xor edx,edx
mov [eax+0x90],edx
mov eax,[rbp-0x8]
xor edx,edx
mov [eax+0x94],edx
jmp JUMP_000450
JUMP_000442:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x14],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x18],eax
mov eax,[DATA_009133]
push rax
mov eax,[rbp-0x14]
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov [rbp-0x8],eax
sub DWORD PTR [rbp-0x18],0x3e8
cmp DWORD PTR [rbp-0x18],+0x0
jl JUMP_000445
cmp DWORD PTR [rbp-0x18],+0x26
jnl JUMP_000445
mov eax,[rbp-0x8]
cmp eax,[DATA_008861]
jnz JUMP_000443
mov eax,[rbp-0x18]
cmp WORD PTR [eax*2+DATA_008896],+0x0
jz JUMP_000444
JUMP_000443:
mov eax,[rbp-0x18]
push rax
mov eax,[rbp-0x8]
push rax
call FUNC_000291
add rsp,16
mov [rbp-0x8],eax
jmp JUMP_000445
JUMP_000444:
xor eax,eax
mov [rbp-0x8],eax
JUMP_000445:
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000446
mov eax,[rbp-0x8]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000447
JUMP_000446:
xor eax,eax
JUMP_000447:
push rax
push rsi
push rbx
call FUNC_000037
add rsp,24
jmp JUMP_000450
JUMP_000448:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x88],eax
mov DWORD PTR [s_defined+20],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x84],eax
mov DWORD PTR [s_defined+24],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x80],eax
mov DWORD PTR [s_defined+28],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x7c],eax
mov DWORD PTR [s_defined+32],0x01010101
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x64],eax
mov DWORD PTR [s_defined+56],0x01010101
xor eax,eax
mov [rbp-0x70],eax
mov DWORD PTR [s_defined+44],0x01010101
lea eax,[rbp-0x88]
push rax
call FUNC_000360
pop rcx
jmp JUMP_000450
JUMP_000449:
mov eax,[DATA_009133]
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov [rbp-0x8],eax
mov eax,[rbp-0x8]
mov BYTE PTR [eax+0xff],0xb
mov eax,[rbp-0x8]
mov al,[eax+0xfe]
mov edx,[rbp-0x8]
mov [edx+0x100],al
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edx,[rbp-0x8]
mov [edx+0xfe],al
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x1c],eax
mov eax,[rbp-0x1c]
lea eax,[eax+eax*2]
mov dx,[eax*4+DATA_001705]
mov ecx,[rbp-0x8]
mov [ecx+0x102],dx
mov dx,[eax*4+DATA_001706]
mov ecx,[rbp-0x8]
mov [ecx+0x104],dx
mov ax,[eax*4+DATA_001707]
mov edx,[rbp-0x8]
mov [edx+0x106],ax
JUMP_000450:
test edi,edi
jz JUMP_000359
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_001333:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],1333
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
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
FUNC_001532:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],1532
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
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
FUNC_999980:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],999980
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
pushfq
push rax
push rcx
push rdx
push rsi
push rdi
push r11
push r12
mov r12,rsp
mov edi,DWORD PTR [rsp+72]
and rsp,-16
call s_strlen_admit
mov rsp,r12
pop r12
pop r11
pop rdi
pop rsi
pop rdx
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rdi
mov edi,[rbp+16]
mov ecx,0xffffffff
xor al,al
cld
repne scasb
not ecx
lea eax,[ecx-0x1]
pop rdi
pop rbp
ret
FUNC_000031:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],31
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,31
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000037:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],37
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,37
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000052:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],52
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov edi,52
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000331:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],331
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov eax,DWORD PTR [rbp+56]
mov DWORD PTR [s_args+20],eax
mov edi,331
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000342:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],342
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp

mov edi,342
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000326:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],326
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp

mov edi,326
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000038:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],38
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,38
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000101:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],101
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov edi,101
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000102:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],102
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,102
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000103:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],103
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,103
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000097:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],97
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,97
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000098:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],98
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov edi,98
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000099:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],99
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,99
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000100:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],100
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,100
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000104:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],104
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,104
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000105:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],105
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,105
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000772:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],772
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,772
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000039:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],39
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,39
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000953:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],953
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,953
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000349:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],349
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,349
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000345:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],345
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,345
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000346:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],346
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,346
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000360:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],360
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,360
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_001344:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],1344
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,1344
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000048:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],48
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,48
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000352:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],352
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,352
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000347:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],347
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,347
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000332:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],332
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,332
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000359:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],359
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp

mov edi,359
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000314:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],314
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov eax,DWORD PTR [rbp+56]
mov DWORD PTR [s_args+20],eax
mov eax,DWORD PTR [rbp+64]
mov DWORD PTR [s_args+24],eax
mov eax,DWORD PTR [rbp+72]
mov DWORD PTR [s_args+28],eax
mov eax,DWORD PTR [rbp+80]
mov DWORD PTR [s_args+32],eax
mov eax,DWORD PTR [rbp+88]
mov DWORD PTR [s_args+36],eax
mov eax,DWORD PTR [rbp+96]
mov DWORD PTR [s_args+40],eax
mov edi,314
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000315:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],315
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov edi,315
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000664:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],664
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov edi,664
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000236:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],236
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,236
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000665:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],665
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,665
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000666:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],666
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,666
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000668:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],668
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,668
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000297:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],297
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov edi,297
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000290:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],290
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov edi,290
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000040:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],40
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [s_args+12],eax
mov eax,DWORD PTR [rbp+48]
mov DWORD PTR [s_args+16],eax
mov eax,DWORD PTR [rbp+56]
mov DWORD PTR [s_args+20],eax
mov eax,DWORD PTR [rbp+64]
mov DWORD PTR [s_args+24],eax
mov eax,DWORD PTR [rbp+72]
mov DWORD PTR [s_args+28],eax
mov eax,DWORD PTR [rbp+80]
mov DWORD PTR [s_args+32],eax
mov edi,40
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000942:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],942
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,942
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000926:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],926
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,926
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000305:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],305
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,305
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000304:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],304
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [s_args+8],eax
mov edi,304
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000702:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],702
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,702
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000291:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [s_trace_count]
mov DWORD PTR [s_trace+rcx*4],291
inc DWORD PTR [s_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov eax,DWORD PTR [rbp+16]
mov DWORD PTR [s_args+0],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [s_args+4],eax
mov edi,291
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret

.global call_kernel
call_kernel:
mov [s_saved_rsp],rsp
mov esp,OFFSET FLAT:s_stack_end
push OFFSET FLAT:s_task
push OFFSET FLAT:s_ip
call FUNC_000041
mov rsp,[s_saved_rsp]
ret
.section .data
DATA_007754:.long FUNC_001532
DATA_007639:.long FUNC_001344
s_empty:.byte 0,0
DATA_008861=s_root+200
DATA_008862=s_root+204
DATA_008885=s_root+266
DATA_008896=s_root+308
DATA_009133=s_root+22540
DATA_008558=s_text_pointer
DATA_001705=s_vectors
DATA_001706=s_vectors+4
DATA_001707=s_vectors+8
DATA_002244=s_empty
.section .bss
.balign 16
s_stack:.zero 4194304
s_stack_end:
s_saved_rsp:.zero 8
.section .note.GNU-stack,"",@progbits
