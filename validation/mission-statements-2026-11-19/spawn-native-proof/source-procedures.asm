FUNC_000039:			; Pos = 12b38

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		pop ebp
		ret




FUNC_000040:			; Pos = 12b40

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
		mov esi,[ebp+0xc]
		lea eax,[ebp-0x4]
		push eax
		mov eax,[ebp+0x8]
		push eax
		push byte +0x1d
		mov ebx,[DATA_009133]
		push ebx
		push esi
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		push eax
		push ebx
		call near [DATA_007198]    ; FUNC_000927
		add esp,byte +0x14
		mov ebx,eax
		test ebx,ebx
		jnz JUMP_000357
		mov eax,ebx
		jmp JUMP_000358
	JUMP_000357:			; Pos = 12b7c
		mov eax,[ebp+0x10]
		mov [ebx+0xa0],eax
		mov eax,esi
		mov [ebx+0x56],al
		mov word [ebx+0xda],0xfffc
		mov eax,[DATA_008804]
		mov [ebx+0xa8],eax
		mov eax,[DATA_008807]
		mov [ebx+0xac],eax
		mov eax,[ebp+0x1c]
		mov [ebx+0xc2],eax
		mov edx,[DATA_008807]
		push edx
		mov edx,[DATA_008804]
		push edx
		push byte +0x0
		push byte +0x0
		push eax
		lea eax,[ebx+0xba]
		push eax
		call near [DATA_007743]    ; FUNC_001510
		add esp,byte +0x18
		mov eax,[ebp+0x18]
		shl eax,0x10
		add [ebx+0xbe],eax
		xor eax,eax
		mov [ebx+0xa4],eax
		mov ax,[ebp+0x20]
		mov [ebx+0xc6],ax
		mov byte [ebx+0x87],0x1
		mov eax,[ebp+0x14]
		mov [ebx+0xb0],eax
		mov eax,[ebx+0xbe]
		push eax
		movsx eax,word [ebx+0xc6]
		push eax
		mov eax,[ebx+0xb0]
		push eax
		push ebx
		call near [DATA_007741]    ; FUNC_001507
		add esp,byte +0x10
		mov ax,[ebp+0x28]
		mov [ebx+0xcc],ax
		mov al,[ebp+0x24]
		mov [ebx+0xc8],al
		movsx edx,word [ebx+0xcc]
		push edx
		mov ecx,eax
		mov eax,[ebx+0xa8]
		shl eax,cl
		push eax
		push ebx
		call FUNC_001675_MatBuildYZT
		add esp,byte +0xc
		mov eax,ebx
	JUMP_000358:			; Pos = 12c56
		pop esi
		pop ebx
		pop ecx
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




FUNC_001510:			; Pos = 5321a

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		mov ecx,[ebp+0x1c]
		mov eax,[ebp+0x14]
		mov edx,[ebp+0x10]
		mov ebx,[ebp+0x8]
		not eax
		not edx
		inc eax
		test eax,eax
		jnz JUMP_005680
		inc edx
	JUMP_005680:			; Pos = 53237
		add eax,ecx
		add edx,[ebp+0x18]
		cmp eax,ecx
		jnc JUMP_005681
		inc edx
	JUMP_005681:			; Pos = 53241
		push dword [ebp+0xc]
		push eax
		push edx
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001509
		add esp,byte +0x10
		mov eax,[ebp-0x8]
		mov [ebx],eax
		mov eax,[ebp-0x4]
		mov [ebx+0x4],eax
		mov eax,ebx
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001509:			; Pos = 531c8

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		mov ebx,[ebp+0x8]
		mov eax,[ebp+0x10]
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov [ebp-0x4],eax
		push dword [ebp+0x14]
		push dword [ebp-0x4]
		push dword [ebp-0x8]
		lea eax,[ebp-0x10]
		push eax
		call FUNC_001338_Int64Mul32
		add esp,byte +0x10
		mov eax,[ebp-0xc]
		shl eax,0x3
		mov edx,[ebp-0x10]
		shr edx,0x1d
		or eax,edx
		mov [ebp-0xc],eax
		shl dword [ebp-0x10],0x3
		mov eax,[ebp-0x10]
		mov [ebx],eax
		mov eax,[ebp-0xc]
		mov [ebx+0x4],eax
		mov eax,ebx
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001338_Int64Mul32:			; Pos = 4ebdd

		push ebp
		mov ebp,esp
		push ecx
		mov eax,[ebp+0xc]
		mul dword [ebp+0x14]
		mov ecx,[ebp+0x8]
		mov [ecx],eax
		mov [ecx+0x4],edx
		mov eax,[ebp+0x10]
		mul dword [ebp+0x14]
		add [ecx+0x4],eax
		pop ecx
		pop ebp
		ret



; void F1339 (int64 *rval, int op1, int op2)


FUNC_001675_MatBuildYZT:			; Pos = 5aff0

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edi,[ebp+0x10]
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push esi
		call FUNC_001914_Sin32
		pop ecx
		mov [ebx+0x4],eax
		push edi
		call FUNC_001914_Sin32
		pop ecx
		mov [ebx+0x18],eax
		add esi,0x4000
		push esi
		call FUNC_001914_Sin32
		pop ecx
		mov [ebx+0x10],eax
		add edi,0x4000
		push edi
		call FUNC_001914_Sin32
		pop ecx
		mov [ebx+0x20],eax
		xor eax,eax
		mov [ebx+0x1c],eax

		mov eax,[ebx+0x18]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x14],eax

		mov eax,[ebx+0x20]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx],eax

		mov eax,[ebx+0x20]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		neg eax
		mov [ebx+0xc],eax

		mov eax,[ebx+0x10]
		push eax
		mov eax,[ebx+0x18]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		neg eax
		mov [ebx+0x8],eax

		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001914_Sin32:			; Pos = 70b41

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,eax
		and edx,0x3fff
		shr eax,0xe
		and eax,byte +0x3
		sub eax,byte +0x1
		jc JUMP_008167
		jz JUMP_008168
		dec eax
		jz JUMP_008169
		dec eax
		jz JUMP_008170
		pop ebp
		ret
	JUMP_008167:			; Pos = 70b64
		mov eax,[edx*4+DATA_007975]
		pop ebp
		ret
	JUMP_008168:			; Pos = 70b6d
		mov eax,0x3fff
		sub eax,edx
		mov eax,[eax*4+DATA_007975]
		pop ebp
		ret
	JUMP_008169:			; Pos = 70b7d
		mov eax,[edx*4+DATA_007975]
		neg eax
		pop ebp
		ret
	JUMP_008170:			; Pos = 70b88
		mov eax,0x3fff
		sub eax,edx
		mov eax,[eax*4+DATA_007975]
		neg eax
		pop ebp
		ret




FUNC_001521:			; Pos = 537b0

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		imul dword [ebp+0xc]
		shl eax,1
		rcl edx,1
		mov eax,edx
		pop ebp
		ret




FUNC_999999:
ret
