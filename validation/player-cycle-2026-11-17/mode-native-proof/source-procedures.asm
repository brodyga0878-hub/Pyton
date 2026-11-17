FUNC_001008:			; Pos = 40aac

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ebx,[ebp+0x8]
		mov esi,DATA_008804
		mov ax,[ebx+0xe8]
		test ax,ax
		jz JUMP_004178
		mov edx,[DATA_009155]
		cmp edx,0xffff
		ja JUMP_004177
		movzx eax,ax
		cmp edx,eax
		ja JUMP_004176
		mov ax,[DATA_009155]
		sub [ebx+0xe8],ax
		jmp short JUMP_004178
	JUMP_004176:			; Pos = 40ae9
		mov word [ebx+0xe8],0x0
		jmp short JUMP_004178
	JUMP_004177:			; Pos = 40af4
		mov word [ebx+0xe8],0x0

	JUMP_004178:			; Pos = 40afd
		cmp byte [esi+0xe8],0x2
		jnz JUMP_004181
		and word [esi+0xc6],0xfffd
		cmp byte [ebx+0xff],0x1e
		jna JUMP_004180
		test byte [esi+0xe9],0x2
		jz JUMP_004179
		call FUNC_001116
	JUMP_004179:			; Pos = 40b26
		and byte [esi+0xe9],0xfd
		jmp short JUMP_004181
	JUMP_004180:			; Pos = 40b2f
		or byte [esi+0xe9],0x2
		test byte [esi+0xe9],0x2
		jz JUMP_004181
		call FUNC_001116

	JUMP_004181:			; Pos = 40b44
		test byte [esi+0xe9],0x2
		jz JUMP_004183
		movzx edx,word [ebx+0x9e]
		mov eax,[DATA_009155]
		shr eax,1
		cmp edx,eax
		jna JUMP_004182
		sub [ebx+0x9e],ax
		jmp short JUMP_004187
	JUMP_004182:			; Pos = 40b68
		mov word [ebx+0x9e],0x0
		jmp short JUMP_004187
	JUMP_004183:			; Pos = 40b73
		cmp byte [esi+0xe8],0x2
		jz JUMP_004185
		cmp dword [esi+0xd8],0x186a0
		jl JUMP_004185
		test byte [esi+0xc6],0x2
		jnz JUMP_004184
		push byte -0x1
		push dword 0x98ce
		call FUNC_001097
		add esp,byte +0x8
	JUMP_004184:			; Pos = 40ba0
		or word [esi+0xc6],byte +0x2
	JUMP_004185:			; Pos = 40ba8
		movzx eax,word [ebx+0x9e]
		mov edx,[DATA_009155]
		shr edx,1
		add eax,edx
		cmp eax,0xffff
		jna JUMP_004186
		mov word [ebx+0x9e],0xffff
		jmp short JUMP_004187
	JUMP_004186:			; Pos = 40bcb
		mov eax,[DATA_009155]
		shr eax,1
		add [ebx+0x9e],ax
	JUMP_004187:			; Pos = 40bd9
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001009:			; Pos = 40be0

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov eax,[ebp+0x8]
		mov ebx,[eax+0x8]
		mov edx,[eax]
		mov ecx,edx
		sub ecx,[ebx+0xa8]
		mov esi,[eax+0x4]
		sub esi,[ebx+0xac]
		cmp edx,[ebx+0xa8]
		mov edi,0x1
		jc JUMP_004188
		dec edi
	JUMP_004188:			; Pos = 40c0d
		sub esi,edi
		mov [ebx+0xa8],edx
		mov eax,[eax+0x4]
		mov [ebx+0xac],eax
		mov [DATA_008868],ecx
		mov [DATA_008869],esi
		mov byte [ebx+0x8a],0x0
		mov byte [ebx+0x8b],0x0
		push ebx
		call FUNC_001008
		pop ecx
		push ebx
		movsx eax,byte [DATA_008870]
		sar eax,1
		mov eax,[eax*8+DATA_007255]
		call eax
		pop ecx
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001010:			; Pos = 40c58

		push ebp
		mov ebp,esp
		mov al,[DATA_008872]
		cmp al,0x6
		jz JUMP_004190
		cmp al,0x5
		jz JUMP_004190
		cmp dword [DATA_007246],byte +0x0
		jz JUMP_004189
		call FUNC_001062
	JUMP_004189:			; Pos = 40c76
		cmp dword [DATA_007247],byte +0x0
		jz JUMP_004190
		call FUNC_001064
	JUMP_004190:			; Pos = 40c84
		movsx eax,byte [DATA_008870]
		sar eax,1
		mov eax,[eax*8+DATA_007256]
		call eax
		pop ebp
		ret



