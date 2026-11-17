FUNC_000582:			; Pos = 28dec

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov bl,[esi]
		inc esi
		test bl,bl
		jz near JUMP_002531
	JUMP_002509:			; Pos = 28e03
		xor eax,eax
		mov al,[esi]
		mov [ebp-0x4],eax
		inc esi
		test bl,0x20
		jz near JUMP_002516
		mov al,[esi]
		inc esi
		and eax,0xff
		mov edx,[ebp+0x14]
		movzx edx,word [edx+eax*2+0x9c]
		mov al,[esi]
		inc esi
		movsx ecx,al
		and ecx,byte +0x1f
		shr edx,cl
		movsx eax,al
		sar eax,0x7
		xor edx,eax
		test dl,0x1
		jz JUMP_002516
		and ebx,0xc0
		sub ebx,byte +0x1
		jc JUMP_002510
		sub ebx,byte +0x3f
		jz JUMP_002513
		sub ebx,byte +0x40
		jz JUMP_002514
		sub ebx,byte +0x40
		jz JUMP_002515
		jmp JUMP_002530
	JUMP_002510:			; Pos = 28e5e
		movzx edi,byte [esi]
		inc esi
		cmp edi,0xff
		jnz JUMP_002511
		add esi,byte +0x6
		push esi
		call FUNC_001822
		pop ecx
		mov esi,eax
		jmp JUMP_002530
	JUMP_002511:			; Pos = 28e7b
		test edi,edi
		jz near JUMP_002530
	JUMP_002512:			; Pos = 28e83
		movzx edi,byte [esi]
		inc esi
		test edi,edi
		jnz JUMP_002512
		jmp JUMP_002530
	JUMP_002513:			; Pos = 28e90
		movzx edi,byte [esi]
		inc esi
		test edi,edi
		jnz JUMP_002513
		jmp JUMP_002530
	JUMP_002514:			; Pos = 28e9d
		add esi,byte +0x4
		jmp JUMP_002530
	JUMP_002515:			; Pos = 28ea5
		movzx edi,byte [esi]
		inc esi
		test edi,edi
		jnz JUMP_002515
		jmp JUMP_002530

	JUMP_002516:			; Pos = 28eb2
		mov eax,ebx
		and eax,0xc0
		sub eax,byte +0x1
		jc JUMP_002517
		sub eax,byte +0x3f
		jz near JUMP_002522
		sub eax,byte +0x40
		jz near JUMP_002525
		sub eax,byte +0x40
		jz near JUMP_002527
		jmp JUMP_002530

	JUMP_002517:			; Pos = 28ede
		movzx edi,byte [esi]
		inc esi
		cmp edi,0xff
		jnz JUMP_002519
		mov eax,[ebp+0xc]
		push eax
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x14]
		push eax
		push esi
		lea eax,[ebp-0x8]
		push eax
		call FUNC_000581
		add esp,byte +0x14
		mov esi,eax
		cmp dword [ebp-0x8],byte +0x0
		jnz JUMP_002518
		mov al,[ebp-0x4]
		or [DATA_008697],al
		mov eax,[ebp+0x8]
		mov [eax],bl
		xor eax,eax
		jmp JUMP_002532
	JUMP_002518:			; Pos = 28f20
		mov al,[ebp-0x4]
		and al,0x7f
		or [DATA_008697],al
		jmp JUMP_002530
	JUMP_002519:			; Pos = 28f30
		test edi,edi
		jz near JUMP_002530
	JUMP_002520:			; Pos = 28f38
		mov eax,[ebp+0xc]
		push eax
		push edi
		mov eax,[ebp+0x18]
		push eax
		call FUNC_000583
		add esp,byte +0xc
		test eax,eax
		jz JUMP_002521
		mov al,[ebp-0x4]
		and al,0x7f
		or [DATA_008697],al
		mov eax,[ebp+0x8]
		mov [eax],bl
		or eax,byte -0x1
		jmp JUMP_002532
	JUMP_002521:			; Pos = 28f65
		inc esi
		movzx edi,byte [esi-0x1]
		test edi,edi
		jnz JUMP_002520
		jmp JUMP_002530

	JUMP_002522:			; Pos = 28f73
		movzx edi,byte [esi]
		inc esi
		test edi,edi
		jnz JUMP_002523
		mov al,[ebp-0x4]
		and al,0x7f
		or [DATA_008697],al
		mov eax,[ebp+0x8]
		mov [eax],bl
		or eax,byte -0x1
		jmp JUMP_002532
	JUMP_002523:			; Pos = 28f93
		mov eax,[ebp+0xc]
		push eax
		push edi
		mov eax,[ebp+0x18]
		push eax
		call FUNC_000583
		add esp,byte +0xc
		test eax,eax
		jnz JUMP_002522
	JUMP_002524:			; Pos = 28fa8
		mov al,[esi]
		inc esi
		test al,al
		jnz JUMP_002524
		jmp JUMP_002530

	JUMP_002525:			; Pos = 28fb4
		movzx edi,byte [esi]
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
		mov ecx,[ebp+0x14]
		push ecx
		mov ecx,[ebp+0x18]
		push ecx
		push edx
		push eax
		push edi
		mov eax,[ebp+0xc]
		push eax
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000580
		add esp,byte +0x1c
		mov edx,[ebp+0x8]
		mov dl,[edx]
		or [DATA_008701],dl
		test eax,eax
		jnl JUMP_002526
		mov al,[ebp-0x4]
		and al,0x7f
		or [DATA_008697],al
		mov eax,[ebp+0x8]
		mov [eax],bl
		or eax,byte -0x1
		jmp short JUMP_002532
	JUMP_002526:			; Pos = 29007
		test eax,eax
		jg JUMP_002530
		mov al,[ebp-0x4]
		or [DATA_008697],al
		test byte [ebp-0x4],0x80
		jz JUMP_002530
		mov eax,[ebp+0x8]
		mov [eax],bl
		xor eax,eax
		jmp short JUMP_002532

	JUMP_002527:			; Pos = 29023
		movzx edi,byte [esi]
		inc esi
		test edi,edi
		jnz JUMP_002528
		mov al,[ebp-0x4]
		or [DATA_008697],al
		test byte [ebp-0x4],0x80
		jz JUMP_002528
		mov eax,[ebp+0x8]
		mov [eax],bl
		xor eax,eax
		jmp short JUMP_002532
	JUMP_002528:			; Pos = 29043
		mov eax,[ebp+0xc]
		push eax
		push edi
		mov eax,[ebp+0x18]
		push eax
		call FUNC_000583
		add esp,byte +0xc
		test eax,eax
		jz JUMP_002527
	JUMP_002529:			; Pos = 29058
		mov bl,[esi]
		inc esi
		test bl,bl
		jnz JUMP_002529

	JUMP_002530:			; Pos = 2905f
		mov bl,[esi]
		inc esi
		test bl,bl
		jnz near JUMP_002509

	JUMP_002531:			; Pos = 2906a
		mov eax,[ebp+0x8]
		mov byte [eax],0x0
		mov al,0x1
	JUMP_002532:			; Pos = 29072
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001822:			; Pos = 6250c

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		movsx edx,word [eax]
		test edx,edx
		jz JUMP_006982
	JUMP_006981:			; Pos = 62519
		add eax,byte +0x10
		movsx edx,word [eax]
		test edx,edx
		jnz JUMP_006981
	JUMP_006982:			; Pos = 62523
		add eax,byte +0x2
		pop ebp
		ret




FUNC_999999:
ret
