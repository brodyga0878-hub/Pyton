FUNC_001037:			; Pos = 41f3c

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x8]
		mov ebx,DATA_008804
		cmp byte [DATA_008630],0x0
		jnl near JUMP_004290
		test byte [ebx+0xe9],0x1
		jnz near JUMP_004289
		cmp byte [DATA_007692],0x0
		jnz JUMP_004285
		cmp dword [ebx+0x1b8],byte +0x0
		jnl JUMP_004284
		xor eax,eax
		mov [ebx+0x1b8],eax
		push esi
		call FUNC_001038
		pop ecx
		jmp JUMP_004290
	JUMP_004284:			; Pos = 41f8a
		mov eax,[ebx+0x1b8]
		push eax
		call FUNC_001121
		pop ecx
		add [ebx+0x1b8],eax
		cmp dword [ebx+0x1b8],byte +0x0
		jnl JUMP_004285
		mov dword [ebx+0x1b8],0x7fffffff
	JUMP_004285:			; Pos = 41fb0
		cmp byte [DATA_007694],0x0
		jnz JUMP_004288
		mov eax,[ebx+0x1b8]
		test eax,eax
		jg JUMP_004286
		test byte [ebx+0xe9],0x80
		jnz JUMP_004289
		mov edx,[DATA_009122]
		shr edx,0x8
		push edx
		mov edx,eax
		pop eax
		sub edx,eax
		mov [ebx+0x1b8],edx
		test edx,edx
		jng JUMP_004289
		mov dword [ebx+0x1b8],0x80000000
		jmp short JUMP_004289
	JUMP_004286:			; Pos = 41ff1
		mov edi,[ebx+0x1b8]
		or byte [ebx+0xe9],0x80
		mov eax,[ebx+0x1b8]
		push eax
		call FUNC_001121
		pop ecx
		sub [ebx+0x1b8],eax
		mov eax,[ebx+0x1b8]
		cmp edi,eax
		jl JUMP_004287
		test eax,eax
		jnl JUMP_004289
	JUMP_004287:			; Pos = 4201f
		xor eax,eax
		mov [ebx+0x1b8],eax
		jmp short JUMP_004289
	JUMP_004288:			; Pos = 42029
		and byte [ebx+0xe9],0x7f
	JUMP_004289:			; Pos = 42030
		push esi
		call FUNC_001038
		pop ecx
	JUMP_004290:			; Pos = 42037
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret



FUNC_001038: ; Pos = 4203c
	push ebp
	mov ebp,esp
	add esp,0xfffffff8
	push ebx
	push esi
	mov esi,dword [ebp+0x8]
	mov ebx,DATA_008804
	mov eax,dword [ebx+0xd0]
	mov dword [ebp-0x4],eax
	call near [DATA_007682]
	mov dword [ebx+0xd0],eax
	mov ax,word [ebx+0xd0]
	sub ax,word [ebp-0x4]
	shl eax,0x6
	mov word [ebp-0x8],ax
	mov ax,word [ebx+0xd2]
	sub ax,word [ebp-0x2]
	shl eax,0x6
	mov word [ebp-0x6],ax
	mov al,byte [ebx+0xea]
	cmp al,0x2
	je near INPUT_441df2
	cmp al,0x3
	je near INPUT_441df2
	cmp byte [ebx+0x3f54],0x0
	jne short INPUT_441d88
	movsx eax,word [ebp-0x8]
	mov edx,eax
	neg eax
	mov word [ebp-0x8],ax
INPUT_441d88:
	cmp byte [ebx+0x3f55],0x0
	jne short INPUT_441d9d
	movsx eax,word [ebp-0x6]
	mov edx,eax
	neg eax
	mov word [ebp-0x6],ax
INPUT_441d9d:
	mov ax,word [ebp-0x6]
	add word [esi+0xb0],ax
	cmp byte [ebx+0x3f56],0x0
	jne short INPUT_441dc1
	mov ax,word [ebp-0x8]
	sub word [esi+0xb4],ax
	jmp near INPUT_441e5e
INPUT_441dc1:
	test byte [ebx+0x212],0x20
	jne near INPUT_441e5e
	mov ax,word [ebp-0x8]
	add word [esi+0xb2],ax
	cmp dword [ebx+0xdc],0x2625a00
	jg short INPUT_441e5e
	mov ax,word [ebp-0x6]
	sub word [esi+0xb4],ax
	jmp short INPUT_441e5e
INPUT_441df2:
	mov ax,word [ebp-0x8]
	add word [ebx+0x204],ax
	mov ax,word [ebp-0x6]
	sub word [ebx+0x206],ax
	cmp word [ebx+0x206],0x0
	jge short INPUT_441e2f
	mov byte [ebx+0xea],0x2
	cmp word [ebx+0x206],0xc000
	jg short INPUT_441e5e
	mov word [ebx+0x206],0xc001
	jmp short INPUT_441e5e
INPUT_441e2f:
	cmp byte [esi+0xd1],0x4
	jl short INPUT_441e55
	mov byte [ebx+0xea],0x3
	cmp word [ebx+0x206],0x4000
	jl short INPUT_441e5e
	mov word [ebx+0x206],0x3fff
	jmp short INPUT_441e5e
INPUT_441e55:
	mov word [ebx+0x206],0xffff
INPUT_441e5e:
	pop esi
	pop ebx
	pop ecx
	pop ecx
	pop ebp
	ret 


FUNC_001039:			; Pos = 42188

		push ebp
		mov ebp,esp
		mov al,[DATA_008872]
		cmp al,0x2
		jz JUMP_004298
		cmp al,0x3
		jnz JUMP_004299
	JUMP_004298:			; Pos = 42198
		mov eax,[ebp+0x8]
		push eax
		call FUNC_001038
		pop ecx
	JUMP_004299:			; Pos = 421a2
		pop ebp
		ret




FUNC_001040:			; Pos = 421a4

		push ebp
		mov ebp,esp
		call near [DATA_007682]    ; FUNC_001445_GuiGetXYAccum
		cmp byte [DATA_008872],0x5
		jz JUMP_004304
		cmp byte [DATA_007696],0x0
		jz JUMP_004300
		test byte [DATA_009163],0x10
		jz JUMP_004300
		test byte [DATA_009163],0x20
		jz JUMP_004300
		cmp byte [DATA_007708],0x0
		jz JUMP_004304
		cmp byte [DATA_007711],0x0
		jz JUMP_004304
	JUMP_004300:			; Pos = 421e3
		mov al,[DATA_008872]
		cmp al,0x4
		jz JUMP_004301
		cmp al,0x6
		jnz JUMP_004302
	JUMP_004301:			; Pos = 421f0
		xor eax,eax
		jmp short JUMP_004303
	JUMP_004302:			; Pos = 421f4
		movsx eax,byte [DATA_008872]
	JUMP_004303:			; Pos = 421fb
		push eax
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000931
		add esp,byte +0x8
	JUMP_004304:			; Pos = 42208
		pop ebp
		ret




FUNC_001121:			; Pos = 461f8

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		xor edx,edx
	JUMP_004635:			; Pos = 46200
		test eax,0x80000000
		jz JUMP_004636
		mov eax,0x7ffeffff
		jmp short JUMP_004637
	JUMP_004636:			; Pos = 4620e
		add eax,eax
		inc edx
		cmp edx,byte +0x5
		jl JUMP_004635
	JUMP_004637:			; Pos = 46216
		shr eax,0x10
		inc eax
		mov edx,[DATA_007690]
		mov ecx,edx
		and ecx,0xff
		cmp ecx,byte +0x10
		jng JUMP_004638
		imul edx,eax
		mov eax,edx
		shr eax,0x4
		cmp eax,0x7fff
		jna JUMP_004638
		mov eax,0x7fff
	JUMP_004638:			; Pos = 46241
		imul dword [DATA_009122]
		shr eax,0x6
		pop ebp
		ret



