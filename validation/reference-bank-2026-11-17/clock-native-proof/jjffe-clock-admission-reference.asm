	JUMP_003850:			; Pos = 3c7f4
		mov eax,[DATA_009156]
		mov [DATA_009155],eax
		sub [DATA_009156],eax
		mov esi,[ebx+0x4]
		add [ebx],eax
		cmp eax,[ebx]
		jna JUMP_003851
		inc dword [ebx+0x4]
		cmp dword [ebx+0x4],0x127c8e
		jna JUMP_003851
		push byte +0x1
		call FUNC_000918
		pop ecx
	JUMP_003851:			; Pos = 3c821
		mov eax,[ebx+0x4]
		cmp eax,[ebx+0x7a]
; FIX: Groundhog day bug
		ja .rollback
		jc JUMP_003852
		mov eax,[ebx]
		cmp eax,[ebx+0x76]
		jc JUMP_003852
	.rollback:	
		mov eax,[ebx+0x76]
		mov [ebx],eax
		mov eax,[ebx+0x7a]
		mov [ebx+0x4],eax
		push byte +0x0
		push byte +0x15
		call FUNC_000148
		add esp,byte +0x8
		mov dword [ebx+0x7a],0xffffffff
	JUMP_003852:			; Pos = 3c84e
		mov ecx,[ebx+0x4]
		cmp esi,ecx
		jz JUMP_003854
		mov eax,ecx
		mov ecx,0x7
		xor edx,edx
		div ecx
		test edx,edx
		jnz JUMP_003853
		push byte +0x0
		push byte +0x10
		call FUNC_000148
		add esp,byte +0x8
	JUMP_003853:			; Pos = 3c870
		push byte +0x0
		push byte +0xf
		call FUNC_000148
		add esp,byte +0x8
	JUMP_003854:			; Pos = 3c87c
		mov eax,[DATA_009157]
		mov [DATA_009122],eax
		xor edx,edx
		mov [DATA_009157],edx

