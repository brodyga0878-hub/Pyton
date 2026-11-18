FUNC_001103:			; Pos = 45578

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,[eax]
		push edx
		mov al,[eax+0x8]
		push eax
		call FUNC_001102
		add esp,byte +0x8
		pop ebp
		ret




FUNC_001102:			; Pos = 454fc

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ebx,[ebp+0x8]
		cmp dword [ebp+0xc],byte +0x0
		jnz JUMP_004558
		cmp bl,[DATA_008887]
		jnz JUMP_004555
		mov byte [DATA_008887],0x0
	JUMP_004555:			; Pos = 45519
		cmp bl,[DATA_008877]
		jnz JUMP_004557
		mov byte [DATA_008877],0x0
		cmp byte [DATA_008872],0x5
		jnz JUMP_004556
		mov byte [DATA_008872],0x0
	JUMP_004556:			; Pos = 45538
		push byte +0x0
		push byte +0x14
		call FUNC_000262_ConsoleSetButtonImage
		add esp,byte +0x8
		call FUNC_000991
		jmp short JUMP_004559
	JUMP_004557:			; Pos = 4554b
		movsx esi,bl
		push esi
		call FUNC_001101
		pop ecx
		push esi
		call FUNC_001104
		pop ecx
		jmp short JUMP_004559
	JUMP_004558:			; Pos = 4555e
		movsx eax,bl
		cmp eax,[DATA_008857]
		jnz JUMP_004559
		mov dword [DATA_008886],0x1e
	JUMP_004559:			; Pos = 45573
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001101:			; Pos = 45474

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ebx,[ebp+0x8]
		mov esi,DATA_008804
		movsx eax,byte [esi+0xec]
		cmp ebx,eax
		jz JUMP_004551
		movsx eax,byte [esi+0xed]
		cmp ebx,eax
		jnz JUMP_004552
	JUMP_004551:			; Pos = 45497
		push byte -0x1
		push dword 0x98c2
		call FUNC_001097
		add esp,byte +0x8
	JUMP_004552:			; Pos = 454a6
		movsx eax,byte [esi+0xec]
		cmp ebx,eax
		jnz JUMP_004553
		mov byte [esi+0xec],0x0
		cmp ebx,[esi+0xc0]
		jz JUMP_004553
		cmp byte [esi+0xe8],0x2
		jnz JUMP_004553
		mov byte [esi+0xe8],0x0
		call FUNC_001116
		push byte +0xe
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
	JUMP_004553:			; Pos = 454e3
		movsx eax,byte [esi+0xed]
		cmp ebx,eax
		jnz JUMP_004554
		mov byte [esi+0xed],0x0
	JUMP_004554:			; Pos = 454f5
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000061:			; Pos = 145b8

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp dword [eax],byte +0x0
		jnz JUMP_000510
		movsx edx,byte [eax+0x8]
		mov [DATA_008560],edx
		push edx
		push byte +0x0
		push byte +0x16
		call FUNC_000048
		add esp,byte +0xc
		xor eax,eax
		mov [DATA_008560],eax
	JUMP_000510:			; Pos = 145e1
		pop ebp
		ret




FUNC_999999:
ret
