FUNC_000580:			; Pos = 28628

		push ebp
		mov ebp,esp
		add esp,byte -0x30
		push ebx
		push esi
		mov ebx,[ebp+0xc]
		mov eax,[ebp+0x10]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		mov esi,eax
		mov eax,[esi+0xc]
		mov [ebp-0x24],eax
		mov eax,[esi+0x4]
		mov [ebp-0x20],eax
		mov eax,[esi+0x14]
		add eax,[esi+0x18]
		mov [ebp-0x1c],eax
		mov eax,[ebx+0x18]
		mov [ebp-0x18],eax
		movsx eax,byte [ebp+0x14]
		sar eax,1
		lea eax,[eax+eax*2]
		mov edx,[ebx+0x10]
		mov ecx,[edx+eax*2]
		mov [ebp-0x8],ecx
		mov cx,[edx+eax*2+0x4]
		mov [ebp-0x4],cx
		test byte [ebp+0x14],0x1
		jz JUMP_002463
		movsx eax,byte [ebp-0x6]
		neg eax
		mov [ebp-0x14],eax
		jmp short JUMP_002464
	JUMP_002463:			; Pos = 28687
		movsx eax,byte [ebp-0x6]
		mov [ebp-0x14],eax
	JUMP_002464:			; Pos = 2868e
		movsx eax,byte [ebp-0x5]
		mov [ebp-0x10],eax
		movsx eax,byte [ebp-0x4]
		mov [ebp-0xc],eax
		mov eax,[ebx+0x14]
		sub eax,[ebx+0x18]
		test eax,eax
		jnl JUMP_002465
		neg eax
		mov ecx,eax
		sar dword [ebp-0x14],cl
		mov ecx,eax
		sar dword [ebp-0x10],cl
		mov ecx,eax
		sar dword [ebp-0xc],cl
		jmp short JUMP_002466
	JUMP_002465:			; Pos = 286b9
		test eax,eax
		jz JUMP_002466
		mov ecx,eax
		shl dword [ebp-0x14],cl
		mov ecx,eax
		shl dword [ebp-0x10],cl
		mov ecx,eax
		shl dword [ebp-0xc],cl
	JUMP_002466:			; Pos = 286cc
		mov eax,[ebx]
		sub eax,[ebp-0x14]
		mov [ebp-0x14],eax
		mov eax,[ebx+0x4]
		sub eax,[ebp-0x10]
		mov [ebp-0x10],eax
		mov eax,[ebx+0x8]
		sub eax,[ebp-0xc]
		mov [ebp-0xc],eax
		cmp byte [ebp+0x18],0x0
		jnz JUMP_002467
		mov eax,[ebp-0x14]
		mov [ebp-0x30],eax
		mov eax,[ebp-0x10]
		mov [ebp-0x2c],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x28],eax
		jmp JUMP_002477
	JUMP_002467:			; Pos = 28703
		mov al,[ebp+0x18]
		test al,0x20
		jz JUMP_002468
		neg dword [ebp-0x14]
	JUMP_002468:			; Pos = 2870d
		test al,0x10
		jz JUMP_002469
		neg dword [ebp-0x10]
	JUMP_002469:			; Pos = 28714
		test al,0x8
		jz JUMP_002470
		neg dword [ebp-0xc]
	JUMP_002470:			; Pos = 2871b
		mov al,[ebp+0x18]
		and eax,byte +0x7
		cmp eax,byte +0x5
		ja near JUMP_002477
		jmp near [eax*4+DATA_000028]



DATA_000028:			; Pos = 28731
.long JUMP_002471
.long JUMP_002472
.long JUMP_002473
.long JUMP_002474
.long JUMP_002475
.long JUMP_002476



	JUMP_002471:			; Pos = 28749
		mov eax,[ebp-0x14]
		mov [ebp-0x30],eax
		mov eax,[ebp-0x10]
		mov [ebp-0x2c],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x28],eax
		jmp short JUMP_002477
	JUMP_002472:			; Pos = 2875d
		mov eax,[ebp-0x14]
		mov [ebp-0x2c],eax
		mov eax,[ebp-0x10]
		mov [ebp-0x28],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x30],eax
		jmp short JUMP_002477
	JUMP_002473:			; Pos = 28771
		mov eax,[ebp-0x14]
		mov [ebp-0x28],eax
		mov eax,[ebp-0x10]
		mov [ebp-0x30],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x2c],eax
		jmp short JUMP_002477
	JUMP_002474:			; Pos = 28785
		mov eax,[ebp-0x14]
		mov [ebp-0x28],eax
		mov eax,[ebp-0x10]
		mov [ebp-0x2c],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x30],eax
		jmp short JUMP_002477
	JUMP_002475:			; Pos = 28799
		mov eax,[ebp-0x14]
		mov [ebp-0x2c],eax
		mov eax,[ebp-0x10]
		mov [ebp-0x30],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x28],eax
		jmp short JUMP_002477
	JUMP_002476:			; Pos = 287ad
		mov eax,[ebp-0x14]
		mov [ebp-0x30],eax
		mov eax,[ebp-0x10]
		mov [ebp-0x28],eax
		mov eax,[ebp-0xc]
		mov [ebp-0x2c],eax
	JUMP_002477:			; Pos = 287bf
		mov eax,[ebp+0x1c]
		push eax
		mov eax,[ebp+0x20]
		push eax
		mov eax,[esi+0x34]
		push eax
		lea eax,[ebp-0x30]
		push eax
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000582
		add esp,byte +0x14
		movsx eax,al
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret



