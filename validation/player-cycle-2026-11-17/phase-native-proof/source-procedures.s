FUNC_001041:			; Pos = 4220c

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		mov ebx,[ebp+0x8]
		mov eax,[DATA_009155]
		shr eax,1
		push eax
		push byte +0x0
		push eax
		push ebx
		call near [DATA_006143]    ; FUNC_000585
		add esp,byte +0x10
		mov eax,[DATA_009155]
		shr eax,1
		push eax
		push byte +0x0
		push eax
		push ebx
		call near [DATA_006143]    ; FUNC_000585
		add esp,byte +0x10
		mov eax,[DATA_009155]
		push eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call near [DATA_006153]    ; FUNC_000603
		add esp,byte +0xc
		cmp dword [DATA_008867],0x2625a00
		jg JUMP_004305
		push ebx
		call near [DATA_006157]    ; FUNC_000609
		pop ecx
		mov ax,[ebx+0x112]
		mov [ebx+0xb2],ax
	JUMP_004305:			; Pos = 42278
		dec byte [ebx+0x14d]
		mov al,[ebx+0x14d]
		test al,al
		jnl JUMP_004306
		mov eax,[DATA_009133]
		push eax
		push ebx
		call near [DATA_006154]    ; FUNC_000606
		add esp,byte +0x8
		mov byte [ebx+0x14d],0xd
	JUMP_004306:			; Pos = 4229f
		cmp byte [DATA_008870],0x24
		jnz JUMP_004307
		xor eax,eax
		mov [ebp-0xc],eax
		xor eax,eax
		mov [ebp-0x4],eax
		mov dword [ebp-0x8],0xcc6
		lea eax,[ebp-0x18]
		push eax
		lea eax,[ebp-0xc]
		push eax
		push ebx
		call near [DATA_006151]    ; FUNC_000599
		add esp,byte +0xc
		jmp short JUMP_004309
	JUMP_004307:			; Pos = 422cd
		test byte [DATA_008871],0x1
		jz JUMP_004308
		push ebx
		call FUNC_001043
		pop ecx
		jmp short JUMP_004309
	JUMP_004308:			; Pos = 422df
		lea eax,[ebp-0xc]
		push eax
		mov eax,[DATA_008918]
		push eax
		push ebx
		call near [DATA_006155]    ; FUNC_000607
		add esp,byte +0xc
		lea eax,[ebp-0x18]
		push eax
		lea eax,[ebp-0xc]
		push eax
		push ebx
		call near [DATA_006151]    ; FUNC_000599
		add esp,byte +0xc
	JUMP_004309:			; Pos = 42305
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001043:			; Pos = 4237c

		push ebp
		mov ebp,esp
		add esp,byte -0x24
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		xor eax,eax
		mov [ebp-0x4],eax
		mov [ebp-0x8],eax
		mov [ebp-0xc],eax
		test byte [DATA_009046],0x2
		jz near JUMP_004314
		mov eax,[ebx+0x8c]
		sub eax,[DATA_008839]
		mov [ebp-0x24],eax
		mov eax,[ebx+0x90]
		sub eax,[DATA_008840]
		mov [ebp-0x20],eax
		mov eax,[ebx+0x94]
		sub eax,[DATA_008841]
		mov [ebp-0x1c],eax

		mov eax,[ebp-0x24]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov esi,eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax

		mov eax,[ebp-0x24]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add edi,eax

		mov eax,edi
		cmp eax,0x100
		jng JUMP_004311
		mov edx,eax
		neg edx
		shl edx,0x2
		mov [ebp-0xc],edx
	JUMP_004311:			; Pos = 4244b
		cmp eax,0xffffff00
		jnl JUMP_004312
		neg eax
		shl eax,0x2
		mov [ebp-0xc],eax
	JUMP_004312:			; Pos = 4245a
		cmp esi,0x100
		jng JUMP_004313
		mov eax,esi
		neg eax
		shl eax,0x2
		mov [ebp-0x8],eax
	JUMP_004313:			; Pos = 4246c
		cmp esi,0xffffff00
		jnl JUMP_004314
		neg esi
		shl esi,0x2
		mov [ebp-0x8],esi
	JUMP_004314:			; Pos = 4247c

		cmp byte [DATA_007692],0x0
		jnz JUMP_004315
		mov dword [ebp-0x4],0x7fff
		jmp short JUMP_004317
	JUMP_004315:
		cmp byte [DATA_007694],0x0
		jnz JUMP_004316
		mov dword [ebp-0x4],0xffff8001
		jmp short JUMP_004317

	JUMP_004316:			; Pos = 424a0
		push ebx
		push dword 0x12c
		push byte +0x1
		push byte +0x3
		call FUNC_001910_SoundModifyStationNoise
		add esp,byte +0x10
	JUMP_004317:			; Pos = 424b2
		lea eax,[ebp-0x18]
		push eax
		lea eax,[ebp-0xc]
		push eax
		push ebx
		call near [DATA_006151]    ; FUNC_000599
		add esp,byte +0xc
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001044:			; Pos = 424cc

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		push eax
		call FUNC_001045
		pop ecx
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




FUNC_000585:			; Pos = 2929c

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov eax,[ebp+0x14]
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		lea edi,[ebp-0x4]
		mov edx,[ebx+0x82]
		cmp edx,byte +0x35
		jc JUMP_002545
		sar esi,1
		cmp edx,byte +0x3b
		jc JUMP_002545
		sar esi,1
	JUMP_002545:			; Pos = 292c5
		cmp dword [ebp+0x10],byte +0x0
		jz JUMP_002547
		cmp eax,0x7fff
		jl JUMP_002546
		mov eax,0x7fff
	JUMP_002546:			; Pos = 292d7
		movsx edx,word [ebx+0x110]
		imul edx,eax
		sar edx,0x10
		add [ebx+0xb0],dx
		movsx edx,word [ebx+0x112]
		imul edx,eax
		sar edx,0x10
		add [ebx+0xb2],dx
		movsx edx,word [ebx+0x114]
		imul edx,eax
		sar edx,0x10
		add [ebx+0xb4],dx
	JUMP_002547:			; Pos = 29313
		cmp esi,0x7fff
		jl JUMP_002548
		mov esi,0x7fff
	JUMP_002548:			; Pos = 29320
		movsx eax,word [ebx+0xb0]
		mov [edi],eax
		cmp dword [edi],byte +0x0
		jl JUMP_002550
		cmp esi,[edi]
		jnl JUMP_002549
		mov [edi],esi
	JUMP_002549:			; Pos = 29334
		cmp dword [edi],byte +0xf
		jl JUMP_002552
		lea eax,[ebp-0x8]
		push eax
		push edi
		call FUNC_000584
		add esp,byte +0x8
		mov ax,[edi]
		sub [ebx+0xb0],ax
		mov eax,[ebp-0x8]
		push eax
		push byte +0x70
		lea eax,[ebx+0xc]
		push eax
		lea eax,[ebx+0x18]
		push eax
		push ebx
		call FUNC_000611
		add esp,byte +0x14
		jmp short JUMP_002552
	JUMP_002550:			; Pos = 29369
		neg dword [edi]
		cmp esi,[edi]
		jnl JUMP_002551
		mov [edi],esi
	JUMP_002551:			; Pos = 29371
		cmp dword [edi],byte +0xf
		jl JUMP_002552
		lea eax,[ebp-0x8]
		push eax
		push edi
		call FUNC_000584
		add esp,byte +0x8
		mov ax,[edi]
		add [ebx+0xb0],ax
		mov eax,[ebp-0x8]
		push eax
		push byte +0x6d
		lea eax,[ebx+0xc]
		push eax
		lea eax,[ebx+0x18]
		push eax
		push ebx
		call FUNC_000611
		add esp,byte +0x14
	JUMP_002552:			; Pos = 293a4
		movsx eax,word [ebx+0xb2]
		mov [edi],eax
		cmp dword [edi],byte +0x0
		jl JUMP_002554
		cmp esi,[edi]
		jnl JUMP_002553
		mov [edi],esi
	JUMP_002553:			; Pos = 293b8
		cmp dword [edi],byte +0xf
		jl JUMP_002556
		lea eax,[ebp-0x8]
		push eax
		push edi
		call FUNC_000584
		add esp,byte +0x8
		mov ax,[edi]
		sub [ebx+0xb2],ax
		mov eax,[ebp-0x8]
		push eax
		push byte +0x70
		push ebx
		lea eax,[ebx+0xc]
		push eax
		push ebx
		call FUNC_000611
		add esp,byte +0x14
		jmp short JUMP_002556
	JUMP_002554:			; Pos = 293ea
		neg dword [edi]
		cmp esi,[edi]
		jnl JUMP_002555
		mov [edi],esi
	JUMP_002555:			; Pos = 293f2
		cmp dword [edi],byte +0xf
		jl JUMP_002556
		lea eax,[ebp-0x8]
		push eax
		push edi
		call FUNC_000584
		add esp,byte +0x8
		mov ax,[edi]
		add [ebx+0xb2],ax
		mov eax,[ebp-0x8]
		push eax
		push byte +0x6d
		push ebx
		lea eax,[ebx+0xc]
		push eax
		push ebx
		call FUNC_000611
		add esp,byte +0x14
	JUMP_002556:			; Pos = 29422
		movsx eax,word [ebx+0xb4]
		mov [edi],eax
		cmp dword [edi],byte +0x0
		jl JUMP_002558
		cmp esi,[edi]
		jnl JUMP_002557
		mov [edi],esi
	JUMP_002557:			; Pos = 29436
		cmp dword [edi],byte +0xf
		jl near JUMP_002560
		lea eax,[ebp-0x8]
		push eax
		push edi
		call FUNC_000584
		add esp,byte +0x8
		mov ax,[edi]
		sub [ebx+0xb4],ax
		mov eax,[ebp-0x8]
		push eax
		push byte +0x70
		lea eax,[ebx+0x18]
		push eax
		push ebx
		push ebx
		call FUNC_000611
		add esp,byte +0x14
		xor eax,eax
		mov al,[ebx+0x86]
		cmp eax,[DATA_008857]
		jnz JUMP_002560
		mov ax,[edi]
		sub [DATA_008933],ax
		jmp short JUMP_002560
	JUMP_002558:			; Pos = 29486
		neg dword [edi]
		cmp esi,[edi]
		jnl JUMP_002559
		mov [edi],esi
	JUMP_002559:			; Pos = 2948e
		cmp dword [edi],byte +0xf
		jl JUMP_002560
		lea eax,[ebp-0x8]
		push eax
		push edi
		call FUNC_000584
		add esp,byte +0x8
		mov ax,[edi]
		add [ebx+0xb4],ax
		mov eax,[ebp-0x8]
		push eax
		push byte +0x6d
		lea eax,[ebx+0x18]
		push eax
		push ebx
		push ebx
		call FUNC_000611
		add esp,byte +0x14
		xor eax,eax
		mov al,[ebx+0x86]
		cmp eax,[DATA_008857]
		jnz JUMP_002560
		mov ax,[edi]
		add [DATA_008933],ax
	JUMP_002560:			; Pos = 294d8
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_000584:			; Pos = 291f0

		push ebp
		mov ebp,esp
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		cmp dword [eax],0x9fb
		jl JUMP_002538
		mov dword [edx],0x2
		mov dword [eax],0x9fb
		pop ebp
		ret
	JUMP_002538:			; Pos = 2920f
		cmp dword [eax],0x511
		jl JUMP_002539
		mov dword [edx],0x3
		mov dword [eax],0x511
		pop ebp
		ret
	JUMP_002539:			; Pos = 29225
		cmp dword [eax],0x28b
		jl JUMP_002540
		mov dword [edx],0x4
		mov dword [eax],0x28b
		pop ebp
		ret
	JUMP_002540:			; Pos = 2923b
		cmp dword [eax],0x146
		jl JUMP_002541
		mov dword [edx],0x5
		mov dword [eax],0x146
		pop ebp
		ret
	JUMP_002541:			; Pos = 29251
		cmp dword [eax],0xa3
		jl JUMP_002542
		mov dword [edx],0x6
		mov dword [eax],0xa3
		pop ebp
		ret
	JUMP_002542:			; Pos = 29267
		cmp dword [eax],byte +0x52
		jl JUMP_002543
		mov dword [edx],0x7
		mov dword [eax],0x52
		pop ebp
		ret
	JUMP_002543:			; Pos = 2927a
		cmp dword [eax],byte +0x29
		jl JUMP_002544
		mov dword [edx],0x8
		mov dword [eax],0x29
		pop ebp
		ret
	JUMP_002544:			; Pos = 2928d
		mov dword [edx],0x9
		mov dword [eax],0x14
		pop ebp
		ret
		nop




FUNC_000611:			; Pos = 2b1c4

		push ebp
		mov ebp,esp
		add esp,byte -0x24
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x18]
		mov eax,[ebp+0x10]
		mov edx,[ebp+0xc]
		mov ecx,[DATA_006159]
		mov [ebp-0xc],ecx
		mov ecx,[DATA_006160]
		mov [ebp-0x8],ecx
		mov cx,[DATA_006161]
		mov [ebp-0x4],cx
		cmp ebx,byte +0x5
		jg JUMP_002690
		mov esi,ebx
		add esi,esi
		inc esi
		mov ecx,esi
		mov edi,[edx]
		sar edi,cl
		sub [edx],edi
		mov ecx,esi
		mov edi,[edx+0x4]
		sar edi,cl
		sub [edx+0x4],edi
		mov ecx,esi
		mov edi,[edx+0x8]
		sar edi,cl
		sub [edx+0x8],edi
		mov ecx,esi
		mov edi,[eax]
		sar edi,cl
		sub [eax],edi
		mov ecx,esi
		mov edi,[eax+0x4]
		sar edi,cl
		sub [eax+0x4],edi
		mov ecx,esi
		mov esi,[eax+0x8]
		sar esi,cl
		sub [eax+0x8],esi
	JUMP_002690:			; Pos = 2b235
		cmp byte [ebp+0x14],0x70
		jnz JUMP_002691
		mov ecx,ebx
		mov esi,[edx]
		sar esi,cl
		add esi,[eax]
		mov [ebp-0x18],esi
		mov ecx,ebx
		mov esi,[edx+0x4]
		sar esi,cl
		add esi,[eax+0x4]
		mov [ebp-0x14],esi
		mov ecx,ebx
		mov esi,[edx+0x8]
		sar esi,cl
		add esi,[eax+0x8]
		mov [ebp-0x10],esi
		jmp short JUMP_002692
	JUMP_002691:			; Pos = 2b262
		mov ecx,ebx
		mov esi,[edx]
		sar esi,cl
		mov ecx,[eax]
		sub ecx,esi
		mov [ebp-0x18],ecx
		mov ecx,ebx
		mov esi,[edx+0x4]
		sar esi,cl
		mov ecx,[eax+0x4]
		sub ecx,esi
		mov [ebp-0x14],ecx
		mov ecx,ebx
		mov esi,[edx+0x8]
		sar esi,cl
		mov ecx,[eax+0x8]
		sub ecx,esi
		mov [ebp-0x10],ecx
	JUMP_002692:			; Pos = 2b28d
		mov ecx,ebx
		mov esi,[eax]
		sar esi,cl
		mov [ebp-0x24],esi
		mov ecx,ebx
		mov esi,[eax+0x4]
		sar esi,cl
		mov [ebp-0x20],esi
		mov ecx,ebx
		mov esi,[eax+0x8]
		sar esi,cl
		mov [ebp-0x1c],esi
		mov ecx,[ebp-0x18]
		mov [eax],ecx
		mov ecx,[ebp-0x14]
		mov [eax+0x4],ecx
		mov ecx,[ebp-0x10]
		mov [eax+0x8],ecx
		cmp byte [ebp+0x14],0x70
		jnz JUMP_002693
		mov eax,[ebp-0x24]
		sub [edx],eax
		mov eax,[ebp-0x20]
		sub [edx+0x4],eax
		mov eax,[ebp-0x1c]
		sub [edx+0x8],eax
		jmp short JUMP_002694
	JUMP_002693:			; Pos = 2b2d4
		mov eax,[ebp-0x24]
		add [edx],eax
		mov eax,[ebp-0x20]
		add [edx+0x4],eax
		mov eax,[ebp-0x1c]
		add [edx+0x8],eax
	JUMP_002694:			; Pos = 2b2e5
		mov al,[ebp+ebx-0xe]
		mov edx,[ebp+0x8]
		sub [edx+0x24],al
		mov eax,[ebp+0x8]
		cmp byte [eax+0x24],0x0
		jnl JUMP_002695
		mov eax,[ebp+0x8]
		push eax
		call near [DATA_007719]    ; FUNC_001520
		pop ecx
		mov eax,[ebp+0x8]
		mov byte [eax+0x24],0x3c
	JUMP_002695:			; Pos = 2b30a
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000609:			; Pos = 2adac

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,[eax]
		sar edx,0x10
		imul edx,[DATA_008708]
		mov ecx,[eax+0x4]
		sar ecx,0x10
		imul ecx,[DATA_008709]
		add edx,ecx
		mov ecx,[eax+0x8]
		sar ecx,0x10
		imul ecx,[DATA_008710]
		add edx,ecx
		sar edx,0x12
		neg dx
		mov [eax+0x112],dx
		pop ebp
		ret




FUNC_001520:			; Pos = 5375a

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		push ebx
		push ebx
		call FUNC_001519
		add esp,byte +0x8
		lea eax,[ebx+0x18]
		push eax
		lea eax,[ebx+0x18]
		push eax
		call FUNC_001519
		add esp,byte +0x8
		push ebx
		lea eax,[ebx+0x18]
		push eax
		lea eax,[ebx+0xc]
		push eax
		call FUNC_001552
		add esp,byte +0xc
		lea eax,[ebx+0xc]
		push eax
		lea eax,[ebx+0xc]
		push eax
		call FUNC_001519
		add esp,byte +0x8
		lea eax,[ebx+0x18]
		push eax
		lea eax,[ebx+0xc]
		push eax
		push ebx
		call FUNC_001552
		add esp,byte +0xc
		pop ebx
		pop ebp
		ret




FUNC_001519:			; Pos = 536d2

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edi,[ebp+0xc]
		push edi
		call FUNC_001466
		pop ecx
		mov ebx,eax
		inc ebx
		push ebx
		call FUNC_001656_FindMSB
		pop ecx
		mov esi,0x1f
		sub esi,eax
		mov ecx,esi
		shl ebx,cl
		shr ebx,1
		push ebx
		push dword 0x3f800000
		call FUNC_001523
		add esp,byte +0x8
		shr eax,1
		mov ebx,eax
		mov eax,ebx
		dec eax
		push eax
		push dword [edi]
		call FUNC_001521
		add esp,byte +0x8
		lea ecx,[esi+0x1]
		shl eax,cl
		mov edx,[ebp+0x8]
		mov [edx],eax
		mov eax,ebx
		dec eax
		push eax
		push dword [edi+0x4]
		call FUNC_001521
		add esp,byte +0x8
		lea ecx,[esi+0x1]
		shl eax,cl
		mov edx,[ebp+0x8]
		mov [edx+0x4],eax
		dec ebx
		push ebx
		push dword [edi+0x8]
		call FUNC_001521
		add esp,byte +0x8
		lea ecx,[esi+0x1]
		shl eax,cl
		mov edx,[ebp+0x8]
		mov [edx+0x8],eax
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001552:			; Pos = 54660

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov edx,[ebp+0x10]
		mov eax,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov esi,[eax]
		mov edi,[eax+0x4]
		mov eax,[eax+0x8]
		mov [ebp-0x4],eax
		mov eax,[edx]
		mov [ebp-0x8],eax
		mov eax,[edx+0x4]
		mov [ebp-0xc],eax
		mov eax,[edx+0x8]
		mov [ebp-0x10],eax

		mov eax,[ebp-0x10]
		push eax
		push edi
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[ebp-0xc]
		push eax
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		sub edx,eax
		mov [ebx],edx

		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[ebp-0x10]
		push eax
		push esi
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		sub edx,eax
		mov [ebx+0x4],edx

		mov eax,[ebp-0xc]
		push eax
		push esi
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[ebp-0x8]
		push eax
		push edi
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		sub edx,eax
		mov [ebx+0x8],edx

		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001466:			; Pos = 5122f

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		lea esi,[ebp-0xc]
		push dword [ebx]
		call _abs
		pop ecx
		mov [esi],eax
		push dword [ebx+0x4]
		call _abs
		pop ecx
		mov [esi+0x4],eax
		push dword [ebx+0x8]
		call _abs
		pop ecx
		mov [esi+0x8],eax
		mov eax,[esi]
		mov [ebp-0x18],eax
		mov eax,[esi+0x4]
		mov [ebp-0x14],eax
		mov eax,[esi+0x8]
		mov [ebp-0x10],eax
		mov eax,[esi]
		or eax,[esi+0x4]
		or eax,[esi+0x8]
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		mov ebx,0x1e
		sub ebx,eax
		mov ecx,ebx
		shl dword [esi],cl
		mov ecx,ebx
		shl dword [esi+0x4],cl
		mov ecx,ebx
		shl dword [esi+0x8],cl
		test ebx,ebx
		jng JUMP_005489
		push dword [esi]
		push dword [esi]
		call FUNC_001521
		add esp,byte +0x8
		mov edi,eax
		sar edi,0x2
		push dword [esi+0x4]
		push dword [esi+0x4]
		call FUNC_001521
		add esp,byte +0x8
		sar eax,0x2
		add edi,eax
		push dword [esi+0x8]
		push dword [esi+0x8]
		call FUNC_001521
		add esp,byte +0x8
		sar eax,0x2
		add edi,eax
		push edi
		call near [DATA_007738]    ; FUNC_001502
		pop ecx
		lea ecx,[ebx-0x1]
		shr eax,cl
		jmp short JUMP_005490
	JUMP_005489:			; Pos = 512df
		push dword [esi]
		push dword [esi]
		call FUNC_001521
		add esp,byte +0x8
		mov ebx,eax
		sar ebx,0x2
		push dword [esi+0x4]
		push dword [esi+0x4]
		call FUNC_001521
		add esp,byte +0x8
		sar eax,0x2
		add ebx,eax
		push dword [esi+0x8]
		push dword [esi+0x8]
		call FUNC_001521
		add esp,byte +0x8
		sar eax,0x2
		add ebx,eax
		push ebx
		call near [DATA_007738]    ; FUNC_001502
		pop ecx
		add eax,eax
	JUMP_005490:			; Pos = 51320
		cmp eax,[ebp-0x18]
		jnc JUMP_005491
		mov eax,[ebp-0x18]
	JUMP_005491:			; Pos = 51328
		cmp eax,[ebp-0x14]
		jnc JUMP_005492
		mov eax,[ebp-0x14]
	JUMP_005492:			; Pos = 51330
		cmp eax,[ebp-0x10]
		jnc JUMP_005493
		mov eax,[ebp-0x10]
	JUMP_005493:			; Pos = 51338
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




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




FUNC_001523:			; Pos = 537cd

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		shr eax,1
		cmp eax,[ebp+0xc]
		jc JUMP_005691
		or eax,byte -0x1
		pop ebp
		ret
	JUMP_005691:			; Pos = 537df
		mov edx,[ebp+0x8]
		mov eax,edx
		shr edx,1
		shl eax,0x1f
		div dword [ebp+0xc]
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




FUNC_001502:			; Pos = 52e37

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
		xor eax,eax
		mov edx,0x80000000
		cmp edx,[ebp+0x8]
		jna JUMP_005673
	JUMP_005672:			; Pos = 52e49
		inc eax
		shr edx,0x2
		cmp edx,[ebp+0x8]
		ja JUMP_005672
	JUMP_005673:			; Pos = 52e52
		xor edx,edx
		mov [ebp-0x4],edx
		xor edx,edx
		cmp eax,byte +0xf
		jg JUMP_005676
	JUMP_005674:			; Pos = 52e5e
		lea ecx,[eax-0x1]
		mov ebx,[ebp-0x4]
		shr ebx,cl
		add ebx,edx
		mov ecx,eax
		add ecx,ecx
		mov esi,0x80000000
		shr esi,cl
		add ebx,esi
		mov ecx,ebx
		cmp ecx,[ebp+0x8]
		ja JUMP_005675
		mov edx,ecx
		mov ecx,eax
		mov ebx,0x80000000
		shr ebx,cl
		add [ebp-0x4],ebx
	JUMP_005675:			; Pos = 52e8a
		inc eax
		cmp eax,byte +0xf
		jng JUMP_005674
	JUMP_005676:			; Pos = 52e90
		cmp eax,byte +0x1f
		jg JUMP_005679
	JUMP_005677:			; Pos = 52e95
		lea ecx,[eax-0x1]
		mov ebx,[ebp-0x4]
		shr ebx,cl
		mov ecx,ebx
		add ecx,edx
		cmp ecx,[ebp+0x8]
		ja JUMP_005678
		mov edx,ecx
		mov ecx,eax
		mov ebx,0x80000000
		shr ebx,cl
		add [ebp-0x4],ebx
	JUMP_005678:			; Pos = 52eb4
		inc eax
		cmp eax,byte +0x1f
		jng JUMP_005677
	JUMP_005679:			; Pos = 52eba
		mov eax,[ebp-0x4]
		pop esi
		pop ebx
		pop ecx
		pop ebp
		ret




FUNC_000603:			; Pos = 2a718

		push ebp
		mov ebp,esp
		add esp,byte -0x38
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x10]
		mov esi,[ebp+0x8]
		mov al,[esi+0x56]
		test al,al
		jz near JUMP_002662
		mov edx,[ebp+0xc]
		push edx
		and eax,0xff
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov edi,eax
		cmp word [edi+0xa4],byte +0x0
		jz near JUMP_002662
		push esi
		push edi
		add esi,byte +0x3e
		lea edi,[ebp-0x2c]
		mov ecx,0x6
		rep movsd
		pop edi
		pop esi
		push byte +0xd
		lea eax,[ebp-0x2c]
		push eax
		call FUNC_001658_Vec64Truncate
		add esp,byte +0x8
		mov [ebp-0x14],eax
		mov eax,[ebp-0x2c]
		mov [ebp-0x38],eax
		mov eax,[ebp-0x24]
		mov [ebp-0x34],eax
		mov eax,[ebp-0x1c]
		mov [ebp-0x30],eax
		mov eax,[ebp-0x38]
		mov [DATA_008708],eax
		mov eax,[ebp-0x34]
		mov [DATA_008709],eax
		mov eax,[ebp-0x30]
		mov [DATA_008710],eax
		lea eax,[ebp-0x38]
		push eax
		call FUNC_001466
		pop ecx
		mov [ebp-0x4],ax
		mov ax,[ebp-0x14]
		mov [ebp-0x2],ax
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_007722]    ; FUNC_001496
		pop ecx
		mov [ebp-0x4],eax
		cmp word [ebp-0x4],byte +0x0
		jz near JUMP_002662
		mov eax,[ebp-0x4]
		push eax
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001482
		add esp,byte +0x8
		mov [ebp-0x10],eax
		movsx eax,word [ebp-0x4]
		movsx edx,word [ebp-0x10]
		imul edx
		sar eax,0xf
		mov [ebp-0x8],ax
		mov ax,[ebp-0xe]
		mov [ebp-0x6],ax
		mov eax,[ebp-0x8]
		push eax
		call near [DATA_007722]    ; FUNC_001496
		pop ecx
		push eax
		mov eax,[edi+0xa4]
		push eax
		call near [DATA_007731]    ; FUNC_001483
		add esp,byte +0x8
		mov [ebp-0x8],eax
		test ebx,ebx
		jnl JUMP_002656
		cmp ebx,0xffff8001
		jnl JUMP_002658
	JUMP_002655:			; Pos = 2a82a
		inc word [ebp-0x6]
		sar ebx,1
		cmp ebx,0xffff8001
		jl JUMP_002655
		jmp short JUMP_002658
	JUMP_002656:			; Pos = 2a83a
		cmp ebx,0x7fff
		jng JUMP_002658
	JUMP_002657:			; Pos = 2a842
		inc word [ebp-0x6]
		sar ebx,1
		cmp ebx,0x7fff
		jg JUMP_002657
	JUMP_002658:			; Pos = 2a850
		movsx eax,word [ebp-0x8]
		imul ebx
		sar eax,0xf
		neg eax
		mov edx,eax
		imul edx,[ebp-0x38]
		mov [ebp-0x38],edx
		mov edx,eax
		imul edx,[ebp-0x34]
		mov [ebp-0x34],edx
		imul eax,[ebp-0x30]
		mov [ebp-0x30],eax
		mov ax,[ebp-0x6]
		test ax,ax
		jg near JUMP_002660
		cmp ax,byte -0x20
		jng near JUMP_002662
		test ax,ax
		jz JUMP_002659
		movsx edx,ax
		neg edx
		mov ecx,edx
		sar dword [ebp-0x38],cl
		movsx eax,word [ebp-0x6]
		neg eax
		mov ecx,edx
		sar dword [ebp-0x34],cl
		movsx eax,word [ebp-0x6]
		neg eax
		mov ecx,edx
		sar dword [ebp-0x30],cl
	JUMP_002659:			; Pos = 2a8b0
		movzx eax,word [esi+0xec]
		add eax,[ebp-0x38]
		mov edx,eax
		and dx,0xffff
		mov [esi+0xec],dx
		sar eax,0x10
		add [esi+0x8c],eax
		movzx eax,word [esi+0xee]
		add eax,[ebp-0x34]
		mov edx,eax
		and dx,0xffff
		mov [esi+0xee],dx
		sar eax,0x10
		add [esi+0x90],eax
		movzx eax,word [esi+0xf0]
		add eax,[ebp-0x30]
		mov edx,eax
		and dx,0xffff
		mov [esi+0xf0],dx
		sar eax,0x10
		add [esi+0x94],eax
		jmp short JUMP_002662
	JUMP_002660:			; Pos = 2a915
		add word [ebp-0x6],byte -0x10
		mov dx,[ebp-0x6]
		test dx,dx
		jnl JUMP_002661
		movsx eax,dx
		neg eax
		mov ecx,eax
		sar dword [ebp-0x38],cl
		movsx edx,word [ebp-0x6]
		neg edx
		mov ecx,eax
		sar dword [ebp-0x34],cl
		movsx edx,word [ebp-0x6]
		neg edx
		mov ecx,eax
		sar dword [ebp-0x30],cl
	JUMP_002661:			; Pos = 2a943
		mov eax,[ebp-0x38]
		add [esi+0x8c],eax
		mov eax,[ebp-0x34]
		add [esi+0x90],eax
		mov eax,[ebp-0x30]
		add [esi+0x94],eax
	JUMP_002662:			; Pos = 2a95e
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000599:			; Pos = 2a060

		push ebp
		mov ebp,esp
		push ebx
		mov eax,[ebp+0x8]
		mov edx,[ebp+0x10]
		mov ecx,[ebp+0xc]
		mov ebx,[ecx]
		mov [edx],ebx
		mov ebx,[ecx+0x4]
		mov [edx+0x4],ebx
		mov ebx,[ecx+0x8]
		mov [edx+0x8],ebx
		movsx edx,word [eax+0xbc]
		movsx ecx,word [eax+0xbe]
		mov ebx,[ebp+0xc]
		cmp edx,[ebx]
		jnl JUMP_002604
		mov ebx,[ebp+0x10]
		mov [ebx],edx
	JUMP_002604:			; Pos = 2a097
		mov edx,[ebp+0xc]
		cmp ecx,[edx]
		jng JUMP_002605
		mov edx,[ebp+0x10]
		mov [edx],ecx
	JUMP_002605:			; Pos = 2a0a3
		movsx edx,word [eax+0xc0]
		movsx ecx,word [eax+0xc2]
		mov ebx,[ebp+0xc]
		cmp edx,[ebx+0x4]
		jnl JUMP_002606
		mov ebx,[ebp+0x10]
		mov [ebx+0x4],edx
	JUMP_002606:			; Pos = 2a0bf
		mov edx,[ebp+0xc]
		cmp ecx,[edx+0x4]
		jng JUMP_002607
		mov edx,[ebp+0x10]
		mov [edx+0x4],ecx
	JUMP_002607:			; Pos = 2a0cd
		movsx edx,word [eax+0xc4]
		movsx ecx,word [eax+0xc6]
		mov ebx,[ebp+0xc]
		cmp edx,[ebx+0x8]
		jnl JUMP_002608
		mov ebx,[ebp+0x10]
		mov [ebx+0x8],edx
	JUMP_002608:			; Pos = 2a0e9
		mov edx,[ebp+0xc]
		cmp ecx,[edx+0x8]
		jng JUMP_002609
		mov edx,[ebp+0x10]
		mov [edx+0x8],ecx
	JUMP_002609:			; Pos = 2a0f7
		mov edx,[ebp+0x10]
		mov dx,[edx]
		mov [eax+0xb6],dx
		mov edx,[ebp+0x10]
		mov dx,[edx+0x4]
		mov [eax+0xb8],dx
		mov edx,[ebp+0x10]
		mov dx,[edx+0x8]
		mov [eax+0xba],dx
		pop ebx
		pop ebp
		ret




FUNC_000607:			; Pos = 2ac84

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov edi,[ebp+0x10]
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov eax,esi
		mov ecx,0x64
		cdq
		idiv ecx
		add esi,eax
		test esi,esi
		jnl JUMP_002671
		neg esi
		mov eax,[ebx+0x18]
		sar eax,0x10
		push eax
		push esi
		call near [DATA_007748]    ; FUNC_001516
		add esp,byte +0x8
		neg eax
		mov [ebp-0xc],eax
		mov eax,[ebx+0x1c]
		sar eax,0x10
		push eax
		push esi
		call near [DATA_007748]    ; FUNC_001516
		add esp,byte +0x8
		neg eax
		mov [ebp-0x8],eax
		mov eax,[ebx+0x20]
		sar eax,0x10
		push eax
		push esi
		call near [DATA_007748]    ; FUNC_001516
		add esp,byte +0x8
		neg eax
		mov [ebp-0x4],eax
		jmp short JUMP_002672
	JUMP_002671:			; Pos = 2acec
		mov eax,[ebx+0x18]
		sar eax,0x10
		push eax
		push esi
		call near [DATA_007748]    ; FUNC_001516
		add esp,byte +0x8
		mov [ebp-0xc],eax
		mov eax,[ebx+0x1c]
		sar eax,0x10
		push eax
		push esi
		call near [DATA_007748]    ; FUNC_001516
		add esp,byte +0x8
		mov [ebp-0x8],eax
		mov eax,[ebx+0x20]
		sar eax,0x10
		push eax
		push esi
		call near [DATA_007748]    ; FUNC_001516
		add esp,byte +0x8
		mov [ebp-0x4],eax
	JUMP_002672:			; Pos = 2ad28
		mov eax,[ebx+0x8c]
		sub [ebp-0xc],eax
		mov eax,[ebx+0x90]
		sub [ebp-0x8],eax
		mov eax,[ebx+0x94]
		sub [ebp-0x4],eax
		mov eax,[ebp-0xc]
		mov [ebx+0xf2],eax
		mov eax,[ebp-0x8]
		mov [ebx+0xf6],eax
		mov eax,[ebp-0x4]
		mov [ebx+0xfa],eax
		push ebx
		lea eax,[ebp-0xc]
		push eax
		push edi
		call FUNC_001670_VecMatTMul
		add esp,byte +0xc
		shl dword [edi],0x2
		shl dword [edi+0x4],0x2
		shl dword [edi+0x8],0x2
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000601:			; Pos = 2a254

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		lea edi,[ebp-0xc]
		shr edx,0x3
		or esi,byte -0x1
		cmp edx,0x7fff
		jng JUMP_002617
		mov esi,0x10
		cmp edx,0x7fff
		jng JUMP_002617
	JUMP_002616:			; Pos = 2a281
		shr edx,1
		dec esi
		cmp edx,0x7fff
		jg JUMP_002616
	JUMP_002617:			; Pos = 2a28c
		xor ecx,ecx
		mov [edi],ecx
		xor ecx,ecx
		mov [edi+0x4],ecx
		xor ecx,ecx
		mov [edi+0x8],ecx
		movsx ecx,word [eax+0xb6]
		test ecx,ecx
		jz JUMP_002618
		mov ebx,[eax]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		mov [edi],ebx
		mov ebx,[eax+0x4]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		mov [edi+0x4],ebx
		mov ebx,[eax+0x8]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		mov [edi+0x8],ebx
	JUMP_002618:			; Pos = 2a2d9
		movsx ecx,word [eax+0xb8]
		test ecx,ecx
		jz JUMP_002619
		mov ebx,[eax+0xc]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi],ebx
		mov ebx,[eax+0x10]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x4],ebx
		mov ebx,[eax+0x14]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x8],ebx
	JUMP_002619:			; Pos = 2a319
		movsx ecx,word [eax+0xba]
		test ecx,ecx
		jz JUMP_002620
		mov ebx,[eax+0x18]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi],ebx
		mov ebx,[eax+0x1c]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x4],ebx
		mov ebx,[eax+0x20]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x8],ebx
	JUMP_002620:			; Pos = 2a359
		shl dword [edi],1
		shl dword [edi+0x4],1
		shl dword [edi+0x8],1
		test esi,esi
		jnl near JUMP_002634
		cmp edx,0x4014
		jnl JUMP_002621
		movzx ecx,word [eax+0xec]
		add ecx,[edi]
		mov edx,ecx
		and dx,0xffff
		mov [eax+0xec],dx
		sar ecx,0x10
		add [eax+0x8c],ecx
		movzx ecx,word [eax+0xee]
		add ecx,[edi+0x4]
		mov edx,ecx
		and dx,0xffff
		mov [eax+0xee],dx
		sar ecx,0x10
		add [eax+0x90],ecx
		movzx ecx,word [eax+0xf0]
		add ecx,[edi+0x8]
		mov edx,ecx
		and dx,0xffff
		mov [eax+0xf0],dx
		sar ecx,0x10
		add [eax+0x94],ecx
		jmp JUMP_002647
	JUMP_002621:			; Pos = 2a3d8
		movzx ecx,word [eax+0xec]
		add ecx,[edi]
		mov edx,ecx
		and dx,0xffff
		mov [eax+0xec],dx
		mov edx,[eax+0xf2]
		sar ecx,0x10
		test edx,edx
		jl JUMP_002623
		cmp edx,ecx
		jnl JUMP_002622
		mov ecx,edx
	JUMP_002622:			; Pos = 2a402
		test ecx,ecx
		jnl JUMP_002623
		xor ecx,ecx
	JUMP_002623:			; Pos = 2a408
		test edx,edx
		jnl JUMP_002625
		cmp edx,ecx
		jng JUMP_002624
		mov ecx,edx
	JUMP_002624:			; Pos = 2a412
		test ecx,ecx
		jng JUMP_002625
		xor ecx,ecx
	JUMP_002625:			; Pos = 2a418
		add [eax+0x8c],ecx
		movzx ecx,word [eax+0xee]
		add ecx,[edi+0x4]
		mov edx,ecx
		and dx,0xffff
		mov [eax+0xee],dx
		mov edx,[eax+0xf6]
		sar ecx,0x10
		test edx,edx
		jl JUMP_002627
		cmp edx,ecx
		jnl JUMP_002626
		mov ecx,edx
	JUMP_002626:			; Pos = 2a449
		test ecx,ecx
		jnl JUMP_002627
		xor ecx,ecx
	JUMP_002627:			; Pos = 2a44f
		test edx,edx
		jnl JUMP_002629
		cmp edx,ecx
		jng JUMP_002628
		mov ecx,edx
	JUMP_002628:			; Pos = 2a459
		test ecx,ecx
		jng JUMP_002629
		xor ecx,ecx
	JUMP_002629:			; Pos = 2a45f
		add [eax+0x90],ecx
		movzx ecx,word [eax+0xf0]
		add ecx,[edi+0x8]
		mov edx,ecx
		and dx,0xffff
		mov [eax+0xf0],dx
		mov edx,[eax+0xfa]
		sar ecx,0x10
		test edx,edx
		jl JUMP_002631
		cmp edx,ecx
		jnl JUMP_002630
		mov ecx,edx
	JUMP_002630:			; Pos = 2a490
		test ecx,ecx
		jnl JUMP_002631
		xor ecx,ecx
	JUMP_002631:			; Pos = 2a496
		test edx,edx
		jnl JUMP_002633
		cmp edx,ecx
		jng JUMP_002632
		mov ecx,edx
	JUMP_002632:			; Pos = 2a4a0
		test ecx,ecx
		jng JUMP_002633
		xor ecx,ecx
	JUMP_002633:			; Pos = 2a4a6
		add [eax+0x94],ecx
		jmp JUMP_002647
	JUMP_002634:			; Pos = 2a4b1
		mov ecx,esi
		sar dword [edi],cl
		mov ecx,esi
		sar dword [edi+0x4],cl
		mov ecx,esi
		sar dword [edi+0x8],cl
		mov edx,[eax+0xf2]
		test edx,edx
		jl JUMP_002636
		cmp edx,[edi]
		jnl JUMP_002635
		mov [edi],edx
	JUMP_002635:			; Pos = 2a4cf
		cmp dword [edi],byte +0x0
		jnl JUMP_002636
		xor ecx,ecx
		mov [edi],ecx
	JUMP_002636:			; Pos = 2a4d8
		test edx,edx
		jnl JUMP_002638
		cmp edx,[edi]
		jng JUMP_002637
		mov [edi],edx
	JUMP_002637:			; Pos = 2a4e2
		cmp dword [edi],byte +0x0
		jng JUMP_002638
		xor edx,edx
		mov [edi],edx
	JUMP_002638:			; Pos = 2a4eb
		mov edx,[eax+0xf6]
		test edx,edx
		jl JUMP_002640
		cmp edx,[edi+0x4]
		jnl JUMP_002639
		mov [edi+0x4],edx
	JUMP_002639:			; Pos = 2a4fd
		cmp dword [edi+0x4],byte +0x0
		jnl JUMP_002640
		xor ecx,ecx
		mov [edi+0x4],ecx
	JUMP_002640:			; Pos = 2a508
		test edx,edx
		jnl JUMP_002642
		cmp edx,[edi+0x4]
		jng JUMP_002641
		mov [edi+0x4],edx
	JUMP_002641:			; Pos = 2a514
		cmp dword [edi+0x4],byte +0x0
		jng JUMP_002642
		xor edx,edx
		mov [edi+0x4],edx
	JUMP_002642:			; Pos = 2a51f
		mov edx,[eax+0xfa]
		test edx,edx
		jl JUMP_002644
		cmp edx,[edi+0x8]
		jnl JUMP_002643
		mov [edi+0x8],edx
	JUMP_002643:			; Pos = 2a531
		cmp dword [edi+0x8],byte +0x0
		jnl JUMP_002644
		xor ecx,ecx
		mov [edi+0x8],ecx
	JUMP_002644:			; Pos = 2a53c
		test edx,edx
		jnl JUMP_002646
		cmp edx,[edi+0x8]
		jng JUMP_002645
		mov [edi+0x8],edx
	JUMP_002645:			; Pos = 2a548
		cmp dword [edi+0x8],byte +0x0
		jng JUMP_002646
		xor edx,edx
		mov [edi+0x8],edx
	JUMP_002646:			; Pos = 2a553
		mov edx,[edi]
		add [eax+0x8c],edx
		mov edx,[edi+0x4]
		add [eax+0x90],edx
		mov edx,[edi+0x8]
		add [eax+0x94],edx
	JUMP_002647:			; Pos = 2a56d
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000602:			; Pos = 2a574

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		lea edi,[ebp-0xc]
		sar edx,0x3
		or esi,byte -0x1
		cmp edx,0x7fff
		jng JUMP_002649
		mov esi,0xf
		cmp edx,0x7fff
		jng JUMP_002649
	JUMP_002648:			; Pos = 2a5a1
		sar edx,1
		dec esi
		cmp edx,0x7fff
		jg JUMP_002648
	JUMP_002649:			; Pos = 2a5ac
		xor ecx,ecx
		mov [edi],ecx
		xor ecx,ecx
		mov [edi+0x4],ecx
		xor ecx,ecx
		mov [edi+0x8],ecx
		movsx ecx,word [eax+0xb6]
		test ecx,ecx
		jz JUMP_002650
		mov ebx,[eax]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		mov [edi],ebx
		mov ebx,[eax+0x4]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		mov [edi+0x4],ebx
		mov ebx,[eax+0x8]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		mov [edi+0x8],ebx
	JUMP_002650:			; Pos = 2a5f9
		movsx ecx,word [eax+0xb8]
		test ecx,ecx
		jz JUMP_002651
		mov ebx,[eax+0xc]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi],ebx
		mov ebx,[eax+0x10]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x4],ebx
		mov ebx,[eax+0x14]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x8],ebx
	JUMP_002651:			; Pos = 2a639
		movsx ecx,word [eax+0xba]
		test ecx,ecx
		jz JUMP_002652
		mov ebx,[eax+0x18]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi],ebx
		mov ebx,[eax+0x1c]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x4],ebx
		mov ebx,[eax+0x20]
		sar ebx,0x10
		imul ebx,edx
		sar ebx,0xf
		imul ebx,ecx
		add [edi+0x8],ebx
	JUMP_002652:			; Pos = 2a679
		shl dword [edi],1
		shl dword [edi+0x4],1
		shl dword [edi+0x8],1
		test esi,esi
		jnl JUMP_002653
		movzx edx,word [eax+0xec]
		add edx,[edi]
		mov ecx,edx
		and cx,0xffff
		mov [eax+0xec],cx
		sar edx,0x10
		add [eax+0x8c],edx
		movzx edx,word [eax+0xee]
		add edx,[edi+0x4]
		mov ecx,edx
		and cx,0xffff
		mov [eax+0xee],cx
		sar edx,0x10
		add [eax+0x90],edx
		movzx edx,word [eax+0xf0]
		add edx,[edi+0x8]
		mov ecx,edx
		and cx,0xffff
		mov [eax+0xf0],cx
		sar edx,0x10
		add [eax+0x94],edx
		jmp short JUMP_002654
	JUMP_002653:			; Pos = 2a6e9
		mov ecx,esi
		sar dword [edi],cl
		mov ecx,esi
		sar dword [edi+0x4],cl
		mov ecx,esi
		sar dword [edi+0x8],cl
		mov edx,[edi]
		add [eax+0x8c],edx
		mov edx,[edi+0x4]
		add [eax+0x90],edx
		mov edx,[edi+0x8]
		add [eax+0x94],edx
	JUMP_002654:			; Pos = 2a711
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
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


FUNC_001482:			; Pos = 52919

		push ebp
		mov ebp,esp
		push ecx
		mov ax,[ebp+0xa]
		add ax,[ebp+0xe]
		mov [ebp-0x2],ax
		movsx eax,word [ebp+0x8]
		movsx edx,word [ebp+0xc]
		imul edx
		sar eax,0xf
		mov [ebp-0x4],ax
		mov eax,[ebp-0x4]
		pop ecx
		pop ebp
		ret




FUNC_001483:			; Pos = 52975

		push ebp
		mov ebp,esp
		push ecx
		cmp word [ebp+0xc],byte +0x0
		jnz JUMP_005624
		mov word [ebp-0x2],0x7f
		mov word [ebp-0x4],0x7fff
		mov eax,[ebp-0x4]
		pop ecx
		pop ebp
		ret
	JUMP_005624:			; Pos = 52992
		mov ax,[ebp+0xa]
		sub ax,[ebp+0xe]
		mov [ebp-0x2],ax
		movsx eax,word [ebp+0x8]
		shl eax,0xe
		movsx edx,word [ebp+0xc]
		mov ecx,edx
		cdq
		idiv ecx
		mov [ebp-0x4],ax
		movsx eax,word [ebp-0x4]
		cdq
		xor eax,edx
		sub eax,edx
		cmp eax,0x4000
		jl JUMP_005625
		inc word [ebp-0x2]
		jmp short JUMP_005626
	JUMP_005625:			; Pos = 529c8
		shl word [ebp-0x4],1
	JUMP_005626:			; Pos = 529cc
		mov eax,[ebp-0x4]
		pop ecx
		pop ebp
		ret




FUNC_001496:			; Pos = 52d43

		push ebp
		mov ebp,esp
		cmp word [ebp+0x8],byte +0x0
		jz JUMP_005657
		jmp short JUMP_005656
	JUMP_005655:			; Pos = 52d4f
		shl word [ebp+0x8],1
		dec word [ebp+0xa]
	JUMP_005656:			; Pos = 52d57
		movsx eax,word [ebp+0x8]
		test ah,0x40
		jz JUMP_005655
	JUMP_005657:			; Pos = 52d60
		mov eax,[ebp+0x8]
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




FUNC_001515:			; Pos = 535f3

		push ebp
		mov ebp,esp
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		mov ecx,eax
		and ecx,0xffff
		imul ecx,edx
		shr ecx,0x10
		shr eax,0x10
		imul edx
		add ecx,eax
		mov eax,ecx
		pop ebp
		ret




FUNC_001516:			; Pos = 53615

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ebx,[ebp+0xc]
		mov esi,[ebp+0x8]
		test ebx,ebx
		jnl JUMP_005687
		neg ebx
		push ebx
		push esi
		call near [DATA_007747]    ; FUNC_001515
		add esp,byte +0x8
		add eax,eax
		neg eax
		jmp short JUMP_005688
	JUMP_005687:			; Pos = 53637
		push ebx
		push esi
		call near [DATA_007747]    ; FUNC_001515
		add esp,byte +0x8
		add eax,eax
	JUMP_005688:			; Pos = 53644
		pop esi
		pop ebx
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




FUNC_001657_Vec64FindMSB:			; Pos = 59d38

		push ebp
		mov ebp,esp
		push esi
		mov eax,[ebp+0x8]
		mov edx,[eax+0x4]
		test edx,edx
		jz JUMP_006335
		inc edx
		jnz JUMP_006337
	JUMP_006335:			; Pos = 59d49
		mov ecx,[eax+0xc]
		test ecx,ecx
		jz JUMP_006336
		inc ecx
		jnz JUMP_006337
	JUMP_006336:			; Pos = 59d53
		mov esi,[eax+0x14]
		test esi,esi
		jz JUMP_006344
		inc esi
		jz JUMP_006344
	JUMP_006337:			; Pos = 59d5d
		cmp dword [eax+0x4],byte +0x0
		jnl JUMP_006338
		mov edx,[eax+0x4]
		neg edx
		jmp short JUMP_006339
	JUMP_006338:			; Pos = 59d6a
		mov edx,[eax+0x4]
	JUMP_006339:			; Pos = 59d6d
		cmp dword [eax+0xc],byte +0x0
		jnl JUMP_006340
		mov ecx,[eax+0xc]
		neg ecx
		jmp short JUMP_006341
	JUMP_006340:			; Pos = 59d7a
		mov ecx,[eax+0xc]
	JUMP_006341:			; Pos = 59d7d
		or edx,ecx
		cmp dword [eax+0x14],byte +0x0
		jnl JUMP_006342
		mov ecx,[eax+0x14]
		neg ecx
		jmp short JUMP_006343
	JUMP_006342:			; Pos = 59d8c
		mov ecx,[eax+0x14]
	JUMP_006343:			; Pos = 59d8f
		or edx,ecx
		mov eax,0x20
		jmp short JUMP_006351
	JUMP_006344:			; Pos = 59d98
		cmp dword [eax+0x4],byte +0x0
		jnl JUMP_006345
		mov edx,[eax]
		neg edx
		jmp short JUMP_006346
	JUMP_006345:			; Pos = 59da4
		mov edx,[eax]
	JUMP_006346:			; Pos = 59da6
		cmp dword [eax+0xc],byte +0x0
		jnl JUMP_006347
		mov ecx,[eax+0x8]
		neg ecx
		jmp short JUMP_006348
	JUMP_006347:			; Pos = 59db3
		mov ecx,[eax+0x8]
	JUMP_006348:			; Pos = 59db6
		or edx,ecx
		cmp dword [eax+0x14],byte +0x0
		jnl JUMP_006349
		mov ecx,[eax+0x10]
		neg ecx
		jmp short JUMP_006350
	JUMP_006349:			; Pos = 59dc5
		mov ecx,[eax+0x10]
	JUMP_006350:			; Pos = 59dc8
		or edx,ecx
		xor eax,eax
	JUMP_006351:			; Pos = 59dcc
		cmp edx,0xffff
		jna JUMP_006352
		shr edx,0x10
		add eax,byte +0x10
	JUMP_006352:			; Pos = 59dda
		cmp edx,0xff
		jna JUMP_006353
		shr edx,0x8
		add eax,byte +0x8
	JUMP_006353:			; Pos = 59de8
		cmp edx,byte +0xf
		jna JUMP_006354
		shr edx,0x4
		add eax,byte +0x4
	JUMP_006354:			; Pos = 59df3
		cmp edx,byte +0x3
		jna JUMP_006355
		shr edx,0x2
		add eax,byte +0x2
	JUMP_006355:			; Pos = 59dfe
		cmp edx,byte +0x1
		jna JUMP_006356
		inc eax
	JUMP_006356:			; Pos = 59e04
		pop esi
		pop ebp
		ret




FUNC_001658_Vec64Truncate:			; Pos = 59e08

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0x8]
		push esi
		call FUNC_001657_Vec64FindMSB
		pop ecx
		mov ebx,eax
		sub ebx,[ebp+0xc]
		test ebx,ebx
		jg JUMP_006357
		xor eax,eax
		jmp short JUMP_006358
	JUMP_006357:			; Pos = 59e24
		push ebx
		push esi
		call FUNC_001660_Vec64Shift
		add esp,byte +0x8
		mov eax,ebx
	JUMP_006358:			; Pos = 59e30
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001660_Vec64Shift:			; Pos = 59f90

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edx,[ebp+0xc]
		mov eax,[ebp+0x8]
		test edx,edx
		jz near JUMP_006362
		cmp edx,byte +0x20
		jnl JUMP_006359
		mov ebx,0x20
		sub ebx,edx
		mov ecx,ebx
		mov esi,[eax+0x4]
		shl esi,cl
		mov ecx,edx
		mov edi,[eax]
		shr edi,cl
		or esi,edi
		mov [eax],esi
		mov ecx,edx
		sar dword [eax+0x4],cl
		mov ecx,ebx
		mov esi,[eax+0xc]
		shl esi,cl
		mov ecx,edx
		mov edi,[eax+0x8]
		shr edi,cl
		or esi,edi
		mov [eax+0x8],esi
		mov ecx,edx
		sar dword [eax+0xc],cl
		mov ecx,ebx
		mov ebx,[eax+0x14]
		shl ebx,cl
		mov ecx,edx
		mov esi,[eax+0x10]
		shr esi,cl
		or ebx,esi
		mov [eax+0x10],ebx
		mov ecx,edx
		sar dword [eax+0x14],cl
		jmp short JUMP_006362
	JUMP_006359:			; Pos = 59ff8
		cmp edx,byte +0x20
		jng JUMP_006360
		lea ebx,[edx-0x20]
		mov ecx,ebx
		mov esi,[eax+0x4]
		sar esi,cl
		mov [eax],esi
		mov ecx,ebx
		mov esi,[eax+0xc]
		sar esi,cl
		mov [eax+0x8],esi
		mov ecx,ebx
		mov edx,[eax+0x14]
		sar edx,cl
		mov [eax+0x10],edx
		jmp short JUMP_006361
	JUMP_006360:			; Pos = 5a01f
		mov edx,[eax+0x4]
		mov [eax],edx
		mov edx,[eax+0xc]
		mov [eax+0x8],edx
		mov edx,[eax+0x14]
		mov [eax+0x10],edx
	JUMP_006361:			; Pos = 5a030
		sar dword [eax+0x4],0x1f
		sar dword [eax+0xc],0x1f
		sar dword [eax+0x14],0x1f
	JUMP_006362:			; Pos = 5a03c
		pop edi
		pop esi
		pop ebx
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




FUNC_001670_VecMatTMul:			; Pos = 5a968

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov ebx,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[esi]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x4],edx

		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x10]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x14]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x8],edx

		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x20]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax

		mov [edi+0x8],edx
		mov eax,[ebp-0x4]
		mov [edi],eax
		mov eax,[ebp-0x8]
		mov [edi+0x4],eax
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001019:			; Pos = 40f64

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		mov ebx,[ebp+0x8]
		mov esi,DATA_008804
		test byte [esi+0x3fb6],0x2
		jz JUMP_004208
		cmp dword [DATA_009138],byte +0x0
		jz JUMP_004208
		call FUNC_001018
		jmp JUMP_004217
	JUMP_004208:			; Pos = 40f90
		push ebx
		call FUNC_001039
		pop ecx
		lea eax,[ebp-0x2]
		push eax
		lea eax,[ebp-0x1]
		push eax
		lea eax,[ebp-0x8]
		push eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call FUNC_001033
		add esp,byte +0x14
		cmp byte [esi+0xe8],0x2c
		jz near JUMP_004217
		test al,0x20
		jnz JUMP_004210
		test al,0x1
		jz JUMP_004209
		push ebx
		call FUNC_001014
		pop ecx
		jmp JUMP_004216
	JUMP_004209:			; Pos = 40fd3
		push ebx
		call FUNC_001035
		pop ecx
		jmp JUMP_004216
	JUMP_004210:			; Pos = 40fdf
		test al,0x40
		jz near JUMP_004214
		test al,0x80
		jnz near JUMP_004217
		mov eax,[ebp-0x8]
		mov [esi+0xcc],eax
		mov byte [esi+0xf8],0x0
		mov eax,[ebp-0x8]
		mov al,[eax+0x86]
		mov [esi+0xc5],al
		push ebx
		call FUNC_001042
		pop ecx
		mov eax,[ebp-0x8]
		push eax
		mov al,[esi+0xc0]
		push eax
		call FUNC_000652
		add esp,byte +0x8
		mov eax,[ebp-0x8]
		test byte [eax+0x14c],0x40
		jz JUMP_004211
		mov byte [esi+0xe8],0x2e
		call FUNC_000995
		call FUNC_001116
		jmp short JUMP_004213
	JUMP_004211:			; Pos = 41047
		mov dword [esi+0x106],0x70000
		push byte +0x13
		call FUNC_001906_SoundPlaySample
		pop ecx
		and byte [esi+0xe9],0xdb
		mov eax,[ebp-0x8]
		test byte [eax+0x14c],0x20
		jz JUMP_004212
		mov byte [esi+0xe8],0x8
		xor eax,eax
		mov [esi+0xdc],eax
		call FUNC_001116
		jmp short JUMP_004213
	JUMP_004212:			; Pos = 41082
		mov byte [esi+0xe8],0xa
		call FUNC_001116
	JUMP_004213:			; Pos = 4108e
		push byte +0xd
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
		push byte +0xe
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
		jmp short JUMP_004217
	JUMP_004214:			; Pos = 410ac
		test al,0x1
		jz JUMP_004215
		push ebx
		call FUNC_001014
		pop ecx
		jmp short JUMP_004216
	JUMP_004215:			; Pos = 410b9
		push ebx
		call FUNC_001035
		pop ecx
	JUMP_004216:			; Pos = 410c0
		push ebx
		call FUNC_001046
		pop ecx
		mov eax,[esi+0xe0]
		push eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call near [DATA_006153]    ; FUNC_000603
		add esp,byte +0xc
		mov eax,[esi+0xe0]
		push eax
		push ebx
		call near [DATA_006142]    ; FUNC_000601
		add esp,byte +0x8
		mov eax,[esi+0xe0]
		push eax
		push byte +0x1
		push eax
		push ebx
		call near [DATA_006143]    ; FUNC_000585
		add esp,byte +0x10
	JUMP_004217:			; Pos = 41103
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001021:			; Pos = 411b8

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		mov ebx,[ebp+0x8]
		mov esi,DATA_008804
		push ebx
		call FUNC_001037
		pop ecx
		push ebx
		call FUNC_001041
		pop ecx
		test byte [esi+0xe9],0x1
		jz JUMP_004220
		mov eax,[esi+0xe0]
		push eax
		push ebx
		call near [DATA_006152]    ; FUNC_000602
		add esp,byte +0x8
		jmp short JUMP_004221
	JUMP_004220:			; Pos = 411f2
		mov eax,[esi+0xe0]
		push eax
		push ebx
		call near [DATA_006142]    ; FUNC_000601
		add esp,byte +0x8
	JUMP_004221:			; Pos = 41203
		test byte [esi+0x3fb6],0x2
		jz near JUMP_004224
		cmp dword [DATA_009138],byte +0x0
		jz JUMP_004223
		cmp byte [esi+0xe8],0x2
		jnz JUMP_004222
		call FUNC_001018
	JUMP_004222:			; Pos = 41227
		call FUNC_001120
		mov al,[esi+0xe9]
		and eax,byte +0x1
		mov [DATA_009135],eax
		xor eax,eax
		mov [DATA_009138],eax
	JUMP_004223:			; Pos = 41241
		push byte +0xd
		mov eax,[esi+0xe0]
		push eax
		lea eax,[esi+0x88]
		push eax
		mov eax,[esi+0xc8]
		add eax,0x8c
		push eax
		call FUNC_000726
		add esp,byte +0x10
		or byte [esi+0xe9],0x1
		push byte +0xb
		mov eax,[esi+0xe0]
		push eax
		mov eax,[esi+0xc8]
		add eax,0x8c
		push eax
		lea eax,[esi+0x88]
		push eax
		call FUNC_000726
		add esp,byte +0x10
		jmp short JUMP_004225
	JUMP_004224:			; Pos = 41292
		cmp dword [DATA_009138],byte +0x0
		jnz JUMP_004225
		and byte [esi+0xe9],0xfe
		mov al,[DATA_009135]
		or [esi+0xe9],al
		call FUNC_001117
		call FUNC_001116
		mov dword [DATA_009138],0x1
	JUMP_004225:			; Pos = 412c1
		push ebx
		call FUNC_001046
		pop ecx
		lea eax,[ebp-0x6]
		push eax
		lea eax,[ebp-0x5]
		push eax
		lea eax,[ebp-0x4]
		push eax
		mov eax,[DATA_009133]
		push eax
		push ebx
		call FUNC_001033
		add esp,byte +0x14
		cmp byte [esi+0xe8],0x2c
		jz near JUMP_004231
		test al,0x20
		jz JUMP_004228
		test al,0x40
		jz JUMP_004226
		mov byte [esi+0xe8],0x24
		call FUNC_001116
		push byte +0xe
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
	JUMP_004226:			; Pos = 41312
		mov eax,[ebp-0x4]
		test byte [eax+0x14c],0x10
		jz near JUMP_004231
		mov eax,[ebp-0x4]
		push eax
		mov eax,[esi+0xc0]
		push eax
		call FUNC_000657
		add esp,byte +0x8
		test al,al
		jz JUMP_004227
		mov byte [esi+0xe8],0x6
		push byte +0xe
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
		jmp JUMP_004231
	JUMP_004227:			; Pos = 41353
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001022
		pop ecx
		jmp JUMP_004231
	JUMP_004228:			; Pos = 41362
		test al,0x40
		jz JUMP_004229
		mov eax,[ebp-0x4]
		mov [esi+0xcc],eax
		mov al,[eax+0x86]
		mov [esi+0xc5],al
		push ebx
		call FUNC_001042
		pop ecx
		mov byte [esi+0xf8],0xff
		mov byte [esi+0xe8],0x32
		push byte +0xd
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
		push byte +0xe
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
		jmp short JUMP_004231
	JUMP_004229:			; Pos = 413ae
		mov byte [esi+0xeb],0x0
		test al,0x1
		jz JUMP_004230
		push ebx
		call FUNC_001014
		pop ecx
		xor eax,eax
		mov [esi+0x88],eax
		xor eax,eax
		mov [esi+0x8c],eax
		xor eax,eax
		mov [esi+0x90],eax
		mov eax,[esi+0xd8]
		mov [esi+0x94],eax
	JUMP_004230:			; Pos = 413e4
		push ebx
		call FUNC_001035
		pop ecx
	JUMP_004231:			; Pos = 413eb
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001042:			; Pos = 4230c

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		xor edx,edx
		mov [eax+0x8c],edx
		xor edx,edx
		mov [eax+0x90],edx
		xor edx,edx
		mov [eax+0x94],edx
		mov word [eax+0xb0],0x0
		mov word [eax+0xb2],0x0
		xor edx,edx
		mov [DATA_008918],edx
		mov word [eax+0xb6],0x0
		mov word [eax+0xb8],0x0
		mov word [eax+0xba],0x0
		test byte [DATA_008860],0x80
		jz JUMP_004310
		push eax
		push dword 0x12c
		push byte +0x1
		push byte +0x3
		call FUNC_001910_SoundModifyStationNoise
		add esp,byte +0x10
	JUMP_004310:			; Pos = 4237a
		pop ebp
		ret




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



