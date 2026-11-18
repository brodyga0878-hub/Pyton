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




FUNC_000032:			; Pos = 123a8

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x8]
		mov eax,[esi]
		inc dword [esi]
		mov bl,[eax]
		xor eax,eax
		mov al,bl
		shl eax,0x4
		cmp dword [eax+DATA_001702],byte +0x0
		jng near JUMP_000319
		mov edi,[esi]
		mov eax,[eax+DATA_001703]
		sub eax,byte +0x1
		jc JUMP_000310
		jz JUMP_000311
		dec eax
		jz JUMP_000312
		dec eax
		jz JUMP_000313
		jmp short JUMP_000314
	JUMP_000310:			; Pos = 123e5
		xor eax,eax
		mov [ebp-0x4],eax
		jmp short JUMP_000314
	JUMP_000311:			; Pos = 123ec
		mov eax,[ebp+0xc]
		mov eax,[eax+0x1c]
		mov [ebp-0x4],eax
		jmp short JUMP_000314
	JUMP_000312:			; Pos = 123f7
		mov eax,[ebp+0xc]
		mov [ebp-0x4],eax
		jmp short JUMP_000314
	JUMP_000313:			; Pos = 123ff
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x4],eax
	JUMP_000314:			; Pos = 1240f
		xor eax,eax
		mov al,bl
		shl eax,0x4
		mov eax,[eax+DATA_001704]
		sub eax,byte +0x1
		jc JUMP_000315
		jz JUMP_000316
		dec eax
		jz JUMP_000317
		jmp short JUMP_000318
	JUMP_000315:			; Pos = 12428
		xor eax,eax
		mov [ebp-0x8],eax
		jmp short JUMP_000318
	JUMP_000316:			; Pos = 1242f
		push esi
		call FUNC_000020
		pop ecx
		mov [ebp-0x8],eax
		jmp short JUMP_000318
	JUMP_000317:			; Pos = 1243b
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x8],eax
	JUMP_000318:			; Pos = 1244b
		mov eax,[ebp+0x14]
		push eax
		mov eax,[ebp+0xc]
		push eax
		push dword FUNC_000047
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		push eax
		xor eax,eax
		mov al,bl
		shl eax,0x4
		mov eax,[eax+DATA_001702]
		push eax
		call near [ebp+0x10]
		add esp,byte +0x18
		mov [esi],edi
	JUMP_000319:			; Pos = 12476
		xor eax,eax
		mov al,bl
		shl eax,0x4
		cmp dword [eax+DATA_001701],byte +0x0
		jng JUMP_000322
		xor edi,edi
		xor eax,eax
		mov al,bl
		add eax,eax
		lea eax,[eax*8+DATA_001701]
		mov ebx,eax
		jmp short JUMP_000321
	JUMP_000320:			; Pos = 12499
		mov eax,[ebp+0x14]
		push eax
		mov eax,[ebp+0x10]
		push eax
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000032
		add esp,byte +0x10
		inc edi
	JUMP_000321:			; Pos = 124af
		cmp edi,[ebx]
		jl JUMP_000320
		jmp short JUMP_000323
	JUMP_000322:			; Pos = 124b5
		add dword [esi],byte +0x4
	JUMP_000323:			; Pos = 124b8
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_000033:			; Pos = 124c0

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
		push edi
		mov edi,[ebp+0xc]
		mov esi,[ebp+0x8]
		xor ebx,ebx
		jmp short JUMP_000325
	JUMP_000324:			; Pos = 124d1
		mov eax,[eax+ebx*4+0x8]
		mov [ebp-0x4],eax
		push ebx
		push edi
		push esi
		lea eax,[ebp-0x4]
		push eax
		call FUNC_000032
		add esp,byte +0x10
		inc ebx
	JUMP_000325:			; Pos = 124e8
		mov eax,[esi+0x8]
		cmp ebx,[eax+0x4]
		jl JUMP_000324
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ebp
		ret




FUNC_000034:			; Pos = 124f8

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,[ebp+0xc]
		mov [eax*4+DATA_008548],edx
		push eax
		push byte +0x0
		push byte +0x2
		call FUNC_000048
		add esp,byte +0xc
		pop ebp
		ret




FUNC_000035:			; Pos = 12518

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov eax,[eax*4+DATA_008548]
		pop ebp
		ret




FUNC_999999:
ret
