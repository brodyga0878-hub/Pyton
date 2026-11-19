FUNC_000038:			; Pos = 12acc

		push ebp
		mov ebp,esp
		push ebx
		mov eax,[ebp+0x8]
		mov edx,eax
		and edx,0xffff
		mov ebx,edx
		shl ebx,0x2
		lea ebx,[ebx+ebx*8]
		add ebx,DATA_008561
		cmp eax,[ebx+0x4]
		jnz JUMP_000356
		cmp dword [ebx+0x8],byte +0x0
		jz JUMP_000354
		push dword FUNC_000045
		push ebx
		call FUNC_000033
		add esp,byte +0x8
		xor eax,eax
		mov [ebx+0x8],eax
		mov dword [ebx+0xc],0xffffffff
	JUMP_000354:			; Pos = 12b18
		mov eax,[ebx+0x1c]
		cmp dword [eax+0xc],byte +0x0
		jl JUMP_000355
		mov dword [ebx],0x5
		pop ebx
		pop ebp
		ret
	JUMP_000355:			; Pos = 12b2a
		inc word [ebx+0x6]
		mov dword [ebx],0x6
	JUMP_000356:			; Pos = 12b34
		pop ebx
		pop ebp
		ret




FUNC_000047: ; Pos = 14018
 push ebp
 mov ebp,esp
 push ecx
 push ebx
 mov ebx,[ebp+0x8]
 cmp dword [ebx],byte +0x1
 jnz JUMP_000473
 mov eax,[ebx+0x8]
 mov edx,[ebp+0xc]
 mov eax,[eax+edx*4+0x8]
 mov [ebp-0x4],eax
 push ebx
 lea eax,[ebp-0x4]
 push eax
 call FUNC_000031
 add esp,byte +0x8
 test eax,eax
 jz JUMP_000473
 mov dword [ebx],0x2
 push ebx
 lea eax,[ebp-0x4]
 push eax
 call FUNC_000041
 add esp,byte +0x8
 cmp dword [ebx],byte +0x2
 jnz JUMP_000473
 mov dword [ebx],0x1
JUMP_000473:
 pop ebx
 pop ecx
 pop ebp
 ret



FUNC_000052:			; Pos = 141ec

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
		push edi
		mov eax,[ebp+0x14]
		push eax
		mov eax,[ebp+0x10]
		push eax
		call FUNC_000051
		add esp,byte +0x8
		mov esi,eax
		mov eax,[ebp+0x10]
		mov eax,[eax*4+DATA_001697]
		mov eax,[eax]
		mov [ebp-0x4],eax
		xor ebx,ebx
		mov eax,[ebp+0x10]
		lea edi,[eax*4+DATA_001697]
		jmp short JUMP_000488
	JUMP_000487:			; Pos = 14222
		mov eax,[ebp+0xc]
		push eax
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000031
		add esp,byte +0x8
		push eax
		push esi
		lea eax,[ebp-0x4]
		push eax
		call FUNC_000037
		add esp,byte +0xc
		inc ebx
	JUMP_000488:			; Pos = 14241
		mov eax,[edi]
		cmp ebx,[eax+0x8]
		jl JUMP_000487
		mov eax,[ebp+0x10]
		mov eax,[eax*4+DATA_001697]
		mov eax,[eax+0x1c]
		mov [esi+0x10],eax
		xor eax,eax
		mov [esi+0x14],eax
		mov eax,[esi+0x4]
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ebp
		ret




FUNC_000053:			; Pos = 14268

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		lea edi,[ebp-0x4]
		mov dword [ebx],0x3
		cmp dword [ebx+0x8],byte +0x0
		jz JUMP_000489
		push dword FUNC_000045
		push ebx
		call FUNC_000033
		add esp,byte +0x8
		xor eax,eax
		mov [ebx+0x8],eax
		mov dword [ebx+0xc],0xffffffff
	JUMP_000489:			; Pos = 1429b
		mov eax,[ebx+0x10]
		mov eax,[eax]
		mov [edi],eax
		push ebx
		push edi
		call FUNC_000041
		add esp,byte +0x8
		cmp dword [ebx],byte +0x3
		jnz JUMP_000493
		xor esi,esi
		jmp short JUMP_000492
	JUMP_000490:			; Pos = 142b5
		mov eax,[eax+esi*4+0x8]
		mov [edi],eax
		push ebx
		push edi
		call FUNC_000031
		add esp,byte +0x8
		test eax,eax
		jz JUMP_000491
		push ebx
		push edi
		call FUNC_000041
		add esp,byte +0x8
		cmp dword [ebx],byte +0x3
		jnz JUMP_000493
		xor esi,esi
	JUMP_000491:			; Pos = 142da
		inc esi
	JUMP_000492:			; Pos = 142db
		mov eax,[ebx+0x10]
		cmp esi,[eax+0x4]
		jl JUMP_000490
		mov eax,[ebx+0x10]
		mov [ebx+0x8],eax
		mov eax,[ebx+0x14]
		mov [ebx+0xc],eax
		push dword FUNC_000044
		push ebx
		call FUNC_000033
		add esp,byte +0x8
		mov dword [ebx],0x1
	JUMP_000493:			; Pos = 14303
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ebp
		ret




FUNC_999999:
ret
