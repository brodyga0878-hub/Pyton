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



