FUNC_000568:			; Pos = 27438

		push ebp
		mov ebp,esp
		mov byte [DATA_008700],0x0
		mov eax,[ebp+0x20]
		push eax
		mov eax,[ebp+0x1c]
		push eax
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x14]
		push eax
		mov eax,[ebp+0x10]
		push eax
		mov eax,[ebp+0xc]
		push eax
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000570
		add esp,byte +0x1c
		pop ebp
		ret




FUNC_000569:			; Pos = 27468

		push ebp
		mov ebp,esp
		mov byte [DATA_008700],0xff
		mov eax,[ebp+0x20]
		push eax
		mov eax,[ebp+0x1c]
		push eax
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x14]
		push eax
		mov eax,[ebp+0x10]
		push eax
		mov eax,[ebp+0xc]
		push eax
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000570
		add esp,byte +0x1c
		pop ebp
		ret




FUNC_000570:			; Pos = 27498

		push ebp
		mov ebp,esp
		add esp,byte -0x38
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov byte [DATA_008696],0x0
		mov byte [DATA_008697],0x0
		mov byte [DATA_008698],0x0
		mov byte [DATA_008701],0x0
		mov dword [DATA_008703],0xffffffff
		mov byte [DATA_008707],0x0

		mov al,[ebx+0x56]
		test al,al
		jz near JUMP_002393
		mov edx,[ebp+0xc]
		push edx
		and eax,0xff
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov esi,eax
		mov [DATA_008702],esi
		push esi
		lea esi,[ebx+0x3e]
		lea edi,[ebp-0x20]
		mov ecx,0x6
		rep movsd
		pop esi
		push esi
		push ebx
		lea eax,[ebp-0x20]
		push eax
		call FUNC_000575
		add esp,byte +0xc
		mov [ebp-0x1],al

		mov edx,[ebx+0x148]
		test edx,edx
		jz JUMP_002391
		mov eax,[DATA_009155]
		sar eax,1
		jns JUMP_002389
		adc eax,byte +0x0
	JUMP_002389:			; Pos = 2752d
		cmp eax,edx
		jg JUMP_002390
		sub [ebx+0x148],eax
		jmp short JUMP_002393
	JUMP_002390:			; Pos = 27539
		xor eax,eax
		mov [ebx+0x148],eax
		jmp short JUMP_002393
	JUMP_002391:			; Pos = 27543
		test byte [ebp-0x1],0x2
		jz JUMP_002392
		cmp byte [ebx+0x57],0x0
		jnz JUMP_002393
		push esi
		push ebx
		call FUNC_000572
		add esp,byte +0x8
		mov dword [ebx+0x148],0x7f
		jmp short JUMP_002393
	JUMP_002392:			; Pos = 27565
		cmp byte [ebx+0x57],0x0
		jz JUMP_002393
		push esi
		push ebx
		call FUNC_000573
		add esp,byte +0x8
		mov dword [ebx+0x148],0x7f

	JUMP_002393:			; Pos = 2757f
		mov eax,[ebp+0x14]
		mov dl,[ebx+0x56]
		mov [eax],dl
		mov al,[DATA_008696]
		mov [ebp-0x1],al

		mov edi,0x72
		mov eax,[ebp+0xc]
		add eax,byte +0x72
		mov [ebp-0x8],eax
	JUMP_002394:			; Pos = 2759d
		mov eax,[ebp-0x8]
		test byte [eax],0x4
		jz near JUMP_002398
		xor eax,eax
		mov al,[ebx+0x86]
		cmp edi,eax
		jz near JUMP_002398
		mov eax,[ebp+0xc]
		push eax
		push edi
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov esi,eax
		cmp byte [esi+0x8b],0x0
		jnz near JUMP_002398
		mov eax,[ebp+0x14]
		movsx eax,byte [eax]
		xor edx,edx
		mov dl,[esi+0x56]
		cmp eax,edx
		jnz JUMP_002398
		cmp dword [esi+0x82],0x99
		jnz JUMP_002395
		cmp dword [ebx+0x82],0x99
		jnz JUMP_002398
	JUMP_002395:			; Pos = 275fd
		mov al,[ebx+0x57]
		cmp al,[esi+0x57]
		jz JUMP_002396
		push ebx
		lea eax,[ebp-0x20]
		push eax
		call near [DATA_007802]    ; FUNC_001677
		add esp,byte +0x8
		push esi
		lea eax,[ebp-0x38]
		push eax
		call near [DATA_007802]    ; FUNC_001677
		add esp,byte +0x8
		lea eax,[ebp-0x38]
		push eax
		lea eax,[ebp-0x20]
		push eax
		call FUNC_001662
		add esp,byte +0x8
		jmp short JUMP_002397
	JUMP_002396:			; Pos = 27633
		push esi
		push edi
		lea esi,[ebx+0x3e]
		lea edi,[ebp-0x20]
		mov ecx,0x6
		rep movsd
		pop edi
		pop esi
		lea eax,[esi+0x3e]
		push eax
		lea eax,[ebp-0x20]
		push eax
		call FUNC_001662
		add esp,byte +0x8
	JUMP_002397:			; Pos = 27654
		push esi
		push ebx
		lea eax,[ebp-0x20]
		push eax
		call FUNC_000575
		add esp,byte +0xc
	JUMP_002398:			; Pos = 27662
		dec edi
		dec dword [ebp-0x8]
		test edi,edi
		jg near JUMP_002394

		mov al,[ebp-0x1]
		or [DATA_008696],al
		cmp dword [DATA_008704],byte +0x0
		jnz JUMP_002399
		cmp dword [DATA_008703],byte +0x0
		jnl JUMP_002400
	JUMP_002399:			; Pos = 27689
		mov eax,[ebp+0x1c]
		mov dword [eax],0xffffffff
		jmp short JUMP_002401
	JUMP_002400:			; Pos = 27694
		mov eax,[ebp+0x1c]
		mov edx,[DATA_008703]
		mov [eax],edx
	JUMP_002401:			; Pos = 2769f
		mov eax,[ebp+0x18]
		mov edx,[DATA_008702]
		mov [eax],edx
		mov al,[DATA_008701]
		and al,0x1f
		mov edx,[ebp+0x20]
		mov [edx],al
		mov eax,[ebp+0x14]
		mov dl,[DATA_008698]
		mov [eax],dl
		mov eax,[ebp+0x10]
		mov dl,[DATA_008696]
		mov [eax],dl
		mov al,[DATA_008696]
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000572:			; Pos = 27724

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push byte +0x1c
		lea eax,[ebx+0x3e]
		push eax
		call FUNC_001658
		add esp,byte +0x8
		mov edi,eax
		mov eax,[ebx+0x3e]
		mov [ebp-0xc],eax
		mov eax,[ebx+0x46]
		mov [ebp-0x8],eax
		mov eax,[ebx+0x4e]
		mov [ebp-0x4],eax
		push esi
		lea eax,[ebp-0xc]
		push eax
		lea eax,[ebp-0xc]
		push eax
		call FUNC_001670
		add esp,byte +0xc
		push edi
		lea eax,[ebp-0xc]
		push eax
		lea eax,[ebx+0x3e]
		push eax
		call near [DATA_007749]    ; FUNC_001517
		add esp,byte +0xc
		push esi
		push ebx
		push ebx
		call FUNC_001673
		add esp,byte +0xc
		mov al,[DATA_008811]
		dec eax
		mov [ebx+0x58],al
		mov byte [ebx+0x57],0x1
		push esi
		lea eax,[ebx+0x8c]
		push eax
		push eax
		call FUNC_001670
		add esp,byte +0xc
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000573:			; Pos = 277a8

		push ebp
		mov ebp,esp
		add esp,byte -0x24
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push byte +0x1c
		lea eax,[ebx+0x3e]
		push eax
		call FUNC_001658
		add esp,byte +0x8
		mov edi,eax
		mov eax,[ebx+0x3e]
		mov [ebp-0x24],eax
		mov eax,[ebx+0x46]
		mov [ebp-0x20],eax
		mov eax,[ebx+0x4e]
		mov [ebp-0x1c],eax
		push esi
		lea eax,[ebp-0x24]
		push eax
		lea eax,[ebp-0x24]
		push eax
		call FUNC_001669
		add esp,byte +0xc
		push edi
		lea eax,[ebp-0x24]
		push eax
		lea eax,[ebx+0x3e]
		push eax
		call near [DATA_007749]    ; FUNC_001517
		add esp,byte +0xc
		push esi
		push ebx
		push ebx
		call FUNC_001672
		add esp,byte +0xc
		mov byte [ebx+0x57],0x0
		push esi
		lea eax,[ebx+0x8c]
		push eax
		push eax
		call FUNC_001669
		add esp,byte +0xc
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


FUNC_001335:			; Pos = 4eb80

		push ebp
		mov ebp,esp
		mov edx,[ebp+0x8]
		mov eax,[ebp+0xc]
		sub eax,[ebp+0x14]
		mov [edx],eax
		mov eax,[ebp+0x10]
		sbb eax,[ebp+0x18]
		mov [edx+0x4],eax
		pop ebp
		ret



; void F1336 (int64 *rval, int64 op1, int op2)


FUNC_001517:			; Pos = 53648

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ebx,[ebp+0x10]
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		xor ecx,ecx
		mov [eax],ecx
		xor ecx,ecx
		mov [eax+0x8],ecx
		xor ecx,ecx
		mov [eax+0x10],ecx
		cmp ebx,byte +0x20
		jl JUMP_005689
		sub ebx,byte +0x20
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
		jmp short JUMP_005690
	JUMP_005689:			; Pos = 5368b
		mov ecx,[edx]
		mov [eax+0x4],ecx
		mov ecx,[edx+0x4]
		mov [eax+0xc],ecx
		mov edx,[edx+0x8]
		mov [eax+0x14],edx
		mov edx,0x20
		sub edx,ebx
		push edx
		push eax
		call FUNC_001660
		add esp,byte +0x8
	JUMP_005690:			; Pos = 536ad
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001521:			; Pos = 537b0

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		imul dword [ebp+0xc]
		shl eax,1
		rcl edx,1
		mov eax,edx
		pop ebp
		ret




FUNC_001531:			; Pos = 53a34

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,eax
		lea eax,[edx+eax*4]
		lea eax,[edx+eax*4]
		lea eax,[edx+eax*8]
		add eax,eax
		add eax,[DATA_007758]
		add eax,byte +0x74
		pop ebp
		ret




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




FUNC_001657:			; Pos = 59d38

		push ebp
		mov ebp,esp
		push esi
		mov eax,[ebp+0x8]
		mov edx,[eax+0x4]
		test edx,edx
		jz JUMP_006335
		inc edx
		jnz JUMP_006337
	JUMP_006335:			; Pos = 59d49
		mov ecx,[eax+0xc]
		test ecx,ecx
		jz JUMP_006336
		inc ecx
		jnz JUMP_006337
	JUMP_006336:			; Pos = 59d53
		mov esi,[eax+0x14]
		test esi,esi
		jz JUMP_006344
		inc esi
		jz JUMP_006344
	JUMP_006337:			; Pos = 59d5d
		cmp dword [eax+0x4],byte +0x0
		jnl JUMP_006338
		mov edx,[eax+0x4]
		neg edx
		jmp short JUMP_006339
	JUMP_006338:			; Pos = 59d6a
		mov edx,[eax+0x4]
	JUMP_006339:			; Pos = 59d6d
		cmp dword [eax+0xc],byte +0x0
		jnl JUMP_006340
		mov ecx,[eax+0xc]
		neg ecx
		jmp short JUMP_006341
	JUMP_006340:			; Pos = 59d7a
		mov ecx,[eax+0xc]
	JUMP_006341:			; Pos = 59d7d
		or edx,ecx
		cmp dword [eax+0x14],byte +0x0
		jnl JUMP_006342
		mov ecx,[eax+0x14]
		neg ecx
		jmp short JUMP_006343
	JUMP_006342:			; Pos = 59d8c
		mov ecx,[eax+0x14]
	JUMP_006343:			; Pos = 59d8f
		or edx,ecx
		mov eax,0x20
		jmp short JUMP_006351
	JUMP_006344:			; Pos = 59d98
		cmp dword [eax+0x4],byte +0x0
		jnl JUMP_006345
		mov edx,[eax]
		neg edx
		jmp short JUMP_006346
	JUMP_006345:			; Pos = 59da4
		mov edx,[eax]
	JUMP_006346:			; Pos = 59da6
		cmp dword [eax+0xc],byte +0x0
		jnl JUMP_006347
		mov ecx,[eax+0x8]
		neg ecx
		jmp short JUMP_006348
	JUMP_006347:			; Pos = 59db3
		mov ecx,[eax+0x8]
	JUMP_006348:			; Pos = 59db6
		or edx,ecx
		cmp dword [eax+0x14],byte +0x0
		jnl JUMP_006349
		mov ecx,[eax+0x10]
		neg ecx
		jmp short JUMP_006350
	JUMP_006349:			; Pos = 59dc5
		mov ecx,[eax+0x10]
	JUMP_006350:			; Pos = 59dc8
		or edx,ecx
		xor eax,eax
	JUMP_006351:			; Pos = 59dcc
		cmp edx,0xffff
		jna JUMP_006352
		shr edx,0x10
		add eax,byte +0x10
	JUMP_006352:			; Pos = 59dda
		cmp edx,0xff
		jna JUMP_006353
		shr edx,0x8
		add eax,byte +0x8
	JUMP_006353:			; Pos = 59de8
		cmp edx,byte +0xf
		jna JUMP_006354
		shr edx,0x4
		add eax,byte +0x4
	JUMP_006354:			; Pos = 59df3
		cmp edx,byte +0x3
		jna JUMP_006355
		shr edx,0x2
		add eax,byte +0x2
	JUMP_006355:			; Pos = 59dfe
		cmp edx,byte +0x1
		jna JUMP_006356
		inc eax
	JUMP_006356:			; Pos = 59e04
		pop esi
		pop ebp
		ret




FUNC_001658:			; Pos = 59e08

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0x8]
		push esi
		call FUNC_001657
		pop ecx
		mov ebx,eax
		sub ebx,[ebp+0xc]
		test ebx,ebx
		jg JUMP_006357
		xor eax,eax
		jmp short JUMP_006358
	JUMP_006357:			; Pos = 59e24
		push ebx
		push esi
		call FUNC_001660
		add esp,byte +0x8
		mov eax,ebx
	JUMP_006358:			; Pos = 59e30
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001660:			; Pos = 59f90

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		test edx,edx
		jz near JUMP_006362
		cmp edx,byte +0x20
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
		sar dword [eax+0x4],cl
		mov ecx,ebx
		mov esi,[eax+0xc]
		shl esi,cl
		mov ecx,edx
		mov edi,[eax+0x8]
		shr edi,cl
		or esi,edi
		mov [eax+0x8],esi
		mov ecx,edx
		sar dword [eax+0xc],cl
		mov ecx,ebx
		mov ebx,[eax+0x14]
		shl ebx,cl
		mov ecx,edx
		mov esi,[eax+0x10]
		shr esi,cl
		or ebx,esi
		mov [eax+0x10],ebx
		mov ecx,edx
		sar dword [eax+0x14],cl
		jmp short JUMP_006362
	JUMP_006359:			; Pos = 59ff8
		cmp edx,byte +0x20
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
		jmp short JUMP_006361
	JUMP_006360:			; Pos = 5a01f
		mov edx,[eax+0x4]
		mov [eax],edx
		mov edx,[eax+0xc]
		mov [eax+0x8],edx
		mov edx,[eax+0x14]
		mov [eax+0x10],edx
	JUMP_006361:			; Pos = 5a030
		sar dword [eax+0x4],0x1f
		sar dword [eax+0xc],0x1f
		sar dword [eax+0x14],0x1f
	JUMP_006362:			; Pos = 5a03c
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001661:			; Pos = 5a044

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push dword [esi+0x4]
		push dword [esi]
		push dword [ebx+0x4]
		push dword [ebx]
		push ebx
		call FUNC_001333
		add esp,byte +0x14
		push dword [esi+0xc]
		push dword [esi+0x8]
		push dword [ebx+0xc]
		push dword [ebx+0x8]
		lea eax,[ebx+0x8]
		push eax
		call FUNC_001333
		add esp,byte +0x14
		push dword [esi+0x14]
		push dword [esi+0x10]
		push dword [ebx+0x14]
		push dword [ebx+0x10]
		add ebx,byte +0x10
		push ebx
		call FUNC_001333
		add esp,byte +0x14
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001662:			; Pos = 5a098

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push dword [esi+0x4]
		push dword [esi]
		push dword [ebx+0x4]
		push dword [ebx]
		push ebx
		call FUNC_001335
		add esp,byte +0x14
		push dword [esi+0xc]
		push dword [esi+0x8]
		push dword [ebx+0xc]
		push dword [ebx+0x8]
		lea eax,[ebx+0x8]
		push eax
		call FUNC_001335
		add esp,byte +0x14
		push dword [esi+0x14]
		push dword [esi+0x10]
		push dword [ebx+0x14]
		push dword [ebx+0x10]
		add ebx,byte +0x10
		push ebx
		call FUNC_001335
		add esp,byte +0x14
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001663:			; Pos = 5a0ec

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push dword [esi+0x4]
		push dword [esi]
		push dword [DATA_007801]
		push dword [DATA_007800]
		push ebx
		call FUNC_001335
		add esp,byte +0x14
		push dword [esi+0xc]
		push dword [esi+0x8]
		push dword [DATA_007801]
		push dword [DATA_007800]
		lea eax,[ebx+0x8]
		push eax
		call FUNC_001335
		add esp,byte +0x14
		push dword [esi+0x14]
		push dword [esi+0x10]
		push dword [DATA_007801]
		push dword [DATA_007800]
		add ebx,byte +0x10
		push ebx
		call FUNC_001335
		add esp,byte +0x14
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001669:			; Pos = 5a7a8

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov ebx,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[esi]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x4],edx

		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x8],edx

		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax

		mov [edi+0x8],edx
		mov eax,[ebp-0x4]
		mov [edi],eax
		mov eax,[ebp-0x8]
		mov [edi+0x4],eax
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001670:			; Pos = 5a968

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov ebx,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[esi]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x4],edx

		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x8],edx

		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax

		mov [edi+0x8],edx
		mov eax,[ebp-0x4]
		mov [edi],eax
		mov eax,[ebp-0x8]
		mov [edi+0x4],eax
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001672:			; Pos = 5ab0c

		push ebp
		mov ebp,esp
		add esp,byte -0x24
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov ebx,[ebp+0xc]
		mov eax,[esi]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x24],edi

		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x20],edi

		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x1c],edi

		mov eax,[esi]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x18],edi

		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x14],edi

		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x10],edi

		mov eax,[esi]
		push eax
		mov eax,[ebx+0x18]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx+0x1c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx+0x20]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0xc],edi

		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx+0x18]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x1c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x20]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x8],edi

		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx+0x18]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x1c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x20]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x4],edi

		mov eax,[ebp+0x8]
		lea esi,[ebp-0x24]
		mov edi,eax
		mov ecx,0x9
		rep movsd
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001673:			; Pos = 5ad2c

		push ebp
		mov ebp,esp
		add esp,byte -0x24
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov ebx,[ebp+0xc]
		mov eax,[esi]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x24],edi

		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x20],edi

		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x1c],edi

		mov eax,[esi]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x18],edi

		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x14],edi

		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x10],edi

		mov eax,[esi]
		push eax
		mov eax,[ebx+0x18]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx+0x1c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx+0x20]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0xc],edi

		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx+0x18]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x1c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x20]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x8],edi

		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx+0x18]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x1c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x20]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov [ebp-0x4],edi

		mov eax,[ebp+0x8]
		lea esi,[ebp-0x24]
		mov edi,eax
		mov ecx,0x9
		rep movsd
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001677:			; Pos = 5b128

		push ebp
		mov ebp,esp
		add esp,byte -0x28
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0xc]
		mov esi,[ebp+0x8]
		cmp byte [ebx+0x56],0x0
		jz near JUMP_006368
		mov al,[ebx+0x25]
		cmp al,[DATA_008811]
		jnz JUMP_006366
		push esi
		mov edi,esi
		lea esi,[ebx+0x26]
		mov ecx,0x6
		rep movsd
		pop esi
		jmp JUMP_006370
	JUMP_006366:			; Pos = 5b15f
		xor eax,eax
		mov al,[ebx+0x56]
		push eax
		call near [DATA_007753]    ; FUNC_001531
		pop ecx
		mov edi,eax
		push edi
		push esi
		call FUNC_001677
		add esp,byte +0x8
		cmp byte [ebx+0x57],0x0
		jz JUMP_006367
		push esi
		push edi
		lea esi,[ebx+0x3e]
		lea edi,[ebp-0x1c]
		mov ecx,0x6
		rep movsd
		pop edi
		pop esi
		push byte +0x1c
		lea eax,[ebp-0x1c]
		push eax
		call FUNC_001658
		add esp,byte +0x8
		mov [ebp-0x4],eax
		mov eax,[ebp-0x1c]
		mov [ebp-0x28],eax
		mov eax,[ebp-0x14]
		mov [ebp-0x24],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x20],eax
		push edi
		lea eax,[ebp-0x28]
		push eax
		lea eax,[ebp-0x28]
		push eax
		call FUNC_001669
		add esp,byte +0xc
		mov eax,[ebp-0x4]
		push eax
		lea eax,[ebp-0x28]
		push eax
		lea eax,[ebp-0x1c]
		push eax
		call near [DATA_007749]    ; FUNC_001517
		add esp,byte +0xc
		lea eax,[ebp-0x1c]
		push eax
		push esi
		call FUNC_001661
		add esp,byte +0x8
		jmp short JUMP_006369
	JUMP_006367:			; Pos = 5b1e7
		lea eax,[ebx+0x3e]
		push eax
		push esi
		call FUNC_001661
		add esp,byte +0x8
		jmp short JUMP_006369
	JUMP_006368:			; Pos = 5b1f6
		push esi
		mov edi,esi
		lea esi,[ebx+0x3e]
		mov ecx,0x6
		rep movsd
		pop esi
	JUMP_006369:			; Pos = 5b204
		push esi
		lea edi,[ebx+0x26]
		mov ecx,0x6
		rep movsd
		pop esi
		mov al,[DATA_008811]
		mov [ebx+0x25],al
	JUMP_006370:			; Pos = 5b218
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001678:			; Pos = 5b220

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x10]
		mov eax,[ebp+0xc]
		mov esi,[ebp+0x8]
		mov dl,[eax+0x56]
		cmp dl,[ebx+0x56]
		jnz JUMP_006371
		mov dl,[eax+0x57]
		cmp dl,[ebx+0x57]
		jnz JUMP_006372
		push esi
		mov edi,esi
		lea esi,[eax+0x3e]
		mov ecx,0x6
		rep movsd
		pop esi
		add ebx,byte +0x3e
		push ebx
		push esi
		call FUNC_001662
		add esp,byte +0x8
		jmp short JUMP_006373
	JUMP_006371:			; Pos = 5b25c
		mov dl,[ebx+0x56]
		cmp dl,[eax+0x86]
		jnz JUMP_006372
		add ebx,byte +0x3e
		push ebx
		push esi
		call FUNC_001663
		add esp,byte +0x8
		jmp short JUMP_006373
	JUMP_006372:			; Pos = 5b276
		push eax
		push esi
		call near [DATA_007802]    ; FUNC_001677
		add esp,byte +0x8
		add ebx,byte +0x26
		push ebx
		push esi
		call FUNC_001662
		add esp,byte +0x8
	JUMP_006373:			; Pos = 5b28e
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_999999:
ret
