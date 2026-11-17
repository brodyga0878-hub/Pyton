FUNC_000571:			; Pos = 276d8

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		mov eax,[ebp+0x8]
		mov edx,[eax+0x18]
		mov [ebp-0xc],edx
		mov edx,[eax+0x1c]
		mov [ebp-0x8],edx
		mov edx,[eax+0x20]
		mov [ebp-0x4],edx
		mov edx,[eax+0xc]
		mov [eax+0x18],edx
		mov edx,[eax+0x10]
		mov [eax+0x1c],edx
		mov edx,[eax+0x14]
		mov [eax+0x20],edx
		mov edx,[ebp-0xc]
		mov [eax+0xc],edx
		mov edx,[ebp-0x8]
		mov [eax+0x10],edx
		mov edx,[ebp-0x4]
		mov [eax+0x14],edx
		neg dword [eax]
		neg dword [eax+0x4]
		neg dword [eax+0x8]
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


FUNC_001335_Int64Sub64:			; Pos = 4eb80

		push ebp
		mov ebp,esp
		mov edx,[ebp+0x8]
		mov eax,[ebp+0xc]
		sub eax,[ebp+0x14]
		mov [edx],eax
		mov eax,[ebp+0x10]
		sbb eax,[ebp+0x18]
		mov [edx+0x4],eax
		pop ebp
		ret



; void F1336 (int64 *rval, int64 op1, int op2)


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




FUNC_001501:			; Pos = 52df7

		push ebp
		mov ebp,esp
		push ebx
		mov ecx,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov eax,0x1
		test ebx,ebx
		jnl JUMP_005667
		mov edx,ebx
		neg edx
		jmp short JUMP_005668
	JUMP_005667:			; Pos = 52e10
		mov edx,ebx
	JUMP_005668:			; Pos = 52e12
		add edx,edx
		add eax,eax
		cmp ecx,edx
		ja JUMP_005669
		sub edx,ecx
		inc eax
	JUMP_005669:			; Pos = 52e1d
		test eax,eax
		jg JUMP_005668
		and eax,0x7fffffff
		test ebx,ebx
		jnl JUMP_005670
		mov edx,eax
		neg edx
		jmp short JUMP_005671
	JUMP_005670:			; Pos = 52e30
		mov edx,eax
	JUMP_005671:			; Pos = 52e32
		mov eax,edx
		pop ebx
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




FUNC_001503:			; Pos = 52ec2

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ebx,[ebp+0x8]
		push dword [ebx]
		call near [DATA_007737]    ; FUNC_001522
		pop ecx
		mov esi,eax
		push dword [ebx+0x4]
		call near [DATA_007737]    ; FUNC_001522
		pop ecx
		add esi,eax
		push dword [ebx+0x8]
		call near [DATA_007737]    ; FUNC_001522
		pop ecx
		add esi,eax
		push esi
		push dword [ebp+0xc]
		push ebx
		call FUNC_001504
		add esp,byte +0xc
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001504:			; Pos = 52efe

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov edi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		add esi,esi
		push esi
		call near [DATA_007738]    ; FUNC_001502
		pop ecx
		mov esi,eax
		push edi
		push esi
		push dword [ebx]
		call FUNC_001501
		add esp,byte +0x8
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx],eax
		push edi
		push esi
		push dword [ebx+0x4]
		call FUNC_001501
		add esp,byte +0x8
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x4],eax
		push edi
		push esi
		push dword [ebx+0x8]
		call FUNC_001501
		add esp,byte +0x8
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x8],eax
		pop edi
		pop esi
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




FUNC_001522:			; Pos = 537c1

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		imul eax
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




FUNC_001538:			; Pos = 53f88

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov eax,[eax*4+DATA_004681]
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




FUNC_000575:			; Pos = 27898

		push ebp
		mov ebp,esp
		add esp,0xffffff2c
		push ebx
		push esi
		push edi
		mov edi,[ebp+0x10]
		mov ebx,[ebp+0xc]
		mov esi,[ebp+0x8]
		push esi
		push edi
		lea edi,[ebp-0x38]
		mov ecx,0x6
		rep movsd
		pop edi
		pop esi
		push esi
		push esi
		call FUNC_001664_Vec64Abs
		add esp,byte +0x8
		push dword [esi+0xc]
		push dword [esi+0x8]
		push dword [esi+0x4]
		push dword [esi]
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		push dword [esi+0x14]
		push dword [esi+0x10]
		push dword [ebp-0x4]
		push dword [ebp-0x8]
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		push byte -0x1
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001341_Int64ArithShift
		add esp,byte +0x8
		push dword [ebx+0x13c]
		push dword [ebx+0x138]
		push dword [ebp-0x4]
		push dword [ebp-0x8]
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001335_Int64Sub64
		add esp,byte +0x14
		cmp dword [ebp-0x4],byte +0x0
		jl JUMP_002404
		push dword [edi+0x13c]
		push dword [edi+0x138]
		push dword [ebp-0x4]
		push dword [ebp-0x8]
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001335_Int64Sub64
		add esp,byte +0x14
		cmp dword [ebp-0x4],byte +0x0
		jl JUMP_002404
		xor eax,eax
		jmp JUMP_002432
	JUMP_002404:			; Pos = 27951
		mov byte [DATA_008707],0x0
		cmp byte [edi+0x14c],0x0
		jnl JUMP_002406
		lea eax,[ebp-0x38]
		push eax
		push edi
		push ebx
		call FUNC_000576
		add esp,byte +0xc
		test eax,eax
		jnz JUMP_002405
		cmp byte [DATA_008707],0x0
		jnz JUMP_002410
		push edi
		push ebx
		call FUNC_000578
		add esp,byte +0x8
		mov al,[DATA_008696]
		jmp JUMP_002432
	JUMP_002405:			; Pos = 27990
		mov al,[DATA_008696]
		jmp JUMP_002432
	JUMP_002406:			; Pos = 2799a
		push esi
		lea eax,[ebp-0x38]
		mov edx,0x5
	JUMP_002407:			; Pos = 279a3
		push dword [eax+edx*4]
		dec edx
		jns JUMP_002407
		push edi
		push ebx
		lea eax,[ebp-0xc]
		push eax
		call FUNC_000577
		add esp,byte +0x28
		test eax,eax
		jnz JUMP_002409
		mov al,[edi+0x86]
		cmp al,[ebx+0x56]
		jz JUMP_002408
		push edi
		push ebx
		call FUNC_000578
		add esp,byte +0x8
		mov al,[DATA_008696]
		jmp JUMP_002432
	JUMP_002408:			; Pos = 279da
		mov byte [DATA_008707],0x2
		jmp short JUMP_002410
	JUMP_002409:			; Pos = 279e3
		mov al,[DATA_008696]
		jmp JUMP_002432

	JUMP_002410:			; Pos = 279ed
		or byte [DATA_008696],0x2
		mov eax,[ebx+0x8c]
		push eax
		call _abs
		pop ecx
		mov esi,eax
		mov eax,[ebx+0x90]
		push eax
		call _abs
		pop ecx
		add esi,eax
		mov eax,[ebx+0x94]
		push eax
		call _abs
		pop ecx
		add esi,eax
		mov [ebp-0x10],esi
		cmp byte [DATA_008707],0x1
		jnz JUMP_002411
		push edi
		lea esi,[ebp-0x38]
		lea edi,[ebp-0x50]
		mov ecx,0x6
		rep movsd
		pop edi
		push byte +0x1c
		lea eax,[ebp-0x50]
		push eax
		call FUNC_001658_Vec64Truncate
		add esp,byte +0x8
		mov eax,[ebp-0x50]
		mov [ebp-0x80],eax
		mov eax,[ebp-0x48]
		mov [ebp-0x7c],eax
		mov eax,[ebp-0x40]
		mov [ebp-0x78],eax
		push dword 0x7fffffff
		lea eax,[ebp-0x80]
		push eax
		call FUNC_001503
		add esp,byte +0x8
		jmp short JUMP_002412
	JUMP_002411:			; Pos = 27a6f
		mov eax,[ebp-0x38]
		mov [ebp-0x80],eax
		mov eax,[ebp-0x30]
		mov [ebp-0x7c],eax
		mov eax,[ebp-0x28]
		mov [ebp-0x78],eax
		lea eax,[ebp-0x80]
		push eax
		lea eax,[ebp-0x80]
		push eax
		call FUNC_001519
		add esp,byte +0x8
	JUMP_002412:			; Pos = 27a91
		mov eax,[ebp-0x80]
		push eax
		mov eax,[ebx+0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov esi,eax
		mov eax,[ebp-0x7c]
		push eax
		mov eax,[ebx+0x10]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax
		mov eax,[ebp-0x78]
		push eax
		mov eax,[ebx+0x14]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax
		mov eax,esi
		cmp dword [ebp-0x10],0x258
		jg JUMP_002413
		cmp word [ebx+0x9e],0xffff
		jnz JUMP_002413
		cmp eax,0x78000000
		jl JUMP_002413
		or byte [DATA_008696],0x40
		and byte [DATA_008696],0x7f
		mov byte [DATA_008699],0x0
		jmp short JUMP_002414
	JUMP_002413:			; Pos = 27afb
		mov al,[DATA_008700]
		mov [DATA_008699],al
	JUMP_002414:			; Pos = 27b05
		mov eax,[ebx+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		mov [ebp-0x18],eax
		mov eax,[edi+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		mov edx,eax
		cmp byte [DATA_008707],0x1
		jnz near JUMP_002418
		push dword [DATA_008706]
		push dword [DATA_008705]
		push dword [ebx+0x144]
		push dword [ebx+0x140]
		lea eax,[ebp-0x20]
		push eax
		call FUNC_001335_Int64Sub64
		add esp,byte +0x14
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebp-0x80]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp+0xffffff68],eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebp-0x7c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp+0xffffff70],eax
		mov eax,[ebp-0x20]
		push eax
		mov eax,[ebp-0x78]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp+0xffffff78],eax
		or eax,byte -0x1
		cmp dword [ebp+0xffffff68],byte +0x0
		jl JUMP_002415
		inc eax
	JUMP_002415:			; Pos = 27ba6
		mov [ebp+0xffffff6c],eax
		or eax,byte -0x1
		cmp dword [ebp+0xffffff70],byte +0x0
		jl JUMP_002416
		inc eax
	JUMP_002416:			; Pos = 27bb9
		mov [ebp+0xffffff74],eax
		or eax,byte -0x1
		cmp dword [ebp+0xffffff78],byte +0x0
		jl JUMP_002417
		inc eax
	JUMP_002417:			; Pos = 27bcc
		mov [ebp+0xffffff7c],eax
		push dword [ebp+0xffffff6c]
		push dword [ebp+0xffffff68]
		push dword [ebx+0x42]
		push dword [ebx+0x3e]
		lea eax,[ebx+0x3e]
		push eax
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		push dword [ebp+0xffffff74]
		push dword [ebp+0xffffff70]
		push dword [ebx+0x4a]
		push dword [ebx+0x46]
		lea eax,[ebx+0x46]
		push eax
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		push dword [ebp+0xffffff7c]
		push dword [ebp+0xffffff78]
		push dword [ebx+0x52]
		push dword [ebx+0x4e]
		lea eax,[ebx+0x4e]
		push eax
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		jmp JUMP_002421
	JUMP_002418:			; Pos = 27c31
		mov eax,[edx+0x2c]
		shl eax,0x10
		mov esi,[edx+0x14]
		add esi,[edx+0x18]
		mov edx,[ebp-0x18]
		mov edx,[edx+0x14]
		mov ecx,[ebp-0x18]
		add edx,[ecx+0x18]
		push edx
		mov edx,esi
		pop ecx
		sub edx,ecx
		mov ecx,[ebp-0x18]
		mov ecx,[ecx+0x30]
		shl ecx,0x10
		mov [ebp-0x14],ecx
		test edx,edx
		jz JUMP_002419
		mov ecx,edx
		sar dword [ebp-0x14],cl
	JUMP_002419:			; Pos = 27c64
		add eax,[ebp-0x14]
		test eax,eax
		jnl JUMP_002420
		shr eax,1
		inc dword [ebp-0xc]
	JUMP_002420:			; Pos = 27c70
		mov edx,[ebp-0x38]
		mov [ebp-0x68],edx
		mov edx,[ebp-0x30]
		mov [ebp-0x64],edx
		mov edx,[ebp-0x28]
		mov [ebp-0x60],edx
		mov edx,[ebp-0xc]
		push edx
		push eax
		lea eax,[ebp-0x68]
		push eax
		call FUNC_001504
		add esp,byte +0xc
		sub esi,byte +0x37
		neg esi
		inc esi
		mov eax,0x20
		sub eax,esi
		mov ecx,eax

		mov edx,[ebp-0x68]
		shl edx,cl
		mov [ebx+0x3e],edx
		mov ecx,eax
		mov edx,[ebp-0x64]
		shl edx,cl
		mov [ebx+0x46],edx
		mov ecx,eax
		mov eax,[ebp-0x60]
		shl eax,cl
		mov [ebx+0x4e],eax
		mov ecx,esi

		mov eax,[ebp-0x68]
		sar eax,cl
		mov [ebx+0x42],eax
		mov ecx,esi
		mov eax,[ebp-0x64]
		sar eax,cl
		mov [ebx+0x4a],eax
		mov ecx,esi
		mov eax,[ebp-0x60]
		sar eax,cl
		mov [ebx+0x52],eax
	JUMP_002421:			; Pos = 27cdc
		cmp byte [DATA_008699],0x0
		jz near JUMP_002428
		or byte [DATA_008696],0x80
		xor eax,eax
		mov al,[ebx+0x86]
		cmp eax,[DATA_008857]
		jnz near JUMP_002426
		push edi
		mov esi,ebx
		lea edi,[ebp+0xffffff2c]
		mov ecx,0x9
		rep movsd
		pop edi
		mov eax,[ebp-0x80]
		mov [ebx+0xc],eax
		mov eax,[ebp-0x7c]
		mov [ebx+0x10],eax
		mov eax,[ebp-0x78]
		mov [ebx+0x14],eax
		push ebx
		call FUNC_000571
		pop ecx
		push ebx
		call near [DATA_007719]    ; FUNC_001520
		pop ecx
		push ebx
		call FUNC_000571
		pop ecx
		mov eax,[ebp-0x80]
		push eax
		mov eax,[ebx+0x8c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov esi,eax
		mov eax,[ebp-0x7c]
		push eax
		mov eax,[ebx+0x90]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax
		mov eax,[ebp-0x78]
		push eax
		mov eax,[ebx+0x94]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax

		push esi
		mov eax,[ebp-0x80]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp-0x68],eax
		push esi
		mov eax,[ebp-0x7c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp-0x64],eax
		push esi
		mov eax,[ebp-0x78]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp-0x60],eax

		mov eax,[ebx+0x8c]
		add eax,eax
		mov ecx,0x3
		cdq
		idiv ecx
		mov ecx,eax

		mov eax,[ebp-0x68]
		add eax,eax
		lea eax,[eax+eax*4]
		mov esi,0xc
		cdq
		idiv esi
		sub ecx,eax
		mov [ebx+0x8c],ecx

		mov eax,[ebx+0x90]
		add eax,eax
		mov ecx,0x3
		cdq
		idiv ecx
		mov ecx,eax
		mov eax,[ebp-0x64]
		add eax,eax
		lea eax,[eax+eax*4]
		mov esi,0xc
		cdq
		idiv esi
		sub ecx,eax
		mov [ebx+0x90],ecx

		mov eax,[ebx+0x94]
		add eax,eax
		mov ecx,0x3
		cdq
		idiv ecx
		mov ecx,eax
		mov eax,[ebp-0x60]
		add eax,eax
		lea eax,[eax+eax*4]
		mov esi,0xc
		cdq
		idiv esi
		sub ecx,eax
		mov [ebx+0x94],ecx

		mov eax,[ebx+0x8c]
		mov [ebp-0x68],eax
		mov eax,[ebx+0x90]
		mov [ebp-0x64],eax
		mov eax,[ebx+0x94]
		mov [ebp-0x60],eax

		mov eax,[ebx+0x8c]
		push eax
		mov eax,[ebp+0xffffff44]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov esi,eax
		mov eax,[ebx+0x90]
		push eax
		mov eax,[ebp+0xffffff48]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax
		mov eax,[ebx+0x94]
		push eax
		mov eax,[ebp+0xffffff4c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add esi,eax
		test esi,esi
		jnl JUMP_002422
		neg dword [ebp-0x68]
		neg dword [ebp-0x64]
		neg dword [ebp-0x60]
	JUMP_002422:			; Pos = 27e9a
		mov eax,[ebx+0x8c]
		push eax
		call _abs
		pop ecx
		mov esi,eax
		mov eax,[ebx+0x90]
		push eax
		call _abs
		pop ecx
		add esi,eax
		mov eax,[ebx+0x94]
		push eax
		call _abs
		pop ecx
		add esi,eax
		sub [ebp-0x10],esi
		mov eax,[ebx+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		mov eax,[eax+0x38]
		movsx ecx,word [eax+0x6]
		shl ecx,0x2
		mov eax,ecx
		imul dword [ebp-0x10]
		mov esi,0x708
		cdq
		idiv esi
		mov edx,ecx
		test edx,edx
		jns JUMP_002423
		add edx,byte +0x3
	JUMP_002423:			; Pos = 27ef8
		sar edx,0x2
		cmp eax,edx
		jnl JUMP_002424
		mov eax,edx
	JUMP_002424:			; Pos = 27f01
		push byte +0x0
		push eax
		push ebx
		call FUNC_000953
		add esp,byte +0xc
		cmp dword [ebp-0x68],byte +0x0
		jnz JUMP_002425
		cmp dword [ebp-0x64],byte +0x0
		jnz JUMP_002425
		cmp dword [ebp-0x60],byte +0x0
		jnz JUMP_002425
		mov eax,[ebp+0xffffff44]
		mov [ebp-0x68],eax
		mov eax,[ebp+0xffffff48]
		mov [ebp-0x64],eax
		mov eax,[ebp+0xffffff4c]
		mov [ebp-0x60],eax
	JUMP_002425:			; Pos = 27f3a
		push dword 0x7fffffff
		lea eax,[ebp-0x68]
		push eax
		call FUNC_001503
		add esp,byte +0x8
		push edi
		lea esi,[ebp+0xffffff2c]
		mov edi,ebx
		mov ecx,0x9
		rep movsd
		pop edi
		mov eax,[ebp-0x68]
		mov [ebx+0x18],eax
		mov eax,[ebp-0x64]
		mov [ebx+0x1c],eax
		mov eax,[ebp-0x60]
		mov [ebx+0x20],eax
		push ebx
		call near [DATA_007719]    ; FUNC_001520
		pop ecx
		jmp JUMP_002429
	JUMP_002426:			; Pos = 27f7b
		cmp dword [ebx+0x82],byte +0xd
		jna near JUMP_002429
		mov al,[ebx+0x87]
		cmp al,0xb
		jz JUMP_002427
		cmp al,0xe
		jnz near JUMP_002429
	JUMP_002427:			; Pos = 27f9a
		mov eax,[ebp-0x80]
		mov [ebx+0xc],eax
		mov eax,[ebp-0x7c]
		mov [ebx+0x10],eax
		mov eax,[ebp-0x78]
		mov [ebx+0x14],eax
		push ebx
		call FUNC_000571
		pop ecx
		push ebx
		call near [DATA_007719]    ; FUNC_001520
		pop ecx
		push ebx
		call FUNC_000571
		pop ecx
		xor eax,eax
		mov [ebx+0x8c],eax
		xor eax,eax
		mov [ebx+0x90],eax
		xor eax,eax
		mov [ebx+0x94],eax
		cmp byte [DATA_008700],0x0
		jz JUMP_002429
		push byte +0x0
		push byte -0x1
		push ebx
		call FUNC_000953
		add esp,byte +0xc
		jmp short JUMP_002429
	JUMP_002428:			; Pos = 27ff2
		mov eax,[ebp-0x80]
		mov [ebx+0xc],eax
		mov eax,[ebp-0x7c]
		mov [ebx+0x10],eax
		mov eax,[ebp-0x78]
		mov [ebx+0x14],eax
		push ebx
		call FUNC_000571
		pop ecx
		push ebx
		call near [DATA_007719]    ; FUNC_001520
		pop ecx
		push ebx
		call FUNC_000571
		pop ecx
		xor eax,eax
		mov [ebx+0x8c],eax
		xor eax,eax
		mov [ebx+0x90],eax
		xor eax,eax
		mov [ebx+0x94],eax
	JUMP_002429:			; Pos = 28032
		mov eax,[edi+0x140]
		cmp eax,[edi+0x138]
		jz JUMP_002430
		or byte [DATA_008696],0x1
	JUMP_002430:			; Pos = 28047
		cmp byte [DATA_008698],0x0
		jnz JUMP_002431
		mov al,[edi+0x86]
		mov [DATA_008698],al
		mov [DATA_008702],edi
	JUMP_002431:			; Pos = 28061
		mov al,[DATA_008696]
	JUMP_002432:			; Pos = 28066
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000577:			; Pos = 28244

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x2c]
		mov esi,[ebp+0x10]
		mov edi,[ebp+0x8]
		mov eax,[ebx+0x4]
		or eax,[ebx+0xc]
		or eax,[ebx+0x14]
		or eax,[esi+0x13c]
		mov [ebp-0x4],eax
		cmp dword [ebp-0x4],byte +0x0
		jz JUMP_002446
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		mov ebx,eax
		add ebx,byte +0x3
		jmp short JUMP_002447
	JUMP_002446:			; Pos = 2827f
		mov eax,[ebx]
		or eax,[ebx+0x8]
		or eax,[ebx+0x10]
		or eax,[esi+0x138]
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		add eax,byte -0x1d
		mov ebx,eax
	JUMP_002447:			; Pos = 28299
		test ebx,ebx
		jg JUMP_002448
		neg ebx
		mov ecx,ebx
		mov eax,[ebp+0xc]
		mov eax,[eax+0x140]

; FIX: Collision radius
		add eax,[esi+0x138]
;		add eax,[esi+0x138]

		shl eax,cl
		mov [ebp-0x8],eax
		mov ecx,ebx
		shl dword [ebp+0x14],cl
		mov ecx,ebx
		shl dword [ebp+0x1c],cl
		mov ecx,ebx
		shl dword [ebp+0x24],cl
		neg ebx
		jmp short JUMP_002449
	JUMP_002448:			; Pos = 282c8
		push ebx
		lea eax,[ebp+0x14]
		push eax
		call FUNC_001660_Vec64Shift
		add esp,byte +0x8
		mov eax,[ebp+0xc]
		push dword [eax+0x13c]
		push dword [eax+0x138]
		push dword [esi+0x13c]
		push dword [esi+0x138]
		lea eax,[ebp-0x10]
		push eax
		call FUNC_001333_Int64Add64
		add esp,byte +0x14
		mov eax,ebx
		neg eax
		push eax
		lea eax,[ebp-0x10]
		push eax
		call FUNC_001341_Int64ArithShift
		add esp,byte +0x8
		mov eax,[ebp-0x10]
		mov [ebp-0x8],eax
	JUMP_002449:			; Pos = 28313
		mov eax,[ebp+0x14]
		push eax
		call near [DATA_007737]    ; FUNC_001522
		pop ecx
		push eax
		mov eax,[ebp+0x1c]
		push eax
		call near [DATA_007737]    ; FUNC_001522
		pop ecx
		pop edx
		add edx,eax
		push edx
		mov eax,[ebp+0x24]
		push eax
		call near [DATA_007737]    ; FUNC_001522
		pop ecx
		pop edx
		add edx,eax
		mov [edi],edx
		mov eax,[ebp-0x8]
		push eax
		call near [DATA_007737]    ; FUNC_001522
		pop ecx
		cmp eax,[edi]
		jna JUMP_002450
		xor eax,eax
		jmp short JUMP_002453
	JUMP_002450:			; Pos = 28351
		or byte [DATA_008696],0x2
		mov eax,[edi]
		shr eax,1
		push eax
		call near [DATA_007738]    ; FUNC_001502
		pop ecx
		add eax,eax
		mov [DATA_008703],eax
		cmp dword [DATA_008703],byte +0x0
		jnl JUMP_002451
		xor eax,eax
		mov [DATA_008703],eax
	JUMP_002451:			; Pos = 2837b
		xor eax,eax
		mov [DATA_008704],eax
		push ebx
		push dword DATA_008703
		call FUNC_001341_Int64ArithShift
		add esp,byte +0x8
		mov eax,[esi+0x140]
		cmp eax,[esi+0x138]
		jz JUMP_002452
		or byte [DATA_008696],0x1
	JUMP_002452:			; Pos = 283a5
		or eax,byte -0x1
	JUMP_002453:			; Pos = 283a8
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000578: ; Pos = 283b0, restored from actual DOS
DOS_PAIR_4281b8:
push ebp
DOS_PAIR_4281b9:
mov ebp,esp
DOS_PAIR_4281bb:
push ebx
DOS_PAIR_4281bc:
push esi
DOS_PAIR_4281bd:
mov esi,dword [ebp+0xc]
DOS_PAIR_4281c0:
mov ebx,dword [ebp+0x8]
DOS_PAIR_4281c3:
or byte [DATA_008696],0x80
DOS_PAIR_4281ca:
mov al,byte [ebx+0x56]
DOS_PAIR_4281cd:
cmp al,byte [esi+0x86]
DOS_PAIR_4281d3:
je DOS_PAIR_4281e2
DOS_PAIR_4281d5:
cmp byte [esi+0x87],0x1
DOS_PAIR_4281dc:
jne DOS_PAIR_428265
DOS_PAIR_4281e2:
mov eax,dword [ebx+0x8c]
DOS_PAIR_4281e8:
sar eax,0x2
DOS_PAIR_4281eb:
neg eax
DOS_PAIR_4281ed:
mov dword [ebx+0x8c],eax
DOS_PAIR_4281f3:
mov eax,dword [ebx+0x90]
DOS_PAIR_4281f9:
sar eax,0x2
DOS_PAIR_4281fc:
neg eax
DOS_PAIR_4281fe:
mov dword [ebx+0x90],eax
DOS_PAIR_428204:
mov eax,dword [ebx+0x94]
DOS_PAIR_42820a:
sar eax,0x2
DOS_PAIR_42820d:
neg eax
DOS_PAIR_42820f:
mov dword [ebx+0x94],eax
DOS_PAIR_428215:
mov eax,dword [ebx+0x8c]
DOS_PAIR_42821b:
push eax
DOS_PAIR_42821c:
call _abs
DOS_PAIR_428221:
pop ecx
DOS_PAIR_428222:
mov esi,eax
DOS_PAIR_428224:
mov eax,dword [ebx+0x90]
DOS_PAIR_42822a:
push eax
DOS_PAIR_42822b:
call _abs
DOS_PAIR_428230:
pop ecx
DOS_PAIR_428231:
add esi,eax
DOS_PAIR_428233:
mov eax,dword [ebx+0x94]
DOS_PAIR_428239:
push eax
DOS_PAIR_42823a:
call _abs
DOS_PAIR_42823f:
pop ecx
DOS_PAIR_428240:
add esi,eax
DOS_PAIR_428242:
mov eax,esi
DOS_PAIR_428244:
add eax,0xa
DOS_PAIR_428247:
cmp dword [ebx+0x82],0xd
DOS_PAIR_42824e:
jbe DOS_PAIR_428354
DOS_PAIR_428254:
push 0x0
DOS_PAIR_428256:
push eax
DOS_PAIR_428257:
push ebx
DOS_PAIR_428258:
call FUNC_000953
DOS_PAIR_42825d:
add esp,0xc
DOS_PAIR_428260:
jmp DOS_PAIR_428354
DOS_PAIR_428265:
mov eax,dword [ebx+0x8c]
DOS_PAIR_42826b:
add eax,dword [esi+0x8c]
DOS_PAIR_428271:
sar eax,1
DOS_PAIR_428273:
mov dword [esi+0x8c],eax
DOS_PAIR_428279:
mov dword [ebx+0x8c],eax
DOS_PAIR_42827f:
mov eax,dword [ebx+0x90]
DOS_PAIR_428285:
add eax,dword [esi+0x90]
DOS_PAIR_42828b:
sar eax,1
DOS_PAIR_42828d:
mov dword [esi+0x90],eax
DOS_PAIR_428293:
mov dword [ebx+0x90],eax
DOS_PAIR_428299:
mov eax,dword [ebx+0x94]
DOS_PAIR_42829f:
add eax,dword [esi+0x94]
DOS_PAIR_4282a5:
sar eax,1
DOS_PAIR_4282a7:
mov dword [esi+0x94],eax
DOS_PAIR_4282ad:
mov dword [ebx+0x94],eax
DOS_PAIR_4282b3:
cmp byte [DATA_008700],0x0
DOS_PAIR_4282ba:
je DOS_PAIR_428354
DOS_PAIR_4282c0:
cmp dword [ebx+0x82],0xd
DOS_PAIR_4282c7:
jbe DOS_PAIR_428354
DOS_PAIR_4282cd:
cmp dword [esi+0x82],0xd
DOS_PAIR_4282d4:
jbe DOS_PAIR_428354
DOS_PAIR_4282d6:
mov ax,word [esi+0xe4]
DOS_PAIR_4282dd:
cmp ax,word [ebx+0xe4]
DOS_PAIR_4282e4:
ja DOS_PAIR_42831c
DOS_PAIR_4282e6:
xor edx,edx
DOS_PAIR_4282e8:
mov dl,byte [ebx+0x86]
DOS_PAIR_4282ee:
push edx
DOS_PAIR_4282ef:
movzx eax,ax
DOS_PAIR_4282f2:
add eax,eax
DOS_PAIR_4282f4:
push eax
DOS_PAIR_4282f5:
push esi
DOS_PAIR_4282f6:
call FUNC_000953
DOS_PAIR_4282fb:
add esp,0xc
DOS_PAIR_4282fe:
xor eax,eax
DOS_PAIR_428300:
mov al,byte [esi+0x86]
DOS_PAIR_428306:
push eax
DOS_PAIR_428307:
movzx eax,word [esi+0xe4]
DOS_PAIR_42830e:
add eax,eax
DOS_PAIR_428310:
push eax
DOS_PAIR_428311:
push ebx
DOS_PAIR_428312:
call FUNC_000953
DOS_PAIR_428317:
add esp,0xc
DOS_PAIR_42831a:
jmp DOS_PAIR_428354
DOS_PAIR_42831c:
xor eax,eax
DOS_PAIR_42831e:
mov al,byte [ebx+0x86]
DOS_PAIR_428324:
push eax
DOS_PAIR_428325:
movzx eax,word [ebx+0xe4]
DOS_PAIR_42832c:
add eax,eax
DOS_PAIR_42832e:
push eax
DOS_PAIR_42832f:
push esi
DOS_PAIR_428330:
call FUNC_000953
DOS_PAIR_428335:
add esp,0xc
DOS_PAIR_428338:
xor eax,eax
DOS_PAIR_42833a:
mov al,byte [esi+0x86]
DOS_PAIR_428340:
push eax
DOS_PAIR_428341:
movzx eax,word [ebx+0xe4]
DOS_PAIR_428348:
add eax,eax
DOS_PAIR_42834a:
push eax
DOS_PAIR_42834b:
push ebx
DOS_PAIR_42834c:
call FUNC_000953
DOS_PAIR_428351:
add esp,0xc
DOS_PAIR_428354:
pop esi
DOS_PAIR_428355:
pop ebx
DOS_PAIR_428356:
pop ebp
DOS_PAIR_428357:
ret 

FUNC_001332_Int64Abs:			; Pos = 4eb18

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp dword [ebp+0x10],byte +0x0
		jnl JUMP_005278
		push dword [ebp+0x10]
		push dword [ebp+0xc]
		push dword [DATA_007636]
		push dword [DATA_007635]
		push eax
		call FUNC_001335_Int64Sub64
		add esp,byte +0x14
		pop ebp
		ret
	JUMP_005278:			; Pos = 4eb41
		mov edx,[ebp+0xc]
		mov [eax],edx
		mov edx,[ebp+0x10]
		mov [eax+0x4],edx
		pop ebp
		ret



; void F1333 (int *rval, int64 op1, int64 op2)


FUNC_001341_Int64ArithShift:			; Pos = 4ec90

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov eax,[ebp+0xc]
		mov edx,[ebp+0x8]
		test eax,eax
		jz JUMP_005286
		test eax,eax
		jnl JUMP_005284
		neg eax
		cmp eax,byte +0x20
		jnl JUMP_005283
		mov ecx,eax
		mov ebx,[edx]
		shr ebx,cl
		mov ecx,0x20
		sub ecx,eax
		mov esi,[edx+0x4]
		shl esi,cl
		or ebx,esi
		mov [edx],ebx
		mov ecx,eax
		sar dword [edx+0x4],cl
		jmp short JUMP_005286
	JUMP_005283:			; Pos = 4ecc7
		lea ecx,[eax-0x20]
		mov eax,[edx+0x4]
		sar eax,cl
		mov [edx],eax
		sar dword [edx+0x4],0x1f
		jmp short JUMP_005286
	JUMP_005284:			; Pos = 4ecd7
		test eax,eax
		jng JUMP_005286
		cmp eax,byte +0x20
		jnl JUMP_005285
		mov ecx,eax
		mov ebx,[edx+0x4]
		shl ebx,cl
		mov ecx,0x20
		sub ecx,eax
		mov esi,[edx]
		shr esi,cl
		or ebx,esi
		mov [edx+0x4],ebx
		mov ecx,eax
		shl dword [edx],cl
		jmp short JUMP_005286
	JUMP_005285:			; Pos = 4ecfd
		lea ecx,[eax-0x20]
		mov eax,[edx]
		shl eax,cl
		mov [edx+0x4],eax
		xor eax,eax
		mov [edx],eax
	JUMP_005286:			; Pos = 4ed0b
		pop esi
		pop ebx
		pop ebp
		ret



; FF80 function prototype:
; char *FF80Func (int stringindex, StringVars *vars, char *dest)
;
; Listed in D7649
; code>>9 & 0x3f = index into D7649
; code & 0x1ff = string index
;
; StringVars - array of five vars to be used by FF30 codes
; Each FF80 func writes a string in a  (function-specific) array
; indexed by stringindex to dest, with full expansion.
;
; Call [D7641] (dest, stringindex&0x1ff, vars, char **arrayptr)
; arrayptr is specific to the function. [D7641] = F1347.
; returns end of dest string.


; FF30 function prototype:
; char *FF30Func (char *dest)
;
; Listed in D7652_PLUS_52
; code - 0x3000 = index into D7652_PLUS_52
;
; Uses vars at [D9149], writes string using one of them.
; returns end of dest string 


; FF40 codes:
; Handled by function [D7640] = F1345
; char *F1345 (char *dest, int stringindex)
;
; code & 0x3fff = stringindex 
; indexes into array at D4682 - ship strings
; Expands string into dest, returns end of dest string.



; char *F1342 (int stridx, StrVars *vars, char *dest)
; Null FF80 code function - inserts "MODULE STRING"


FUNC_001664_Vec64Abs:			; Pos = 5a154

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		push dword [esi+0x4]
		push dword [esi]
		push ebx
		call FUNC_001332_Int64Abs
		add esp,byte +0xc
		push dword [esi+0xc]
		push dword [esi+0x8]
		lea eax,[ebx+0x8]
		push eax
		call FUNC_001332_Int64Abs
		add esp,byte +0xc
		push dword [esi+0x14]
		push dword [esi+0x10]
		add ebx,byte +0x10
		push ebx
		call FUNC_001332_Int64Abs
		add esp,byte +0xc
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_999999:
ret
