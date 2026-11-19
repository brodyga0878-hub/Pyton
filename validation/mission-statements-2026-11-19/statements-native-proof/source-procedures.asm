FUNC_000020:			; Pos = 11464

		push ebp
		mov ebp,esp
		push ebx
		mov edx,[ebp+0x8]
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
		add eax,byte +0x4
		mov [edx],eax
		mov eax,ecx
		pop ebx
		pop ebp
		ret




FUNC_000023:			; Pos = 11698

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov ecx,0x15180
		xor edx,edx
		div ecx
		add eax,0x121cf7
		pop ebp
		ret




FUNC_000024:			; Pos = 116b0

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov ecx,0x15180
		xor edx,edx
		div ecx
		imul eax,edx,0xc22e
		pop ebp
		ret




FUNC_000041:			; Pos = 12c5c

		push ebp
		mov ebp,esp
		add esp,0xffffff64
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		xor edi,edi
		jmp JUMP_000450
	JUMP_000359:			; Pos = 12c75
		mov eax,[ebx]
		inc dword [ebx]
		movzx eax,byte [eax]
		cmp eax,byte +0x3c
		ja near JUMP_000450
		jmp near [eax*4+DATA_000005]


SECTION .data

DATA_000005:			; Pos = 12c8c
	dd JUMP_000360
	dd JUMP_000361
	dd JUMP_000362
	dd JUMP_000364
	dd JUMP_000365
	dd JUMP_000368
	dd JUMP_000369
	dd JUMP_000370
	dd JUMP_000371
	dd JUMP_000372
	dd JUMP_000373
	dd JUMP_000374
	dd JUMP_000375
	dd JUMP_000376
	dd JUMP_000377
	dd JUMP_000378
	dd JUMP_000379
	dd JUMP_000380
	dd JUMP_000381
	dd JUMP_000382
	dd JUMP_000385
	dd JUMP_000386
	dd JUMP_000387
	dd JUMP_000388
	dd JUMP_000389
	dd JUMP_000390
	dd JUMP_000391
	dd JUMP_000392
	dd JUMP_000393
	dd JUMP_000394
	dd JUMP_000395
	dd JUMP_000396
	dd JUMP_000397
	dd JUMP_000398
	dd JUMP_000399
	dd JUMP_000400
	dd JUMP_000401
	dd JUMP_000402
	dd JUMP_000403
	dd JUMP_000404
	dd JUMP_000407
	dd JUMP_000408
	dd JUMP_000411
	dd JUMP_000414
	dd JUMP_000417
	dd JUMP_000418
	dd JUMP_000419
	dd JUMP_000420
	dd JUMP_000421
	dd JUMP_000424
	dd JUMP_000425
	dd JUMP_000428
	dd JUMP_000429
	dd JUMP_000434
	dd JUMP_000436
	dd JUMP_000439
	dd JUMP_000440
	dd JUMP_000441
	dd JUMP_000442
	dd JUMP_000448
	dd JUMP_000449


SECTION .text
	JUMP_000360:			; Pos = 12d80
		mov edi,0x1
		jmp JUMP_000450
	JUMP_000361:			; Pos = 12d8a
		push ebx
		call FUNC_000020
		pop ecx
		mov [ebp-0x14],eax
		mov eax,[esi+0x4]
		push eax
		mov eax,[ebp-0x14]
		push eax
		push esi
		push ebx
		call FUNC_000052
		add esp,byte +0x10
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000362:			; Pos = 12dbc
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		test eax,eax
		jz JUMP_000363
		add dword [ebx],byte +0x4
		jmp JUMP_000450
	JUMP_000363:			; Pos = 12dd2
		push ebx
		call FUNC_000020
		pop ecx
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		add eax,byte -0x4
		add [ebx],eax
		jmp JUMP_000450
	JUMP_000364:			; Pos = 12de9
		push ebx
		call FUNC_000020
		pop ecx
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		add eax,byte -0x4
		add [ebx],eax
		jmp JUMP_000450
	JUMP_000365:			; Pos = 12e00
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x20],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x24],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x28],eax
		mov eax,[ebp-0x1c]
		mov [ebp+0xffffff78],eax
		mov eax,[ebp-0x28]
		push eax
		mov eax,[ebp-0x24]
		push eax
		mov eax,[ebp-0x20]
		push eax
		cmp dword [ebp-0x1c],byte +0x0
		jz JUMP_000366
		lea eax,[ebp+0xffffff78]
		jmp short JUMP_000367
	JUMP_000366:			; Pos = 12e71
		xor eax,eax
	JUMP_000367:			; Pos = 12e73
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000331
		add esp,byte +0x18
		jmp JUMP_000450
	JUMP_000368:			; Pos = 12e89
		call FUNC_000342
		jmp JUMP_000450
	JUMP_000369:			; Pos = 12e93
		call FUNC_000326
		jmp JUMP_000450
	JUMP_000370:			; Pos = 12e9d
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000371:			; Pos = 12ebd
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000038
		pop ecx
		mov eax,[ebp-0x14]
		cmp eax,[esi+0x4]
		jnz near JUMP_000450
		mov edi,0x1
		jmp JUMP_000450
	JUMP_000372:			; Pos = 12eea
		push ebx
		call FUNC_000020
		pop ecx
		mov edi,eax
		mov [esi+0x14],edi
		mov eax,[esi+0x1c]
		mov eax,[eax+edi*4+0x1c]
		mov [esi+0x10],eax
		mov dword [esi],0x4
		mov edi,0x1
		jmp JUMP_000450
	JUMP_000373:			; Pos = 12f10
		mov eax,[ebx]
		mov [ebp-0x10],eax
		mov eax,[ebp-0x10]
		push eax
		call _strlen
		pop ecx
		inc eax
		add [ebx],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x20],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x24],eax
		mov eax,[ebp-0x24]
		push eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x10]
		push eax
		call FUNC_000101
		add esp,byte +0x14
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000374:			; Pos = 12f88
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000102
		pop ecx
		jmp JUMP_000450
	JUMP_000375:			; Pos = 12fa4
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000103
		pop ecx
		jmp JUMP_000450
	JUMP_000376:			; Pos = 12fc0
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000097
		pop ecx
		jmp JUMP_000450
	JUMP_000377:			; Pos = 12fdc
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		push byte +0x0
		push byte +0x0
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000098
		add esp,byte +0x14
		jmp JUMP_000450
	JUMP_000378:			; Pos = 13020
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000099
		add esp,byte +0x8
		jmp JUMP_000450
	JUMP_000379:			; Pos = 1304f
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000100
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000380:			; Pos = 1308f
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000104
		add esp,byte +0x8
		jmp JUMP_000450
	JUMP_000381:			; Pos = 130be
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call FUNC_000105
		pop ecx
		jmp JUMP_000450
	JUMP_000382:			; Pos = 130d4
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000772
		pop ecx
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000383
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000384
	JUMP_000383:			; Pos = 13100
		xor eax,eax
	JUMP_000384:			; Pos = 13102
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000385:			; Pos = 13112
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call FUNC_000039
		pop ecx
		jmp JUMP_000450
	JUMP_000386:			; Pos = 13128
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		push eax
		call FUNC_000953
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000387:			; Pos = 13178
		mov dword [ebp-0x70],0xffffffff
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000349
		pop ecx
		jmp JUMP_000450
	JUMP_000388:			; Pos = 131a1
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000345
		pop ecx
		jmp JUMP_000450
	JUMP_000389:			; Pos = 131c3
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000346
		pop ecx
		jmp JUMP_000450
	JUMP_000390:			; Pos = 131e5
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		xor eax,eax
		mov [ebp-0x70],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000360
		pop ecx
		jmp JUMP_000450
	JUMP_000391:			; Pos = 1320c
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		lea eax,[ebp+0xffffff64]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		add eax,0x124
		push eax
		call near [DATA_007639]    ; FUNC_001344
		add esp,byte +0xc
		mov eax,[ebp-0x14]
		push eax
		push byte +0x0
		push byte +0x12
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000392:			; Pos = 13268
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000345
		pop ecx
		jmp JUMP_000450
	JUMP_000393:			; Pos = 1329a
		mov dword [ebp-0x70],0xffffffff
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000349
		pop ecx
		jmp JUMP_000450
	JUMP_000394:			; Pos = 132d3
		mov dword [ebp-0x70],0xffffffff
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000352
		pop ecx
		jmp JUMP_000450
	JUMP_000395:			; Pos = 132fc
		mov dword [ebp-0x70],0xffffffff
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000352
		pop ecx
		jmp JUMP_000450
	JUMP_000396:			; Pos = 13335
		mov dword [ebp-0x70],0xffffffff
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x80],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000352
		pop ecx
		jmp JUMP_000450
	JUMP_000397:			; Pos = 1337b
		mov dword [ebp-0x70],0xffffffff
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000347
		pop ecx
		jmp JUMP_000450
	JUMP_000398:			; Pos = 133a4
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		imul eax,eax,0xc22e
		mov [ebp-0x18],eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000332
		add esp,byte +0x8
		jmp JUMP_000450
	JUMP_000399:			; Pos = 133d9
		call FUNC_000359
		jmp JUMP_000450
	JUMP_000400:			; Pos = 133e3
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		lea eax,[ebp+0xffffff64]
		push eax
		mov eax,[ebp-0x14]
		push eax
		mov eax,[DATA_008558]
		push eax
		call near [DATA_007639]    ; FUNC_001344
		add esp,byte +0xc
		dec eax
		mov [DATA_008558],eax
		jmp JUMP_000450
	JUMP_000401:			; Pos = 13415
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff64],eax
		lea eax,[ebp+0xffffff64]
		push eax
		mov eax,[ebp-0x14]
		push eax
		mov eax,[DATA_008558]
		push eax
		call near [DATA_007639]    ; FUNC_001344
		add esp,byte +0xc
		dec eax
		mov [DATA_008558],eax
		jmp JUMP_000450
	JUMP_000402:			; Pos = 13457
		mov eax,[DATA_008885]
		push eax
		push dword DATA_002244
		push byte +0x0
		push byte +0x0
		push byte +0x0
		push byte +0x0
		push byte +0x0
		push byte +0x0
		push byte +0x0
		push byte +0x0
		push byte +0x7
		call FUNC_000314
		add esp,byte +0x2c
		mov [ebp-0x14],eax
		mov eax,[ebp-0x14]
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000403:			; Pos = 13492
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call FUNC_000315
		pop ecx
		jmp JUMP_000450
	JUMP_000404:			; Pos = 134a8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x20],eax
		mov eax,[ebp-0x20]
		push eax
		call FUNC_000023
		pop ecx
		push eax
		mov eax,[ebp-0x20]
		push eax
		call FUNC_000024
		pop ecx
		push eax
		mov al,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000664
		add esp,byte +0x14
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000405
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000406
	JUMP_000405:			; Pos = 1351b
		xor eax,eax
	JUMP_000406:			; Pos = 1351d
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000407:			; Pos = 1352d
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[DATA_008862]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000236
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000408:			; Pos = 13562
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000665
		add esp,byte +0x8
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000409
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000410
	JUMP_000409:			; Pos = 135a1
		xor eax,eax
	JUMP_000410:			; Pos = 135a3
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000411:			; Pos = 135b3
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000666
		add esp,byte +0x8
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000412
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000413
	JUMP_000412:			; Pos = 135f2
		xor eax,eax
	JUMP_000413:			; Pos = 135f4
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000414:			; Pos = 13604
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000668
		add esp,byte +0x8
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000415
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000416
	JUMP_000415:			; Pos = 13643
		xor eax,eax
	JUMP_000416:			; Pos = 13645
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000417:			; Pos = 13655
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000346
		pop ecx
		jmp JUMP_000450
	JUMP_000418:			; Pos = 13687
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff64],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff68],eax
		lea eax,[ebp+0xffffff64]
		push eax
		mov eax,[ebp-0x14]
		push eax
		mov eax,[DATA_008558]
		push eax
		call near [DATA_007639]    ; FUNC_001344
		add esp,byte +0xc
		dec eax
		mov [DATA_008558],eax
		jmp JUMP_000450
	JUMP_000419:			; Pos = 136d9
		mov dword [ebp-0x70],0xffffffff
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000347
		pop ecx
		jmp JUMP_000450
	JUMP_000420:			; Pos = 13712
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff64],eax
		lea eax,[ebp+0xffffff64]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		add eax,0x124
		push eax
		call near [DATA_007639]    ; FUNC_001344
		add esp,byte +0xc
		mov eax,[ebp-0x14]
		push eax
		push byte +0x0
		push byte +0x12
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000421:			; Pos = 1377e
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x20],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x24],eax
		mov eax,[ebp-0x24]
		push eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000297
		add esp,byte +0x14
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000422
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000423
	JUMP_000422:			; Pos = 137f0
		xor eax,eax
	JUMP_000423:			; Pos = 137f2
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000424:			; Pos = 13802
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call FUNC_000023
		pop ecx
		mov [ebp-0x20],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x24],eax
		mov eax,[ebp-0x24]
		push eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000290
		add esp,byte +0x14
		jmp JUMP_000450
	JUMP_000425:			; Pos = 1386b
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x20],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x24],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x28],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x2c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x30],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		mov eax,[ebp-0x30]
		push eax
		mov eax,[ebp-0x2c]
		push eax
		mov eax,[ebp-0x28]
		push eax
		mov eax,[ebp-0x24]
		push eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call FUNC_000040
		add esp,byte +0x24
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000426
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000427
	JUMP_000426:			; Pos = 1391b
		xor eax,eax
	JUMP_000427:			; Pos = 1391d
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000428:			; Pos = 1392d
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz near JUMP_000450
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x8]
		push eax
		call FUNC_000942
		add esp,byte +0x8
		jmp JUMP_000450
	JUMP_000429:			; Pos = 1397c
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp-0x18]
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000430
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x14]
		add eax,0x8e00
		push eax
		call FUNC_000926
		add esp,byte +0x8
		jmp short JUMP_000431
	JUMP_000430:			; Pos = 139c9
		xor eax,eax
	JUMP_000431:			; Pos = 139cb
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000432
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000433
	JUMP_000432:			; Pos = 139e0
		xor eax,eax
	JUMP_000433:			; Pos = 139e2
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000434:			; Pos = 139f2
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		cmp dword [ebp-0x14],byte +0x1
		jnz JUMP_000435
		mov eax,[ebp-0x1c]
		push eax
		lea eax,[ebp-0x4]
		push eax
		mov al,[ebp-0x18]
		push eax
		call FUNC_000305
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000435:			; Pos = 13a38
		cmp dword [ebp-0x14],byte +0x2
		jnz near JUMP_000450
		mov eax,[ebp-0x1c]
		push eax
		lea eax,[ebp-0x4]
		push eax
		mov al,[ebp-0x18]
		push eax
		call FUNC_000304
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000436:			; Pos = 13a5b
		mov eax,[DATA_009133]
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov [ebp-0x8],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x3c],eax
		mov eax,[ebp-0x3c]
		push eax
		mov eax,[ebp-0x8]
		push eax
		call FUNC_000702
		add esp,byte +0x8
		cmp dword [ebp-0x18],byte +0x0
		jz near JUMP_000438
		cmp dword [DATA_009133],byte +0x0
		jz JUMP_000437
		mov al,[ebp-0x18]
		mov edx,[ebp-0x8]
		mov [edx+0x56],al
		jmp JUMP_000450
	JUMP_000437:			; Pos = 13ac3
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp-0x18]
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov [ebp-0xc],eax
		mov eax,[ebp-0xc]
		push dword [eax+0x42]
		push dword [eax+0x3e]
		mov eax,[ebp-0x8]
		push dword [eax+0x42]
		push dword [eax+0x3e]
		mov eax,[ebp-0x8]
		add eax,byte +0x3e
		push eax
		call FUNC_001333
		add esp,byte +0x14
		mov eax,[ebp-0xc]
		push dword [eax+0x4a]
		push dword [eax+0x46]
		mov eax,[ebp-0x8]
		push dword [eax+0x4a]
		push dword [eax+0x46]
		mov eax,[ebp-0x8]
		add eax,byte +0x46
		push eax
		call FUNC_001333
		add esp,byte +0x14
		mov eax,[ebp-0xc]
		push dword [eax+0x52]
		push dword [eax+0x4e]
		mov eax,[ebp-0x8]
		push dword [eax+0x52]
		push dword [eax+0x4e]
		mov eax,[ebp-0x8]
		add eax,byte +0x4e
		push eax
		call FUNC_001333
		add esp,byte +0x14
		mov eax,[ebp-0xc]
		mov al,[eax+0x56]
		mov edx,[ebp-0x8]
		mov [edx+0x56],al
		jmp JUMP_000450
	JUMP_000438:			; Pos = 13b4d
		mov eax,[ebp-0x8]
		mov byte [eax+0x56],0x0
		jmp JUMP_000450
	JUMP_000439:			; Pos = 13b59
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x80],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000345
		pop ecx
		jmp JUMP_000450
	JUMP_000440:			; Pos = 13b98
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x80],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x7c],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000345
		pop ecx
		jmp JUMP_000450
	JUMP_000441:			; Pos = 13be4
		mov eax,[DATA_009133]
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov [ebp-0x8],eax
		mov eax,[ebp-0x8]
		xor edx,edx
		mov [eax+0x8c],edx
		mov eax,[ebp-0x8]
		xor edx,edx
		mov [eax+0x90],edx
		mov eax,[ebp-0x8]
		xor edx,edx
		mov [eax+0x94],edx
		jmp JUMP_000450
	JUMP_000442:			; Pos = 13c27
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x14],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x18],eax
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp-0x14]
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov [ebp-0x8],eax
		sub dword [ebp-0x18],0x3e8
		cmp dword [ebp-0x18],byte +0x0
		jl JUMP_000445
		cmp dword [ebp-0x18],byte +0x26
		jnl JUMP_000445
		mov eax,[ebp-0x8]
		cmp eax,[DATA_008861]
		jnz JUMP_000443
		mov eax,[ebp-0x18]
		cmp word [eax*2+DATA_008896],byte +0x0
		jz JUMP_000444
	JUMP_000443:			; Pos = 13c83
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x8]
		push eax
		call FUNC_000291
		add esp,byte +0x8
		mov [ebp-0x8],eax
		jmp short JUMP_000445
	JUMP_000444:			; Pos = 13c98
		xor eax,eax
		mov [ebp-0x8],eax
	JUMP_000445:			; Pos = 13c9d
		cmp dword [ebp-0x8],byte +0x0
		jz JUMP_000446
		mov eax,[ebp-0x8]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000447
	JUMP_000446:			; Pos = 13caf
		xor eax,eax
	JUMP_000447:			; Pos = 13cb1
		push eax
		push esi
		push ebx
		call FUNC_000037
		add esp,byte +0xc
		jmp JUMP_000450
	JUMP_000448:			; Pos = 13cc1
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp+0xffffff7c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x80],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x7c],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x64],eax
		xor eax,eax
		mov [ebp-0x70],eax
		lea eax,[ebp+0xffffff78]
		push eax
		call FUNC_000360
		pop ecx
		jmp JUMP_000450
	JUMP_000449:			; Pos = 13d1f
		mov eax,[DATA_009133]
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov [ebp-0x8],eax
		mov eax,[ebp-0x8]
		mov byte [eax+0xff],0xb
		mov eax,[ebp-0x8]
		mov al,[eax+0xfe]
		mov edx,[ebp-0x8]
		mov [edx+0x100],al
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edx,[ebp-0x8]
		mov [edx+0xfe],al
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x1c],eax
		mov eax,[ebp-0x1c]
		lea eax,[eax+eax*2]
		mov dx,[eax*4+DATA_001705]
		mov ecx,[ebp-0x8]
		mov [ecx+0x102],dx
		mov dx,[eax*4+DATA_001706]
		mov ecx,[ebp-0x8]
		mov [ecx+0x104],dx
		mov ax,[eax*4+DATA_001707]
		mov edx,[ebp-0x8]
		mov [edx+0x106],ax
	JUMP_000450:			; Pos = 13db4
		test edi,edi
		jz near JUMP_000359
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001333:			; Pos = 4eb4e

		push ebp
		mov ebp,esp
		mov edx,[ebp+0x8]
		mov eax,[ebp+0xc]
		add eax,[ebp+0x14]
		mov [edx],eax
		mov eax,[ebp+0x10]
		adc eax,[ebp+0x18]
		mov [edx+0x4],eax
		pop ebp
		ret



; void F1334 (int *rval, int64 op1, int op2)


FUNC_001532:			; Pos = 53a54

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,eax
		lea eax,[edx+eax*4]
		lea eax,[edx+eax*4]
		lea eax,[edx+eax*8]
		add eax,eax
		add eax,[ebp+0xc]
		add eax,byte +0x74
		pop ebp
		ret




FUNC_999980: ; Pos = 70f04
 push ebp
 mov ebp,esp
 push edi
 mov edi,[ebp+0x8]
 mov ecx,0xffffffff
 xor al,al
 cld
 repne scasb
 not ecx
 lea eax,[ecx-0x1]
 pop edi
 pop ebp
 ret

FUNC_999999:
ret
