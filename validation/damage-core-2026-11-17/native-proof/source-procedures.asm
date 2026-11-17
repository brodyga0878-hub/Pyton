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




FUNC_000144:			; Pos = 1934c

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov eax,[eax*4+DATA_004892]
		mov edx,[ebp+0xc]
		mov eax,[eax+edx*4]
		test eax,eax
		jz JUMP_001170
		mov edx,[ebp+0x10]
		push edx
		call eax
		pop ecx
	JUMP_001170:			; Pos = 1936a
		pop ebp
		ret




FUNC_000148:			; Pos = 19470

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		mov eax,[ebp+0x8]
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov [ebp-0x4],eax
		xor ebx,ebx
		mov esi,DATA_008623
	JUMP_001177:			; Pos = 1948b
		test byte [esi],0x2
		jz JUMP_001178
		lea eax,[ebp-0x8]
		push eax
		push byte +0x2
		push ebx
		call FUNC_000144
		add esp,byte +0xc
	JUMP_001178:			; Pos = 1949f
		inc ebx
		add esi,byte +0x8
		cmp ebx,byte +0x15
		jl JUMP_001177
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_000922:			; Pos = 3c944

		push ebp
		mov ebp,esp
		mov eax,[DATA_008818]
		mov edx,[DATA_008820]
		add eax,edx
		mov ecx,edx
		shr ecx,0x1b
		shl edx,0x5
		or ecx,edx
		mov edx,ecx
		add eax,edx
		mov ecx,eax
		shl ecx,0x10
		shr eax,0x10
		or ecx,eax
		mov eax,ecx
		mov [DATA_008818],eax
		mov [DATA_008820],edx
		and eax,0xffff
		mov edx,[ebp+0x8]
		imul edx,eax
		mov eax,edx
		shr eax,0x10
		pop ebp
		ret




FUNC_000953:			; Pos = 3e288

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov edi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		test edi,edi
		jnl JUMP_003996
		mov edi,0x7fffffff
	JUMP_003996:			; Pos = 3e2a0
		xor eax,eax
		mov al,[ebx+0x86]
		push eax
		push byte +0xd
		call FUNC_000034
		add esp,byte +0x8
		mov eax,[ebp+0x10]
		push eax
		push byte +0xe
		call FUNC_000034
		add esp,byte +0x8
		push edi
		push byte +0xc
		call FUNC_000034
		add esp,byte +0x8
		push byte +0xc
		call FUNC_000035
		pop ecx
		mov edi,eax

		xor esi,esi
		mov dword [ebp-0x10],DATA_008623
		jmp short JUMP_003999
	JUMP_003997:			; Pos = 3e2e1
		mov eax,[ebp-0x10]
		test byte [eax],0x4
		jz JUMP_003998
		mov dword [ebp-0xc],0x1
		mov [ebp-0x8],ebx
		mov al,[ebx+0x86]
		mov [ebp-0x4],al
		lea eax,[ebp-0xc]
		push eax
		push byte +0xb
		push esi
		call FUNC_000144
		add esp,byte +0xc
	JUMP_003998:			; Pos = 3e30b
		inc esi
		add dword [ebp-0x10],byte +0x8
	JUMP_003999:			; Pos = 3e310
		cmp esi,[DATA_008621]
		jl JUMP_003997

		cmp byte [ebx+0x87],0x3
		jz JUMP_004000
		cmp byte [ebx+0x87],0xb
		jnz near JUMP_004006
		xor eax,eax
		mov al,[ebx+0x86]
		mov edx,[DATA_007758]
		test byte [edx+eax],0x10
		jnz near JUMP_004006
		mov eax,[ebx+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		cmp dword [eax+0x38],byte +0x0
		jz near JUMP_004006
	JUMP_004000:			; Pos = 3e35e
		movzx eax,word [ebx+0xe0]
		cmp edi,eax
		jg JUMP_004001
		sub [ebx+0xe0],di
		movsx eax,byte [ebx+0x88]
		push eax
		push byte +0x1c
		call FUNC_001907_SoundPlaySampleLogVol
		add esp,byte +0x8
		or byte [ebx+0x151],0x1
		jmp short JUMP_004004
	JUMP_004001:			; Pos = 3e38b
		movzx eax,word [ebx+0xe0]
		sub edi,eax
		mov word [ebx+0xe0],0x0
		movzx eax,word [ebx+0xe4]
		cmp edi,eax
		jl JUMP_004002
		mov eax,[ebp+0x10]
		push eax
		push ebx
		call FUNC_000942
		add esp,byte +0x8
		jmp short JUMP_004007
	JUMP_004002:			; Pos = 3e3b7
		sub [ebx+0xe4],di
		mov byte [ebx+0x14e],0xa
		movsx eax,byte [ebx+0x88]
		push eax
		push byte +0x1d
		call FUNC_001907_SoundPlaySampleLogVol
		add esp,byte +0x8
		movzx esi,word [ebx+0xe4]
		sar esi,0x2
		cmp edi,esi
		jnl JUMP_004003
		call near [DATA_007752]    ; FUNC_001530
		mov ecx,eax
		mov eax,edi
		shl eax,0xf
		cdq
		idiv esi
		cmp ecx,eax
		jnc JUMP_004004
	JUMP_004003:			; Pos = 3e3f9
		push ebx
		call FUNC_000952
		pop ecx
		jmp short JUMP_004007
	JUMP_004004:			; Pos = 3e402
		cmp byte [ebx+0x118],0xff
		jnz JUMP_004005
		push byte +0x0
		push byte +0x17
		call FUNC_000148
		add esp,byte +0x8
	JUMP_004005:			; Pos = 3e417
		mov eax,0x1
		jmp short JUMP_004007
	JUMP_004006:			; Pos = 3e41e
		movsx eax,byte [ebx+0x88]
		push eax
		push byte +0x1d
		call FUNC_001907_SoundPlaySampleLogVol
		add esp,byte +0x8
		mov eax,0x1
	JUMP_004007:			; Pos = 3e435
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001530:			; Pos = 539f4

		mov edx,[DATA_008818]
		mov eax,[DATA_008820]
		xor eax,0x1234567f
		mov ecx,eax
		shl ecx,0x19
		shr eax,0x7
		or ecx,eax
		mov eax,ecx
		add [DATA_008818],eax
		mov eax,edx
		shl eax,0xd
		shr edx,0x13
		or eax,edx
		mov edx,eax
		mov [DATA_008820],edx
		mov eax,[DATA_008818]
		and eax,0xffff
		ret




FUNC_001538:			; Pos = 53f88

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov eax,[eax*4+DATA_004681]
		pop ebp
		ret




FUNC_999999:
ret
