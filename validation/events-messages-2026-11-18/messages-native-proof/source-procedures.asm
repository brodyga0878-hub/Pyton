FUNC_000349:			; Pos = 21dec

		push ebp
		mov ebp,esp
		cmp byte [DATA_008870],0x4
		jz JUMP_001985
		call near [DATA_004920]    ; FUNC_000217_SysMenuPlayTime
	JUMP_001985:			; Pos = 21dfe
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000351
		pop ecx
		pop ebp
		ret




FUNC_000350:			; Pos = 21e0c

		push ebp
		mov ebp,esp
		add esp,0xfffff7ec
		push ebx
		push esi
		mov eax,[ebp+0x8]
		lea esi,[ebp+0xfffff7ec]
		mov edx,[eax+0x8]
		mov [esi+0x4],edx
		mov edx,[eax+0xc]
		mov [esi+0x8],edx
		mov edx,[eax+0x18]
		test edx,edx
		jl JUMP_001989
		test dl,0x1
		jnz JUMP_001988
		mov edx,[eax]
		mov [esi],edx
		mov edx,[eax+0x2c]
		mov [esi+0xc],edx
		mov edx,[eax+0x1c]
		test edx,edx
		jnz JUMP_001986
		mov eax,DATA_009148
		mov [esi+0x10],eax
		jmp short JUMP_001987
	JUMP_001986:			; Pos = 21e53
		add edx,0x124
		mov [esi+0x10],edx
	JUMP_001987:			; Pos = 21e5c
		mov eax,0x9917
		mov bl,0x5f
		jmp short JUMP_001990
	JUMP_001988:			; Pos = 21e65
		mov edx,[eax+0x4]
		mov [esi],edx
		mov edx,[eax+0x24]
		mov [esi+0xc],edx
		mov edx,[eax+0x2c]
		mov [esi+0x10],edx
		mov eax,[eax]
		mov bl,0x5f
		jmp short JUMP_001990
	JUMP_001989:			; Pos = 21e7c
		mov edx,[eax+0x4]
		mov [esi],edx
		mov edx,[eax+0x8]
		mov [esi+0x4],edx
		mov edx,[eax+0xc]
		mov [esi+0x8],edx
		mov edx,[eax+0x24]
		mov [esi+0xc],edx
		mov edx,[eax+0x2c]
		mov [esi+0x10],edx
		mov eax,[eax]
		mov bl,0x11
	JUMP_001990:			; Pos = 21e9d
		push esi
		push eax
		lea eax,[ebp+0xfffff800]
		push eax
		call near [DATA_007639]    ; FUNC_001344_StringExpandFFCode
		add esp,byte +0xc
		xor eax,eax
		cmp dword [ebp+0xc],byte +0x0
		jnz JUMP_001991
		inc eax
	JUMP_001991:			; Pos = 21eb8
		push eax
		push ebx
		lea eax,[ebp+0xfffff800]
		push eax
		call FUNC_000271
		add esp,byte +0xc
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000351:			; Pos = 21ed0

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		cmp byte [DATA_008870],0x2c
		jz JUMP_001993
		cmp dword [ebx+0x18],byte +0x0
		jl JUMP_001992
		push byte +0x16
		call FUNC_001906_SoundPlaySample
		pop ecx
	JUMP_001992:			; Pos = 21eee
		push byte +0x1
		push ebx
		call FUNC_000350
		add esp,byte +0x8
	JUMP_001993:			; Pos = 21ef9
		pop ebx
		pop ebp
		ret




FUNC_000352:			; Pos = 21efc

		push ebp
		mov ebp,esp
		add esp,byte -0x30
		push esi
		push edi
		mov eax,[ebp+0x8]
		mov esi,eax
		lea edi,[ebp-0x30]
		mov ecx,0xc
		rep movsd
		mov dword [ebp-0x18],0xffffffff
		push byte +0x0
		lea eax,[ebp-0x30]
		push eax
		call FUNC_000350
		add esp,byte +0x8
		pop edi
		pop esi
		mov esp,ebp
		pop ebp
		ret




FUNC_000271:			; Pos = 1d6c0

		push ebp
		mov ebp,esp
		add esp,0xfffffc00
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x8]
		test esi,esi
		jz near JUMP_001597
		xor ebx,ebx
		push esi
		mov edi,esi
		lea esi,[ebp+0xfffffc00]
		xor eax,eax
		or ecx,byte -0x1
		repne scasb
		not ecx
		sub edi,ecx
		xchg esi,edi
		mov eax,edi
		mov edx,ecx
		shr ecx,0x2
		rep movsd
		mov ecx,edx
		and ecx,byte +0x3
		rep movsb
		pop esi
		push byte +0x78
		lea eax,[ebp+0xfffffc00]
		push eax
		call near [DATA_007643]    ; FUNC_001398_StringWrap
		add esp,byte +0x8
		lea eax,[ebp+0xfffffc00]
		jmp short JUMP_001591
	JUMP_001589:			; Pos = 1d71a
		cmp dl,0xd
		jnz JUMP_001590
		inc ebx
	JUMP_001590:			; Pos = 1d720
		inc eax
	JUMP_001591:			; Pos = 1d721
		mov dl,[eax]
		test dl,dl
		jnz JUMP_001589
		mov eax,[DATA_005099]
		mov edx,eax
		shl eax,0x6
		add eax,edx
		shl eax,0x3
		sub eax,edx
		add eax,eax
		add eax,DATA_008681
		push esi
		mov edi,esi
		mov esi,eax
		xor eax,eax
		or ecx,byte -0x1
		repne scasb
		not ecx
		sub edi,ecx
		xchg esi,edi
		mov eax,edi
		mov edx,ecx
		shr ecx,0x2
		rep movsd
		mov ecx,edx
		and ecx,byte +0x3
		rep movsb
		pop esi
		mov ecx,[DATA_005099]
		mov eax,ecx
		shl ecx,0x6
		add ecx,eax
		shl ecx,0x3
		sub ecx,eax
		mov eax,[ebp+0x10]
		mov [ecx*2+DATA_008682],eax
		mov al,[ebp+0xc]
		mov [ecx*2+DATA_008680],al
		mov eax,[DATA_008807]
		mov [ecx*2+DATA_008678],eax
		mov eax,[DATA_008804]
		mov [ecx*2+DATA_008679],eax
		mov edi,[DATA_005099]
		mov esi,edi
		mov [DATA_005098],esi
		mov eax,esi
		inc eax
		mov esi,0xa
		cdq
		idiv esi
		mov [DATA_005097],edx
		test byte [ecx*2+DATA_008682],0x1
		jnz JUMP_001592
		mov eax,edi
		inc eax
		mov ecx,0xa
		cdq
		idiv ecx
		mov [DATA_005099],edx
		mov dword [DATA_005094],0xffffffff
		jmp short JUMP_001593
	JUMP_001592:			; Pos = 1d7e7
		mov [DATA_005094],ebx
	JUMP_001593:			; Pos = 1d7ed
		mov eax,ebx
		shl eax,0x3
		add eax,byte -0x18
		sub eax,[DATA_005096]
		test eax,eax
		jng JUMP_001594
		mov eax,ebx
		shl eax,0x3
		add eax,byte -0x18
		sub eax,[DATA_005096]
		jmp short JUMP_001595
	JUMP_001594:			; Pos = 1d80f
		mov eax,ebx
		shl eax,0x3
		add eax,byte -0x18
		sub eax,[DATA_005096]
		neg eax
	JUMP_001595:			; Pos = 1d81f
		mov [DATA_005092],eax
		or eax,byte -0x1
		shl ebx,0x3
		add ebx,byte -0x18
		cmp ebx,[DATA_005096]
		jl JUMP_001596
		add eax,byte +0x2
	JUMP_001596:			; Pos = 1d838
		mov [DATA_008677],eax
		mov eax,[DATA_008799]
		mov [DATA_005093],eax
		jmp short JUMP_001599
	JUMP_001597:			; Pos = 1d849
		mov ecx,[DATA_005099]
		mov eax,ecx
		shl ecx,0x6
		add ecx,eax
		shl ecx,0x3
		sub ecx,eax
		test byte [ecx*2+DATA_008682],0x1
		jz JUMP_001599
		dec dword [DATA_005098]
		cmp dword [DATA_005098],byte -0x1
		jnz JUMP_001598
		mov dword [DATA_005098],0x9
	JUMP_001598:			; Pos = 1d87e
		mov eax,[DATA_005098]
		inc eax
		mov ebx,0xa
		cdq
		idiv ebx
		mov [DATA_005097],edx
		xor eax,eax
		mov [ecx*2+DATA_008682],eax
		mov byte [ecx*2+DATA_008681],0x0
		mov dword [DATA_005094],0xffffffff
	JUMP_001599:			; Pos = 1d8ad
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret



