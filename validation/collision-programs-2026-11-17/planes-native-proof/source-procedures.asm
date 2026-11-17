FUNC_000583:			; Pos = 2907c

		push ebp
		mov ebp,esp
		add esp,byte -0x28
		push ebx
		push esi
		push edi
		mov edx,[ebp+0x10]
		mov eax,[ebp+0xc]
		mov ecx,eax
		sar ecx,1
		lea ecx,[ecx+ecx*2]
		mov ebx,[edx+0xc]
		mov esi,[ebx+ecx*2-0x6]
		mov [ebp-0x8],esi
		mov si,[ebx+ecx*2-0x2]
		mov [ebp-0x4],si

		mov bl,[ebp-0x8]
		xor ecx,ecx
		mov cl,bl
		sar ecx,1
		lea ecx,[ecx+ecx*2]
		mov esi,[edx+0x10]
		mov edi,[esi+ecx*2]
		mov [ebp-0x10],edi
		mov di,[esi+ecx*2+0x4]
		mov [ebp-0xc],di

		test al,0x1
		jz JUMP_002533
		movsx eax,byte [ebp-0x6]
		neg eax
		shl eax,0x8
		mov [ebp-0x1c],eax
		movsx eax,byte [ebp-0x5]
		shl eax,0x8
		mov [ebp-0x18],eax
		movsx eax,byte [ebp-0x4]
		shl eax,0x8
		mov [ebp-0x14],eax
		xor eax,eax
		mov al,[ebp-0x8]
		test al,0x1
		jnz JUMP_002534
		neg byte [ebp-0xe]
		jmp short JUMP_002534
	JUMP_002533:			; Pos = 290f5
		movsx eax,byte [ebp-0x6]
		shl eax,0x8
		mov [ebp-0x1c],eax
		movsx eax,byte [ebp-0x5]
		shl eax,0x8
		mov [ebp-0x18],eax
		movsx eax,byte [ebp-0x4]
		shl eax,0x8
		mov [ebp-0x14],eax
		test bl,0x1
		jz JUMP_002534
		neg byte [ebp-0xe]
	JUMP_002534:			; Pos = 2911b
		mov eax,[edx+0x14]
		sub eax,[edx+0x18]
		test eax,eax
		jnl JUMP_002535
		neg eax
		mov ecx,eax
		movsx ebx,byte [ebp-0xe]
		sar ebx,cl
		mov [ebp-0x28],ebx
		mov ecx,eax
		movsx ebx,byte [ebp-0xd]
		sar ebx,cl
		mov [ebp-0x24],ebx
		mov ecx,eax
		movsx eax,byte [ebp-0xc]
		sar eax,cl
		mov [ebp-0x20],eax
		jmp short JUMP_002536
	JUMP_002535:			; Pos = 2914a
		mov ecx,eax
		movsx ebx,byte [ebp-0xe]
		shl ebx,cl
		mov [ebp-0x28],ebx
		mov ecx,eax
		movsx ebx,byte [ebp-0xd]
		shl ebx,cl
		mov [ebp-0x24],ebx
		mov ecx,eax
		movsx eax,byte [ebp-0xc]
		shl eax,cl
		mov [ebp-0x20],eax
	JUMP_002536:			; Pos = 2916b
		mov eax,[edx]
		sub [ebp-0x28],eax
		mov eax,[edx+0x4]
		sub [ebp-0x24],eax
		mov eax,[edx+0x8]
		sub [ebp-0x20],eax
		mov eax,[ebp-0x28]
		push eax
		call _abs
		pop ecx
		mov ebx,eax
		mov eax,[ebp-0x24]
		push eax
		call _abs
		pop ecx
		or ebx,eax
		mov eax,[ebp-0x20]
		push eax
		call _abs
		pop ecx
		or ebx,eax
		push ebx
		call FUNC_001656_FindMSB
		pop ecx
		add eax,byte -0xd
		test eax,eax
		jnl JUMP_002537
		xor eax,eax
	JUMP_002537:			; Pos = 291b0
		mov ecx,eax
		mov edx,[ebp-0x28]
		sar edx,cl
		imul edx,[ebp-0x1c]

		mov ecx,eax
		mov ebx,[ebp-0x24]
		sar ebx,cl
		imul ebx,[ebp-0x18]
		add edx,ebx

		mov ecx,eax
		mov ebx,[ebp-0x20]
		sar ebx,cl
		imul ebx,[ebp-0x14]
		add edx,ebx

		neg edx
		add edx,edx
		mov ecx,eax
		mov eax,[ebp+0x8]
		sar eax,cl
		cmp edx,eax
		setnl al
		and eax,byte +0x1
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001656_FindMSB:			; Pos = 59cec

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp eax,0x10000
		jc JUMP_006329
		shr eax,0x10
		mov edx,0x10
		jmp short JUMP_006330
	JUMP_006329:			; Pos = 59d03
		xor edx,edx
	JUMP_006330:			; Pos = 59d05
		cmp eax,0x100
		jc JUMP_006331
		shr eax,0x8
		add edx,byte +0x8
	JUMP_006331:			; Pos = 59d12
		cmp eax,byte +0x10
		jc JUMP_006332
		shr eax,0x4
		add edx,byte +0x4
	JUMP_006332:			; Pos = 59d1d
		cmp eax,byte +0x4
		jc JUMP_006333
		shr eax,0x2
		add edx,byte +0x2
	JUMP_006333:			; Pos = 59d28
		cmp eax,byte +0x2
		jc JUMP_006334
		lea eax,[edx+0x1]
		pop ebp
		ret
	JUMP_006334:			; Pos = 59d32
		mov eax,edx
		pop ebp
		ret




FUNC_999999:
ret
