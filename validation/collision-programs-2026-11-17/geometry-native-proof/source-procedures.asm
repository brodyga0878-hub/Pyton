FUNC_000576:			; Pos = 28070

		push ebp
		mov ebp,esp
		add esp,byte -0x30
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x8]
		mov byte [DATA_008697],0x0
		mov eax,[esi+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		mov edx,0x17
		sub edx,[eax+0x14]
		mov [ebp-0xc],edx
		mov eax,[eax+0x34]
		mov [ebp-0x4],eax
		mov ebx,[esi+0x140]
		mov eax,[ebp+0x10]
		push esi
		mov esi,eax
		lea edi,[ebp-0x24]
		mov ecx,0x6
		rep movsd
		pop esi
	JUMP_002433:			; Pos = 280b9
		push ebx
		lea eax,[ebp-0x24]
		push eax
		mov eax,[ebp+0xc]
		push eax
		push esi
		lea eax,[ebp-0x5]
		push eax
		call FUNC_000579
		add esp,byte +0x14
		test al,al
		jng JUMP_002434
		or byte [DATA_008697],0x80
	JUMP_002434:			; Pos = 280da
		mov dl,[DATA_008697]
		test dl,dl
		jz JUMP_002435
		mov ecx,[ebp+0xc]
		mov cl,[ecx+0x86]
		mov [DATA_008698],cl
		mov ecx,[ebp+0xc]
		mov [DATA_008702],ecx
		mov [DATA_008696],dl
		mov dl,[ebp-0x5]
		mov [DATA_008701],dl
	JUMP_002435:			; Pos = 2810b
		test al,al
		jl JUMP_002436
		xor eax,eax
		jmp JUMP_002445
	JUMP_002436:			; Pos = 28116
		cmp byte [esi+0x14c],0x0
		jl JUMP_002437
		or eax,byte -0x1
		jmp JUMP_002445
	JUMP_002437:			; Pos = 28127
		sub dword [ebp-0x4],byte +0x2
		mov eax,[ebp-0x4]
		movsx eax,word [eax]
		test eax,eax
		jnz JUMP_002438
		or eax,byte -0x1
		jmp JUMP_002445
	JUMP_002438:			; Pos = 2813d
		sub dword [ebp-0x4],byte +0x2
		mov edx,[ebp-0x4]
		movsx ebx,word [edx]
		mov edx,ebx
		and edx,byte +0x6
		sub edx,byte +0x1
		jc JUMP_002439
		dec edx
		jz JUMP_002440
		sub edx,byte +0x2
		jz JUMP_002441
		jmp short JUMP_002442
	JUMP_002439:			; Pos = 2815b
		mov edx,[esi]
		mov [ebp-0x30],edx
		mov edx,[esi+0x4]
		mov [ebp-0x2c],edx
		mov edx,[esi+0x8]
		mov [ebp-0x28],edx
		jmp short JUMP_002442
	JUMP_002440:			; Pos = 2816e
		mov edx,[esi+0xc]
		mov [ebp-0x30],edx
		mov edx,[esi+0x10]
		mov [ebp-0x2c],edx
		mov edx,[esi+0x14]
		mov [ebp-0x28],edx
		jmp short JUMP_002442
	JUMP_002441:			; Pos = 28182
		mov edx,[esi+0x18]
		mov [ebp-0x30],edx
		mov edx,[esi+0x1c]
		mov [ebp-0x2c],edx
		mov edx,[esi+0x20]
		mov [ebp-0x28],edx
	JUMP_002442:			; Pos = 28194
		test bl,0x1
		jz JUMP_002443
		neg dword [ebp-0x30]
		neg dword [ebp-0x2c]
		neg dword [ebp-0x28]
	JUMP_002443:			; Pos = 281a2
		mov edx,[ebp-0x30]
		sar edx,0x10
		imul edx,eax
		mov [ebp-0x30],edx
		mov edx,[ebp-0x2c]
		sar edx,0x10
		imul edx,eax
		mov [ebp-0x2c],edx
		mov edx,[ebp-0x28]
		sar edx,0x10
		imul edx,eax
		mov [ebp-0x28],edx
		and ebx,0xfff8
		shl ebx,0xf
		cmp dword [ebp-0xc],byte +0x0
		jz JUMP_002444
		mov ecx,[ebp-0xc]
		sar dword [ebp-0x30],cl
		mov ecx,[ebp-0xc]
		sar dword [ebp-0x2c],cl
		mov ecx,[ebp-0xc]
		sar dword [ebp-0x28],cl
		mov ecx,[ebp-0xc]
		sar ebx,cl
	JUMP_002444:			; Pos = 281ec
		mov eax,[ebp-0x30]
		push eax
		mov eax,[ebp+0x10]
		push dword [eax+0x4]
		push dword [eax]
		lea eax,[ebp-0x24]
		push eax
		call FUNC_001334_Int64Add32
		add esp,byte +0x10
		mov eax,[ebp-0x2c]
		push eax
		mov eax,[ebp+0x10]
		push dword [eax+0xc]
		push dword [eax+0x8]
		lea eax,[ebp-0x1c]
		push eax
		call FUNC_001334_Int64Add32
		add esp,byte +0x10
		mov eax,[ebp-0x28]
		push eax
		mov eax,[ebp+0x10]
		push dword [eax+0x14]
		push dword [eax+0x10]
		lea eax,[ebp-0x14]
		push eax
		call FUNC_001334_Int64Add32
		add esp,byte +0x10
		jmp JUMP_002433

	JUMP_002445:			; Pos = 2823b
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000579:			; Pos = 28550

		push ebp
		mov ebp,esp
		add esp,byte -0x1c
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x14]
		mov edi,[ebp+0x10]
		mov eax,[edi+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		mov ebx,eax
		mov eax,[ebx+0xc]
		mov [ebp-0x10],eax
		mov eax,[ebx+0x4]
		mov [ebp-0xc],eax
		mov eax,[ebx+0x14]
		add eax,[ebx+0x18]
		mov [ebp-0x8],eax
		push byte +0x1c
		push esi
		call FUNC_001658_Vec64Truncate
		add esp,byte +0x8
		mov edx,[esi]
		mov [ebp-0x1c],edx
		mov edx,[esi+0x8]
		mov [ebp-0x18],edx
		mov edx,[esi+0x10]
		mov [ebp-0x14],edx
		mov [ebp-0x4],eax
		mov edx,[ebp-0x8]
		add edx,byte -0x17
		sub eax,edx
		test eax,eax
		jnl JUMP_002458
		neg eax
		add [ebp-0x4],eax
		mov ecx,eax
		sar dword [ebp-0x1c],cl
		mov ecx,eax
		sar dword [ebp-0x18],cl
		mov ecx,eax
		sar dword [ebp-0x14],cl
	JUMP_002458:			; Pos = 285c3
		mov eax,[ebp-0x4]
		test eax,eax
		jnl JUMP_002459
		mov ecx,eax
		neg ecx
		shl dword [ebp+0x18],cl
		jmp short JUMP_002460
	JUMP_002459:			; Pos = 285d3
		test eax,eax
		jng JUMP_002460
		mov ecx,eax
		sar dword [ebp+0x18],cl
	JUMP_002460:			; Pos = 285dc
		mov eax,[ebp+0xc]
		cmp byte [eax+0x57],0x0
		jz JUMP_002461
		mov eax,[ebp+0xc]
		mov al,[eax+0x56]
		cmp al,[edi+0x86]
		jz JUMP_002462
	JUMP_002461:			; Pos = 285f3
		push edi
		lea eax,[ebp-0x1c]
		push eax
		lea eax,[ebp-0x1c]
		push eax
		call FUNC_001670_VecMatTMul
		add esp,byte +0xc
	JUMP_002462:			; Pos = 28604
		mov eax,[ebp+0x18]
		push eax
		push edi
		mov eax,[ebx+0x34]
		push eax
		lea eax,[ebp-0x1c]
		push eax
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000582
		add esp,byte +0x14
		movsx eax,al
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001334_Int64Add32:			; Pos = 4eb67

		push ebp
		mov ebp,esp
		push ecx
		mov ecx,[ebp+0x8]
		mov eax,[ebp+0x14]
		cdq
		add eax,[ebp+0xc]
		mov [ecx],eax
		adc edx,[ebp+0x10]
		mov [ecx+0x4],edx
		pop ecx
		pop ebp
		ret



; void F1335 (int64 *rval, int64 op1, int64 op2)


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
