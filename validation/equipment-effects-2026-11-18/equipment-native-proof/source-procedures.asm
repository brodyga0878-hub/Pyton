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




FUNC_000933:			; Pos = 3d410

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edi,[ebp+0x8]
		mov esi,[edi+0xc8]
		mov edx,esi
		shr edx,0x10
		shl esi,0x10
		or edx,esi
		mov esi,edx
		test esi,esi
		jz JUMP_003915
		mov ebx,0x1c
	JUMP_003912:			; Pos = 3d434
		push byte +0x1d
		call near [DATA_007217]    ; FUNC_000922
		pop ecx
		mov ecx,eax
		mov edx,0x1
		shl edx,cl
		test edx,esi
		jnz JUMP_003913
		dec ebx
		test ebx,ebx
		jnl JUMP_003912

	JUMP_003913:			; Pos = 3d44f
		test ebx,ebx
		jnl JUMP_003914
		xor eax,eax
		jmp short JUMP_003916
	JUMP_003914:			; Pos = 3d457
		mov ecx,eax
		xor ecx,byte +0x10
		mov edx,0x1
		shl edx,cl
		or [edi+0xcc],edx
		not edx
		and [edi+0xc8],edx
		mov eax,[eax*4+DATA_007211]
		jmp short JUMP_003916
	JUMP_003915:			; Pos = 3d47a
		xor eax,eax
	JUMP_003916:			; Pos = 3d47c
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000943:			; Pos = 3dfa8

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp byte [eax+0x118],0xff
		jnz JUMP_003975
		push byte +0x0
		push byte +0x17
		call FUNC_000148
		add esp,byte +0x8
	JUMP_003975:			; Pos = 3dfc3
		mov eax,0x1
		pop ebp
		ret




FUNC_000944:			; Pos = 3dfcc

		push ebp
		mov ebp,esp
		add esp,byte -0x30
		push ebx
		mov ebx,[ebp+0x8]
		cmp byte [ebx+0x118],0xff
		jnz JUMP_003976
		mov dword [ebp-0x18],0xffffffff
		mov eax,[ebp+0xc]
		mov [ebp-0x30],eax
		mov eax,[ebp+0x10]
		mov [ebp-0x2c],eax
		lea eax,[ebp-0x30]
		push eax
		call FUNC_000349
		pop ecx
		push byte +0x0
		push byte +0x17
		call FUNC_000148
		add esp,byte +0x8
	JUMP_003976:			; Pos = 3e008
		push ebx
		call FUNC_000943
		pop ecx
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000945:			; Pos = 3e014

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		push ebx
		call FUNC_000933
		pop ecx
		test eax,eax
		jz JUMP_003977
		push eax
		push dword 0x98c9
		push ebx
		call FUNC_000944
		add esp,byte +0xc
		pop ebx
		pop ebp
		ret
	JUMP_003977:			; Pos = 3e038
		push ebx
		call FUNC_000943
		pop ecx
		pop ebx
		pop ebp
		ret




FUNC_000946:			; Pos = 3e044

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		add [DATA_008904],ax
		mov edx,[DATA_008891]
		add edx,eax
		mov [DATA_008891],edx
		add eax,[DATA_008889]
		mov [DATA_008889],eax
		pop ebp
		ret




FUNC_000947:			; Pos = 3e06c

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		movsx eax,byte [ebx+0xd0]
		mov byte [ebx+0xd0],0x0
		xor edx,edx
		mov [ebx+0x11e],edx
		cmp byte [ebx+0x118],0xff
		jnz JUMP_003978
		mov eax,[eax*4+DATA_007210]
		push eax
		call FUNC_000946
		pop ecx
	JUMP_003978:			; Pos = 3e0a0
		push byte +0x0
		push dword 0x98ca
		push ebx
		call FUNC_000944
		add esp,byte +0xc
		pop ebx
		pop ebp
		ret




FUNC_000948:			; Pos = 3e0b4

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		mov al,[ebx+0xd0]
		test al,al
		jz JUMP_003979
		movsx eax,al
		mov byte [ebx+0xd0],0x1
		cmp byte [ebx+0x118],0xff
		jnz JUMP_003979
		mov eax,[eax*4+DATA_007210]
		sub eax,byte +0x4
		push eax
		call FUNC_000946
		pop ecx
	JUMP_003979:			; Pos = 3e0e9
		push byte +0x0
		push dword 0x98ca
		push ebx
		call FUNC_000944
		add esp,byte +0xc
		pop ebx
		pop ebp
		ret




FUNC_000949:			; Pos = 3e0fc

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		push byte +0x6
		call near [DATA_007217]    ; FUNC_000922
		pop ecx
		mov edx,eax
		cmp edx,byte +0x5
		ja JUMP_003986
		jmp near [edx*4+DATA_000038]


SECTION .data

DATA_000038:			; Pos = 3e11a
	dd JUMP_003980
	dd JUMP_003981
	dd JUMP_003982
	dd JUMP_003983
	dd JUMP_003984
	dd JUMP_003985


SECTION .text
	JUMP_003980:			; Pos = 3e132
		mov word [ebx+0xbc],0x0
		jmp short JUMP_003986
	JUMP_003981:			; Pos = 3e13d
		mov word [ebx+0xbe],0x0
		jmp short JUMP_003986
	JUMP_003982:			; Pos = 3e148
		mov word [ebx+0xc0],0x0
		jmp short JUMP_003986
	JUMP_003983:			; Pos = 3e153
		mov word [ebx+0xc2],0x0
		jmp short JUMP_003986
	JUMP_003984:			; Pos = 3e15e
		mov word [ebx+0xc4],0x0
		jmp short JUMP_003986
	JUMP_003985:			; Pos = 3e169
		mov word [ebx+0xc6],0x0
	JUMP_003986:			; Pos = 3e172
		cmp byte [ebx+0x118],0xff
		jnz JUMP_003987
		xor edx,edx
		mov [eax*4+DATA_008935],edx
	JUMP_003987:			; Pos = 3e184
		add eax,0x99ae
		push eax
		push dword 0x98cb
		push ebx
		call FUNC_000944
		add esp,byte +0xc
		pop ebx
		pop ebp
		ret




FUNC_000950:			; Pos = 3e19c

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		call near [DATA_007752]    ; FUNC_001530
		cmp ax,0x5555
		jc JUMP_003988
		push ebx
		call FUNC_000945
		pop ecx
		pop ebx
		pop ebp
		ret
	JUMP_003988:			; Pos = 3e1b9
		cmp ax,0x888
		jnc JUMP_003989
		push ebx
		call FUNC_000947
		pop ecx
		pop ebx
		pop ebp
		ret
	JUMP_003989:			; Pos = 3e1c9
		cmp ax,0x1c71
		jnc JUMP_003990
		push ebx
		call FUNC_000948
		pop ecx
		pop ebx
		pop ebp
		ret
	JUMP_003990:			; Pos = 3e1d9
		push ebx
		call FUNC_000949
		pop ecx
		pop ebx
		pop ebp
		ret




FUNC_000951:			; Pos = 3e1e4

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ecx,[ebp+0xc]
		mov esi,[ebp+0x8]
		cmp ecx,[DATA_008891]
		jnl JUMP_003993
		mov edx,0x25
		mov eax,DATA_008906
	JUMP_003991:			; Pos = 3e201
		movzx ebx,word [eax]
		sub ecx,ebx
		jns JUMP_003992
		dec word [eax]
		inc word [DATA_008904]
		add edx,0x8e00
		push edx
		push dword 0x98c8
		push esi
		call FUNC_000944
		add esp,byte +0xc
		jmp short JUMP_003994
	JUMP_003992:			; Pos = 3e229
		dec edx
		add eax,byte -0x2
		test edx,edx
		jnl JUMP_003991

	JUMP_003993:			; Pos = 3e231
		push esi
		call FUNC_000943
		pop ecx
	JUMP_003994:			; Pos = 3e238
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000952:			; Pos = 3e23c

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		cmp byte [ebx+0x118],0xff
		jnz JUMP_003995
		mov eax,[ebx+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		mov eax,[eax+0x38]
		movsx eax,word [eax+0x8]
		push eax
		call near [DATA_007217]    ; FUNC_000922
		pop ecx
		cmp eax,[DATA_008889]
		jnl JUMP_003995
		push eax
		push ebx
		call FUNC_000951
		add esp,byte +0x8
		pop ebx
		pop ebp
		ret
	JUMP_003995:			; Pos = 3e27e
		push ebx
		call FUNC_000950
		pop ecx
		pop ebx
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
