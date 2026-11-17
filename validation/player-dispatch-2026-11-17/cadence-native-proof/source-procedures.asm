FUNC_000149:			; Pos = 194b0

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov eax,[ebp+0xc]
		mov [ebp-0xc],eax
		mov eax,[ebp+0x10]
		mov [ebp-0x8],eax
		mov eax,[ebp+0x8]
		mov [DATA_007758],eax
		mov esi,0x72
		mov eax,[ebp+0x8]
		lea ebx,[eax+0x9783]
		mov eax,[ebp+0x8]
		lea edi,[eax+0x72]
	JUMP_001179:			; Pos = 194e1
		test byte [edi],0x1
		jz JUMP_001180
		mov al,[ebx]
		add byte [ebx],0xff
		test al,al
		jnz JUMP_001180
		mov al,[ebx-0x1]
		mov [ebx],al
		lea eax,[esi+esi*4]
		lea eax,[esi+eax*4]
		lea eax,[esi+eax*8]
		add eax,eax
		add eax,[ebp+0x8]
		add eax,byte +0x74
		mov [ebp-0x4],eax
		lea eax,[ebp-0xc]
		push eax
		push byte +0x5
		xor eax,eax
		mov al,[ebx-0x4]
		push eax
		call FUNC_000144
		add esp,byte +0xc
	JUMP_001180:			; Pos = 1951c
		dec esi
		add ebx,0xfffffeae
		dec edi
		test esi,esi
		jg JUMP_001179


		pop edi
		pop esi
		pop ebx
		mov esp,ebp
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



