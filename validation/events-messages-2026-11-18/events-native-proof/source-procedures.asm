FUNC_000042:			; Pos = 13dc4

		push ebp
		mov ebp,esp
		push ebx
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		mov ecx,[eax]
		mov ebx,[edx]
		cmp ecx,ebx
		jz JUMP_000451
		sub ecx,ebx
		mov eax,ecx
		pop ebx
		pop ebp
		ret
	JUMP_000451:			; Pos = 13ddd
		mov ecx,[eax+0x4]
		mov ebx,[edx+0x4]
		cmp ecx,ebx
		jz JUMP_000452
		sub ecx,ebx
		mov eax,ecx
		pop ebx
		pop ebp
		ret
	JUMP_000452:			; Pos = 13dee
		mov ecx,[eax+0x8]
		mov ebx,[edx+0x8]
		cmp ecx,ebx
		jz JUMP_000453
		sub ecx,ebx
		mov eax,ecx
		pop ebx
		pop ebp
		ret
	JUMP_000453:			; Pos = 13dff
		mov ecx,[eax+0x10]
		mov ebx,[edx+0x10]
		cmp ecx,ebx
		jz JUMP_000454
		sub ecx,ebx
		mov eax,ecx
		pop ebx
		pop ebp
		ret
	JUMP_000454:			; Pos = 13e10
		mov ecx,[eax+0x14]
		mov ebx,[edx+0x14]
		cmp ecx,ebx
		jz JUMP_000455
		sub ecx,ebx
		mov eax,ecx
		pop ebx
		pop ebp
		ret
	JUMP_000455:			; Pos = 13e21
		mov eax,[eax+0xc]
		sub eax,[edx+0xc]
		pop ebx
		pop ebp
		ret




FUNC_000043:			; Pos = 13e2c

		push ebp
		mov ebp,esp
		push ebx
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		mov ecx,[eax]
		mov ebx,[edx]
		cmp ecx,ebx
		jz JUMP_000456
		sub ecx,ebx
		mov eax,ecx
		pop ebx
		pop ebp
		ret
	JUMP_000456:			; Pos = 13e45
		mov ecx,[eax+0x4]
		mov ebx,[edx+0x4]
		cmp ecx,ebx
		jz JUMP_000457
		sub ecx,ebx
		mov eax,ecx
		pop ebx
		pop ebp
		ret
	JUMP_000457:			; Pos = 13e56
		mov eax,[eax+0x8]
		sub eax,[edx+0x8]
		pop ebx
		pop ebp
		ret




FUNC_000044:			; Pos = 13e60

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		push byte +0x20
		call _malloc
		pop ecx
		mov esi,eax
		xor eax,eax
		mov [esi],eax
		xor eax,eax
		mov [esi+0x4],eax
		mov eax,[ebp+0x8]
		mov [esi+0x8],eax
		mov eax,[ebp+0xc]
		mov [esi+0xc],eax
		mov eax,[ebp+0x10]
		mov [esi+0x10],eax
		mov eax,[ebp+0x14]
		mov [esi+0x14],eax
		mov eax,[ebp+0x18]
		mov [esi+0x18],eax
		mov eax,[ebp+0x1c]
		mov [esi+0x1c],eax
		mov ebx,DATA_008564
		jmp short JUMP_000460
	JUMP_000458:			; Pos = 13ea4
		add edi,byte +0x8
		push edi
		lea eax,[esi+0x8]
		push eax
		call FUNC_000042
		add esp,byte +0x8
		test eax,eax
		jnl JUMP_000459
		mov ebx,[ebx]
		jmp short JUMP_000460
	JUMP_000459:			; Pos = 13ebc
		mov eax,[ebx]
		add eax,byte +0x4
		mov ebx,eax
	JUMP_000460:			; Pos = 13ec3
		mov edi,[ebx]
		test edi,edi
		jnz JUMP_000458
		mov [ebx],esi
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000045:			; Pos = 13ed0

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		push esi
		mov eax,[ebp+0x8]
		mov [ebp-0x18],eax
		mov eax,[ebp+0xc]
		mov [ebp-0x14],eax
		mov eax,[ebp+0x10]
		mov [ebp-0x10],eax
		mov eax,[ebp+0x14]
		mov [ebp-0xc],eax
		mov eax,[ebp+0x18]
		mov [ebp-0x8],eax
		mov eax,[ebp+0x1c]
		mov [ebp-0x4],eax
		mov ebx,DATA_008564
		jmp short JUMP_000463
	JUMP_000461:			; Pos = 13f03
		add eax,byte +0x8
		push eax
		lea eax,[ebp-0x18]
		push eax
		call FUNC_000042
		add esp,byte +0x8
		test eax,eax
		jnl JUMP_000462
		mov ebx,[ebx]
		jmp short JUMP_000463
	JUMP_000462:			; Pos = 13f1b
		test eax,eax
		jng JUMP_000464
		mov eax,[ebx]
		add eax,byte +0x4
		mov ebx,eax
	JUMP_000463:			; Pos = 13f26
		mov eax,[ebx]
		test eax,eax
		jnz JUMP_000461

	JUMP_000464:			; Pos = 13f2c
		mov eax,[ebx]
		test eax,eax
		jz JUMP_000470
		mov edx,[eax+0x4]
		test edx,edx
		jz JUMP_000468
		cmp dword [eax],byte +0x0
		jnz JUMP_000465
		mov esi,edx
		push eax
		call _free
		pop ecx
		mov [ebx],esi
		jmp short JUMP_000470

	JUMP_000465:			; Pos = 13f4b
		mov eax,[ebx]
		jmp short JUMP_000467
	JUMP_000466:			; Pos = 13f4f
		add edx,byte +0x4
		mov eax,edx
	JUMP_000467:			; Pos = 13f54
		mov edx,[eax]
		cmp dword [edx+0x4],byte +0x0
		jnz JUMP_000466
		mov edx,[eax]
		mov esi,edx
		mov edx,[edx]
		mov [eax],edx
		mov eax,[ebx]
		mov eax,[eax]
		mov [esi],eax
		mov eax,[ebx]
		mov eax,[eax+0x4]
		mov [esi+0x4],eax
		mov eax,[ebx]
		push eax
		call _free
		pop ecx
		mov [ebx],esi
		jmp short JUMP_000470

	JUMP_000468:			; Pos = 13f7f
		mov edx,[ebx]
		mov eax,[edx]
		test eax,eax
		jz JUMP_000469
		mov esi,eax
		push edx
		call _free
		pop ecx
		mov [ebx],esi
		jmp short JUMP_000470
	JUMP_000469:			; Pos = 13f94
		mov eax,[ebx]
		push eax
		call _free
		pop ecx
		xor eax,eax
		mov [ebx],eax
	JUMP_000470:			; Pos = 13fa1
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000046:			; Pos = 13fa8

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		test esi,esi
		jz JUMP_000472
		mov eax,[ebp+0x10]
		push eax
		mov eax,[esi]
		push eax
		push ebx
		call FUNC_000046
		add esp,byte +0xc
		mov eax,[ebp+0x10]
		push eax
		lea eax,[esi+0x8]
		push eax
		call FUNC_000043
		add esp,byte +0x8
		test eax,eax
		jnz JUMP_000471
		push byte +0x10
		call _malloc
		pop ecx
		mov edi,eax
		mov eax,[ebx]
		mov [eax],edi
		xor eax,eax
		mov [edi],eax
		mov eax,[esi+0x14]
		mov [edi+0x4],eax
		mov eax,[esi+0x18]
		mov [edi+0x8],eax
		mov eax,[esi+0x1c]
		mov [edi+0xc],eax
		mov [ebx],edi
	JUMP_000471:			; Pos = 14002
		mov eax,[ebp+0x10]
		push eax
		mov eax,[esi+0x4]
		push eax
		push ebx
		call FUNC_000046
		add esp,byte +0xc
	JUMP_000472:			; Pos = 14013
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000048:			; Pos = 14070

		push ebp
		mov ebp,esp
		add esp,byte -0x20
		push ebx
		push esi
		lea esi,[ebp-0x4]
		mov eax,[ebp+0x8]
		mov [ebp-0x20],eax
		mov eax,[ebp+0xc]
		mov [ebp-0x1c],eax
		mov eax,[ebp+0x10]
		mov [ebp-0x18],eax
		mov ebx,DATA_008564
		jmp short JUMP_000476
	JUMP_000474:			; Pos = 14094
		add eax,byte +0x8
		push eax
		lea eax,[ebp-0x20]
		push eax
		call FUNC_000043
		add esp,byte +0x8
		test eax,eax
		jnl JUMP_000475
		mov ebx,[ebx]
		jmp short JUMP_000476
	JUMP_000475:			; Pos = 140ac
		test eax,eax
		jng JUMP_000477
		mov eax,[ebx]
		add eax,byte +0x4
		mov ebx,eax
	JUMP_000476:			; Pos = 140b7
		mov eax,[ebx]
		test eax,eax
		jnz JUMP_000474

	JUMP_000477:			; Pos = 140bd
		cmp dword [ebx],byte +0x0
		jz JUMP_000482
		xor eax,eax
		mov [esi],eax
		mov [ebp-0x8],esi
		lea eax,[ebp-0x20]
		push eax
		mov eax,[ebx]
		push eax
		lea eax,[ebp-0x8]
		push eax
		call FUNC_000046
		add esp,byte +0xc
		mov ebx,[esi]
		test ebx,ebx
		jz JUMP_000479
	JUMP_000478:			; Pos = 140e2
		mov eax,[ebx+0xc]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call near [ebx+0x4]
		add esp,byte +0x8
		mov ebx,[ebx]
		test ebx,ebx
		jnz JUMP_000478
	JUMP_000479:			; Pos = 140f6
		cmp dword [esi],byte +0x0
		jz JUMP_000481

	JUMP_000480:			; Pos = 140fb
		mov ebx,[esi]
		mov eax,[esi]
		mov eax,[eax]
		mov [esi],eax
		push ebx
		call _free
		pop ecx
		cmp dword [esi],byte +0x0
		jnz JUMP_000480

	JUMP_000481:			; Pos = 1410f
		call FUNC_000054
	JUMP_000482:			; Pos = 14114
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000049:			; Pos = 1411c

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		test ebx,ebx
		jz JUMP_000483
		mov eax,[ebx]
		push eax
		call FUNC_000049
		pop ecx
		mov eax,[ebx+0x4]
		push eax
		call FUNC_000049
		pop ecx
		push ebx
		call _free
		pop ecx
	JUMP_000483:			; Pos = 14141
		pop ebx
		pop ebp
		ret




FUNC_000050:			; Pos = 14144

		push ebp
		mov ebp,esp
		mov eax,[DATA_008564]
		push eax
		call FUNC_000049
		pop ecx
		xor eax,eax
		mov [DATA_008564],eax
		pop ebp
		ret




FUNC_000051:			; Pos = 1415c

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov eax,[ebp+0x8]
		xor esi,esi
		lea edi,[eax*4+DATA_001697]
		mov ebx,DATA_008561
	JUMP_000484:			; Pos = 14173
		cmp dword [ebx],byte +0x0
		jnz JUMP_000485
		mov dword [ebx],0x4
		mov [ebx+0x4],si
		inc word [ebx+0x6]
		xor edx,edx
		mov [ebx+0x8],edx
		mov dword [ebx+0xc],0xffffffff
		xor edx,edx
		mov [ebx+0x10],edx
		mov dword [ebx+0x14],0xffffffff
		mov [ebx+0x18],eax
		mov eax,[edi]
		mov [ebx+0x1c],eax
		mov eax,[edi]
		mov eax,[eax+0x10]
		shl eax,0x2
		push eax
		call _malloc
		pop ecx
		mov [ebx+0x20],eax
		mov eax,[ebx+0x20]
		mov edx,[ebx+0x4]
		mov [eax],edx
		mov eax,[ebx+0x20]
		mov edx,[ebp+0xc]
		mov [eax+0x4],edx
		mov eax,esi
		shl eax,0x2
		lea eax,[eax+eax*8]
		add eax,DATA_008561
		jmp short JUMP_000486
	JUMP_000485:			; Pos = 141d9
		inc esi
		add ebx,byte +0x24
		cmp esi,0x96
		jl JUMP_000484
		xor eax,eax
	JUMP_000486:			; Pos = 141e7
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000054:			; Pos = 1430c

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
	JUMP_000494:			; Pos = 14312
		xor ecx,ecx
		xor edx,edx
		mov eax,DATA_008561

	JUMP_000495:			; Pos = 1431b
		mov ebx,[eax]
		cmp ecx,ebx
		jnl JUMP_000496
		mov ecx,ebx
		mov esi,edx
	JUMP_000496:			; Pos = 14325
		inc edx
		add eax,byte +0x24
		cmp edx,0x96
		jl JUMP_000495

		cmp ecx,byte +0x3
		jng near JUMP_000500
		sub ecx,byte +0x4
		jz JUMP_000497
		dec ecx
		jz JUMP_000498
		dec ecx
		jz JUMP_000499
		jmp short JUMP_000494
	JUMP_000497:			; Pos = 14347
		mov eax,esi
		shl eax,0x2
		lea eax,[eax+eax*8]
		add eax,DATA_008561
		push eax
		call FUNC_000053
		pop ecx
		jmp short JUMP_000494
	JUMP_000498:			; Pos = 1435e
		lea eax,[esi+esi*8]
		mov dword [eax*4+DATA_008561],0x6
		mov eax,[eax*4+DATA_008562]
		mov edx,[eax*4+DATA_001697]
		mov ecx,[edx+0xc]
		mov eax,[edx+ecx*4+0x1c]
		mov eax,[eax]
		mov [ebp-0x4],eax
		mov eax,esi
		shl eax,0x2
		lea eax,[eax+eax*8]
		add eax,DATA_008561
		push eax
		lea eax,[ebp-0x4]
		push eax
		call FUNC_000041
		add esp,byte +0x8
		jmp JUMP_000494
	JUMP_000499:			; Pos = 143a6
		lea ebx,[esi+esi*8]
		mov eax,[ebx*4+DATA_008563]
		push eax
		call _free
		pop ecx
		xor eax,eax
		mov [ebx*4+DATA_008561],eax
		jmp JUMP_000494
	JUMP_000500:			; Pos = 143c5
		pop esi
		pop ebx
		pop ecx
		pop ebp
		ret




FUNC_000055:			; Pos = 143cc

		push ebp
		mov ebp,esp
		xor eax,eax
		mov [DATA_008557],eax
		mov [DATA_008556],eax
		mov [DATA_008555],eax
		mov [DATA_008554],eax
		mov [DATA_008553],eax
		mov [DATA_008552],eax
		mov [DATA_008551],eax
		mov [DATA_008550],eax
		push byte +0x0
		push byte +0x0
		push byte +0x0
		push byte +0x0
		call FUNC_000052
		add esp,byte +0x10
		call FUNC_000054
		pop ebp
		ret




FUNC_000056:			; Pos = 14410

		push ebp
		mov ebp,esp
		push ebx
		push esi
		xor esi,esi
		mov ebx,DATA_008561
	JUMP_000501:			; Pos = 1441c
		cmp dword [ebx],byte +0x0
		jng JUMP_000502
		mov eax,[ebx+0x20]
		push eax
		call _free
		pop ecx
		xor eax,eax
		mov [ebx],eax
	JUMP_000502:			; Pos = 1442f
		inc esi
		add ebx,byte +0x24
		cmp esi,0x96
		jl JUMP_000501
		call FUNC_000050
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_999999:
ret
