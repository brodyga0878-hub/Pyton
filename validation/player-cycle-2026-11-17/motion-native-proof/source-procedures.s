FUNC_001046:			; Pos = 424fc

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		cmp byte [ebx+0x14e],0x0
		jz JUMP_004318
		push byte +0x0
		lea eax,[ebx+0x3e]
		push eax
		push ebx
		call FUNC_000939
		add esp,byte +0xc
	JUMP_004318:			; Pos = 4251b
		push ebx
		call FUNC_001045
		pop ecx
		cmp byte [DATA_009030],0x0
		jz near JUMP_004327
		cmp dword [DATA_009116],byte +0x0
		jnl near JUMP_004327
		cmp word [ebx+0xb6],byte +0x0
		jl JUMP_004319
		movsx edx,word [ebx+0xb6]
		jmp short JUMP_004320
	JUMP_004319:			; Pos = 4254f
		movsx edx,word [ebx+0xb6]
		neg edx
	JUMP_004320:			; Pos = 42558
		cmp word [ebx+0xb8],byte +0x0
		jl JUMP_004321
		movsx eax,word [ebx+0xb8]
		jmp short JUMP_004322
	JUMP_004321:			; Pos = 4256b
		movsx eax,word [ebx+0xb8]
		neg eax
	JUMP_004322:			; Pos = 42574
		cmp word [ebx+0xba],byte +0x0
		jl JUMP_004323
		movsx ecx,word [ebx+0xba]
		jmp short JUMP_004324
	JUMP_004323:			; Pos = 42587
		movsx ecx,word [ebx+0xba]
		neg ecx
	JUMP_004324:			; Pos = 42590
		cmp edx,eax
		jng JUMP_004325
		mov eax,edx
	JUMP_004325:			; Pos = 42596
		cmp ecx,eax
		jng JUMP_004326
		mov eax,ecx
	JUMP_004326:			; Pos = 4259c
		sub eax,0x221
		test eax,eax
		jl JUMP_004327
		push ebx
		mov edx,0x1ae
		sub edx,eax
		push edx
		push eax
		push byte +0x3
		call FUNC_001910_SoundModifyStationNoise
		add esp,byte +0x10
		or word [DATA_008860],0x80
	JUMP_004327:			; Pos = 425c2
		pop ebx
		pop ebp
		ret




FUNC_001033:			; Pos = 41a7c

		push ebp
		mov ebp,esp
		add esp,byte -0x38
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x10]
		mov edi,[ebp+0x8]
		mov esi,DATA_008804
		mov eax,[ebp+0x18]
		push eax
		lea eax,[ebp-0x4]
		push eax
		push ebx
		mov eax,[ebp+0x14]
		push eax
		lea eax,[ebp-0x5]
		push eax
		mov eax,[ebp+0xc]
		push eax
		push edi
		call near [DATA_006141]    ; FUNC_000569
		add esp,byte +0x1c
		mov al,[ebp-0x5]
		mov [esi+0x212],al
		cmp dword [ebp-0x4],byte -0x1
		jnz JUMP_004261
		mov eax,0x7fffffff
		jmp short JUMP_004262
	JUMP_004261:			; Pos = 41ac5
		mov eax,[ebp-0x4]
	JUMP_004262:			; Pos = 41ac8
		mov [esi+0xdc],eax
		cmp eax,0xb71b00
		jl JUMP_004264
		cmp byte [esi+0xe8],0x2c
		jz JUMP_004266
		test byte [esi+0xc6],0x40
		jz JUMP_004263
		cmp byte [DATA_008630],0x0
		jnl JUMP_004263
		call FUNC_001116
	JUMP_004263:			; Pos = 41af5
		or word [esi+0xc6],byte +0x40
		jmp short JUMP_004266
	JUMP_004264:			; Pos = 41aff
		test byte [esi+0xc6],0x40
		jz JUMP_004265
		cmp byte [DATA_008630],0x0
		jnl JUMP_004265
		call FUNC_001116
	JUMP_004265:			; Pos = 41b16
		and word [esi+0xc6],0xffbf
	JUMP_004266:			; Pos = 41b1f
		test byte [esi+0x212],0x1
		jnz JUMP_004267
		push edi
		call FUNC_001034
		pop ecx
		movsx eax,byte [esi+0x212]
		jmp JUMP_004274
	JUMP_004267:			; Pos = 41b3b
		mov eax,[ebx]
		mov eax,[eax+0x82]
		cmp eax,0x86
		jc near JUMP_004273
		cmp eax,0x94
		ja near JUMP_004273
		test byte [edi+0xca],0x10
		jz near JUMP_004270
		cmp dword [ebp-0x4],0x1c9c380
		jg JUMP_004268
		cmp dword [esi+0xd8],0x2328
		jl JUMP_004268
		mov eax,[esi+0x1e8]
		cmp eax,[DATA_009155]
		jna JUMP_004269
	JUMP_004268:			; Pos = 41b89
		movsx eax,byte [esi+0x212]
		jmp JUMP_004274
	JUMP_004269:			; Pos = 41b95
		mov eax,[esi+0x120]
		cmp eax,[esi+0x118]
		jnl JUMP_004270
		inc dword [esi+0x120]
		inc word [esi+0x15a]
		mov dword [ebp-0x38],0x9906
		movzx eax,word [esi+0x15a]
		mov [ebp-0x34],eax
		lea eax,[ebp-0x38]
		push eax
		call FUNC_000349
		pop ecx
		push dword 0x8e13
		push byte +0x16
		call FUNC_000148
		add esp,byte +0x8
		push byte +0x11
		call FUNC_001906_SoundPlaySample
		pop ecx
	JUMP_004270:			; Pos = 41be9
		mov dword [esi+0x1e8],0x2468a
		mov eax,[ebx]
		mov edx,[eax+0x82]
		cmp edx,0x89
		jc JUMP_004273
		mov eax,[esi+0x1ec]
		cmp edx,0x8c
		jc JUMP_004271
		mov edx,[DATA_009155]
		shr edx,0x8
		jmp short JUMP_004272
	JUMP_004271:			; Pos = 41c1c
		mov edx,[DATA_009155]
		shr edx,0xa
	JUMP_004272:			; Pos = 41c25
		add edx,[esi+0x1ec]
		mov [esi+0x1ec],edx
		cmp eax,[esi+0x1ec]
		jng JUMP_004273
		push byte +0x0
		push byte -0x1
		push edi
		call FUNC_000953
		add esp,byte +0xc
	JUMP_004273:			; Pos = 41c46
		movsx eax,byte [esi+0x212]
	JUMP_004274:			; Pos = 41c4d
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001034:			; Pos = 41c54

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		test byte [eax+0xca],0x2
		jnz JUMP_004276
		cmp word [DATA_008900],byte +0x0
		jz JUMP_004275
		dec word [DATA_008900]
		inc word [DATA_008898]
	JUMP_004275:			; Pos = 41c7b
		cmp word [DATA_008899],byte +0x0
		jz JUMP_004276
		dec word [DATA_008899]
		inc word [DATA_008897]
	JUMP_004276:			; Pos = 41c93
		pop ebp
		ret




FUNC_001045:			; Pos = 424dc

		push ebp
		mov ebp,esp
		mov eax,[DATA_008868]
		push eax
		mov eax,[DATA_008869]
		push eax
		mov eax,[ebp+0x8]
		push eax
		call near [DATA_007744]    ; FUNC_001512
		add esp,byte +0xc
		pop ebp
		ret




FUNC_001512:			; Pos = 5345c

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		lea edx,[eax+0x8c]
		push edx
		push dword [ebp+0x10]
		push dword [ebp+0xc]
		add eax,byte +0x3e
		push eax
		call FUNC_001511
		add esp,byte +0x10
		pop ebp
		ret




FUNC_001511:			; Pos = 53264

		push ebp
		mov ebp,esp
		add esp,byte -0x24
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x10]
		mov edi,[ebp+0xc]
		xor esi,esi
		test edi,0x80000000
		setnz al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		cmp dword [ebp-0x4],byte +0x0
		jz JUMP_005682
		not ebx
		inc ebx
		not edi
		test ebx,ebx
		setz al
		and eax,byte +0x1
		add edi,eax
	JUMP_005682:			; Pos = 53299
		shr ebx,0x7
		mov eax,edi
		shl eax,0x19
		or ebx,eax
		shr edi,0x7
		test edi,edi
		jz JUMP_005683
		push edi
		call FUNC_001656_FindMSB
		pop ecx
		mov esi,eax
		inc esi
		mov ecx,esi
		shr ebx,cl
		mov ecx,0x20
		sub ecx,esi
		shl edi,cl
		or ebx,edi
	JUMP_005683:			; Pos = 532c3
		push ebx
		call FUNC_001656_FindMSB
		pop ecx
		add eax,byte -0xe
		test eax,eax
		jnl JUMP_005684
		xor eax,eax
	JUMP_005684:			; Pos = 532d3
		add esi,eax
		mov ecx,eax
		shr ebx,cl
		mov eax,[ebp+0x14]
		mov eax,[eax]
		mov [ebp-0xc],eax
		mov eax,[ebp+0x14]
		mov eax,[eax]
		sar eax,0x1f
		mov [ebp-0x8],eax
		push ebx
		push dword [ebp-0x8]
		push dword [ebp-0xc]
		lea eax,[ebp-0x24]
		push eax
		call FUNC_001338_Int64Mul32
		add esp,byte +0x10
		mov eax,[ebp+0x14]
		mov eax,[eax+0x4]
		mov [ebp-0xc],eax
		mov eax,[ebp+0x14]
		mov eax,[eax+0x4]
		sar eax,0x1f
		mov [ebp-0x8],eax
		push ebx
		push dword [ebp-0x8]
		push dword [ebp-0xc]
		lea eax,[ebp-0x1c]
		push eax
		call FUNC_001338_Int64Mul32
		add esp,byte +0x10
		mov eax,[ebp+0x14]
		mov eax,[eax+0x8]
		mov [ebp-0xc],eax
		mov eax,[ebp+0x14]
		mov eax,[eax+0x8]
		sar eax,0x1f
		mov [ebp-0x8],eax
		push ebx
		push dword [ebp-0x8]
		push dword [ebp-0xc]
		lea eax,[ebp-0x14]
		push eax
		call FUNC_001338_Int64Mul32
		add esp,byte +0x10
		mov eax,[ebp-0x24]
		shr eax,0x2
		mov edx,[ebp-0x20]
		shl edx,0x1e
		or eax,edx
		mov [ebp-0x24],eax
		sar dword [ebp-0x20],0x2
		mov eax,[ebp-0x1c]
		shr eax,0x2
		mov edx,[ebp-0x18]
		shl edx,0x1e
		or eax,edx
		mov [ebp-0x1c],eax
		sar dword [ebp-0x18],0x2
		mov eax,[ebp-0x14]
		shr eax,0x2
		mov edx,[ebp-0x10]
		shl edx,0x1e
		or eax,edx
		mov [ebp-0x14],eax
		sar dword [ebp-0x10],0x2
		test esi,esi
		jz JUMP_005685
		mov ecx,esi
		mov eax,[ebp-0x20]
		shl eax,cl
		mov ecx,0x20
		sub ecx,esi
		mov edx,[ebp-0x24]
		shr edx,cl
		or eax,edx
		mov [ebp-0x20],eax
		mov ecx,esi
		shl dword [ebp-0x24],cl
		mov ecx,esi
		mov eax,[ebp-0x18]
		shl eax,cl
		mov ecx,0x20
		sub ecx,esi
		mov edx,[ebp-0x1c]
		shr edx,cl
		or eax,edx
		mov [ebp-0x18],eax
		mov ecx,esi
		shl dword [ebp-0x1c],cl
		mov ecx,esi
		mov eax,[ebp-0x10]
		shl eax,cl
		mov ecx,0x20
		sub ecx,esi
		mov edx,[ebp-0x14]
		shr edx,cl
		or eax,edx
		mov [ebp-0x10],eax
		mov ecx,esi
		shl dword [ebp-0x14],cl
	JUMP_005685:			; Pos = 533e9
		cmp dword [ebp-0x4],byte +0x0
		jz JUMP_005686
		mov eax,[ebp-0x24]
		not eax
		inc eax
		mov [ebp-0x24],eax
		mov eax,[ebp-0x20]
		not eax
		cmp dword [ebp-0x24],byte +0x0
		setz dl
		and edx,byte +0x1
		add eax,edx
		mov [ebp-0x20],eax
		mov eax,[ebp-0x1c]
		not eax
		inc eax
		mov [ebp-0x1c],eax
		mov eax,[ebp-0x18]
		not eax
		cmp dword [ebp-0x1c],byte +0x0
		setz dl
		and edx,byte +0x1
		add eax,edx
		mov [ebp-0x18],eax
		mov eax,[ebp-0x14]
		not eax
		inc eax
		mov [ebp-0x14],eax
		mov eax,[ebp-0x10]
		not eax
		cmp dword [ebp-0x14],byte +0x0
		setz dl
		and edx,byte +0x1
		add eax,edx
		mov [ebp-0x10],eax
	JUMP_005686:			; Pos = 53446
		lea eax,[ebp-0x24]
		push eax
		push dword [ebp+0x8]
		call FUNC_001661_Vec64Add
		add esp,byte +0x8
		pop edi
		pop esi
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


FUNC_001656_FindMSB:			; Pos = 59cec

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp eax,0x10000
		jc JUMP_006329
		shr eax,0x10
		mov edx,0x10
		jmp short JUMP_006330
	JUMP_006329:			; Pos = 59d03
		xor edx,edx
	JUMP_006330:			; Pos = 59d05
		cmp eax,0x100
		jc JUMP_006331
		shr eax,0x8
		add edx,byte +0x8
	JUMP_006331:			; Pos = 59d12
		cmp eax,byte +0x10
		jc JUMP_006332
		shr eax,0x4
		add edx,byte +0x4
	JUMP_006332:			; Pos = 59d1d
		cmp eax,byte +0x4
		jc JUMP_006333
		shr eax,0x2
		add edx,byte +0x2
	JUMP_006333:			; Pos = 59d28
		cmp eax,byte +0x2
		jc JUMP_006334
		lea eax,[edx+0x1]
		pop ebp
		ret
	JUMP_006334:			; Pos = 59d32
		mov eax,edx
		pop ebp
		ret




FUNC_001661_Vec64Add:			; Pos = 5a044

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push dword [esi+0x4]
		push dword [esi]
		push dword [ebx+0x4]
		push dword [ebx]
		push ebx
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		push dword [esi+0xc]
		push dword [esi+0x8]
		push dword [ebx+0xc]
		push dword [ebx+0x8]
		lea eax,[ebx+0x8]
		push eax
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		push dword [esi+0x14]
		push dword [esi+0x10]
		push dword [ebx+0x14]
		push dword [ebx+0x10]
		add ebx,byte +0x10
		push ebx
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001333_Int64Add64:			; Pos = 4eb4e

		push ebp
		mov ebp,esp
		mov edx,[ebp+0x8]
		mov eax,[ebp+0xc]
		add eax,[ebp+0x14]
		mov [edx],eax
		mov eax,[ebp+0x10]
		adc eax,[ebp+0x18]
		mov [edx+0x4],eax
		pop ebp
		ret



; void F1334 (int *rval, int64 op1, int op2)

