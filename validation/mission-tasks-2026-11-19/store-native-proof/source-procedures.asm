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




FUNC_000037:			; Pos = 1267c

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x8]
		mov eax,[esi]
		inc dword [esi]
		movzx eax,byte [eax]
		cmp eax,byte +0x42
		ja near JUMP_000353
		mov al,[eax+DATA_000003]
		jmp near [eax*4+DATA_000004]


SECTION .data

DATA_000003:			; Pos = 126a2
	db 0x0, 0x0, 0x0, 0x11, 0x10, 0xf, 0xe, 0x0
	db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xd
	db 0x0, 0x0, 0xc, 0xb, 0xa, 0x9, 0x0, 0x0
	db 0x8, 0x7, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	db 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	db 0x5, 0x0, 0x0, 0x0, 0x0, 0x4, 0x3, 0x0
	db 0x0, 0x2, 0x1

DATA_000004:			; Pos = 126e5
	dd JUMP_000353
	dd JUMP_000352
	dd JUMP_000351
	dd JUMP_000350
	dd JUMP_000349
	dd JUMP_000348
	dd JUMP_000347
	dd JUMP_000353
	dd JUMP_000353
	dd JUMP_000340
	dd JUMP_000339
	dd JUMP_000338
	dd JUMP_000353
	dd JUMP_000337
	dd JUMP_000336
	dd JUMP_000335
	dd JUMP_000334
	dd JUMP_000333


SECTION .text
	JUMP_000333:			; Pos = 1272d
		mov eax,[ebp+0x10]
		push eax
		push esi
		call FUNC_000020
		pop ecx
		push eax
		call FUNC_000022
		add esp,byte +0x8
		jmp JUMP_000353
	JUMP_000334:			; Pos = 12746
		push esi
		call FUNC_000020
		pop ecx
		mov ebx,eax
		mov eax,[ebp+0x10]
		push eax
		push ebx
		call FUNC_000034
		add esp,byte +0x8
		jmp JUMP_000353
	JUMP_000335:			; Pos = 12761
		push esi
		call FUNC_000020
		pop ecx
		mov ebx,eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x1c]
		mov eax,[eax+0x14]
		mov edx,[ebp+0x10]
		mov [eax+ebx*4],edx
		push ebx
		mov eax,[ebp+0xc]
		mov eax,[eax+0x1c]
		push eax
		push byte +0x3
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_000353
	JUMP_000336:			; Pos = 12790
		push esi
		call FUNC_000020
		pop ecx
		mov ebx,eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x20]
		mov edx,[ebp+0x10]
		mov [eax+ebx*4],edx
		push ebx
		mov eax,[ebp+0xc]
		push eax
		push byte +0x4
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_000353
	JUMP_000337:			; Pos = 127b9
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		test ebx,ebx
		jl near JUMP_000353
		cmp ebx,byte +0x6
		jnl near JUMP_000353
		mov eax,[ebp+0x10]
		mov [ebx*4+DATA_009093],eax
		push ebx
		push byte +0x0
		push byte +0x15
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_000353
	JUMP_000338:			; Pos = 127f5
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		test ebx,ebx
		jl near JUMP_000353
		cmp ebx,byte +0x6
		jnl near JUMP_000353
		mov eax,[ebp+0x10]
		mov [ebx*4+DATA_009095],eax
		push ebx
		push byte +0x0
		push byte +0xa
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_000353
	JUMP_000339:			; Pos = 12831
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov edi,eax
		mov eax,[edi+0xa0]
		push eax
		mov eax,[ebp+0x10]
		push eax
		push edi
		call FUNC_000441
		add esp,byte +0xc
		jmp JUMP_000353
	JUMP_000340:			; Pos = 12869
		mov eax,[DATA_009133]
		push eax
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov edi,eax
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		cmp ebx,0x3e8
		jnl JUMP_000344
		sub ebx,byte +0x64
		push ebx
		push edi
		call FUNC_000392
		add esp,byte +0x8
		mov esi,[ebp+0x10]
		sub esi,eax
		test esi,esi
		jng JUMP_000342
		test esi,esi
		jng near JUMP_000353
	JUMP_000341:			; Pos = 128bd
		push ebx
		push edi
		call FUNC_000390
		add esp,byte +0x8
		test eax,eax
		jnz near JUMP_000353
		dec esi
		test esi,esi
		jg JUMP_000341
		jmp JUMP_000353
	JUMP_000342:			; Pos = 128d9
		test esi,esi
		jnl near JUMP_000353
	JUMP_000343:			; Pos = 128e1
		push ebx
		push edi
		call FUNC_000391
		add esp,byte +0x8
		test eax,eax
		jnz near JUMP_000353
		inc esi
		test esi,esi
		jl JUMP_000343
		jmp JUMP_000353
	JUMP_000344:			; Pos = 128fd
		sub ebx,0x3e8
		cmp edi,[DATA_008861]
		jnz near JUMP_000353
		cmp ebx,byte +0x26
		jnl near JUMP_000353
		movzx eax,word [ebx*2+DATA_008896]
		mov esi,[ebp+0x10]
		sub esi,eax
		test esi,esi
		jng JUMP_000345
		mov edx,[DATA_008891]
		mov ecx,edx
		add ecx,esi
		mov eax,[DATA_008889]
		cmp ecx,eax
		jng JUMP_000346
		mov esi,eax
		sub esi,edx
		jmp short JUMP_000346
	JUMP_000345:			; Pos = 12942
		cmp dword [ebp+0x10],byte +0x0
		jnl JUMP_000346
		mov esi,eax
		neg esi
	JUMP_000346:			; Pos = 1294c
		add [DATA_008891],esi
		add [ebx*2+DATA_008896],si
		jmp JUMP_000353
	JUMP_000347:			; Pos = 1295f
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		test ebx,ebx
		jl near JUMP_000353
		cmp ebx,byte +0x6
		jnl near JUMP_000353
		mov eax,[ebp+0x10]
		mov [ebx*4+DATA_008908],eax
		push ebx
		push byte +0x0
		push byte +0x11
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_000353
	JUMP_000348:			; Pos = 1299b
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov edx,[ebp+0x10]
		mov [eax+0xa0],edx
		jmp JUMP_000353
	JUMP_000349:			; Pos = 129c8
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		mov eax,[ebp+0x10]
		push eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		push eax
		call FUNC_000036
		add esp,byte +0x8
		jmp JUMP_000353
	JUMP_000350:			; Pos = 129f9
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov dl,[ebp+0x10]
		mov [eax+0xff],dl
		push ebx
		push byte +0x0
		push byte +0x17
		call FUNC_000048
		add esp,byte +0xc
		jmp short JUMP_000353
	JUMP_000351:			; Pos = 12a30
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov dl,[ebp+0x10]
		mov [eax+0xfe],dl
		jmp short JUMP_000353
	JUMP_000352:			; Pos = 12a5a
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		mov eax,[ebp+0xc]
		push eax
		push esi
		call FUNC_000031
		add esp,byte +0x8
		add eax,0xfffffc18
		mov esi,eax
		push ebx
		call FUNC_000649
		pop ecx
		test eax,eax
		jz JUMP_000353
		test esi,esi
		jl JUMP_000353
		cmp esi,byte +0x26
		jnl JUMP_000353
		mov edx,[ebp+0x10]
		mov [eax+esi*8+0x4],edx
		add esi,0x3e8
		push esi
		push ebx
		push byte +0x18
		call FUNC_000048
		add esp,byte +0xc
	JUMP_000353:			; Pos = 12aaa
		pop edi
		pop esi
		pop ebx
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




FUNC_999999:
ret
