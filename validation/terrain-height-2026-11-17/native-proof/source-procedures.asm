FUNC_000581:			; Pos = 287e4

		push ebp
		mov ebp,esp
		add esp,0xffffff70
		push ebx
		push esi
		push edi
		mov eax,[ebp+0xc]
		movzx eax,byte [eax]
		mov edx,[ebp+0xc]
		movzx edx,byte [edx+0x1]

		mov ecx,[ebp+0xc]
		xor ebx,ebx
		mov bl,[ecx+0x2]

		mov ecx,[ebp+0xc]
		movzx ecx,byte [ecx+0x3]
		mov [ebp-0x4],ecx

		mov ecx,[ebp+0xc]
		movzx ecx,byte [ecx+0x5]
		shl ecx,0x8
		mov esi,[ebp+0xc]
		movzx esi,byte [esi+0x4]
		or ecx,esi
		mov [ebp-0x8],ecx
		mov byte [DATA_008707],0xff
		mov ecx,eax
		sar ecx,1
		lea ecx,[ecx+ecx*2]
		mov esi,[ebp+0x18]
		mov esi,[esi+0x10]
		mov edi,[esi+ecx*2]
		mov [ebp-0x10],edi
		mov di,[esi+ecx*2+0x4]
		mov [ebp-0xc],di
		test al,0x1
		jz JUMP_002478
		movsx eax,byte [ebp-0xe]
		neg eax
		mov [ebp-0x30],eax
		jmp short JUMP_002479
	JUMP_002478:			; Pos = 28857
		movsx eax,byte [ebp-0xe]
		mov [ebp-0x30],eax
	JUMP_002479:			; Pos = 2885e
		movsx eax,byte [ebp-0xd]
		mov [ebp-0x2c],eax
		movsx eax,byte [ebp-0xc]
		mov [ebp-0x28],eax
		mov eax,edx
		sar eax,1
		lea eax,[eax+eax*2]
		mov ecx,[ebp+0x18]
		mov ecx,[ecx+0x10]
		mov esi,[ecx+eax*2]
		mov [ebp-0x10],esi
		mov si,[ecx+eax*2+0x4]
		mov [ebp-0xc],si
		test dl,0x1
		jz JUMP_002480
		movsx eax,byte [ebp-0xe]
		neg eax
		mov [ebp-0x78],eax
		jmp short JUMP_002481
	JUMP_002480:			; Pos = 28898
		movsx eax,byte [ebp-0xe]
		mov [ebp-0x78],eax
	JUMP_002481:			; Pos = 2889f
		movsx eax,byte [ebp-0xd]
		mov [ebp-0x74],eax
		movsx eax,byte [ebp-0xc]
		mov [ebp-0x70],eax
		mov eax,ebx
		sar eax,1
		lea eax,[eax+eax*2]
		mov edx,[ebp+0x18]
		mov edx,[edx+0x10]
		mov ecx,[edx+eax*2]
		mov [ebp-0x10],ecx
		mov cx,[edx+eax*2+0x4]
		mov [ebp-0xc],cx
		test bl,0x1
		jz JUMP_002482
		movsx eax,byte [ebp-0xe]
		neg eax
		mov [ebp-0x6c],eax
		jmp short JUMP_002483
	JUMP_002482:			; Pos = 288d9
		movsx eax,byte [ebp-0xe]
		mov [ebp-0x6c],eax
	JUMP_002483:			; Pos = 288e0
		movsx eax,byte [ebp-0xd]
		mov [ebp-0x68],eax
		movsx eax,byte [ebp-0xc]
		mov [ebp-0x64],eax
		mov eax,[ebp-0x4]
		sar eax,1
		lea eax,[eax+eax*2]
		mov edx,[ebp+0x18]
		mov edx,[edx+0x10]
		mov ecx,[edx+eax*2]
		mov [ebp-0x10],ecx
		mov cx,[edx+eax*2+0x4]
		mov [ebp-0xc],cx
		test byte [ebp-0x4],0x1
		jz JUMP_002484
		movsx eax,byte [ebp-0xe]
		neg eax
		mov [ebp-0x60],eax
		jmp short JUMP_002485
	JUMP_002484:			; Pos = 2891c
		movsx eax,byte [ebp-0xe]
		mov [ebp-0x60],eax
	JUMP_002485:			; Pos = 28923
		movsx eax,byte [ebp-0xd]
		mov [ebp-0x5c],eax
		movsx eax,byte [ebp-0xc]
		mov [ebp-0x58],eax
		mov eax,[ebp+0x18]
		mov eax,[eax+0x14]
		mov edx,[ebp+0x18]
		sub eax,[edx+0x18]
		test eax,eax
		jnl JUMP_002486
		neg eax
		mov ecx,eax
		sar dword [ebp-0x30],cl
		mov ecx,eax
		sar dword [ebp-0x2c],cl
		mov ecx,eax
		sar dword [ebp-0x28],cl
		mov ecx,eax
		sar dword [ebp-0x78],cl
		mov ecx,eax
		sar dword [ebp-0x74],cl
		mov ecx,eax
		sar dword [ebp-0x70],cl
		mov ecx,eax
		sar dword [ebp-0x6c],cl
		mov ecx,eax
		sar dword [ebp-0x68],cl
		mov ecx,eax
		sar dword [ebp-0x64],cl
		mov ecx,eax
		sar dword [ebp-0x60],cl
		mov ecx,eax
		sar dword [ebp-0x5c],cl
		mov ecx,eax
		sar dword [ebp-0x58],cl
		jmp short JUMP_002487
	JUMP_002486:			; Pos = 28981
		mov ecx,eax
		shl dword [ebp-0x30],cl
		mov ecx,eax
		shl dword [ebp-0x2c],cl
		mov ecx,eax
		shl dword [ebp-0x28],cl
		mov ecx,eax
		shl dword [ebp-0x78],cl
		mov ecx,eax
		shl dword [ebp-0x74],cl
		mov ecx,eax
		shl dword [ebp-0x70],cl
		mov ecx,eax
		shl dword [ebp-0x6c],cl
		mov ecx,eax
		shl dword [ebp-0x68],cl
		mov ecx,eax
		shl dword [ebp-0x64],cl
		mov ecx,eax
		shl dword [ebp-0x60],cl
		mov ecx,eax
		shl dword [ebp-0x5c],cl
		mov ecx,eax
		shl dword [ebp-0x58],cl
	JUMP_002487:			; Pos = 289bd
		mov eax,[ebp-0x30]
		neg eax
		add [ebp-0x78],eax
		mov edx,[ebp-0x2c]
		neg edx
		add [ebp-0x74],edx
		mov ecx,[ebp-0x28]
		neg ecx
		add [ebp-0x70],ecx

		mov ebx,[ebp-0x30]
		neg ebx
		add [ebp-0x6c],eax
		mov ebx,[ebp-0x2c]
		neg ebx
		add [ebp-0x68],edx
		mov ebx,[ebp-0x28]
		neg ebx
		add [ebp-0x64],ecx

		mov ebx,[ebp-0x30]
		neg ebx
		add [ebp-0x60],eax
		mov eax,[ebp-0x2c]
		neg eax
		add [ebp-0x5c],edx
		mov eax,[ebp-0x28]
		neg eax
		add [ebp-0x58],ecx

		mov eax,[ebp+0x18]
		mov eax,[eax]
		sub [ebp-0x30],eax
		mov eax,[ebp+0x18]
		mov eax,[eax+0x4]
		sub [ebp-0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax+0x8]
		sub [ebp-0x28],eax

		lea eax,[ebp-0x30]
		push eax
		call FUNC_001466
		pop ecx
		mov [ebp-0x14],eax
		mov eax,[ebp+0x10]
		mov edx,[eax+0x138]
		mov [ebp-0x20],edx
		mov edx,[eax+0x13c]
		mov [ebp-0x1c],edx

		mov eax,[ebp+0x18]
		mov eax,[eax+0x18]
		neg eax
		push eax
		lea eax,[ebp-0x20]
		push eax
		call FUNC_001341_Int64ArithShift
		add esp,byte +0x8

		mov eax,[ebp-0x14]
		sub eax,[ebp-0x20]
		cmp eax,[ebp+0x14]
		jl JUMP_002488
		mov eax,[ebp+0x8]
		mov dword [eax],0xffffffff
		mov byte [DATA_008707],0x0
		mov eax,[ebp+0xc]
		add eax,byte +0x6
		push eax
		call FUNC_001822
		pop ecx
		jmp JUMP_002508
	JUMP_002488:			; Pos = 28a83
		mov eax,[ebp+0x10]
		mov edx,[eax+0x140]
		mov [ebp-0x20],edx
		mov edx,[eax+0x144]
		mov [ebp-0x1c],edx
		mov eax,[ebp+0x18]
		mov eax,[eax+0x18]
		neg eax
		push eax
		lea eax,[ebp-0x20]
		push eax
		call FUNC_001341_Int64ArithShift
		add esp,byte +0x8
		mov eax,[ebp-0x14]
		sub eax,[ebp-0x20]
		cmp eax,[ebp+0x14]
		jg JUMP_002489
		mov eax,[ebp+0x8]
		xor edx,edx
		mov [eax],edx
		mov byte [DATA_008707],0x1
		mov eax,[ebp+0xc]
		add eax,byte +0x6
		push eax
		call FUNC_001822
		pop ecx
		jmp JUMP_002508
	JUMP_002489:			; Pos = 28ad8
		mov eax,[ebp-0x30]
		test eax,eax
		jz near JUMP_002496
		mov [ebp+0xffffff7c],eax
		mov eax,[ebp-0x2c]
		mov [ebp-0x80],eax
		xor eax,eax
		mov [ebp-0x7c],eax
		lea eax,[ebp+0xffffff7c]
		push eax
		call FUNC_001466
		pop ecx
		mov edi,eax
		mov ebx,[ebp+0xffffff7c]
		test ebx,ebx
		jnl JUMP_002491
		push edi
		neg ebx
		push ebx
		call FUNC_001523
		add esp,byte +0x8
		mov ebx,eax
		test ebx,ebx
		jnl JUMP_002490
		mov ebx,0x7fffffff
	JUMP_002490:			; Pos = 28b24
		neg ebx
		jmp short JUMP_002492
	JUMP_002491:			; Pos = 28b28
		push edi
		mov eax,[ebp+0xffffff7c]
		push eax
		call FUNC_001523
		add esp,byte +0x8
		mov ebx,eax
		test ebx,ebx
		jnl JUMP_002492
		mov ebx,0x7fffffff
	JUMP_002492:			; Pos = 28b43
		mov esi,[ebp-0x80]
		test esi,esi
		jnl JUMP_002494
		push edi
		neg esi
		push esi
		call FUNC_001523
		add esp,byte +0x8
		mov esi,eax
		test esi,esi
		jnl JUMP_002493
		mov esi,0x7fffffff
	JUMP_002493:			; Pos = 28b61
		neg esi
		jmp short JUMP_002495
	JUMP_002494:			; Pos = 28b65
		push edi
		mov eax,[ebp-0x80]
		push eax
		call FUNC_001523
		add esp,byte +0x8
		mov esi,eax
		test esi,esi
		jnl JUMP_002495
		mov esi,0x7fffffff
	JUMP_002495:			; Pos = 28b7d
		mov [ebp-0x54],esi
		mov [ebp-0x50],ebx
		xor eax,eax
		mov [ebp-0x4c],eax
		neg ebx
		mov [ebp-0x48],ebx
		mov [ebp-0x44],esi
		xor eax,eax
		mov [ebp-0x40],eax
		xor eax,eax
		mov [ebp-0x3c],eax
		xor eax,eax
		mov [ebp-0x38],eax
		mov dword [ebp-0x34],0x7fffffff
		mov [ebp-0x2c],edi
		jmp short JUMP_002497
	JUMP_002496:			; Pos = 28bab
		mov dword [ebp-0x54],0x7fffffff
		xor eax,eax
		mov [ebp-0x50],eax
		xor eax,eax
		mov [ebp-0x4c],eax
		xor eax,eax
		mov [ebp-0x48],eax
		mov dword [ebp-0x44],0x7fffffff
		xor eax,eax
		mov [ebp-0x40],eax
		xor eax,eax
		mov [ebp-0x3c],eax
		xor eax,eax
		mov [ebp-0x38],eax
		mov dword [ebp-0x34],0x7fffffff

	JUMP_002497:			; Pos = 28bde
		mov eax,[ebp-0x2c]
		test eax,eax
		jz near JUMP_002504
		xor edx,edx
		mov [ebp+0xffffff70],edx
		mov [ebp+0xffffff74],eax
		mov eax,[ebp-0x28]
		mov [ebp+0xffffff78],eax
		lea eax,[ebp+0xffffff70]
		push eax
		call FUNC_001466
		pop ecx
		mov edi,eax
		mov ebx,[ebp+0xffffff74]
		test ebx,ebx
		jnl JUMP_002499
		push edi
		neg ebx
		push ebx
		call FUNC_001523
		add esp,byte +0x8
		mov ebx,eax
		test ebx,ebx
		jnl JUMP_002498
		mov ebx,0x7fffffff
	JUMP_002498:			; Pos = 28c30
		neg ebx
		jmp short JUMP_002500
	JUMP_002499:			; Pos = 28c34
		push edi
		mov eax,[ebp+0xffffff74]
		push eax
		call FUNC_001523
		add esp,byte +0x8
		mov ebx,eax
		test ebx,ebx
		jnl JUMP_002500
		mov ebx,0x7fffffff
	JUMP_002500:			; Pos = 28c4f
		mov esi,[ebp+0xffffff78]
		test esi,esi
		jnl JUMP_002502
		push edi
		neg esi
		push esi
		call FUNC_001523
		add esp,byte +0x8
		mov esi,eax
		test esi,esi
		jnl JUMP_002501
		mov esi,0x7fffffff
	JUMP_002501:			; Pos = 28c70
		neg esi
		jmp short JUMP_002503
	JUMP_002502:			; Pos = 28c74
		push edi
		mov eax,[ebp+0xffffff78]
		push eax
		call FUNC_001523
		add esp,byte +0x8
		mov esi,eax
		test esi,esi
		jnl JUMP_002503
		mov esi,0x7fffffff
	JUMP_002503:			; Pos = 28c8f
		push ebx
		mov eax,[ebp-0x50]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp-0x4c],eax
		push esi
		mov eax,[ebp-0x50]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp-0x50],eax

		push ebx
		mov eax,[ebp-0x44]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp-0x40],eax
		push esi
		mov eax,[ebp-0x44]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebp-0x44],eax

		neg ebx
		mov [ebp-0x38],ebx
		mov [ebp-0x34],esi

	JUMP_002504:			; Pos = 28cd7
		xor eax,eax
		mov [ebp-0x30],eax
		xor eax,eax
		mov [ebp-0x2c],eax
		mov eax,[ebp-0x14]
		mov [ebp-0x28],eax
		lea eax,[ebp-0x54]
		push eax
		lea eax,[ebp-0x78]
		push eax
		lea eax,[ebp-0x78]
		push eax
		call FUNC_001669_VecMatMul
		add esp,byte +0xc
		lea eax,[ebp-0x54]
		push eax
		lea eax,[ebp-0x6c]
		push eax
		lea eax,[ebp-0x6c]
		push eax
		call FUNC_001669_VecMatMul
		add esp,byte +0xc
		lea eax,[ebp-0x54]
		push eax
		lea eax,[ebp-0x60]
		push eax
		lea eax,[ebp-0x60]
		push eax
		call FUNC_001669_VecMatMul
		add esp,byte +0xc

		push byte +0x1
		push byte +0x0
		push byte +0x0
		push byte +0x0
		mov eax,[ebp-0x8]
		push eax
		lea eax,[ebp-0x78]
		push eax
		lea eax,[ebp-0x30]
		push eax
		mov eax,[ebp+0xc]
		add eax,byte +0x6
		push eax
		push byte +0x0
		mov eax,[ebp+0x10]
		push eax
		mov eax,[ebp+0x18]
		mov ecx,[eax+0x18]
		mov eax,0x77359400
		sar eax,cl
		push eax
		lea eax,[ebp-0x18]
		push eax
		call FUNC_001876
		add esp,byte +0x30

		mov [ebp+0xc],eax
		xor eax,eax
		mov edx,[ebp+0x14]
		sar edx,0x10
		cmp edx,[ebp-0x18]
		jg JUMP_002505
		dec eax
	JUMP_002505:			; Pos = 28d6f
		mov edx,[ebp+0x8]
		mov [edx],eax

		mov eax,[ebp+0x18]
		mov eax,[eax+0x18]
		mov ecx,eax
		mov edx,0x77359400
		sar edx,cl
		cmp edx,[ebp-0x18]
		jng JUMP_002506
		mov edx,[ebp-0x18]
		mov [DATA_008703],edx
		mov edx,[ebp-0x18]
		sar edx,0x1f
		mov [DATA_008704],edx
		push eax
		push dword DATA_008703
		call FUNC_001341_Int64ArithShift
		add esp,byte +0x8
	JUMP_002506:			; Pos = 28dab
		mov eax,[DATA_008703]
		mov [DATA_008705],eax
		mov eax,[DATA_008704]
		mov [DATA_008706],eax
		mov eax,[ebp+0x8]
		cmp dword [eax],byte +0x0
		jnz JUMP_002507
		xor eax,eax
		mov [DATA_008703],eax
		xor eax,eax
		mov [DATA_008704],eax
		mov byte [DATA_008707],0x1
	JUMP_002507:			; Pos = 28de0
		mov eax,[ebp+0xc]
	JUMP_002508:			; Pos = 28de3
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




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


FUNC_001339_Int64MulCreate:			; Pos = 4ebfb

		push ebp
		mov ebp,esp
		push ecx
		mov eax,[ebp+0xc]
		imul dword [ebp+0x10]
		mov ecx,[ebp+0x8]
		mov [ecx],eax
		mov [ecx+0x4],edx
		pop ecx
		pop ebp
		ret



; void F1340 (int64 *val, int shift)


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


FUNC_001465:			; Pos = 51208

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
		mov eax,[ebx]
		imul dword [ebx]
		mov edx,[ebx+0x4]
		imul edx,[ebx+0x4]
		add eax,edx
		mov edx,[ebx+0x8]
		imul edx,[ebx+0x8]
		add eax,edx
		push eax
		call FUNC_001467
		pop ecx
		pop ebx
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




FUNC_001467:			; Pos = 5133f

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp eax,0x4000000
		jnc JUMP_005498
		cmp eax,0x400000
		jc JUMP_005494
		shr eax,0xf
		movzx eax,word [eax*2+DATA_007977]
		sar eax,0x3
		pop ebp
		ret
	JUMP_005494:			; Pos = 51363
		cmp eax,0x40000
		jc JUMP_005495
		shr eax,0xb
		movzx eax,word [eax*2+DATA_007977]
		sar eax,0x5
		pop ebp
		ret
	JUMP_005495:			; Pos = 5137a
		cmp eax,0x4000
		jc JUMP_005496
		shr eax,0x7
		movzx eax,word [eax*2+DATA_007977]
		sar eax,0x7
		pop ebp
		ret
	JUMP_005496:			; Pos = 51391
		cmp eax,0x400
		jc JUMP_005497
		shr eax,0x3
		movzx eax,word [eax*2+DATA_007977]
		sar eax,0x9
		pop ebp
		ret
	JUMP_005497:			; Pos = 513a8
		add eax,eax
		movzx eax,word [eax*2+DATA_007977]
		sar eax,0xb
		pop ebp
		ret
	JUMP_005498:			; Pos = 513b7
		cmp eax,0x40000000
		jc JUMP_005499
		shr eax,0x15
		movzx eax,word [eax*2+DATA_007977]
		pop ebp
		ret
	JUMP_005499:			; Pos = 513cb
		cmp eax,0x10000000
		jc JUMP_005500
		shr eax,0x13
		movzx eax,word [eax*2+DATA_007977]
		sar eax,1
		pop ebp
		ret
	JUMP_005500:			; Pos = 513e1
		shr eax,0x11
		movzx eax,word [eax*2+DATA_007977]
		sar eax,0x2
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




FUNC_001669_VecMatMul:			; Pos = 5a7a8

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
		mov eax,[esi+0xc]
		push eax
		mov eax,[ebx+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[esi+0x18]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x4],edx

		mov eax,[esi+0x4]
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
		mov eax,[esi+0x1c]
		push eax
		mov eax,[ebx+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [ebp-0x8],edx

		mov eax,[esi+0x8]
		push eax
		mov eax,[ebx]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[esi+0x14]
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




FUNC_001816:			; Pos = 623ac

		push ebx
		push esi
		push edi
		mov ecx,DATA_009274
		mov ebx,DATA_009277
		cmp dword [DATA_009272],byte +0x0
		jnz JUMP_006975
		mov [DATA_009272],ecx
		xor eax,eax
		mov edx,ecx
	JUMP_006973:			; Pos = 623cc
		mov esi,eax
		shl esi,0x3
		lea esi,[esi+esi*8]
		lea edi,[ecx+0x48]
		add esi,edi
		mov [edx],esi
		inc eax
		add edx,byte +0x48
		cmp eax,0x5db
		jl JUMP_006973
		xor eax,eax
		mov [ecx+0x1a598],eax
		mov [DATA_009275],ebx
		xor eax,eax
		mov edx,ebx
	JUMP_006974:			; Pos = 623f8
		mov ecx,eax
		shl ecx,0x4
		lea esi,[ebx+0x10]
		add ecx,esi
		mov [edx],ecx
		inc eax
		add edx,byte +0x10
		cmp eax,0xbb7
		jl JUMP_006974
		xor eax,eax
		mov [ebx+0xbb70],eax
		xor eax,eax
		mov [DATA_009273],eax
		xor eax,eax
		mov [DATA_009276],eax
	JUMP_006975:			; Pos = 62425
		pop edi
		pop esi
		pop ebx
		ret




FUNC_001817:			; Pos = 6242c

		xor eax,eax
		mov [DATA_009272],eax
		ret




FUNC_001818:			; Pos = 62434

		push ebx
		mov ebx,[DATA_009272]
		inc dword [DATA_009273]
		cmp dword [DATA_009273],0x5dc
		jl JUMP_006976
		push byte +0x1
		push dword DATA_009271
		call _LongJmp
		add esp,byte +0x8
	JUMP_006976:			; Pos = 6245c
		mov eax,[DATA_009272]
		mov eax,[eax]
		mov [DATA_009272],eax
		mov eax,ebx
		pop ebx
		ret




FUNC_001819:			; Pos = 6246c

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		dec dword [DATA_009273]
		mov edx,[DATA_009272]
		mov [eax],edx
		mov [DATA_009272],eax
		pop ebp
		ret




FUNC_001820:			; Pos = 62488

		push ebx
		mov eax,[DATA_009275]
		mov ebx,eax
		mov eax,[eax]
		mov [DATA_009275],eax
		inc dword [DATA_009276]
		cmp dword [DATA_009276],0xbb8
		jl JUMP_006977
		push byte +0x2
		push dword DATA_009271
		call _LongJmp
		add esp,byte +0x8
	JUMP_006977:			; Pos = 624b8
		xor eax,eax
		mov [ebx+0x4],eax
		xor eax,eax
		mov [ebx+0xc],eax
		xor eax,eax
		mov [ebx+0x8],eax
		mov eax,ebx
		pop ebx
		ret
		nop




FUNC_001821:			; Pos = 624cc

		push ebp
		mov ebp,esp
		push ebx
		mov ebx,[ebp+0x8]
	JUMP_006978:			; Pos = 624d3
		mov eax,[ebx+0x4]
		test eax,eax
		jz JUMP_006979
		push eax
		call FUNC_001821
		pop ecx
	JUMP_006979:			; Pos = 624e1
		mov eax,[ebx+0x8]
		test eax,eax
		jz JUMP_006980
		push eax
		call FUNC_001819
		pop ecx
	JUMP_006980:			; Pos = 624ef
		dec dword [DATA_009276]
		mov eax,[DATA_009275]
		mov [ebx],eax
		mov [DATA_009275],ebx
		mov ebx,[ebx+0xc]
		test ebx,ebx
		jnz JUMP_006978
		pop ebx
		pop ebp
		ret




FUNC_001822:			; Pos = 6250c

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		movsx edx,word [eax]
		test edx,edx
		jz JUMP_006982
	JUMP_006981:			; Pos = 62519
		add eax,byte +0x10
		movsx edx,word [eax]
		test edx,edx
		jnz JUMP_006981
	JUMP_006982:			; Pos = 62523
		add eax,byte +0x2
		pop ebp
		ret




FUNC_001823:			; Pos = 62528

		push ebp
		mov ebp,esp
		add esp,byte -0x1c
		push ebx
		push esi
		mov dword [ebp-0x10],0x58
		mov dword [ebp-0x14],DATA_009258
		xor edx,edx
		mov eax,[ebp-0x14]
		add eax,byte +0x8
	JUMP_006983:			; Pos = 62546
		xor ecx,ecx
		mov [eax],ecx
		inc edx
		add eax,byte +0x4
		cmp edx,byte +0x14
		jl JUMP_006983
		xor edx,edx
		mov eax,[ebp-0x14]
	JUMP_006984:			; Pos = 62558
		xor ecx,ecx
		mov [eax],ecx
		inc edx
		add eax,byte +0x4
		cmp edx,byte +0x2
		jl JUMP_006984
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov [ebp-0x4],eax
		cmp dword [ebp-0x4],byte +0x0
		jz near JUMP_006998
	JUMP_006985:			; Pos = 62578
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov [ebp-0xc],eax
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		mov [ebp-0x18],eax
		mov ecx,0x10
		sub ecx,[ebp-0x18]
		mov eax,[ebp-0x4]
		shl eax,cl
		and eax,0xffff
		mov [ebp-0x4],eax
		mov ebx,[ebp-0x14]
		mov eax,[ebp-0x18]
		add eax,byte -0x3
		sar eax,1
		jns JUMP_006986
		adc eax,byte +0x0
	JUMP_006986:			; Pos = 625b4
		mov [ebp-0x18],eax
		cmp dword [ebp-0x18],byte +0x0
		jng near JUMP_006994
	JUMP_006987:			; Pos = 625c1
		mov eax,[ebp-0x4]
		shr eax,0xb
		mov [ebp-0x8],eax
		mov [ebp-0x1c],ebx
		mov eax,[ebp-0x1c]
		mov edx,[ebp-0x8]
		mov ebx,[eax+edx*4+0x8]
		test ebx,ebx
		jnz JUMP_006993
		mov ebx,DATA_009258
		add ebx,[ebp-0x10]
		mov eax,[ebp-0x10]
		add eax,byte +0x18
		mov [ebp-0x10],eax
		xor edx,edx
		lea eax,[ebx+0x8]
	JUMP_006988:			; Pos = 625f1
		xor ecx,ecx
		mov [eax],ecx
		inc edx
		add eax,byte +0x4
		cmp edx,byte +0x4
		jl JUMP_006988
		xor edx,edx
		mov ecx,ebx
		mov eax,[ebp-0x1c]
	JUMP_006989:			; Pos = 62605
		mov esi,[eax]
		test esi,esi
		jng JUMP_006990
		lea esi,[esi+esi*2]
		mov esi,[esi*4+DATA_007842]
		dec esi
		neg esi
		mov [ecx],esi
		jmp short JUMP_006992
	JUMP_006990:			; Pos = 6261c
		mov esi,[eax]
		test esi,esi
		jnl JUMP_006991
		inc esi
		mov [ecx],esi
		jmp short JUMP_006992
	JUMP_006991:			; Pos = 62627
		xor esi,esi
		mov [ecx],esi
	JUMP_006992:			; Pos = 6262b
		inc edx
		add ecx,byte +0x4
		add eax,byte +0x4
		cmp edx,byte +0x2
		jl JUMP_006989
		mov eax,[ebp-0x1c]
		mov edx,[ebp-0x8]
		mov [eax+edx*4+0x8],ebx
	JUMP_006993:			; Pos = 62641
		mov eax,[ebp-0x4]
		shl eax,0x2
		and eax,0x1fff
		mov [ebp-0x4],eax
		dec dword [ebp-0x18]
		cmp dword [ebp-0x18],byte +0x0
		jg near JUMP_006987
	JUMP_006994:			; Pos = 6265c
		xor edx,edx
		mov eax,ebx
	JUMP_006995:			; Pos = 62660
		cmp dword [eax],byte +0x0
		jz JUMP_006996
		inc edx
		add eax,byte +0x4
		cmp edx,byte +0x2
		jl JUMP_006995
	JUMP_006996:			; Pos = 6266e
		cmp edx,byte +0x2
		jnl JUMP_006997
		mov eax,DATA_009258
		add eax,[ebp-0x10]
		mov ecx,[ebp-0x10]
		add ecx,byte +0x10
		mov [ebp-0x10],ecx
		mov [ebx+edx*4],eax
		mov edx,[ebp-0xc]
		mov [eax],edx
		mov edx,[ebp+0xc]
		mov dx,[edx+0x4]
		mov [eax+0x4],dx
		mov edx,[ebp+0xc]
		mov dx,[edx+0x6]
		mov [eax+0x6],dx
		mov edx,[ebp+0xc]
		mov dx,[edx+0x8]
		mov [eax+0x8],dx
		mov edx,[ebp+0xc]
		mov dx,[edx+0xa]
		mov [eax+0xa],dx
		mov edx,[ebp+0xc]
		mov dx,[edx+0xc]
		mov [eax+0xc],dx
		mov edx,[ebp+0xc]
		mov dx,[edx+0xe]
		mov [eax+0xe],dx
	JUMP_006997:			; Pos = 626ce
		add dword [ebp+0xc],byte +0x10
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov [ebp-0x4],eax
		cmp dword [ebp-0x4],byte +0x0
		jnz near JUMP_006985
	JUMP_006998:			; Pos = 626e5
		mov eax,[ebp+0x8]
		mov edx,[ebp-0x14]
		mov [eax],edx
		mov eax,[ebp+0xc]
		add eax,byte +0x2
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001824:			; Pos = 626fc

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,eax
		shr edx,0x1b
		mov ecx,eax
		shl ecx,0x5
		or edx,ecx
		add edx,eax
		mov ecx,edx
		shr ecx,0x10
		shl edx,0x10
		or ecx,edx
		add eax,ecx
		pop ebp
		ret




FUNC_001825:			; Pos = 62720

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp dword [eax],byte +0x0
		jnl JUMP_006999
		mov edx,[eax]
		neg edx
		jmp short JUMP_007000
	JUMP_006999:			; Pos = 62731
		mov edx,[eax]
	JUMP_007000:			; Pos = 62733
		cmp dword [eax+0x4],byte +0x0
		jnl JUMP_007001
		mov ecx,[eax+0x4]
		neg ecx
		jmp short JUMP_007002
	JUMP_007001:			; Pos = 62740
		mov ecx,[eax+0x4]
	JUMP_007002:			; Pos = 62743
		or edx,ecx
		cmp dword [eax+0x8],byte +0x0
		jnl JUMP_007003
		mov ecx,[eax+0x8]
		neg ecx
		jmp short JUMP_007004
	JUMP_007003:			; Pos = 62752
		mov ecx,[eax+0x8]
	JUMP_007004:			; Pos = 62755
		or edx,ecx
		push edx
		call FUNC_001656_FindMSB
		pop ecx
		pop ebp
		ret




FUNC_001826:			; Pos = 62760

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ebx,[ebp+0xc]
		mov esi,[ebp+0x8]
		cmp dword [ebx],byte +0x0
		jnl JUMP_007005
		mov eax,[ebx]
		neg eax
		jmp short JUMP_007006
	JUMP_007005:			; Pos = 62776
		mov eax,[ebx]
	JUMP_007006:			; Pos = 62778
		cmp dword [ebx+0x4],byte +0x0
		jnl JUMP_007007
		mov edx,[ebx+0x4]
		neg edx
		jmp short JUMP_007008
	JUMP_007007:			; Pos = 62785
		mov edx,[ebx+0x4]
	JUMP_007008:			; Pos = 62788
		or eax,edx
		cmp dword [ebx+0x8],byte +0x0
		jnl JUMP_007009
		mov edx,[ebx+0x8]
		neg edx
		jmp short JUMP_007010
	JUMP_007009:			; Pos = 62797
		mov edx,[ebx+0x8]
	JUMP_007010:			; Pos = 6279a
		or eax,edx
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		add eax,byte -0xd
		test eax,eax
		jl JUMP_007011
		mov ecx,eax
		mov edx,[ebx]
		sar edx,cl
		mov [esi],edx
		mov ecx,eax
		mov edx,[ebx+0x4]
		sar edx,cl
		mov [esi+0x4],edx
		mov ecx,eax
		mov eax,[ebx+0x8]
		sar eax,cl
		mov [esi+0x8],eax
		jmp short JUMP_007012
	JUMP_007011:			; Pos = 627c8
		mov eax,[ebx]
		mov [esi],eax
		mov eax,[ebx+0x4]
		mov [esi+0x4],eax
		mov eax,[ebx+0x8]
		mov [esi+0x8],eax
	JUMP_007012:			; Pos = 627d8
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001827:			; Pos = 627dc

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		push esi
		push edi
		mov ecx,[ebp+0x14]
		mov edx,[ebp+0x10]
		mov eax,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov esi,[edx]
		mov edi,[eax]
		neg edi
		add esi,edi
		mov [ebp-0xc],esi
		mov esi,[edx+0x4]
		mov edi,[eax+0x4]
		neg edi
		add esi,edi
		mov [ebp-0x8],esi
		mov edx,[edx+0x8]
		mov esi,[eax+0x8]
		neg esi
		add edx,esi
		mov [ebp-0x4],edx
		mov edx,[ecx]
		mov esi,[eax]
		neg esi
		add edx,esi
		mov [ebp-0x18],edx
		mov edx,[ecx+0x4]
		mov esi,[eax+0x4]
		neg esi
		add edx,esi
		mov [ebp-0x14],edx
		mov edx,[ecx+0x8]
		mov eax,[eax+0x8]
		neg eax
		add edx,eax
		mov [ebp-0x10],edx
		lea eax,[ebp-0xc]
		push eax
		call FUNC_001825
		pop ecx
		add eax,byte -0x6
		test eax,eax
		jng JUMP_007013
		mov ecx,eax
		sar dword [ebp-0xc],cl
		mov ecx,eax
		sar dword [ebp-0x8],cl
		mov ecx,eax
		sar dword [ebp-0x4],cl
	JUMP_007013:			; Pos = 6285b
		lea eax,[ebp-0x18]
		push eax
		call FUNC_001825
		pop ecx
		add eax,byte -0x6
		test eax,eax
		jng JUMP_007014
		mov ecx,eax
		sar dword [ebp-0x18],cl
		mov ecx,eax
		sar dword [ebp-0x14],cl
		mov ecx,eax
		sar dword [ebp-0x10],cl
	JUMP_007014:			; Pos = 6287b
		mov eax,[ebp-0x8]
		imul dword [ebp-0x10]
		mov edx,[ebp-0x4]
		imul edx,[ebp-0x14]
		sub eax,edx
		mov [ebx],eax
		mov eax,[ebp-0x4]
		imul dword [ebp-0x18]
		mov edx,[ebp-0xc]
		imul edx,[ebp-0x10]
		sub eax,edx
		mov [ebx+0x4],eax
		mov eax,[ebp-0xc]
		imul dword [ebp-0x14]
		mov edx,[ebp-0x8]
		imul edx,[ebp-0x18]
		sub eax,edx
		mov [ebx+0x8],eax
		push ebx
		call near [DATA_007724]    ; FUNC_001465
		pop ecx
		mov ecx,eax
		inc ecx
		mov eax,[ebx]
		shl eax,0xf
		cdq
		idiv ecx
		mov [ebx],eax
		mov eax,[ebx+0x4]
		shl eax,0xf
		cdq
		idiv ecx
		mov [ebx+0x4],eax
		mov eax,[ebx+0x8]
		shl eax,0xf
		cdq
		idiv ecx
		mov [ebx+0x8],eax
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001829:			; Pos = 62a34

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov esi,[ebx+0xc]
		cmp esi,0x400
		jnl JUMP_007017
		mov esi,0x400
	JUMP_007017:			; Pos = 62a4d
		push esi
		call FUNC_001656_FindMSB
		pop ecx
		mov edi,[DATA_009269]
		sub edi,eax
		mov [ebx+0x44],edi
		dec edi
		jnl JUMP_007018
		mov dword [ebx+0x44],0x1
	JUMP_007018:			; Pos = 62a69
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001831:			; Pos = 62bbc

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp eax,0xffff8002
		jnz JUMP_007034
		mov eax,0x8
		pop ebp
		ret
	JUMP_007034:			; Pos = 62bd0
		cmp eax,0xa0
		jnz JUMP_007035
		mov eax,0x2
		pop ebp
		ret
	JUMP_007035:			; Pos = 62bde
		mov edx,0x1
		cmp eax,0xa0
		jl JUMP_007036
		add edx,byte +0x3
	JUMP_007036:			; Pos = 62bed
		mov eax,edx
		pop ebp
		ret




FUNC_001832:			; Pos = 62bf4

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp eax,0xffff8002
		jnz JUMP_007037
		mov eax,0x8
		pop ebp
		ret
	JUMP_007037:			; Pos = 62c08
		cmp eax,byte +0x4f
		jnz JUMP_007038
		mov eax,0x2
		pop ebp
		ret
	JUMP_007038:			; Pos = 62c14
		mov edx,0x1
		cmp eax,byte +0x4f
		jl JUMP_007039
		add edx,byte +0x3
	JUMP_007039:			; Pos = 62c21
		mov eax,edx
		pop ebp
		ret




FUNC_001833:			; Pos = 62c28

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov esi,[ebp+0x8]
		mov ebx,[ebp+0x10]
		shl ebx,0x4
		lea ebx,[ebx+ebx*2]
		add ebx,DATA_007843
		cmp dword [ebp+0x14],byte +0x0
		jz JUMP_007040
		mov dword [DATA_009280],FUNC_001831
		mov dword [DATA_009281],FUNC_001832
		mov dword [DATA_009282],FUNC_001848
		jmp short JUMP_007041
	JUMP_007040:			; Pos = 62c65
		mov dword [DATA_009280],FUNC_001715
		mov dword [DATA_009281],FUNC_001716
		mov dword [DATA_009282],FUNC_001847
	JUMP_007041:			; Pos = 62c83
		test esi,esi
		jz JUMP_007042
		mov ecx,[esi+0x130]
		jmp short JUMP_007043
	JUMP_007042:			; Pos = 62c8f
		xor ecx,ecx
	JUMP_007043:			; Pos = 62c91
		mov eax,0x1dcd6500
		sar eax,cl
		mov [DATA_009264],eax
		mov eax,[ebx]
		mov [DATA_009270],eax
		push ebx
		call near [ebx+0x4]
		pop ecx
		mov [DATA_009261],esi
		mov eax,[ebx+0x8]
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001834:			; Pos = 62cb8

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov eax,[ebp+0x1c]
		mov edi,[ebp+0x10]
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		cmp dword [ebp+0x14],byte +0x0
		jz JUMP_007044
		add eax,byte +0x8
	JUMP_007044:			; Pos = 62cd6
		cmp dword [ebp+0x18],byte +0x0
		jnz JUMP_007045
		add eax,byte +0x2
	JUMP_007045:			; Pos = 62cdf
		mov edx,[eax*4+DATA_007844]
		mov [DATA_009279],edx
		mov eax,[eax*4+DATA_007845]
		mov [DATA_009278],eax
		push ebx
		call FUNC_001829
		pop ecx
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		push esi
		call FUNC_001829
		pop ecx
		movsx eax,word [esi]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [esi+0x24],ax
		movsx eax,word [esi+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [esi+0x26],ax
		push edi
		call FUNC_001829
		pop ecx
		movsx eax,word [edi]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [edi+0x24],ax
		movsx eax,word [edi+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [edi+0x26],ax
		cmp dword [ebp+0x14],byte +0x0
		jz near JUMP_007053
		xor eax,eax
		mov [ebp-0x4],eax
		mov eax,[ebp+0x14]
		mov [ebp-0x10],eax
	JUMP_007046:			; Pos = 62d7f
		mov eax,[ebp-0x10]
		cmp dword [eax],byte +0x0
		jng near JUMP_007052
		mov eax,[ebp-0x10]
		mov eax,[eax]
		mov edx,[eax]
		shl edx,0x2
		lea edx,[edx+edx*2]
		add edx,DATA_007841
		mov [ebp-0xc],edx
		add eax,byte +0x4
		movsx edx,word [eax]
		cmp edx,0x80
		jnc JUMP_007048
		movsx edx,word [eax+0x2]
		cmp edx,0x80
		jnc JUMP_007048
		movsx edx,word [eax]
		movsx ecx,word [eax+0x2]
		shl ecx,0x7
		add edx,ecx
		mov [ebp-0x8],edx
		sar dword [ebx+0x3c],0x7
		mov edx,[ebp-0xc]
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007047
		mov edx,[ebp-0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp-0x8]
		movzx edx,byte [edx+ecx]
		imul edx,[ebx+0x3c]
		mov [ebx+0x3c],edx
	JUMP_007047:			; Pos = 62deb
		mov edx,[ebp-0xc]
		mov edx,[edx]
		mov ecx,[ebp-0x8]
		movsx edx,byte [edx+ecx]
		shl edx,0x15
		add [ebx+0x3c],edx
	JUMP_007048:			; Pos = 62dfd
		movsx edx,word [eax+0x4]
		cmp edx,0x80
		jnc JUMP_007050
		movsx edx,word [eax+0x6]
		cmp edx,0x80
		jnc JUMP_007050
		movsx edx,word [eax+0x4]
		movsx ecx,word [eax+0x6]
		shl ecx,0x7
		add edx,ecx
		mov [ebp-0x8],edx
		sar dword [esi+0x3c],0x7
		mov edx,[ebp-0xc]
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007049
		mov edx,[ebp-0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp-0x8]
		movzx edx,byte [edx+ecx]
		imul edx,[esi+0x3c]
		mov [esi+0x3c],edx
	JUMP_007049:			; Pos = 62e46
		mov edx,[ebp-0xc]
		mov edx,[edx]
		mov ecx,[ebp-0x8]
		movsx edx,byte [edx+ecx]
		shl edx,0x15
		add [esi+0x3c],edx
	JUMP_007050:			; Pos = 62e58
		movsx edx,word [eax+0x8]
		cmp edx,0x80
		jnc JUMP_007052
		movsx edx,word [eax+0xa]
		cmp edx,0x80
		jnc JUMP_007052
		movsx edx,word [eax+0x8]
		movsx eax,word [eax+0xa]
		shl eax,0x7
		add edx,eax
		mov [ebp-0x8],edx
		sar dword [edi+0x3c],0x7
		mov eax,[ebp-0xc]
		mov eax,[eax+0x4]
		test eax,eax
		jz JUMP_007051
		mov edx,[ebp-0x8]
		movzx eax,byte [eax+edx]
		imul eax,[edi+0x3c]
		mov [edi+0x3c],eax
	JUMP_007051:			; Pos = 62e9c
		mov eax,[ebp-0xc]
		mov eax,[eax]
		mov edx,[ebp-0x8]
		movsx eax,byte [eax+edx]
		shl eax,0x15
		add [edi+0x3c],eax
	JUMP_007052:			; Pos = 62eae
		inc dword [ebp-0x4]
		add dword [ebp-0x10],byte +0x4
		cmp dword [ebp-0x4],byte +0x2
		jl near JUMP_007046
	JUMP_007053:			; Pos = 62ebf
		cmp dword [ebx+0x3c],byte +0x0
		jnl JUMP_007054
		xor eax,eax
		jmp short JUMP_007055
	JUMP_007054:			; Pos = 62ec9
		mov eax,[ebx+0x3c]
	JUMP_007055:			; Pos = 62ecc
		mov [ebx+0x40],eax
		cmp dword [esi+0x3c],byte +0x0
		jnl JUMP_007056
		xor eax,eax
		jmp short JUMP_007057
	JUMP_007056:			; Pos = 62ed9
		mov eax,[esi+0x3c]
	JUMP_007057:			; Pos = 62edc
		mov [esi+0x40],eax
		cmp dword [edi+0x3c],byte +0x0
		jnl JUMP_007058
		xor eax,eax
		jmp short JUMP_007059
	JUMP_007058:			; Pos = 62ee9
		mov eax,[edi+0x3c]
	JUMP_007059:			; Pos = 62eec
		mov [edi+0x40],eax
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001836:			; Pos = 63040

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		pop ebp
		ret




FUNC_001841:			; Pos = 63a8c

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		xor eax,eax
		mov [ebp-0x4],eax
		mov edx,DATA_007848
		mov eax,DATA_007850
	JUMP_007115:			; Pos = 63aa7
		mov ecx,[eax]
		mov ecx,[ebx+ecx*4+0xc]
		imul ecx,[eax+0x4]
		mov esi,[eax+0x8]
		mov esi,[ebx+esi*4+0xc]
		imul esi,[eax+0xc]
		add ecx,esi
		sar ecx,0x4
		and ecx,0xf0f0f
		mov [edx],ecx
		inc dword [ebp-0x4]
		add edx,byte +0x4
		add eax,byte +0x10
		cmp dword [ebp-0x4],byte +0x16
		jl JUMP_007115
		xor eax,eax
		mov [ebp-0x4],eax
		mov dword [ebp-0x14],DATA_007851
		mov dword [ebp-0x10],DATA_007849
	JUMP_007116:			; Pos = 63aeb
		xor ecx,ecx
		mov eax,[ebp-0x10]
		mov edx,eax
		mov eax,[ebp-0x14]
	JUMP_007117:			; Pos = 63af5
		mov esi,[eax]
		mov esi,[ebx+esi*4+0xc]
		imul esi,[eax+0x4]
		mov edi,[eax+0x8]
		mov edi,[ebx+edi*4+0xc]
		imul edi,[eax+0xc]
		add esi,edi
		sar esi,0x4
		and esi,0xf0f0f
		mov [edx],esi
		inc ecx
		add edx,byte +0x4
		add eax,byte +0x10
		cmp ecx,byte +0x7
		jl JUMP_007117
		inc dword [ebp-0x4]
		add dword [ebp-0x14],byte +0x70
		add dword [ebp-0x10],byte +0x1c
		cmp dword [ebp-0x4],byte +0x15
		jl JUMP_007116
		xor eax,eax
		mov [ebp-0x4],eax
		mov dword [ebp-0x18],DATA_007846
	JUMP_007118:			; Pos = 63b40
		mov eax,[ebp-0x4]
		shl eax,0x2
		inc eax
		mov ecx,0x3
		cdq
		idiv ecx
		mov edx,0x4
		sub edx,eax
		mov ecx,edx
		imul ecx,[ebx+0xc]
		mov esi,[ebx+0x10]
		imul esi,eax
		add ecx,esi
		sar ecx,0x2
		and ecx,0xf0f0f
		mov [ebp-0x8],ecx
		imul edx,[ebx+0x14]
		mov ecx,[ebx+0x18]
		imul ecx,eax
		add edx,ecx
		sar edx,0x2
		and edx,0xf0f0f
		mov [ebp-0xc],edx
		xor ecx,ecx
		mov eax,[ebp-0x18]
		mov esi,eax
	JUMP_007119:			; Pos = 63b8f
		mov eax,ecx
		shl eax,0x3
		add eax,byte +0x3
		mov edi,0x6
		cdq
		idiv edi
		mov edx,0x8
		sub edx,eax
		imul edx,[ebp-0x8]
		mov edi,[ebp-0xc]
		imul edi,eax
		add edx,edi
		sar edx,0x3
		and edx,0xf0f0f
		mov [esi],edx
		inc ecx
		add esi,byte +0x4
		cmp ecx,byte +0x7
		jl JUMP_007119
		inc dword [ebp-0x4]
		add dword [ebp-0x18],byte +0x20
		cmp dword [ebp-0x4],byte +0x4
		jl near JUMP_007118
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop
		nop




FUNC_001843:			; Pos = 63d68

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		xor ecx,ecx
		mov edx,DATA_007852
		mov eax,DATA_007853
	JUMP_007128:			; Pos = 63d7a
		mov ebx,[ebp+0x8]
		mov esi,[eax]
		mov ebx,[ebx+esi*4+0xc]
		imul ebx,[eax+0x4]
		mov esi,[ebp+0x8]
		mov edi,[eax+0x8]
		mov esi,[esi+edi*4+0xc]
		imul esi,[eax+0xc]
		add ebx,esi
		sar ebx,0x4
		and ebx,0xf0f0f
		mov [edx],ebx
		inc ecx
		add edx,byte +0x4
		add eax,byte +0x10
		cmp ecx,byte +0x20
		jl JUMP_007128
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret
		nop




FUNC_001846:			; Pos = 63ebc

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edi,[ebp+0xc]
		mov esi,[ebp+0x8]
		cmp dword [ebp+0x10],byte +0x1
		jg JUMP_007132
		xor esi,edi
		push esi
		call FUNC_001824
		pop ecx
		sar eax,0x4
		jmp short JUMP_007134
	JUMP_007132:			; Pos = 63edc
		mov ebx,esi
		sub ebx,edi
		test ebx,ebx
		jnl JUMP_007133
		neg ebx
	JUMP_007133:			; Pos = 63ee6
		push ebx
		xor esi,edi
		push esi
		call FUNC_001824
		pop ecx
		push eax
		call FUNC_001521
		add esp,byte +0x8
		sar eax,1
	JUMP_007134:			; Pos = 63efb
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_001848:			; Pos = 63fb8

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		cmp dword [eax+0x4],byte +0x0
		jnz JUMP_007145
		mov word [eax+0x24],0x2
		jmp short JUMP_007147
	JUMP_007145:			; Pos = 63fcc
		mov dx,0x1
		cmp dword [eax+0x4],byte +0x0
		jl JUMP_007146
		add edx,byte +0x3
	JUMP_007146:			; Pos = 63fd9
		mov [eax+0x24],dx
	JUMP_007147:			; Pos = 63fdd
		cmp dword [eax+0x8],byte +0x0
		jnz JUMP_007148
		mov word [eax+0x26],0x2
		pop ebp
		ret
	JUMP_007148:			; Pos = 63feb
		mov dx,0x1
		cmp dword [eax+0x8],byte +0x0
		jl JUMP_007149
		add edx,byte +0x3
	JUMP_007149:			; Pos = 63ff8
		mov [eax+0x26],dx
		pop ebp
		ret
		nop
		nop




FUNC_001849:			; Pos = 64000

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007157
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007150
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007151
	JUMP_007150:			; Pos = 64041
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007151:			; Pos = 64058
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x30],eax
		mov eax,[ebp+0x18]
		mov edi,[eax*4+DATA_007839]
		mov eax,[ebp+0x18]
		cmp eax,[esi+0x44]
		jng near JUMP_007155
		mov eax,[ebp+0x18]
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007155
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007152
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007153
	JUMP_007152:			; Pos = 64116
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007156
	JUMP_007153:			; Pos = 64123
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007154
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x4]
		shl edx,0x4
		lea ecx,[edx+DATA_007854]
		mov esi,[ebp-0x8]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007855
		mov ecx,[ebp-0x8]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007154:			; Pos = 641e3
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp short JUMP_007156
	JUMP_007155:			; Pos = 64204
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007156:			; Pos = 64263
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007157:			; Pos = 6426a
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret
		nop
		nop
		nop




FUNC_001850:			; Pos = 64274

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007165
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007158
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007159
	JUMP_007158:			; Pos = 642b5
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007159:			; Pos = 642cc
		mov eax,[esi+0x28]
		mov [ebx+0x28],eax
		mov eax,[esi+0x2c]
		mov [ebx+0x2c],eax
		mov eax,[esi+0x30]
		mov [ebx+0x30],eax
		xor edi,edi
		mov eax,[ebp+0x18]
		cmp eax,[esi+0x44]
		jng near JUMP_007163
		mov eax,[ebp+0x18]
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007163
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007160
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007161
	JUMP_007160:			; Pos = 64342
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007164
	JUMP_007161:			; Pos = 6434f
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007162
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0xc],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x8]
		shl edx,0x4
		lea ecx,[edx+DATA_007856]
		mov esi,[ebp-0xc]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007857
		mov ecx,[ebp-0xc]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007162:			; Pos = 6440f
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007164
	JUMP_007163:			; Pos = 64433
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebp-0x4],eax
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		add eax,[ebp-0x4]
		mov [ebx+0x3c],eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007164:			; Pos = 644bd
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007165:			; Pos = 644c4
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop




FUNC_001851:			; Pos = 644cc

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007175
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007166
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007167
	JUMP_007166:			; Pos = 6450d
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007167:			; Pos = 64524
		mov eax,[esi+0x28]
		mov [ebx+0x28],eax
		mov eax,[esi+0x2c]
		mov [ebx+0x2c],eax
		mov eax,[esi+0x30]
		mov [ebx+0x30],eax
		xor edi,edi
		mov eax,[esi+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007168
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007169
	JUMP_007168:			; Pos = 6454d
		mov eax,[ebp+0x18]
	JUMP_007169:			; Pos = 64550
		cmp eax,[esi+0x44]
		jng near JUMP_007173
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007173
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007170
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007171
	JUMP_007170:			; Pos = 645ac
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007174
	JUMP_007171:			; Pos = 645b9
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007172
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x4]
		shl edx,0x4
		lea ecx,[edx+DATA_007858]
		mov esi,[ebp-0x8]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007859
		mov ecx,[ebp-0x8]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007172:			; Pos = 64679
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007174
	JUMP_007173:			; Pos = 6469d
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		mov edx,[esi+0x3c]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x3c]
		sar edx,1
		add eax,edx
		mov [ebx+0x3c],eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007174:			; Pos = 64723
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007175:			; Pos = 6472a
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret
		nop
		nop
		nop




FUNC_001852:			; Pos = 64734

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007183
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007176
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007177
	JUMP_007176:			; Pos = 64775
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007177:			; Pos = 6478c
		mov eax,[esi+0x28]
		mov [ebx+0x28],eax
		mov eax,[esi+0x2c]
		mov [ebx+0x2c],eax
		mov eax,[esi+0x30]
		mov [ebx+0x30],eax
		xor eax,eax
		mov [ebp-0x4],eax
		mov eax,[ebp+0x18]
		cmp eax,[esi+0x44]
		jng near JUMP_007181
		mov eax,[ebp+0x18]
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007181
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007178
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007179
	JUMP_007178:			; Pos = 64805
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007182
	JUMP_007179:			; Pos = 64812
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007180
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0xc],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x8]
		shl edx,0x4
		lea ecx,[edx+DATA_007860]
		mov esi,[ebp-0xc]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007861
		mov ecx,[ebp-0xc]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007180:			; Pos = 648d2
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007182
	JUMP_007181:			; Pos = 648f6
		mov edi,[esi+0x3c]
		mov eax,[ebp+0x10]
		add edi,[eax+0x3c]
		sar edi,1
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		add eax,edi
		mov [ebx+0x3c],eax
		mov eax,[ebx+0x3c]
		sub eax,edi
		sar eax,0x3
		add eax,[ebp-0x4]
		mov edi,eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007182:			; Pos = 64989
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007183:			; Pos = 64990
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop




FUNC_001853:			; Pos = 64998

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007198
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007184
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007185
	JUMP_007184:			; Pos = 649d9
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007185:			; Pos = 649f0
		mov eax,[esi+0x28]
		mov [ebx+0x28],eax
		mov eax,[esi+0x2c]
		mov [ebx+0x2c],eax
		mov eax,[esi+0x30]
		mov [ebx+0x30],eax
		xor edi,edi
		mov eax,[esi+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007186
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007187
	JUMP_007186:			; Pos = 64a19
		mov eax,[ebp+0x18]
	JUMP_007187:			; Pos = 64a1c
		cmp eax,[esi+0x44]
		jng near JUMP_007194
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007194
		mov eax,[esi+0x40]
		test eax,eax
		jnz JUMP_007188
		mov edx,[ebp+0x10]
		cmp dword [edx+0x40],byte +0x0
		jz JUMP_007189
	JUMP_007188:			; Pos = 64a41
		mov edx,[ebp+0x10]
		add eax,[edx+0x40]
		sar eax,1
		mov [ebx+0x40],eax
		mov [ebx+0x3c],eax
		jmp short JUMP_007190
	JUMP_007189:			; Pos = 64a51
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		xor eax,eax
		mov [ebx+0x40],eax
	JUMP_007190:			; Pos = 64a64
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007191
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007192
	JUMP_007191:			; Pos = 64a9d
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007197
	JUMP_007192:			; Pos = 64aaa
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007193
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x4]
		shl edx,0x4
		lea ecx,[edx+DATA_007862]
		mov esi,[ebp-0x8]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007863
		mov ecx,[ebp-0x8]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007193:			; Pos = 64b6a
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007197
	JUMP_007194:			; Pos = 64b8e
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		mov edx,[esi+0x3c]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x3c]
		sar edx,1
		add eax,edx
		mov [ebx+0x3c],eax
		cmp dword [ebx+0x3c],byte +0x0
		jl JUMP_007195
		mov eax,[ebx+0x3c]
		jmp short JUMP_007196
	JUMP_007195:			; Pos = 64bc0
		xor eax,eax
	JUMP_007196:			; Pos = 64bc2
		mov [ebx+0x40],eax
		mov edx,[esi+0x40]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x40]
		sar edx,1
		sub eax,edx
		sar eax,0x3
		add edi,eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007197:			; Pos = 64c36
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007198:			; Pos = 64c3d
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret




FUNC_001854:			; Pos = 64c44

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov edi,[ebp+0x18]
		mov esi,[ebp+0xc]
		mov eax,[ebp+0x8]
		mov eax,[eax+0x8]
		test eax,eax
		jnz near JUMP_007206
		call FUNC_001818
		mov edx,[ebp+0x8]
		mov [edx+0x8],eax
		mov ebx,eax
		mov eax,[ebp+0x8]
		cmp esi,[eax]
		jnz JUMP_007199
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007200
	JUMP_007199:			; Pos = 64c94
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0xc],eax
		mov [eax],esi
	JUMP_007200:			; Pos = 64cb1
		mov eax,[edi*4+DATA_007840]
		push eax
		mov eax,[esi+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x28],eax
		mov eax,[edi*4+DATA_007840]
		push eax
		mov eax,[esi+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x2c],eax
		mov eax,[edi*4+DATA_007840]
		push eax
		mov eax,[esi+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x30],eax
		mov eax,[edi*4+DATA_007839]
		mov [ebp-0x4],eax
		cmp edi,[esi+0x44]
		jng near JUMP_007204
		mov eax,[ebp+0x10]
		cmp edi,[eax+0x44]
		jng near JUMP_007204
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007201
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007202
	JUMP_007201:			; Pos = 64d6e
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007205
	JUMP_007202:			; Pos = 64d7b
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007203
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0xc],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x10],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0xc]
		shl edx,0x4
		lea ecx,[edx+DATA_007864]
		mov esi,[ebp-0x10]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007865
		mov ecx,[ebp-0x10]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007203:			; Pos = 64e3b
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007205
	JUMP_007204:			; Pos = 64e5f
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebp-0x8],eax
		push edi
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		add eax,[ebp-0x8]
		mov [ebx+0x3c],eax
		mov eax,[ebp-0x4]
		push eax
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		mov eax,[ebp-0x4]
		push eax
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		mov eax,[ebp-0x4]
		push eax
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007205:			; Pos = 64eef
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007206:			; Pos = 64ef6
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001855:			; Pos = 64f00

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007216
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007207
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007208
	JUMP_007207:			; Pos = 64f41
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007208:			; Pos = 64f58
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x30],eax
		mov eax,[ebp+0x18]
		mov edi,[eax*4+DATA_007839]
		mov eax,[esi+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007209
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007210
	JUMP_007209:			; Pos = 64fd7
		mov eax,[ebp+0x18]
	JUMP_007210:			; Pos = 64fda
		cmp eax,[esi+0x44]
		jng near JUMP_007214
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007214
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007211
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007212
	JUMP_007211:			; Pos = 65036
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007215
	JUMP_007212:			; Pos = 65043
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007213
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x4]
		shl edx,0x4
		lea ecx,[edx+DATA_007866]
		mov esi,[ebp-0x8]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007867
		mov ecx,[ebp-0x8]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007213:			; Pos = 65103
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007215
	JUMP_007214:			; Pos = 65127
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		mov edx,[esi+0x3c]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x3c]
		sar edx,1
		add eax,edx
		mov [ebx+0x3c],eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007215:			; Pos = 651ad
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007216:			; Pos = 651b4
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret
		nop




FUNC_001856:			; Pos = 651bc

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov edi,[ebp+0x18]
		mov esi,[ebp+0xc]
		mov eax,[ebp+0x8]
		mov eax,[eax+0x8]
		test eax,eax
		jnz near JUMP_007224
		call FUNC_001818
		mov edx,[ebp+0x8]
		mov [edx+0x8],eax
		mov ebx,eax
		mov eax,[ebp+0x8]
		cmp esi,[eax]
		jnz JUMP_007217
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007218
	JUMP_007217:			; Pos = 6520c
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov edx,[ebp+0x8]
		mov [edx+0xc],eax
		mov [eax],esi
	JUMP_007218:			; Pos = 65229
		mov eax,[edi*4+DATA_007840]
		push eax
		mov eax,[esi+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x28],eax
		mov eax,[edi*4+DATA_007840]
		push eax
		mov eax,[esi+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x2c],eax
		mov eax,[edi*4+DATA_007840]
		push eax
		mov eax,[esi+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x30],eax
		mov eax,[edi*4+DATA_007839]
		mov [ebp-0x4],eax
		cmp edi,[esi+0x44]
		jng near JUMP_007222
		mov eax,[ebp+0x10]
		cmp edi,[eax+0x44]
		jng near JUMP_007222
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007219
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007220
	JUMP_007219:			; Pos = 652e6
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007223
	JUMP_007220:			; Pos = 652f3
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007221
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0xc],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x10],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0xc]
		shl edx,0x4
		lea ecx,[edx+DATA_007868]
		mov esi,[ebp-0x10]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007869
		mov ecx,[ebp-0x10]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007221:			; Pos = 653b3
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007223
	JUMP_007222:			; Pos = 653d7
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebp-0x8],eax
		push edi
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		add eax,[ebp-0x8]
		mov [ebx+0x3c],eax
		mov eax,[ebx+0x3c]
		sub eax,[ebp-0x8]
		sar eax,0x3
		add eax,[ebp-0x4]
		mov [ebp-0x8],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007223:			; Pos = 65476
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007224:			; Pos = 6547d
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001857:			; Pos = 65484

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007239
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007225
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007226
	JUMP_007225:			; Pos = 654c5
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007226:			; Pos = 654dc
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x30],eax
		mov eax,[ebp+0x18]
		mov edi,[eax*4+DATA_007839]
		mov eax,[esi+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007227
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007228
	JUMP_007227:			; Pos = 6555b
		mov eax,[ebp+0x18]
	JUMP_007228:			; Pos = 6555e
		cmp eax,[esi+0x44]
		jng near JUMP_007235
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007235
		mov eax,[esi+0x40]
		test eax,eax
		jnz JUMP_007229
		mov edx,[ebp+0x10]
		cmp dword [edx+0x40],byte +0x0
		jz JUMP_007230
	JUMP_007229:			; Pos = 65583
		mov edx,[ebp+0x10]
		add eax,[edx+0x40]
		sar eax,1
		mov [ebx+0x40],eax
		mov [ebx+0x3c],eax
		jmp short JUMP_007231
	JUMP_007230:			; Pos = 65593
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		xor eax,eax
		mov [ebx+0x40],eax
	JUMP_007231:			; Pos = 655a6
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007232
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007233
	JUMP_007232:			; Pos = 655df
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007238
	JUMP_007233:			; Pos = 655ec
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007234
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x4]
		shl edx,0x4
		lea ecx,[edx+DATA_007870]
		mov esi,[ebp-0x8]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007871
		mov ecx,[ebp-0x8]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007234:			; Pos = 656ac
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007238
	JUMP_007235:			; Pos = 656d0
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov eax,[eax+0x3c]
		push eax
		mov eax,[esi+0x3c]
		push eax
		call FUNC_001846
		add esp,byte +0xc
		mov edx,[esi+0x3c]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x3c]
		sar edx,1
		add eax,edx
		mov [ebx+0x3c],eax
		cmp dword [ebx+0x3c],byte +0x0
		jl JUMP_007236
		mov eax,[ebx+0x3c]
		jmp short JUMP_007237
	JUMP_007236:			; Pos = 65702
		xor eax,eax
	JUMP_007237:			; Pos = 65704
		mov [ebx+0x40],eax
		mov edx,[esi+0x40]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x40]
		sar edx,1
		sub eax,edx
		sar eax,0x3
		add edi,eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007238:			; Pos = 65778
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007239:			; Pos = 6577f
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret
		nop
		nop




FUNC_001858:			; Pos = 65788

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov eax,[ebx+0x8]
		test eax,eax
		jz JUMP_007242
		mov [ebp-0x4],eax
		xor esi,esi
		mov eax,[ebp-0x4]
		lea ecx,[eax+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0xc],ebx
	JUMP_007240:			; Pos = 657bf
		mov ebx,[ebp-0xc]
		cmp dword [ebx],byte +0x0
		jz JUMP_007241
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007241:			; Pos = 657e4
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0xc],0x100
		cmp esi,byte +0x2
		jl JUMP_007240
		jmp JUMP_007255
	JUMP_007242:			; Pos = 657ff
		call FUNC_001818
		mov [ebx+0x8],eax
		mov [ebp-0x4],eax
		mov eax,[ebx]
		cmp eax,[ebp+0xc]
		jnz JUMP_007243
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007244
	JUMP_007243:			; Pos = 6582d
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007244:			; Pos = 65847
		xor esi,esi
		mov eax,[ebp-0x4]
		lea edx,[eax+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007245:			; Pos = 65868
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007246
		movsx ebx,word [ecx]
		movsx edi,word [eax]
		add ebx,edi
		sar ebx,1
		mov [edx],bx
		movsx ebx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ebx,edi
		sar ebx,1
		mov [edx+0x2],bx
	JUMP_007246:			; Pos = 6588d
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add ecx,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007245
		mov eax,[ebp+0xc]
		mov edx,[ebp-0x4]
		mov ecx,[eax+0x28]
		mov [edx+0x28],ecx
		mov ecx,[eax+0x2c]
		mov [edx+0x2c],ecx
		mov ecx,[eax+0x30]
		mov [edx+0x30],ecx
		xor eax,eax
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007250
		mov eax,[ebp+0x10]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007250
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x3c],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007247
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007248
	JUMP_007247:			; Pos = 65940
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007254
	JUMP_007248:			; Pos = 65950
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007249
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx]
		mov ebx,[ebp+0xc]
		movsx ebx,word [ebx]
		sub ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ebx,esi
		imul ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ebx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ebx,esi
		cmp ecx,ebx
		setg cl
		and ecx,byte +0x1
		mov ebx,eax
		shl ebx,0x4
		add ebx,DATA_007872
		lea ebx,[ebx+edx*8]
		mov bx,[ebx+ecx*4]
		mov esi,[ebp-0x4]
		add [esi],bx
		shl eax,0x4
		add eax,DATA_007873
		lea eax,[eax+edx*8]
		mov ax,[eax+ecx*4]
		mov edx,[ebp-0x4]
		add [edx+0x2],ax
	JUMP_007249:			; Pos = 65a2a
		mov eax,[ebp-0x4]
		movsx eax,word [eax]
		push eax
		call near [DATA_009280]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x24],ax
		mov eax,[ebp-0x4]
		movsx eax,word [eax+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x26],ax
		jmp JUMP_007254
	JUMP_007250:			; Pos = 65a5a
		mov eax,[ebp+0xc]
		mov ebx,[eax+0x3c]
		mov edi,ebx
		mov eax,[ebp+0x10]
		mov esi,[eax+0x3c]
		add edi,esi
		sar edi,1
		mov eax,[ebp+0x18]
		push eax
		push esi
		push ebx
		call FUNC_001846
		add esp,byte +0xc
		add edi,eax
		mov eax,[ebp-0x4]
		mov [eax+0x3c],edi
		xor esi,esi
		mov eax,[ebp-0x4]
		add eax,byte +0x34
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007251:			; Pos = 65a94
		cmp dword [edx],byte +0x0
		jz JUMP_007253
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007253
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007253
		mov ecx,[ebp-0x4]
		sar dword [ecx+0x3c],0x7
		movsx ecx,word [eax]
		movsx ebx,word [eax+0x2]
		shl ebx,0x7
		add ecx,ebx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007252
		mov ebx,[edx+0x4]
		movzx ebx,byte [ebx+ecx]
		mov edi,[ebp-0x4]
		imul ebx,[edi+0x3c]
		mov [edi+0x3c],ebx
	JUMP_007252:			; Pos = 65ada
		mov ebx,[edx]
		movsx ecx,byte [ebx+ecx]
		shl ecx,0x15
		mov ebx,[ebp-0x4]
		add [ebx+0x3c],ecx
	JUMP_007253:			; Pos = 65ae9
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007251
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
	JUMP_007254:			; Pos = 65b7e
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001829
		pop ecx
	JUMP_007255:			; Pos = 65b88
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop




FUNC_001859:			; Pos = 65b90

		push ebp
		mov ebp,esp
		add esp,byte -0x14
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov eax,[ebx+0x8]
		test eax,eax
		jz JUMP_007258
		mov [ebp-0x4],eax
		xor esi,esi
		mov eax,[ebp-0x4]
		lea ecx,[eax+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007256:			; Pos = 65bc7
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007257
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007257:			; Pos = 65bec
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007256
		jmp JUMP_007273
	JUMP_007258:			; Pos = 65c07
		call FUNC_001818
		mov [ebx+0x8],eax
		mov [ebp-0x4],eax
		mov eax,[ebx]
		cmp eax,[ebp+0xc]
		jnz JUMP_007259
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007260
	JUMP_007259:			; Pos = 65c35
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007260:			; Pos = 65c4f
		xor esi,esi
		mov eax,[ebp-0x4]
		lea edx,[eax+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x14],ebx
	JUMP_007261:			; Pos = 65c70
		mov ebx,[ebp-0x14]
		cmp dword [ebx],byte +0x0
		jz JUMP_007262
		movsx ebx,word [ecx]
		movsx edi,word [eax]
		add ebx,edi
		sar ebx,1
		mov [edx],bx
		movsx ebx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ebx,edi
		sar ebx,1
		mov [edx+0x2],bx
	JUMP_007262:			; Pos = 65c95
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add ecx,byte +0x4
		add dword [ebp-0x14],0x100
		cmp esi,byte +0x2
		jl JUMP_007261
		mov eax,[ebp+0xc]
		mov edx,[ebp-0x4]
		mov ecx,[eax+0x28]
		mov [edx+0x28],ecx
		mov ecx,[eax+0x2c]
		mov [edx+0x2c],ecx
		mov ecx,[eax+0x30]
		mov [edx+0x30],ecx
		xor eax,eax
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007263
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007264
	JUMP_007263:			; Pos = 65ce0
		mov eax,[ebp+0x18]
	JUMP_007264:			; Pos = 65ce3
		mov edx,[ebp+0xc]
		cmp eax,[edx+0x44]
		jng near JUMP_007268
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007268
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x3c],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007265
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007266
	JUMP_007265:			; Pos = 65d5d
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007272
	JUMP_007266:			; Pos = 65d6d
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007267
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx]
		mov ebx,[ebp+0xc]
		movsx ebx,word [ebx]
		sub ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ebx,esi
		imul ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ebx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ebx,esi
		cmp ecx,ebx
		setg cl
		and ecx,byte +0x1
		mov ebx,eax
		shl ebx,0x4
		add ebx,DATA_007874
		lea ebx,[ebx+edx*8]
		mov bx,[ebx+ecx*4]
		mov esi,[ebp-0x4]
		add [esi],bx
		shl eax,0x4
		add eax,DATA_007875
		lea eax,[eax+edx*8]
		mov ax,[eax+ecx*4]
		mov edx,[ebp-0x4]
		add [edx+0x2],ax
	JUMP_007267:			; Pos = 65e47
		mov eax,[ebp-0x4]
		movsx eax,word [eax]
		push eax
		call near [DATA_009280]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x24],ax
		mov eax,[ebp-0x4]
		movsx eax,word [eax+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x26],ax
		jmp JUMP_007272
	JUMP_007268:			; Pos = 65e77
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov edi,[eax+0x3c]
		push edi
		mov eax,[ebp+0xc]
		mov esi,[eax+0x3c]
		push esi
		call FUNC_001846
		add esp,byte +0xc
		add esi,edi
		sar esi,1
		add eax,esi
		mov edx,[ebp-0x4]
		mov [edx+0x3c],eax
		xor esi,esi
		mov eax,[ebp-0x4]
		add eax,byte +0x34
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007269:			; Pos = 65eaf
		cmp dword [edx],byte +0x0
		jz JUMP_007271
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007271
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007271
		mov ecx,[ebp-0x4]
		sar dword [ecx+0x3c],0x7
		movsx ecx,word [eax]
		movsx ebx,word [eax+0x2]
		shl ebx,0x7
		add ecx,ebx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007270
		mov ebx,[edx+0x4]
		movzx ebx,byte [ebx+ecx]
		mov edi,[ebp-0x4]
		imul ebx,[edi+0x3c]
		mov [edi+0x3c],ebx
	JUMP_007270:			; Pos = 65ef5
		mov ebx,[edx]
		movsx ecx,byte [ebx+ecx]
		shl ecx,0x15
		mov ebx,[ebp-0x4]
		add [ebx+0x3c],ecx
	JUMP_007271:			; Pos = 65f04
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007269
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
	JUMP_007272:			; Pos = 65f99
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001829
		pop ecx
	JUMP_007273:			; Pos = 65fa3
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop
		nop




FUNC_001860:			; Pos = 65fac

		push ebp
		mov ebp,esp
		add esp,byte -0x14
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov eax,[ebx+0x8]
		test eax,eax
		jz JUMP_007276
		mov [ebp-0x8],eax
		xor esi,esi
		mov eax,[ebp-0x8]
		lea ecx,[eax+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007274:			; Pos = 65fe3
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007275
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007275:			; Pos = 66008
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007274
		jmp JUMP_007289
	JUMP_007276:			; Pos = 66023
		call FUNC_001818
		mov [ebx+0x8],eax
		mov [ebp-0x8],eax
		mov eax,[ebx]
		cmp eax,[ebp+0xc]
		jnz JUMP_007277
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007278
	JUMP_007277:			; Pos = 66051
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007278:			; Pos = 6606b
		xor esi,esi
		mov eax,[ebp-0x8]
		lea edx,[eax+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x14],ebx
	JUMP_007279:			; Pos = 6608c
		mov ebx,[ebp-0x14]
		cmp dword [ebx],byte +0x0
		jz JUMP_007280
		movsx ebx,word [ecx]
		movsx edi,word [eax]
		add ebx,edi
		sar ebx,1
		mov [edx],bx
		movsx ebx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ebx,edi
		sar ebx,1
		mov [edx+0x2],bx
	JUMP_007280:			; Pos = 660b1
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add ecx,byte +0x4
		add dword [ebp-0x14],0x100
		cmp esi,byte +0x2
		jl JUMP_007279
		mov eax,[ebp+0xc]
		mov edx,[ebp-0x8]
		mov ecx,[eax+0x28]
		mov [edx+0x28],ecx
		mov ecx,[eax+0x2c]
		mov [edx+0x2c],ecx
		mov ecx,[eax+0x30]
		mov [edx+0x30],ecx
		xor eax,eax
		mov [ebp-0xc],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007284
		mov eax,[ebp+0x10]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007284
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x3c],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007281
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007282
	JUMP_007281:			; Pos = 66164
		mov eax,[ebp-0x8]
		push eax
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007288
	JUMP_007282:			; Pos = 66174
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007283
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx]
		mov ebx,[ebp+0xc]
		movsx ebx,word [ebx]
		sub ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ebx,esi
		imul ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ebx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ebx,esi
		cmp ecx,ebx
		setg cl
		and ecx,byte +0x1
		mov ebx,eax
		shl ebx,0x4
		add ebx,DATA_007876
		lea ebx,[ebx+edx*8]
		mov bx,[ebx+ecx*4]
		mov esi,[ebp-0x8]
		add [esi],bx
		shl eax,0x4
		add eax,DATA_007877
		lea eax,[eax+edx*8]
		mov ax,[eax+ecx*4]
		mov edx,[ebp-0x8]
		add [edx+0x2],ax
	JUMP_007283:			; Pos = 6624e
		mov eax,[ebp-0x8]
		movsx eax,word [eax]
		push eax
		call near [DATA_009280]
		pop ecx
		mov edx,[ebp-0x8]
		mov [edx+0x24],ax
		mov eax,[ebp-0x8]
		movsx eax,word [eax+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov edx,[ebp-0x8]
		mov [edx+0x26],ax
		jmp JUMP_007288
	JUMP_007284:			; Pos = 6627e
		mov eax,[ebp+0xc]
		mov esi,[eax+0x3c]
		mov ebx,esi
		mov eax,[ebp+0x10]
		mov edi,[eax+0x3c]
		add ebx,edi
		sar ebx,1
		mov eax,[ebp+0x18]
		push eax
		push edi
		push esi
		call FUNC_001846
		add esp,byte +0xc
		add eax,ebx
		mov edx,[ebp-0x8]
		mov [edx+0x3c],eax
		xor esi,esi
		mov eax,[ebp-0x8]
		add eax,byte +0x34
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007285:			; Pos = 662b8
		cmp dword [edx],byte +0x0
		jz JUMP_007287
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007287
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007287
		mov ecx,[ebp-0x8]
		sar dword [ecx+0x3c],0x7
		movsx ecx,word [eax]
		movsx edi,word [eax+0x2]
		shl edi,0x7
		add ecx,edi
		mov [ebp-0x4],ecx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007286
		mov ecx,[edx+0x4]
		mov edi,[ebp-0x4]
		movzx ecx,byte [ecx+edi]
		mov edi,[ebp-0x8]
		imul ecx,[edi+0x3c]
		mov [edi+0x3c],ecx
	JUMP_007286:			; Pos = 66304
		mov ecx,[edx]
		mov edi,[ebp-0x4]
		movsx ecx,byte [ecx+edi]
		shl ecx,0x15
		mov edi,[ebp-0x8]
		add [edi+0x3c],ecx
	JUMP_007287:			; Pos = 66316
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007285
		mov eax,[ebp-0x8]
		mov eax,[eax+0x3c]
		sub eax,ebx
		sar eax,0x3
		add eax,[ebp-0xc]
		mov ebx,eax
		push ebx
		mov eax,[ebp-0x8]
		mov eax,[eax+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x8]
		mov [edx+0x4],eax
		push ebx
		mov eax,[ebp-0x8]
		mov eax,[eax+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x8]
		mov [edx+0x8],eax
		push ebx
		mov eax,[ebp-0x8]
		mov eax,[eax+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x8]
		mov [edx+0xc],eax
		mov eax,[ebp-0x8]
		push eax
		call near [DATA_009282]
		pop ecx
	JUMP_007288:			; Pos = 663b2
		mov eax,[ebp-0x8]
		push eax
		call FUNC_001829
		pop ecx
	JUMP_007289:			; Pos = 663bc
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop




FUNC_001861:			; Pos = 663c4

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x8]
		mov eax,[esi+0x8]
		test eax,eax
		jz JUMP_007292
		mov ebx,eax
		xor esi,esi
		lea ecx,[ebx+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007290:			; Pos = 663f7
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007291
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007291:			; Pos = 6641c
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007290
		jmp JUMP_007312
	JUMP_007292:			; Pos = 66437
		call FUNC_001818
		mov [esi+0x8],eax
		mov ebx,eax
		mov eax,[esi]
		cmp eax,[ebp+0xc]
		jnz JUMP_007293
		call FUNC_001820
		mov [esi+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [esi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007294
	JUMP_007293:			; Pos = 66464
		call FUNC_001820
		mov [esi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [esi+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007294:			; Pos = 6647e
		xor esi,esi
		lea edx,[ebx+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov [ebp-0x18],ecx
		mov ecx,[ebp+0x18]
		lea ecx,[ecx*8+DATA_009260]
		mov [ebp-0x14],ecx
	JUMP_007295:			; Pos = 6649f
		mov ecx,[ebp-0x14]
		cmp dword [ecx],byte +0x0
		jz JUMP_007296
		mov ecx,[ebp-0x18]
		movsx ecx,word [ecx]
		movsx edi,word [eax]
		add ecx,edi
		sar ecx,1
		mov [edx],cx
		mov ecx,[ebp-0x18]
		movsx ecx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ecx,edi
		sar ecx,1
		mov [edx+0x2],cx
	JUMP_007296:			; Pos = 664ca
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x18],byte +0x4
		add dword [ebp-0x14],0x100
		cmp esi,byte +0x2
		jl JUMP_007295
		mov eax,[ebp+0xc]
		mov edx,[eax+0x28]
		mov [ebx+0x28],edx
		mov edx,[eax+0x2c]
		mov [ebx+0x2c],edx
		mov edx,[eax+0x30]
		mov [ebx+0x30],edx
		xor eax,eax
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007297
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007298
	JUMP_007297:			; Pos = 66513
		mov eax,[ebp+0x18]
	JUMP_007298:			; Pos = 66516
		mov edx,[ebp+0xc]
		cmp eax,[edx+0x44]
		jng near JUMP_007305
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007305
		mov eax,[ebp+0xc]
		mov eax,[eax+0x40]
		test eax,eax
		jnz JUMP_007299
		mov edx,[ebp+0x10]
		cmp dword [edx+0x40],byte +0x0
		jz JUMP_007300
	JUMP_007299:			; Pos = 66541
		mov edx,[ebp+0x10]
		add eax,[edx+0x40]
		sar eax,1
		mov [ebx+0x40],eax
		mov [ebx+0x3c],eax
		jmp short JUMP_007301
	JUMP_007300:			; Pos = 66551
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		xor eax,eax
		mov [ebx+0x40],eax
	JUMP_007301:			; Pos = 66567
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007302
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007303
	JUMP_007302:			; Pos = 665ac
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007311
	JUMP_007303:			; Pos = 665b9
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007304
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov [ebp-0xc],edx
		mov edx,[ebp+0x14]
		movsx edx,word [edx]
		mov ecx,[ebp+0xc]
		movsx ecx,word [ecx]
		sub edx,ecx
		mov ecx,[ebp+0x10]
		movsx ecx,word [ecx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		mov ecx,[ebp+0x10]
		movsx ecx,word [ecx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ecx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ecx,esi
		cmp edx,ecx
		setg dl
		and edx,byte +0x1
		mov ecx,eax
		shl ecx,0x4
		add ecx,DATA_007878
		mov esi,[ebp-0xc]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+edx*4]
		add [ebx],cx
		shl eax,0x4
		add eax,DATA_007879
		mov ecx,[ebp-0xc]
		lea eax,[eax+ecx*8]
		mov ax,[eax+edx*4]
		add [ebx+0x2],ax
	JUMP_007304:			; Pos = 66690
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007311
	JUMP_007305:			; Pos = 666b4
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov edi,[eax+0x3c]
		push edi
		mov eax,[ebp+0xc]
		mov esi,[eax+0x3c]
		push esi
		call FUNC_001846
		add esp,byte +0xc
		add esi,edi
		sar esi,1
		add eax,esi
		mov [ebx+0x3c],eax
		xor esi,esi
		lea eax,[ebx+0x34]
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007306:			; Pos = 666e6
		cmp dword [edx],byte +0x0
		jz JUMP_007308
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007308
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007308
		sar dword [ebx+0x3c],0x7
		movsx ecx,word [eax]
		movsx edi,word [eax+0x2]
		shl edi,0x7
		add ecx,edi
		mov [ebp-0x4],ecx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007307
		mov ecx,[edx+0x4]
		mov edi,[ebp-0x4]
		movzx ecx,byte [ecx+edi]
		imul ecx,[ebx+0x3c]
		mov [ebx+0x3c],ecx
	JUMP_007307:			; Pos = 6672c
		mov ecx,[edx]
		mov edi,[ebp-0x4]
		movsx ecx,byte [ecx+edi]
		shl ecx,0x15
		add [ebx+0x3c],ecx
	JUMP_007308:			; Pos = 6673b
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007306
		cmp dword [ebx+0x3c],byte +0x0
		jl JUMP_007309
		mov eax,[ebx+0x3c]
		jmp short JUMP_007310
	JUMP_007309:			; Pos = 66755
		xor eax,eax
	JUMP_007310:			; Pos = 66757
		mov [ebx+0x40],eax
		mov edx,[ebp+0xc]
		mov edx,[edx+0x40]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x40]
		sar edx,1
		mov esi,eax
		sub esi,edx
		sar esi,0x3
		add esi,[ebp-0x8]
		push esi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push esi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push esi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007311:			; Pos = 667da
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007312:			; Pos = 667e1
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001862:			; Pos = 667e8

		push ebp
		mov ebp,esp
		add esp,byte -0x10
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov eax,[ebx+0x8]
		test eax,eax
		jz JUMP_007315
		mov [ebp-0x4],eax
		xor esi,esi
		mov eax,[ebp-0x4]
		lea ecx,[eax+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0xc],ebx
	JUMP_007313:			; Pos = 6681f
		mov ebx,[ebp-0xc]
		cmp dword [ebx],byte +0x0
		jz JUMP_007314
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007314:			; Pos = 66844
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0xc],0x100
		cmp esi,byte +0x2
		jl JUMP_007313
		jmp JUMP_007328
	JUMP_007315:			; Pos = 6685f
		call FUNC_001818
		mov [ebx+0x8],eax
		mov [ebp-0x4],eax
		mov eax,[ebx]
		cmp eax,[ebp+0xc]
		jnz JUMP_007316
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007317
	JUMP_007316:			; Pos = 6688d
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007317:			; Pos = 668a7
		xor esi,esi
		mov eax,[ebp-0x4]
		lea edx,[eax+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007318:			; Pos = 668c8
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007319
		movsx ebx,word [ecx]
		movsx edi,word [eax]
		add ebx,edi
		sar ebx,1
		mov [edx],bx
		movsx ebx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ebx,edi
		sar ebx,1
		mov [edx+0x2],bx
	JUMP_007319:			; Pos = 668ed
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add ecx,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007318
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x4]
		mov [edx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x4]
		mov [edx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x4]
		mov [edx+0x30],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007839]
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007323
		mov eax,[ebp+0x10]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007323
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x3c],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007320
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007321
	JUMP_007320:			; Pos = 66a02
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007327
	JUMP_007321:			; Pos = 66a12
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007322
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx]
		mov ebx,[ebp+0xc]
		movsx ebx,word [ebx]
		sub ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ebx,esi
		imul ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ebx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ebx,esi
		cmp ecx,ebx
		setg cl
		and ecx,byte +0x1
		mov ebx,eax
		shl ebx,0x4
		add ebx,DATA_007880
		lea ebx,[ebx+edx*8]
		mov bx,[ebx+ecx*4]
		mov esi,[ebp-0x4]
		add [esi],bx
		shl eax,0x4
		add eax,DATA_007881
		lea eax,[eax+edx*8]
		mov ax,[eax+ecx*4]
		mov edx,[ebp-0x4]
		add [edx+0x2],ax
	JUMP_007322:			; Pos = 66aec
		mov eax,[ebp-0x4]
		movsx eax,word [eax]
		push eax
		call near [DATA_009280]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x24],ax
		mov eax,[ebp-0x4]
		movsx eax,word [eax+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x26],ax
		jmp JUMP_007327
	JUMP_007323:			; Pos = 66b1c
		mov eax,[ebp+0xc]
		mov ebx,[eax+0x3c]
		mov edi,ebx
		mov eax,[ebp+0x10]
		mov esi,[eax+0x3c]
		add edi,esi
		sar edi,1
		mov eax,[ebp+0x18]
		push eax
		push esi
		push ebx
		call FUNC_001846
		add esp,byte +0xc
		add edi,eax
		mov eax,[ebp-0x4]
		mov [eax+0x3c],edi
		xor esi,esi
		mov eax,[ebp-0x4]
		add eax,byte +0x34
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007324:			; Pos = 66b56
		cmp dword [edx],byte +0x0
		jz JUMP_007326
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007326
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007326
		mov ecx,[ebp-0x4]
		sar dword [ecx+0x3c],0x7
		movsx ecx,word [eax]
		movsx ebx,word [eax+0x2]
		shl ebx,0x7
		add ecx,ebx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007325
		mov ebx,[edx+0x4]
		movzx ebx,byte [ebx+ecx]
		mov edi,[ebp-0x4]
		imul ebx,[edi+0x3c]
		mov [edi+0x3c],ebx
	JUMP_007325:			; Pos = 66b9c
		mov ebx,[edx]
		movsx ecx,byte [ebx+ecx]
		shl ecx,0x15
		mov ebx,[ebp-0x4]
		add [ebx+0x3c],ecx
	JUMP_007326:			; Pos = 66bab
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007324
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
	JUMP_007327:			; Pos = 66c40
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001829
		pop ecx
	JUMP_007328:			; Pos = 66c4a
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop
		nop
		nop




FUNC_001863:			; Pos = 66c54

		push ebp
		mov ebp,esp
		add esp,byte -0x14
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov eax,[ebx+0x8]
		test eax,eax
		jz JUMP_007331
		mov [ebp-0x4],eax
		xor esi,esi
		mov eax,[ebp-0x4]
		lea ecx,[eax+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007329:			; Pos = 66c8b
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007330
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007330:			; Pos = 66cb0
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007329
		jmp JUMP_007346
	JUMP_007331:			; Pos = 66ccb
		call FUNC_001818
		mov [ebx+0x8],eax
		mov [ebp-0x4],eax
		mov eax,[ebx]
		cmp eax,[ebp+0xc]
		jnz JUMP_007332
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007333
	JUMP_007332:			; Pos = 66cf9
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007333:			; Pos = 66d13
		xor esi,esi
		mov eax,[ebp-0x4]
		lea edx,[eax+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x14],ebx
	JUMP_007334:			; Pos = 66d34
		mov ebx,[ebp-0x14]
		cmp dword [ebx],byte +0x0
		jz JUMP_007335
		movsx ebx,word [ecx]
		movsx edi,word [eax]
		add ebx,edi
		sar ebx,1
		mov [edx],bx
		movsx ebx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ebx,edi
		sar ebx,1
		mov [edx+0x2],bx
	JUMP_007335:			; Pos = 66d59
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add ecx,byte +0x4
		add dword [ebp-0x14],0x100
		cmp esi,byte +0x2
		jl JUMP_007334
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x4]
		mov [edx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x4]
		mov [edx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x4]
		mov [edx+0x30],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007839]
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007336
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007337
	JUMP_007336:			; Pos = 66e06
		mov eax,[ebp+0x18]
	JUMP_007337:			; Pos = 66e09
		mov edx,[ebp+0xc]
		cmp eax,[edx+0x44]
		jng near JUMP_007341
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007341
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x3c],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007338
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007339
	JUMP_007338:			; Pos = 66e83
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007345
	JUMP_007339:			; Pos = 66e93
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x4]
		mov [edx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007340
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx]
		mov ebx,[ebp+0xc]
		movsx ebx,word [ebx]
		sub ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ebx,esi
		imul ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ebx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ebx,esi
		cmp ecx,ebx
		setg cl
		and ecx,byte +0x1
		mov ebx,eax
		shl ebx,0x4
		add ebx,DATA_007882
		lea ebx,[ebx+edx*8]
		mov bx,[ebx+ecx*4]
		mov esi,[ebp-0x4]
		add [esi],bx
		shl eax,0x4
		add eax,DATA_007883
		lea eax,[eax+edx*8]
		mov ax,[eax+ecx*4]
		mov edx,[ebp-0x4]
		add [edx+0x2],ax
	JUMP_007340:			; Pos = 66f6d
		mov eax,[ebp-0x4]
		movsx eax,word [eax]
		push eax
		call near [DATA_009280]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x24],ax
		mov eax,[ebp-0x4]
		movsx eax,word [eax+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov edx,[ebp-0x4]
		mov [edx+0x26],ax
		jmp JUMP_007345
	JUMP_007341:			; Pos = 66f9d
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov edi,[eax+0x3c]
		push edi
		mov eax,[ebp+0xc]
		mov esi,[eax+0x3c]
		push esi
		call FUNC_001846
		add esp,byte +0xc
		add esi,edi
		sar esi,1
		add eax,esi
		mov edx,[ebp-0x4]
		mov [edx+0x3c],eax
		xor esi,esi
		mov eax,[ebp-0x4]
		add eax,byte +0x34
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007342:			; Pos = 66fd5
		cmp dword [edx],byte +0x0
		jz JUMP_007344
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007344
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007344
		mov ecx,[ebp-0x4]
		sar dword [ecx+0x3c],0x7
		movsx ecx,word [eax]
		movsx ebx,word [eax+0x2]
		shl ebx,0x7
		add ecx,ebx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007343
		mov ebx,[edx+0x4]
		movzx ebx,byte [ebx+ecx]
		mov edi,[ebp-0x4]
		imul ebx,[edi+0x3c]
		mov [edi+0x3c],ebx
	JUMP_007343:			; Pos = 6701b
		mov ebx,[edx]
		movsx ecx,byte [ebx+ecx]
		shl ecx,0x15
		mov ebx,[ebp-0x4]
		add [ebx+0x3c],ecx
	JUMP_007344:			; Pos = 6702a
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007342
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x4],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0x8],eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp-0x4]
		mov eax,[eax+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x4]
		mov [edx+0xc],eax
		mov eax,[ebp-0x4]
		push eax
		call near [DATA_009282]
		pop ecx
	JUMP_007345:			; Pos = 670bf
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001829
		pop ecx
	JUMP_007346:			; Pos = 670c9
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001864:			; Pos = 670d0

		push ebp
		mov ebp,esp
		add esp,byte -0x14
		push ebx
		push esi
		push edi
		mov ebx,[ebp+0x8]
		mov eax,[ebx+0x8]
		test eax,eax
		jz JUMP_007349
		mov [ebp-0x8],eax
		xor esi,esi
		mov eax,[ebp-0x8]
		lea ecx,[eax+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007347:			; Pos = 67107
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007348
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007348:			; Pos = 6712c
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007347
		jmp JUMP_007362
	JUMP_007349:			; Pos = 67147
		call FUNC_001818
		mov [ebx+0x8],eax
		mov [ebp-0x8],eax
		mov eax,[ebx]
		cmp eax,[ebp+0xc]
		jnz JUMP_007350
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007351
	JUMP_007350:			; Pos = 67175
		call FUNC_001820
		mov [ebx+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [ebx+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007351:			; Pos = 6718f
		xor esi,esi
		mov eax,[ebp-0x8]
		lea edx,[eax+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x14],ebx
	JUMP_007352:			; Pos = 671b0
		mov ebx,[ebp-0x14]
		cmp dword [ebx],byte +0x0
		jz JUMP_007353
		movsx ebx,word [ecx]
		movsx edi,word [eax]
		add ebx,edi
		sar ebx,1
		mov [edx],bx
		movsx ebx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ebx,edi
		sar ebx,1
		mov [edx+0x2],bx
	JUMP_007353:			; Pos = 671d5
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add ecx,byte +0x4
		add dword [ebp-0x14],0x100
		cmp esi,byte +0x2
		jl JUMP_007352
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x8]
		mov [edx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x8]
		mov [edx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp-0x8]
		mov [edx+0x30],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007839]
		mov [ebp-0xc],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007357
		mov eax,[ebp+0x10]
		mov eax,[eax+0x44]
		cmp eax,[ebp+0x18]
		jnl near JUMP_007357
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x3c],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007354
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007355
	JUMP_007354:			; Pos = 672ea
		mov eax,[ebp-0x8]
		push eax
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007361
	JUMP_007355:			; Pos = 672fa
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov edx,[ebp-0x8]
		mov [edx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007356
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx]
		mov ebx,[ebp+0xc]
		movsx ebx,word [ebx]
		sub ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ebx,esi
		imul ecx,ebx
		mov ebx,[ebp+0x10]
		movsx ebx,word [ebx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ebx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ebx,esi
		cmp ecx,ebx
		setg cl
		and ecx,byte +0x1
		mov ebx,eax
		shl ebx,0x4
		add ebx,DATA_007884
		lea ebx,[ebx+edx*8]
		mov bx,[ebx+ecx*4]
		mov esi,[ebp-0x8]
		add [esi],bx
		shl eax,0x4
		add eax,DATA_007885
		lea eax,[eax+edx*8]
		mov ax,[eax+ecx*4]
		mov edx,[ebp-0x8]
		add [edx+0x2],ax
	JUMP_007356:			; Pos = 673d4
		mov eax,[ebp-0x8]
		movsx eax,word [eax]
		push eax
		call near [DATA_009280]
		pop ecx
		mov edx,[ebp-0x8]
		mov [edx+0x24],ax
		mov eax,[ebp-0x8]
		movsx eax,word [eax+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov edx,[ebp-0x8]
		mov [edx+0x26],ax
		jmp JUMP_007361
	JUMP_007357:			; Pos = 67404
		mov eax,[ebp+0xc]
		mov esi,[eax+0x3c]
		mov ebx,esi
		mov eax,[ebp+0x10]
		mov edi,[eax+0x3c]
		add ebx,edi
		sar ebx,1
		mov eax,[ebp+0x18]
		push eax
		push edi
		push esi
		call FUNC_001846
		add esp,byte +0xc
		add eax,ebx
		mov edx,[ebp-0x8]
		mov [edx+0x3c],eax
		xor esi,esi
		mov eax,[ebp-0x8]
		add eax,byte +0x34
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007358:			; Pos = 6743e
		cmp dword [edx],byte +0x0
		jz JUMP_007360
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007360
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007360
		mov ecx,[ebp-0x8]
		sar dword [ecx+0x3c],0x7
		movsx ecx,word [eax]
		movsx edi,word [eax+0x2]
		shl edi,0x7
		add ecx,edi
		mov [ebp-0x4],ecx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007359
		mov ecx,[edx+0x4]
		mov edi,[ebp-0x4]
		movzx ecx,byte [ecx+edi]
		mov edi,[ebp-0x8]
		imul ecx,[edi+0x3c]
		mov [edi+0x3c],ecx
	JUMP_007359:			; Pos = 6748a
		mov ecx,[edx]
		mov edi,[ebp-0x4]
		movsx ecx,byte [ecx+edi]
		shl ecx,0x15
		mov edi,[ebp-0x8]
		add [edi+0x3c],ecx
	JUMP_007360:			; Pos = 6749c
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007358
		mov eax,[ebp-0x8]
		mov eax,[eax+0x3c]
		sub eax,ebx
		sar eax,0x3
		add eax,[ebp-0xc]
		mov ebx,eax
		push ebx
		mov eax,[ebp-0x8]
		mov eax,[eax+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x8]
		mov [edx+0x4],eax
		push ebx
		mov eax,[ebp-0x8]
		mov eax,[eax+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x8]
		mov [edx+0x8],eax
		push ebx
		mov eax,[ebp-0x8]
		mov eax,[eax+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov edx,[ebp-0x8]
		mov [edx+0xc],eax
		mov eax,[ebp-0x8]
		push eax
		call near [DATA_009282]
		pop ecx
	JUMP_007361:			; Pos = 67538
		mov eax,[ebp-0x8]
		push eax
		call FUNC_001829
		pop ecx
	JUMP_007362:			; Pos = 67542
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret
		nop
		nop
		nop




FUNC_001865:			; Pos = 6754c

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x8]
		mov eax,[esi+0x8]
		test eax,eax
		jz JUMP_007365
		mov ebx,eax
		xor esi,esi
		lea ecx,[ebx+0x34]
		mov eax,[ebp+0x10]
		lea edx,[eax+0x34]
		mov eax,[ebp+0xc]
		add eax,byte +0x34
		mov ebx,[ebp+0x18]
		lea ebx,[ebx*8+DATA_009260]
		mov [ebp-0x10],ebx
	JUMP_007363:			; Pos = 6757f
		mov ebx,[ebp-0x10]
		cmp dword [ebx],byte +0x0
		jz JUMP_007364
		movsx ebx,word [eax]
		movsx edi,word [edx]
		add ebx,edi
		sar ebx,1
		mov [ecx],bx
		movsx ebx,word [eax+0x2]
		movsx edi,word [edx+0x2]
		add ebx,edi
		sar ebx,1
		mov [ecx+0x2],bx
	JUMP_007364:			; Pos = 675a4
		inc esi
		add ecx,byte +0x4
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x10],0x100
		cmp esi,byte +0x2
		jl JUMP_007363
		jmp JUMP_007385
	JUMP_007365:			; Pos = 675bf
		call FUNC_001818
		mov [esi+0x8],eax
		mov ebx,eax
		mov eax,[esi]
		cmp eax,[ebp+0xc]
		jnz JUMP_007366
		call FUNC_001820
		mov [esi+0x4],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
		call FUNC_001820
		mov [esi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007367
	JUMP_007366:			; Pos = 675ec
		call FUNC_001820
		mov [esi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [esi+0xc],eax
		mov edx,[ebp+0xc]
		mov [eax],edx
	JUMP_007367:			; Pos = 67606
		xor esi,esi
		lea edx,[ebx+0x34]
		mov eax,[ebp+0x10]
		add eax,byte +0x34
		mov ecx,[ebp+0xc]
		add ecx,byte +0x34
		mov [ebp-0x18],ecx
		mov ecx,[ebp+0x18]
		lea ecx,[ecx*8+DATA_009260]
		mov [ebp-0x14],ecx
	JUMP_007368:			; Pos = 67627
		mov ecx,[ebp-0x14]
		cmp dword [ecx],byte +0x0
		jz JUMP_007369
		mov ecx,[ebp-0x18]
		movsx ecx,word [ecx]
		movsx edi,word [eax]
		add ecx,edi
		sar ecx,1
		mov [edx],cx
		mov ecx,[ebp-0x18]
		movsx ecx,word [ecx+0x2]
		movsx edi,word [eax+0x2]
		add ecx,edi
		sar ecx,1
		mov [edx+0x2],cx
	JUMP_007369:			; Pos = 67652
		inc esi
		add edx,byte +0x4
		add eax,byte +0x4
		add dword [ebp-0x18],byte +0x4
		add dword [ebp-0x14],0x100
		cmp esi,byte +0x2
		jl JUMP_007368
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x30],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007839]
		mov [ebp-0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		dec eax
		mov edx,[ebp+0x10]
		mov edx,[edx+0x3c]
		dec edx
		xor eax,edx
		jnl JUMP_007370
		mov eax,[ebp+0x18]
		dec eax
		jmp short JUMP_007371
	JUMP_007370:			; Pos = 676f7
		mov eax,[ebp+0x18]
	JUMP_007371:			; Pos = 676fa
		mov edx,[ebp+0xc]
		cmp eax,[edx+0x44]
		jng near JUMP_007378
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007378
		mov eax,[ebp+0xc]
		mov eax,[eax+0x40]
		test eax,eax
		jnz JUMP_007372
		mov edx,[ebp+0x10]
		cmp dword [edx+0x40],byte +0x0
		jz JUMP_007373
	JUMP_007372:			; Pos = 67725
		mov edx,[ebp+0x10]
		add eax,[edx+0x40]
		sar eax,1
		mov [ebx+0x40],eax
		mov [ebx+0x3c],eax
		jmp short JUMP_007374
	JUMP_007373:			; Pos = 67735
		mov eax,[ebp+0xc]
		mov eax,[eax+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		xor eax,eax
		mov [ebx+0x40],eax
	JUMP_007374:			; Pos = 6774b
		mov eax,[ebp+0xc]
		mov eax,[eax+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[ebp+0xc]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		mov eax,[ebp+0xc]
		cmp dword [eax+0xc],byte +0x40
		jl JUMP_007375
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007376
	JUMP_007375:			; Pos = 67790
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007384
	JUMP_007376:			; Pos = 6779d
		mov eax,[ebp+0xc]
		movsx eax,word [eax]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		mov eax,[ebp+0xc]
		movsx eax,word [eax+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007377
		mov eax,[ebp+0xc]
		mov ax,[eax+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov edx,[ebp+0xc]
		mov dx,[edx]
		mov ecx,[ebp+0x10]
		cmp dx,[ecx]
		setg dl
		and edx,byte +0x1
		mov [ebp-0xc],edx
		mov edx,[ebp+0x14]
		movsx edx,word [edx]
		mov ecx,[ebp+0xc]
		movsx ecx,word [ecx]
		sub edx,ecx
		mov ecx,[ebp+0x10]
		movsx ecx,word [ecx+0x2]
		mov esi,[ebp+0xc]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		mov ecx,[ebp+0x10]
		movsx ecx,word [ecx]
		mov esi,[ebp+0xc]
		movsx esi,word [esi]
		sub ecx,esi
		mov esi,[ebp+0x14]
		movsx esi,word [esi+0x2]
		mov edi,[ebp+0xc]
		movsx edi,word [edi+0x2]
		sub esi,edi
		imul ecx,esi
		cmp edx,ecx
		setg dl
		and edx,byte +0x1
		mov ecx,eax
		shl ecx,0x4
		add ecx,DATA_007886
		mov esi,[ebp-0xc]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+edx*4]
		add [ebx],cx
		shl eax,0x4
		add eax,DATA_007887
		mov ecx,[ebp-0xc]
		lea eax,[eax+ecx*8]
		mov ax,[eax+edx*4]
		add [ebx+0x2],ax
	JUMP_007377:			; Pos = 67874
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp JUMP_007384
	JUMP_007378:			; Pos = 67898
		mov eax,[ebp+0x18]
		push eax
		mov eax,[ebp+0x10]
		mov edi,[eax+0x3c]
		push edi
		mov eax,[ebp+0xc]
		mov esi,[eax+0x3c]
		push esi
		call FUNC_001846
		add esp,byte +0xc
		add esi,edi
		sar esi,1
		add eax,esi
		mov [ebx+0x3c],eax
		xor esi,esi
		lea eax,[ebx+0x34]
		mov edx,[ebp+0x18]
		lea edx,[edx*8+DATA_009260]
	JUMP_007379:			; Pos = 678ca
		cmp dword [edx],byte +0x0
		jz JUMP_007381
		movsx ecx,word [eax]
		cmp ecx,0x80
		jnc JUMP_007381
		movsx ecx,word [eax+0x2]
		cmp ecx,0x80
		jnc JUMP_007381
		sar dword [ebx+0x3c],0x7
		movsx ecx,word [eax]
		movsx edi,word [eax+0x2]
		shl edi,0x7
		add ecx,edi
		mov [ebp-0x4],ecx
		cmp dword [edx+0x4],byte +0x0
		jz JUMP_007380
		mov ecx,[edx+0x4]
		mov edi,[ebp-0x4]
		movzx ecx,byte [ecx+edi]
		imul ecx,[ebx+0x3c]
		mov [ebx+0x3c],ecx
	JUMP_007380:			; Pos = 67910
		mov ecx,[edx]
		mov edi,[ebp-0x4]
		movsx ecx,byte [ecx+edi]
		shl ecx,0x15
		add [ebx+0x3c],ecx
	JUMP_007381:			; Pos = 6791f
		inc esi
		add eax,byte +0x4
		add edx,0x100
		cmp esi,byte +0x2
		jl JUMP_007379
		cmp dword [ebx+0x3c],byte +0x0
		jl JUMP_007382
		mov eax,[ebx+0x3c]
		jmp short JUMP_007383
	JUMP_007382:			; Pos = 67939
		xor eax,eax
	JUMP_007383:			; Pos = 6793b
		mov [ebx+0x40],eax
		mov edx,[ebp+0xc]
		mov edx,[edx+0x40]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x40]
		sar edx,1
		mov esi,eax
		sub esi,edx
		sar esi,0x3
		add esi,[ebp-0x8]
		push esi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push esi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push esi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[ebp+0xc]
		mov edx,[edx+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007384:			; Pos = 679be
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007385:			; Pos = 679c5
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001866:			; Pos = 679cc

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007393
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007386
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007387
	JUMP_007386:			; Pos = 67a0d
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007387:			; Pos = 67a24
		mov eax,[esi+0x28]
		mov [ebx+0x28],eax
		mov eax,[esi+0x2c]
		mov [ebx+0x2c],eax
		mov eax,[esi+0x30]
		mov [ebx+0x30],eax
		xor edi,edi
		mov eax,[ebp+0x18]
		cmp eax,[esi+0x44]
		jng near JUMP_007391
		mov eax,[ebp+0x18]
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007391
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007388
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007389
	JUMP_007388:			; Pos = 67a9a
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007392
	JUMP_007389:			; Pos = 67aa7
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007390
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x4]
		shl edx,0x4
		lea ecx,[edx+DATA_007888]
		mov esi,[ebp-0x8]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007889
		mov ecx,[ebp-0x8]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007390:			; Pos = 67b67
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp short JUMP_007392
	JUMP_007391:			; Pos = 67b88
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007392:			; Pos = 67bf5
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007393:			; Pos = 67bfc
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret
		nop




FUNC_001867:			; Pos = 67c04

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov edi,[ebp+0x8]
		mov eax,[edi+0x8]
		test eax,eax
		jnz near JUMP_007401
		call FUNC_001818
		mov [edi+0x8],eax
		mov ebx,eax
		cmp esi,[edi]
		jnz JUMP_007394
		call FUNC_001820
		mov [edi+0x4],eax
		mov [eax],esi
		call FUNC_001820
		mov [edi+0xc],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		jmp short JUMP_007395
	JUMP_007394:			; Pos = 67c45
		call FUNC_001820
		mov [edi+0x4],eax
		mov edx,[ebp+0x10]
		mov [eax],edx
		call FUNC_001820
		mov [edi+0xc],eax
		mov [eax],esi
	JUMP_007395:			; Pos = 67c5c
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x28]
		mov edx,[ebp+0x10]
		add eax,[edx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x28],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x2c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x2c],eax
		mov eax,[ebp+0x18]
		mov eax,[eax*4+DATA_007840]
		push eax
		mov eax,[esi+0x30]
		mov edx,[ebp+0x10]
		add eax,[edx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov [ebx+0x30],eax
		mov eax,[ebp+0x18]
		mov edi,[eax*4+DATA_007839]
		mov eax,[ebp+0x18]
		cmp eax,[esi+0x44]
		jng near JUMP_007399
		mov eax,[ebp+0x18]
		mov edx,[ebp+0x10]
		cmp eax,[edx+0x44]
		jng near JUMP_007399
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		mov eax,[esi+0x4]
		mov edx,[ebp+0x10]
		add eax,[edx+0x4]
		sar eax,1
		mov [ebx+0x4],eax
		mov eax,[esi+0x8]
		mov edx,[ebp+0x10]
		add eax,[edx+0x8]
		sar eax,1
		mov [ebx+0x8],eax
		mov eax,[esi+0xc]
		mov edx,[ebp+0x10]
		add eax,[edx+0xc]
		sar eax,1
		mov [ebx+0xc],eax
		cmp dword [esi+0xc],byte +0x40
		jl JUMP_007396
		mov eax,[ebp+0x10]
		cmp dword [eax+0xc],byte +0x40
		jnl JUMP_007397
	JUMP_007396:			; Pos = 67d28
		push ebx
		call near [DATA_009282]
		pop ecx
		jmp JUMP_007400
	JUMP_007397:			; Pos = 67d35
		movsx eax,word [esi]
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		add eax,edx
		sar eax,1
		mov [ebx],ax
		movsx eax,word [esi+0x2]
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		add eax,edx
		sar eax,1
		mov [ebx+0x2],ax
		mov eax,[ebp+0x14]
		cmp dword [eax+0xc],byte +0x40
		jng near JUMP_007398
		mov ax,[esi+0x2]
		mov edx,[ebp+0x10]
		cmp ax,[edx+0x2]
		setg al
		and eax,byte +0x1
		mov [ebp-0x4],eax
		mov ax,[esi]
		mov edx,[ebp+0x10]
		cmp ax,[edx]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		mov eax,[ebp+0x14]
		movsx eax,word [eax]
		movsx edx,word [esi]
		sub eax,edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx+0x2]
		movsx ecx,word [esi+0x2]
		sub edx,ecx
		imul edx
		mov edx,[ebp+0x10]
		movsx edx,word [edx]
		movsx ecx,word [esi]
		sub edx,ecx
		mov ecx,[ebp+0x14]
		movsx ecx,word [ecx+0x2]
		movsx esi,word [esi+0x2]
		sub ecx,esi
		imul edx,ecx
		cmp eax,edx
		setg al
		and eax,byte +0x1
		mov edx,[ebp-0x4]
		shl edx,0x4
		lea ecx,[edx+DATA_007890]
		mov esi,[ebp-0x8]
		lea ecx,[ecx+esi*8]
		mov cx,[ecx+eax*4]
		add [ebx],cx
		add edx,DATA_007891
		mov ecx,[ebp-0x8]
		lea edx,[edx+ecx*8]
		mov ax,[edx+eax*4]
		add [ebx+0x2],ax
	JUMP_007398:			; Pos = 67df5
		movsx eax,word [ebx]
		push eax
		call near [DATA_009280]
		pop ecx
		mov [ebx+0x24],ax
		movsx eax,word [ebx+0x2]
		push eax
		call near [DATA_009281]
		pop ecx
		mov [ebx+0x26],ax
		jmp short JUMP_007400
	JUMP_007399:			; Pos = 67e16
		mov eax,[esi+0x3c]
		mov edx,[ebp+0x10]
		add eax,[edx+0x3c]
		sar eax,1
		mov [ebx+0x3c],eax
		push edi
		mov eax,[ebx+0x28]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x4]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x4]
		sar edx,1
		add eax,edx
		mov [ebx+0x4],eax
		push edi
		mov eax,[ebx+0x2c]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0x8]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0x8]
		sar edx,1
		add eax,edx
		mov [ebx+0x8],eax
		push edi
		mov eax,[ebx+0x30]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		mov edx,[esi+0xc]
		mov ecx,[ebp+0x10]
		add edx,[ecx+0xc]
		sar edx,1
		add eax,edx
		mov [ebx+0xc],eax
		push ebx
		call near [DATA_009282]
		pop ecx
	JUMP_007400:			; Pos = 67e83
		push ebx
		call FUNC_001829
		pop ecx
	JUMP_007401:			; Pos = 67e8a
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ecx
		pop ebp
		ret
		nop
		nop
		nop




FUNC_001875:			; Pos = 6d5f0

		push ebp
		mov ebp,esp
		add esp,byte -0x18
		push ebx
		push esi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov eax,[esi+0x4]
		push eax
		mov eax,[ebx]
		push eax
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001339_Int64MulCreate
		add esp,byte +0xc
		mov eax,[esi]
		push eax
		mov eax,[ebx+0x4]
		push eax
		lea eax,[ebp-0x10]
		push eax
		call FUNC_001339_Int64MulCreate
		add esp,byte +0xc
		push dword [ebp-0xc]
		push dword [ebp-0x10]
		push dword [ebp-0x4]
		push dword [ebp-0x8]
		lea eax,[ebp-0x18]
		push eax
		call FUNC_001335_Int64Sub64
		add esp,byte +0x14
		mov eax,[ebp-0x14]
		sar eax,0x1f
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_001876:			; Pos = 6d648

		push ebp
		mov ebp,esp
		add esp,0xfffff658
		push ebx
		push esi
		push edi
		mov esi,DATA_007893
		lea edi,[ebp+0xfffffd84]
		mov ecx,0x78
		rep movsd
		mov esi,DATA_007894
		lea edi,[ebp+0xfffff6f4]
		mov ecx,0x3c
		rep movsd
		mov eax,[ebp+0x10]
		mov eax,[eax+0xa0]
		mov [ebp-0x4],eax
		cmp dword [ebp+0x34],byte +0x0
		jz JUMP_007953
		mov dword [DATA_009283],0x7fffffff
		mov eax,[ebp+0xc]
		mov [DATA_009285],eax
		mov dword [DATA_009284],0x4000
		jmp short JUMP_007956
	JUMP_007953:			; Pos = 6d6a8
		mov eax,[ebp+0x14]
		mov eax,[eax+0x148]
		add eax,byte -0x8
		mov [ebp-0x10],eax
		cmp dword [ebp-0x10],byte +0x0
		jnl JUMP_007954
		mov ecx,[ebp-0x10]
		neg ecx
		sar dword [ebp+0x28],cl
		jmp short JUMP_007955
	JUMP_007954:			; Pos = 6d6c7
		mov ecx,[ebp-0x10]
		shl dword [ebp+0x28],cl
	JUMP_007955:			; Pos = 6d6cd
		mov eax,[ebp+0x30]
		push eax
		lea eax,[ebp-0x30]
		push eax
		call FUNC_001692
		add esp,byte +0x8
		lea eax,[ebp-0x30]
		push dword [eax+0xc]
		push dword [eax+0x8]
		push dword [eax+0x4]
		push dword [eax]
		push dword DATA_009259
		call FUNC_001691
		add esp,byte +0x14
		mov eax,[ebp+0x28]
		push eax
		mov eax,[ebp+0x2c]
		push eax
		mov eax,[DATA_009259]
		push eax
		mov eax,[ebp+0x20]
		push eax
		mov eax,[ebp+0x1c]
		push eax
		mov eax,[ebp+0x14]
		push eax
		call FUNC_001877
		add esp,byte +0x18
	JUMP_007956:			; Pos = 6d71a
		mov eax,[ebp+0x20]
		push eax
		call FUNC_001825
		pop ecx
		add eax,byte -0xe
		mov [ebp-0x10],eax
		cmp dword [ebp-0x10],byte +0x0
		jng JUMP_007957
		mov ecx,[ebp-0x10]
		mov eax,[ebp+0x20]
		mov eax,[eax]
		sar eax,cl
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx]
		sar edx,cl
		imul edx
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x4]
		sar edx,cl
		mov ecx,[ebp-0x10]
		mov ebx,[ebp+0x20]
		mov ebx,[ebx+0x4]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x8]
		sar edx,cl
		mov ecx,[ebp-0x10]
		mov ebx,[ebp+0x20]
		mov ebx,[ebx+0x8]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		push eax
		call near [DATA_007723]    ; FUNC_001467
		pop ecx
		mov ecx,[ebp-0x10]
		shl eax,cl
		mov [ebp-0xc],eax
		jmp short JUMP_007958
	JUMP_007957:			; Pos = 6d78e
		mov eax,[ebp+0x20]
		mov eax,[eax]
		mov edx,[ebp+0x20]
		imul dword [edx]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x4]
		mov ecx,[ebp+0x20]
		imul edx,[ecx+0x4]
		add eax,edx
		mov edx,[ebp+0x20]
		mov edx,[edx+0x8]
		mov ecx,[ebp+0x20]
		imul edx,[ecx+0x8]
		add eax,edx
		push eax
		call near [DATA_007723]    ; FUNC_001467
		pop ecx
		mov [ebp-0xc],eax
	JUMP_007958:			; Pos = 6d7c1
		mov eax,[ebp+0x20]
		add eax,byte +0xc
		push eax
		call FUNC_001825
		pop ecx
		add eax,byte -0xe
		mov [ebp-0x10],eax
		cmp dword [ebp-0x10],byte +0x0
		jng JUMP_007959
		mov ecx,[ebp-0x10]
		mov eax,[ebp+0x20]
		mov eax,[eax+0xc]
		sar eax,cl
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0xc]
		sar edx,cl
		imul edx
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x10]
		sar edx,cl
		mov ecx,[ebp-0x10]
		mov ebx,[ebp+0x20]
		mov ebx,[ebx+0x10]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x14]
		sar edx,cl
		mov ecx,[ebp-0x10]
		mov ebx,[ebp+0x20]
		mov ebx,[ebx+0x14]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		push eax
		call near [DATA_007723]    ; FUNC_001467
		pop ecx
		mov ecx,[ebp-0x10]
		shl eax,cl
		mov [ebp-0x8],eax
		jmp short JUMP_007960
	JUMP_007959:			; Pos = 6d83a
		mov eax,[ebp+0x20]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x20]
		imul dword [edx+0xc]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x10]
		mov ecx,[ebp+0x20]
		imul edx,[ecx+0x10]
		add eax,edx
		mov edx,[ebp+0x20]
		mov edx,[edx+0x14]
		mov ecx,[ebp+0x20]
		imul edx,[ecx+0x14]
		add eax,edx
		push eax
		call near [DATA_007723]    ; FUNC_001467
		pop ecx
		mov [ebp-0x8],eax
	JUMP_007960:			; Pos = 6d86f
		mov eax,[ebp-0x8]
		cmp eax,[ebp-0xc]
		jng JUMP_007961
		mov eax,[ebp-0x8]
		mov [ebp-0xc],eax
	JUMP_007961:			; Pos = 6d87d
		mov eax,[ebp+0x20]
		add eax,byte +0x18
		push eax
		call FUNC_001825
		pop ecx
		add eax,byte -0xe
		mov [ebp-0x10],eax
		cmp dword [ebp-0x10],byte +0x0
		jng JUMP_007962
		mov ecx,[ebp-0x10]
		mov eax,[ebp+0x20]
		mov eax,[eax+0x18]
		sar eax,cl
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x18]
		sar edx,cl
		imul edx
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x1c]
		sar edx,cl
		mov ecx,[ebp-0x10]
		mov ebx,[ebp+0x20]
		mov ebx,[ebx+0x1c]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		mov ecx,[ebp-0x10]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x20]
		sar edx,cl
		mov ecx,[ebp-0x10]
		mov ebx,[ebp+0x20]
		mov ebx,[ebx+0x20]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		push eax
		call near [DATA_007723]    ; FUNC_001467
		pop ecx
		mov ecx,[ebp-0x10]
		shl eax,cl
		mov [ebp-0x8],eax
		jmp short JUMP_007963
	JUMP_007962:			; Pos = 6d8f6
		mov eax,[ebp+0x20]
		mov eax,[eax+0x18]
		mov edx,[ebp+0x20]
		imul dword [edx+0x18]
		mov edx,[ebp+0x20]
		mov edx,[edx+0x1c]
		mov ecx,[ebp+0x20]
		imul edx,[ecx+0x1c]
		add eax,edx
		mov edx,[ebp+0x20]
		mov edx,[edx+0x20]
		mov ecx,[ebp+0x20]
		imul edx,[ecx+0x20]
		add eax,edx
		push eax
		call near [DATA_007723]    ; FUNC_001467
		pop ecx
		mov [ebp-0x8],eax
	JUMP_007963:			; Pos = 6d92b
		mov eax,[ebp-0x8]
		cmp eax,[ebp-0xc]
		jng JUMP_007964
		mov eax,[ebp-0x8]
		mov [ebp-0xc],eax
	JUMP_007964:			; Pos = 6d939
		push dword 0x54000000
		mov eax,[ebp-0xc]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		add eax,eax
		mov [ebp-0x8],eax
		cmp dword [ebp+0x34],byte +0x0
		jnz near JUMP_007966
		mov eax,[DATA_008812]
		dec eax
		mov [DATA_007837],eax
		mov eax,[ebp+0x1c]
		push eax
		call FUNC_001825
		pop ecx
		add eax,byte -0xe
		mov [ebp-0x38],eax
		cmp dword [ebp-0x38],byte +0x0
		jnl JUMP_007965
		xor eax,eax
		mov [ebp-0x38],eax
	JUMP_007965:			; Pos = 6d97f
		mov ecx,[ebp-0x38]
		mov eax,[ebp+0x1c]
		mov eax,[eax]
		sar eax,cl
		mov ecx,[ebp-0x38]
		mov edx,[ebp+0x1c]
		mov edx,[edx]
		sar edx,cl
		imul edx
		mov ecx,[ebp-0x38]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x4]
		sar edx,cl
		mov ecx,[ebp-0x38]
		mov ebx,[ebp+0x1c]
		mov ebx,[ebx+0x4]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		mov ecx,[ebp-0x38]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x8]
		sar edx,cl
		mov ecx,[ebp-0x38]
		mov ebx,[ebp+0x1c]
		mov ebx,[ebx+0x8]
		sar ebx,cl
		imul edx,ebx
		add eax,edx
		push eax
		call near [DATA_007723]    ; FUNC_001467
		pop ecx
		mov ecx,[ebp-0x38]
		shl eax,cl
		mov [ebp-0x34],eax
		mov eax,[ebp-0xc]
		sar eax,0x4
		add eax,[ebp-0xc]
		cmp eax,[ebp-0x34]
		jnc JUMP_007967
		inc dword [DATA_007837]
		mov eax,[ebp-0xc]
		sar eax,0x3
		add eax,[ebp-0xc]
		cmp eax,[ebp-0x34]
		jnc JUMP_007967
		inc dword [DATA_007837]
		jmp short JUMP_007967
	JUMP_007966:			; Pos = 6da05
		mov eax,[DATA_008812]
		dec eax
		mov [DATA_007837],eax
	JUMP_007967:			; Pos = 6da10
		mov eax,[ebp-0x8]
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		add eax,[DATA_007837]
		mov [DATA_009269],eax
		xor ebx,ebx
		lea edi,[ebp+0xfffff7e8]
		mov esi,DATA_007892
	JUMP_007968:			; Pos = 6da32
		mov eax,[ebp+0x20]
		mov eax,[eax]
		push eax
		mov eax,[esi]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[ebp+0x20]
		mov eax,[eax+0xc]
		push eax
		mov eax,[esi+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[ebp+0x20]
		mov eax,[eax+0x18]
		push eax
		mov eax,[esi+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [edi],edx
		mov eax,[ebp+0x20]
		mov eax,[eax+0x4]
		push eax
		mov eax,[esi]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[ebp+0x20]
		mov eax,[eax+0x10]
		push eax
		mov eax,[esi+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[ebp+0x20]
		mov eax,[eax+0x1c]
		push eax
		mov eax,[esi+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [edi+0x4],edx
		mov eax,[ebp+0x20]
		mov eax,[eax+0x8]
		push eax
		mov eax,[esi]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		push eax
		mov eax,[ebp+0x20]
		mov eax,[eax+0x14]
		push eax
		mov eax,[esi+0x4]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		push edx
		mov eax,[ebp+0x20]
		mov eax,[eax+0x20]
		push eax
		mov eax,[esi+0x8]
		push eax
		call FUNC_001521
		add esp,byte +0x8
		pop edx
		add edx,eax
		mov [edi+0x8],edx
		mov eax,[edi]
		mov [edi+0x24],eax
		mov eax,[edi+0x4]
		mov [edi+0x28],eax
		mov eax,[edi+0x8]
		mov [edi+0x2c],eax
		mov eax,[ebp+0x1c]
		mov eax,[eax]
		add [edi],eax
		mov eax,[ebp+0x1c]
		mov eax,[eax+0x4]
		add [edi+0x4],eax
		mov eax,[ebp+0x1c]
		mov eax,[eax+0x8]
		add [edi+0x8],eax
		cmp dword [ebp+0x34],byte +0x1
		jz JUMP_007969
		mov eax,ebx
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e8]
		add eax,edx
		push eax
		mov eax,ebx
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		push eax
		call FUNC_001479
		add esp,byte +0x8
	JUMP_007969:			; Pos = 6db53
		mov eax,[ebp-0x4]
		push eax
		call FUNC_001824
		pop ecx
		mov [ebp-0x4],eax
		mov eax,[ebp+0x24]
		add eax,eax
		lea eax,[eax+eax*2]
		mov eax,[eax*8+DATA_007843]
		cmp eax,FUNC_001842
		jz JUMP_007970
		mov eax,[ebp-0x4]
		sar eax,0x4
		mov [edi+0x38],eax
		jmp short JUMP_007971
	JUMP_007970:			; Pos = 6db81
		mov eax,[esi+0x4]
		sar eax,0x5
		add eax,0x4000000
		mov [edi+0x38],eax
	JUMP_007971:			; Pos = 6db8f
		inc ebx
		add edi,byte +0x48
		add esi,byte +0xc
		cmp ebx,byte +0xc
		jl near JUMP_007968
		mov eax,[ebp+0x18]
		push eax
		lea eax,[ebp-0x14]
		push eax
		call FUNC_001823
		add esp,byte +0x8
		mov [ebp+0x18],eax
		mov eax,[ebp+0x1c]
		mov eax,[eax+0x8]
		mov edx,[ebp-0xc]
		add edx,edx
		cmp eax,edx
		jng JUMP_007972
		mov dword [ebp-0x18],0x1
		jmp short JUMP_007973
	JUMP_007972:			; Pos = 6dbca
		xor eax,eax
		mov [ebp-0x18],eax
	JUMP_007973:			; Pos = 6dbcf
		push dword DATA_009271
		call _SetJmp
		pop ecx
		mov [ebp-0x20],eax
		test eax,eax
		jz JUMP_007974
		call FUNC_001817
		mov eax,[ebp+0x18]
		jmp JUMP_008044
	JUMP_007974:			; Pos = 6dbee
		call FUNC_001816
		xor ebx,ebx
		lea esi,[ebp+0xfffff6f4]
		lea edi,[ebp+0xfffff67c]
	JUMP_007975:			; Pos = 6dc01
		call FUNC_001820
		mov [edi],eax
		mov eax,[esi]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		mov edx,[edi]
		mov [edx],eax
		inc ebx
		add esi,byte +0x8
		add edi,byte +0x4
		cmp ebx,byte +0x1e
		jl JUMP_007975
		mov eax,[ebp+0x34]
		push eax
		mov eax,[ebp+0x24]
		push eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[ebp+0x14]
		push eax
		call FUNC_001833
		add esp,byte +0x10
		mov [ebp-0x1c],eax
		cmp dword [ebp+0x34],byte +0x1
		jnz near JUMP_008038
		xor ebx,ebx
	JUMP_007976:			; Pos = 6dc4f
		mov eax,[ebp-0x14]
		mov eax,[eax+ebx*4+0x8]
		mov [ebp-0x60],eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x60]
		push eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd8c]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		push eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd88]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		push eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd84]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		push eax
		call FUNC_001834
		add esp,byte +0x18
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd84]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7e8]
		mov edx,[ebp+0x1c]
		mov edx,[edx]
		neg edx
		add eax,edx
		mov [ebp+0xfffff670],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd84]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7ec]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x4]
		neg edx
		add eax,edx
		mov [ebp+0xfffff674],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd84]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7f0]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x8]
		neg edx
		add eax,edx
		mov [ebp+0xfffff678],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd88]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7e8]
		mov edx,[ebp+0x1c]
		mov edx,[edx]
		neg edx
		add eax,edx
		mov [ebp+0xfffff664],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd88]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7ec]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x4]
		neg edx
		add eax,edx
		mov [ebp+0xfffff668],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd88]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7f0]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x8]
		neg edx
		add eax,edx
		mov [ebp+0xfffff66c],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd8c]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7e8]
		mov edx,[ebp+0x1c]
		mov edx,[edx]
		neg edx
		add eax,edx
		mov [ebp+0xfffff658],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd8c]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7ec]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x4]
		neg edx
		add eax,edx
		mov [ebp+0xfffff65c],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd8c]
		lea eax,[eax+eax*8]
		mov eax,[ebp+eax*8+0xfffff7f0]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x8]
		neg edx
		add eax,edx
		mov [ebp+0xfffff660],eax
		lea eax,[ebp+0xfffff664]
		push eax
		lea eax,[ebp+0xfffff670]
		push eax
		call FUNC_001875
		add esp,byte +0x8
		mov [ebp-0x3c],eax
		lea eax,[ebp+0xfffff658]
		push eax
		lea eax,[ebp+0xfffff664]
		push eax
		call FUNC_001875
		add esp,byte +0x8
		mov [ebp-0x40],eax
		lea eax,[ebp+0xfffff670]
		push eax
		lea eax,[ebp+0xfffff658]
		push eax
		call FUNC_001875
		add esp,byte +0x8
		mov [ebp-0x44],eax
		cmp dword [ebp-0x3c],byte +0x0
		jl near JUMP_008037
		cmp dword [ebp-0x40],byte +0x0
		jl near JUMP_008037
		cmp dword [ebp-0x44],byte +0x0
		jl near JUMP_008037
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd84]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		mov [ebp-0x48],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd88]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		mov [ebp-0x4c],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd8c]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		mov [ebp-0x50],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd90]
		mov eax,[ebp+eax*4+0xfffff67c]
		mov [ebp-0x54],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd94]
		mov eax,[ebp+eax*4+0xfffff67c]
		mov [ebp-0x58],eax
		lea eax,[ebx+ebx*2]
		mov eax,[ebp+eax*8+0xfffffd98]
		mov eax,[ebp+eax*4+0xfffff67c]
		mov [ebp-0x5c],eax
		xor eax,eax
		mov [ebp-0x10],eax
		jmp JUMP_008001
	JUMP_007977:			; Pos = 6def9
		cmp dword [ebp-0x60],byte +0x0
		jz near JUMP_007982
		xor ebx,ebx
		mov eax,[ebp-0x50]
		add eax,byte +0x34
		mov [ebp+0xffffff64],eax
		mov eax,[ebp-0x4c]
		add eax,byte +0x34
		mov [ebp+0xffffff68],eax
		mov eax,[ebp-0x48]
		add eax,byte +0x34
		mov [ebp+0xffffff6c],eax
		mov dword [ebp+0xffffff70],DATA_009260
		mov eax,[ebp-0x60]
		mov [ebp+0xffffff74],eax
	JUMP_007978:			; Pos = 6df3c
		mov eax,[ebp+0xffffff74]
		cmp dword [eax],byte +0x0
		jng JUMP_007981
		mov eax,[ebp+0xffffff74]
		mov eax,[eax]
		mov [ebp-0x68],eax
		mov eax,[ebp-0x68]
		mov ecx,[eax]
		shl ecx,0x2
		lea ecx,[ecx+ecx*2]
		add ecx,DATA_007841
		mov eax,[ecx+0x8]
		add eax,[ebp-0x10]
		dec eax
		mov edx,[ebp+0xffffff70]
		lea edx,[edx+eax*8]
		cmp eax,[ebp-0x10]
		jl JUMP_007980
	JUMP_007979:			; Pos = 6df78
		mov esi,[ecx]
		mov [edx],esi
		mov esi,[ecx+0x4]
		mov [edx+0x4],esi
		dec eax
		add edx,byte -0x8
		cmp eax,[ebp-0x10]
		jnl JUMP_007979
	JUMP_007980:			; Pos = 6df8b
		mov eax,[ebp-0x68]
		mov eax,[eax+0x4]
		mov edx,[ebp+0xffffff6c]
		mov [edx],eax
		mov eax,[ebp-0x68]
		mov eax,[eax+0x8]
		mov edx,[ebp+0xffffff68]
		mov [edx],eax
		mov eax,[ebp-0x68]
		mov eax,[eax+0xc]
		mov edx,[ebp+0xffffff64]
		mov [edx],eax
	JUMP_007981:			; Pos = 6dfb5
		inc ebx
		add dword [ebp+0xffffff64],byte +0x4
		add dword [ebp+0xffffff68],byte +0x4
		add dword [ebp+0xffffff6c],byte +0x4
		add dword [ebp+0xffffff70],0x100
		add dword [ebp+0xffffff74],byte +0x4
		cmp ebx,byte +0x2
		jl near JUMP_007978
	JUMP_007982:			; Pos = 6dfe5
		cmp dword [ebp-0x10],byte +0x5
		jnl JUMP_007983
		mov eax,[ebp-0x10]
		push eax
		mov eax,[ebp-0x48]
		push eax
		mov eax,[ebp-0x50]
		push eax
		mov eax,[ebp-0x4c]
		push eax
		mov eax,[ebp-0x58]
		push eax
		call near [DATA_009278]
		add esp,byte +0x14
		mov eax,[ebp-0x10]
		push eax
		mov eax,[ebp-0x4c]
		push eax
		mov eax,[ebp-0x48]
		push eax
		mov eax,[ebp-0x50]
		push eax
		mov eax,[ebp-0x5c]
		push eax
		call near [DATA_009278]
		add esp,byte +0x14
		mov eax,[ebp-0x10]
		push eax
		mov eax,[ebp-0x50]
		push eax
		mov eax,[ebp-0x4c]
		push eax
		mov eax,[ebp-0x48]
		push eax
		mov eax,[ebp-0x54]
		push eax
		call near [DATA_009278]
		add esp,byte +0x14
		jmp short JUMP_007984
	JUMP_007983:			; Pos = 6e044
		mov eax,[ebp-0x10]
		push eax
		mov eax,[ebp-0x48]
		push eax
		mov eax,[ebp-0x50]
		push eax
		mov eax,[ebp-0x4c]
		push eax
		mov eax,[ebp-0x58]
		push eax
		call near [DATA_009279]
		add esp,byte +0x14
		mov eax,[ebp-0x10]
		push eax
		mov eax,[ebp-0x4c]
		push eax
		mov eax,[ebp-0x48]
		push eax
		mov eax,[ebp-0x50]
		push eax
		mov eax,[ebp-0x5c]
		push eax
		call near [DATA_009279]
		add esp,byte +0x14
		mov eax,[ebp-0x10]
		push eax
		mov eax,[ebp-0x50]
		push eax
		mov eax,[ebp-0x4c]
		push eax
		mov eax,[ebp-0x48]
		push eax
		mov eax,[ebp-0x54]
		push eax
		call near [DATA_009279]
		add esp,byte +0x14
	JUMP_007984:			; Pos = 6e09b
		mov eax,[ebp-0x58]
		mov eax,[eax+0x8]
		mov ecx,[eax+0x4]
		mov edx,[ebp+0x1c]
		mov edx,[edx]
		neg edx
		add ecx,edx
		mov [ebp+0xfffff670],ecx
		mov ebx,[eax+0x8]
		mov ecx,[ebp+0x1c]
		mov ecx,[ecx+0x4]
		neg ecx
		add ebx,ecx
		mov [ebp+0xfffff674],ebx
		mov eax,[eax+0xc]
		mov ebx,[ebp+0x1c]
		mov ebx,[ebx+0x8]
		neg ebx
		add eax,ebx
		mov [ebp+0xfffff678],eax
		mov eax,[ebp-0x5c]
		mov eax,[eax+0x8]
		mov ebx,[eax+0x4]
		mov esi,[ebp+0x1c]
		mov esi,[esi]
		neg esi
		add ebx,edx
		mov [ebp+0xfffff664],ebx
		mov ebx,[eax+0x8]
		mov esi,[ebp+0x1c]
		mov esi,[esi+0x4]
		neg esi
		add ebx,ecx
		mov [ebp+0xfffff668],ebx
		mov eax,[eax+0xc]
		mov ebx,[ebp+0x1c]
		mov ebx,[ebx+0x8]
		neg ebx
		add eax,ebx
		mov [ebp+0xfffff66c],eax
		mov eax,[ebp-0x54]
		mov eax,[eax+0x8]
		mov eax,[eax+0x4]
		mov ebx,[ebp+0x1c]
		mov ebx,[ebx]
		neg ebx
		add eax,edx
		mov [ebp+0xfffff658],eax
		mov eax,[ebp-0x54]
		mov eax,[eax+0x8]
		mov eax,[eax+0x8]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x4]
		neg edx
		add eax,ecx
		mov [ebp+0xfffff65c],eax
		mov eax,[ebp-0x54]
		mov eax,[eax+0x8]
		mov eax,[eax+0xc]
		mov edx,[ebp+0x1c]
		mov edx,[edx+0x8]
		neg edx
		add eax,edx
		mov [ebp+0xfffff660],eax
		lea eax,[ebp+0xfffff664]
		push eax
		lea eax,[ebp+0xfffff658]
		push eax
		call FUNC_001875
		add esp,byte +0x8
		test eax,eax
		jl JUMP_007989
		mov eax,[ebp-0x54]
		mov eax,[eax]
		cmp eax,[ebp-0x48]
		jnz JUMP_007985
		mov eax,[ebp-0x54]
		mov esi,[eax+0x4]
		jmp short JUMP_007986
	JUMP_007985:			; Pos = 6e18d
		mov eax,[ebp-0x54]
		mov esi,[eax+0xc]
	JUMP_007986:			; Pos = 6e193
		call FUNC_001820
		mov ebx,eax
		mov eax,[ebp-0x54]
		mov eax,[eax+0x8]
		mov [ebx],eax
		mov eax,[ebp-0x5c]
		mov eax,[eax]
		cmp eax,[ebp-0x48]
		jnz JUMP_007987
		mov eax,[ebp-0x5c]
		mov eax,[eax+0x4]
		jmp short JUMP_007988
	JUMP_007987:			; Pos = 6e1b4
		mov eax,[ebp-0x5c]
		mov eax,[eax+0xc]
	JUMP_007988:			; Pos = 6e1ba
		mov edx,[ebp-0x48]
		mov [ebp-0x48],edx
		mov edx,[ebp-0x54]
		mov edx,[edx+0x8]
		mov [ebp-0x4c],edx
		mov edx,[ebp-0x5c]
		mov edx,[edx+0x8]
		mov [ebp-0x50],edx
		cmp dword [ebp-0x60],byte +0x0
		jz near JUMP_008000
		mov edx,[ebp-0x60]
		mov edx,[edx+0x8]
		mov [ebp-0x60],edx
		jmp JUMP_008000
	JUMP_007989:			; Pos = 6e1ea
		lea eax,[ebp+0xfffff658]
		push eax
		lea eax,[ebp+0xfffff670]
		push eax
		call FUNC_001875
		add esp,byte +0x8
		test eax,eax
		jl JUMP_007994
		mov eax,[ebp-0x58]
		mov eax,[eax]
		cmp eax,[ebp-0x4c]
		jnz JUMP_007990
		mov eax,[ebp-0x58]
		mov esi,[eax+0x4]
		jmp short JUMP_007991
	JUMP_007990:			; Pos = 6e216
		mov eax,[ebp-0x58]
		mov esi,[eax+0xc]
	JUMP_007991:			; Pos = 6e21c
		call FUNC_001820
		mov ebx,eax
		mov eax,[ebp-0x58]
		mov eax,[eax+0x8]
		mov [ebx],eax
		mov eax,[ebp-0x54]
		mov eax,[eax]
		cmp eax,[ebp-0x4c]
		jnz JUMP_007992
		mov eax,[ebp-0x54]
		mov eax,[eax+0x4]
		jmp short JUMP_007993
	JUMP_007992:			; Pos = 6e23d
		mov eax,[ebp-0x54]
		mov eax,[eax+0xc]
	JUMP_007993:			; Pos = 6e243
		mov edx,[ebp-0x4c]
		mov [ebp-0x48],edx
		mov edx,[ebp-0x58]
		mov edx,[edx+0x8]
		mov [ebp-0x4c],edx
		mov edx,[ebp-0x54]
		mov edx,[edx+0x8]
		mov [ebp-0x50],edx
		cmp dword [ebp-0x60],byte +0x0
		jz near JUMP_008000
		mov edx,[ebp-0x60]
		mov edx,[edx+0xc]
		mov [ebp-0x60],edx
		jmp JUMP_008000
	JUMP_007994:			; Pos = 6e273
		lea eax,[ebp+0xfffff670]
		push eax
		lea eax,[ebp+0xfffff664]
		push eax
		call FUNC_001875
		add esp,byte +0x8
		test eax,eax
		jl JUMP_007999
		mov eax,[ebp-0x5c]
		mov eax,[eax]
		cmp eax,[ebp-0x50]
		jnz JUMP_007995
		mov eax,[ebp-0x5c]
		mov esi,[eax+0x4]
		jmp short JUMP_007996
	JUMP_007995:			; Pos = 6e29f
		mov eax,[ebp-0x5c]
		mov esi,[eax+0xc]
	JUMP_007996:			; Pos = 6e2a5
		call FUNC_001820
		mov ebx,eax
		mov eax,[ebp-0x5c]
		mov eax,[eax+0x8]
		mov [ebx],eax
		mov eax,[ebp-0x58]
		mov eax,[eax]
		cmp eax,[ebp-0x50]
		jnz JUMP_007997
		mov eax,[ebp-0x58]
		mov eax,[eax+0x4]
		jmp short JUMP_007998
	JUMP_007997:			; Pos = 6e2c6
		mov eax,[ebp-0x58]
		mov eax,[eax+0xc]
	JUMP_007998:			; Pos = 6e2cc
		mov edx,[ebp-0x50]
		mov [ebp-0x48],edx
		mov edx,[ebp-0x5c]
		mov edx,[edx+0x8]
		mov [ebp-0x4c],edx
		mov edx,[ebp-0x58]
		mov edx,[edx+0x8]
		mov [ebp-0x50],edx
		cmp dword [ebp-0x60],byte +0x0
		jz JUMP_008000
		mov edx,[ebp-0x60]
		mov edx,[edx+0x10]
		mov [ebp-0x60],edx
		jmp short JUMP_008000
	JUMP_007999:			; Pos = 6e2f5
		call FUNC_001820
		mov esi,eax
		mov eax,[ebp-0x5c]
		mov eax,[eax+0x8]
		mov [esi],eax
		call FUNC_001820
		mov ebx,eax
		mov eax,[ebp-0x54]
		mov eax,[eax+0x8]
		mov [ebx],eax
		call FUNC_001820
		mov edx,[ebp-0x58]
		mov edx,[edx+0x8]
		mov [eax],edx
		mov edx,[ebp-0x58]
		mov edx,[edx+0x8]
		mov [ebp-0x48],edx
		mov edx,[ebp-0x5c]
		mov edx,[edx+0x8]
		mov [ebp-0x4c],edx
		mov edx,[ebp-0x54]
		mov edx,[edx+0x8]
		mov [ebp-0x50],edx
		cmp dword [ebp-0x60],byte +0x0
		jz JUMP_008000
		mov edx,[ebp-0x60]
		mov edx,[edx+0x14]
		mov [ebp-0x60],edx
	JUMP_008000:			; Pos = 6e34a
		mov [ebp-0x54],esi
		mov [ebp-0x58],ebx
		mov [ebp-0x5c],eax
		inc dword [ebp-0x10]
	JUMP_008001:			; Pos = 6e356
		cmp dword [ebp-0x10],byte +0x9
		jg JUMP_008002
		mov eax,[ebp-0x48]
		mov eax,[eax+0x44]
		cmp eax,[ebp-0x10]
		jnl near JUMP_007977
		mov eax,[ebp-0x4c]
		mov eax,[eax+0x44]
		cmp eax,[ebp-0x10]
		jnl near JUMP_007977
		mov eax,[ebp-0x50]
		mov eax,[eax+0x44]
		cmp eax,[ebp-0x10]
		jnl near JUMP_007977
	JUMP_008002:			; Pos = 6e389
		mov eax,[ebp-0x48]
		cmp dword [eax+0x4],byte +0x0
		jnl JUMP_008003
		mov eax,[ebp-0x48]
		mov eax,[eax+0x4]
		neg eax
		jmp short JUMP_008004
	JUMP_008003:			; Pos = 6e39c
		mov eax,[ebp-0x48]
		mov eax,[eax+0x4]
	JUMP_008004:			; Pos = 6e3a2
		mov edx,[ebp-0x48]
		cmp dword [edx+0x8],byte +0x0
		jnl JUMP_008005
		mov edx,[ebp-0x48]
		mov edx,[edx+0x8]
		neg edx
		jmp short JUMP_008006
	JUMP_008005:			; Pos = 6e3b5
		mov edx,[ebp-0x48]
		mov edx,[edx+0x8]
	JUMP_008006:			; Pos = 6e3bb
		or eax,edx
		mov edx,[ebp-0x48]
		cmp dword [edx+0xc],byte +0x0
		jnl JUMP_008007
		mov edx,[ebp-0x48]
		mov edx,[edx+0xc]
		neg edx
		jmp short JUMP_008008
	JUMP_008007:			; Pos = 6e3d0
		mov edx,[ebp-0x48]
		mov edx,[edx+0xc]
	JUMP_008008:			; Pos = 6e3d6
		or eax,edx
		mov edx,[ebp-0x4c]
		cmp dword [edx+0x4],byte +0x0
		jnl JUMP_008009
		mov edx,[ebp-0x4c]
		mov edx,[edx+0x4]
		neg edx
		jmp short JUMP_008010
	JUMP_008009:			; Pos = 6e3eb
		mov edx,[ebp-0x4c]
		mov edx,[edx+0x4]
	JUMP_008010:			; Pos = 6e3f1
		or eax,edx
		mov edx,[ebp-0x4c]
		cmp dword [edx+0x8],byte +0x0
		jnl JUMP_008011
		mov edx,[ebp-0x4c]
		mov edx,[edx+0x8]
		neg edx
		jmp short JUMP_008012
	JUMP_008011:			; Pos = 6e406
		mov edx,[ebp-0x4c]
		mov edx,[edx+0x8]
	JUMP_008012:			; Pos = 6e40c
		or eax,edx
		mov edx,[ebp-0x4c]
		cmp dword [edx+0xc],byte +0x0
		jnl JUMP_008013
		mov edx,[ebp-0x4c]
		mov edx,[edx+0xc]
		neg edx
		jmp short JUMP_008014
	JUMP_008013:			; Pos = 6e421
		mov edx,[ebp-0x4c]
		mov edx,[edx+0xc]
	JUMP_008014:			; Pos = 6e427
		or eax,edx
		mov edx,[ebp-0x50]
		cmp dword [edx+0x4],byte +0x0
		jnl JUMP_008015
		mov edx,[ebp-0x50]
		mov edx,[edx+0x4]
		neg edx
		jmp short JUMP_008016
	JUMP_008015:			; Pos = 6e43c
		mov edx,[ebp-0x50]
		mov edx,[edx+0x4]
	JUMP_008016:			; Pos = 6e442
		or eax,edx
		mov edx,[ebp-0x50]
		cmp dword [edx+0x8],byte +0x0
		jnl JUMP_008017
		mov edx,[ebp-0x50]
		mov edx,[edx+0x8]
		neg edx
		jmp short JUMP_008018
	JUMP_008017:			; Pos = 6e457
		mov edx,[ebp-0x50]
		mov edx,[edx+0x8]
	JUMP_008018:			; Pos = 6e45d
		or eax,edx
		mov edx,[ebp-0x50]
		cmp dword [edx+0xc],byte +0x0
		jnl JUMP_008019
		mov edx,[ebp-0x50]
		mov edx,[edx+0xc]
		neg edx
		jmp short JUMP_008020
	JUMP_008019:			; Pos = 6e472
		mov edx,[ebp-0x50]
		mov edx,[edx+0xc]
	JUMP_008020:			; Pos = 6e478
		or eax,edx
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		add eax,byte -0xd
		mov [ebp-0x6c],eax
		cmp dword [ebp-0x6c],byte +0x0
		jng near JUMP_008021
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x48]
		mov eax,[eax+0x4]
		sar eax,cl
		mov [ebp+0xfffff670],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x48]
		mov eax,[eax+0x8]
		sar eax,cl
		mov [ebp+0xfffff674],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x48]
		mov eax,[eax+0xc]
		sar eax,cl
		mov [ebp+0xfffff678],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x4c]
		mov eax,[eax+0x4]
		sar eax,cl
		mov [ebp+0xfffff664],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x4c]
		mov eax,[eax+0x8]
		sar eax,cl
		mov [ebp+0xfffff668],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x4c]
		mov eax,[eax+0xc]
		sar eax,cl
		mov [ebp+0xfffff66c],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x50]
		mov eax,[eax+0x4]
		sar eax,cl
		mov [ebp+0xfffff658],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x50]
		mov eax,[eax+0x8]
		sar eax,cl
		mov [ebp+0xfffff65c],eax
		mov ecx,[ebp-0x6c]
		mov eax,[ebp-0x50]
		mov eax,[eax+0xc]
		sar eax,cl
		mov [ebp+0xfffff660],eax
		jmp short JUMP_008022
	JUMP_008021:			; Pos = 6e52c
		mov eax,[ebp-0x48]
		mov edx,[eax+0x4]
		mov [ebp+0xfffff670],edx
		mov edx,[eax+0x8]
		mov [ebp+0xfffff674],edx
		mov edx,[eax+0xc]
		mov [ebp+0xfffff678],edx
		mov eax,[ebp-0x4c]
		mov edx,[eax+0x4]
		mov [ebp+0xfffff664],edx
		mov edx,[eax+0x8]
		mov [ebp+0xfffff668],edx
		mov edx,[eax+0xc]
		mov [ebp+0xfffff66c],edx
		mov eax,[ebp-0x50]
		mov edx,[eax+0x4]
		mov [ebp+0xfffff658],edx
		mov edx,[eax+0x8]
		mov [ebp+0xfffff65c],edx
		mov edx,[eax+0xc]
		mov [ebp+0xfffff660],edx
		xor eax,eax
		mov [ebp-0x6c],eax
	JUMP_008022:			; Pos = 6e58b
		mov eax,[ebp+0xfffff670]
		sub eax,[ebp+0xfffff658]
		imul dword [ebp+0xfffff668]
		mov edx,[ebp+0xfffff664]
		sub edx,[ebp+0xfffff670]
		imul edx,[ebp+0xfffff65c]
		add eax,edx
		mov edx,[ebp+0xfffff658]
		sub edx,[ebp+0xfffff664]
		imul edx,[ebp+0xfffff674]
		add eax,edx
		mov [ebp-0x70],eax
		mov eax,[ebp+0xfffff670]
		sub eax,[ebp+0xfffff664]
		imul dword [ebp+0xfffff65c]
		mov edx,[ebp+0xfffff658]
		sub edx,[ebp+0xfffff670]
		imul edx,[ebp+0xfffff668]
		add eax,edx
		mov edx,[ebp+0xfffff664]
		sub edx,[ebp+0xfffff658]
		imul edx,[ebp+0xfffff674]
		add eax,edx
		mov [ebp-0x74],eax
		mov eax,[ebp+0xfffff670]
		imul dword [ebp+0xfffff668]
		mov edx,[ebp+0xfffff664]
		imul edx,[ebp+0xfffff674]
		sub eax,edx
		mov [ebp-0x78],eax
		mov eax,[ebp+0xfffff670]
		imul dword [ebp+0xfffff65c]
		mov edx,[ebp+0xfffff658]
		imul edx,[ebp+0xfffff674]
		sub eax,edx
		mov [ebp-0x7c],eax
		cmp dword [ebp-0x7c],byte +0x0
		jnl JUMP_008023
		mov eax,[ebp-0x7c]
		neg eax
		jmp short JUMP_008024
	JUMP_008023:			; Pos = 6e652
		mov eax,[ebp-0x7c]
	JUMP_008024:			; Pos = 6e655
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		mov ebx,0x1e
		sub ebx,eax
		test ebx,ebx
		jnl JUMP_008025
		xor ebx,ebx
	JUMP_008025:			; Pos = 6e669
		cmp ebx,byte +0xf
		jng JUMP_008026
		mov ebx,0xf
	JUMP_008026:			; Pos = 6e673
		cmp ebx,byte +0xf
		jnl JUMP_008027
		mov ecx,0xf
		sub ecx,ebx
		sar dword [ebp-0x74],cl
		cmp dword [ebp-0x74],byte +0x0
		jnz JUMP_008027
		mov dword [ebp-0x74],0x1
	JUMP_008027:			; Pos = 6e68f
		mov ecx,ebx
		mov eax,[ebp-0x7c]
		shl eax,cl
		cdq
		idiv dword [ebp-0x74]
		mov [ebp-0x80],eax
		cmp dword [ebp-0x78],byte +0x0
		jnl JUMP_008028
		mov eax,[ebp-0x78]
		neg eax
		jmp short JUMP_008029
	JUMP_008028:			; Pos = 6e6aa
		mov eax,[ebp-0x78]
	JUMP_008029:			; Pos = 6e6ad
		push eax
		call FUNC_001656_FindMSB
		pop ecx
		mov ebx,0x1e
		sub ebx,eax
		test ebx,ebx
		jnl JUMP_008030
		xor ebx,ebx
	JUMP_008030:			; Pos = 6e6c1
		cmp ebx,byte +0xf
		jng JUMP_008031
		mov ebx,0xf
	JUMP_008031:			; Pos = 6e6cb
		cmp ebx,byte +0xf
		jnl JUMP_008032
		mov ecx,0xf
		sub ecx,ebx
		sar dword [ebp-0x70],cl
		cmp dword [ebp-0x70],byte +0x0
		jnz JUMP_008032
		mov dword [ebp-0x70],0x1
	JUMP_008032:			; Pos = 6e6e7
		mov ecx,ebx
		mov eax,[ebp-0x78]
		shl eax,cl
		cdq
		idiv dword [ebp-0x70]
		mov [ebp+0xffffff7c],eax
		cmp dword [ebp-0x6c],byte +0xf
		jnl JUMP_008033
		mov ecx,0xf
		sub ecx,[ebp-0x6c]
		mov eax,[ebp+0xfffff66c]
		sub eax,[ebp+0xfffff678]
		imul dword [ebp-0x80]
		mov edx,[ebp+0xfffff660]
		sub edx,[ebp+0xfffff678]
		imul edx,[ebp+0xffffff7c]
		add eax,edx
		sar eax,cl
		mov edx,[ebp-0x48]
		add eax,[edx+0xc]
		mov [ebp+0xffffff78],eax
		jmp short JUMP_008034
	JUMP_008033:			; Pos = 6e73a
		mov ecx,[ebp-0x6c]
		add ecx,byte -0xf
		mov eax,[ebp+0xfffff66c]
		sub eax,[ebp+0xfffff678]
		imul dword [ebp-0x80]
		mov edx,[ebp+0xfffff660]
		sub edx,[ebp+0xfffff678]
		imul edx,[ebp+0xffffff7c]
		add eax,edx
		shl eax,cl
		mov edx,[ebp-0x48]
		add eax,[edx+0xc]
		mov [ebp+0xffffff78],eax
	JUMP_008034:			; Pos = 6e772
		mov eax,[ebp+0xffffff78]
		mov [DATA_009283],eax
		xor eax,eax
		mov [DATA_009284],eax
		xor ebx,ebx
		mov dword [ebp+0xffffff64],DATA_009260
	JUMP_008035:			; Pos = 6e790
		xor eax,eax
		mov edx,[ebp+0xffffff64]
	JUMP_008036:			; Pos = 6e798
		xor ecx,ecx
		mov [edx],ecx
		xor ecx,ecx
		mov [edx+0x4],ecx
		inc eax
		add edx,byte +0x8
		cmp eax,byte +0x20
		jl JUMP_008036
		inc ebx
		add dword [ebp+0xffffff64],0x100
		cmp ebx,byte +0x2
		jl JUMP_008035
		jmp JUMP_008040
	JUMP_008037:			; Pos = 6e7bf
		inc ebx
		cmp ebx,byte +0x14
		jl near JUMP_007976
		jmp JUMP_008040
	JUMP_008038:			; Pos = 6e7ce
		xor ebx,ebx
		lea esi,[ebp+0xfffffd84]
	JUMP_008039:			; Pos = 6e7d6
		mov eax,[ebp+0x34]
		push eax
		mov eax,[ebp-0x1c]
		push eax
		mov eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x14]
		mov eax,[eax+ebx*4+0x8]
		push eax
		mov eax,[ebp-0x8]
		push eax
		mov eax,[esi+0x14]
		mov eax,[ebp+eax*4+0xfffff67c]
		push eax
		mov eax,[esi+0x10]
		mov eax,[ebp+eax*4+0xfffff67c]
		push eax
		mov eax,[esi+0xc]
		mov eax,[ebp+eax*4+0xfffff67c]
		push eax
		mov eax,[esi+0x8]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		push eax
		mov eax,[esi+0x4]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		push eax
		mov eax,[esi]
		shl eax,0x3
		lea eax,[eax+eax*8]
		lea edx,[ebp+0xfffff7e4]
		add eax,edx
		push eax
		call FUNC_001835
		add esp,byte +0x2c
		inc ebx
		add esi,byte +0x18
		cmp ebx,byte +0x14
		jl JUMP_008039
	JUMP_008040:			; Pos = 6e855
		call FUNC_001817
		cmp dword [ebp+0x34],byte +0x0
		jz JUMP_008043
		cmp dword [DATA_009283],0x7fffffff
		jz JUMP_008041
		mov eax,[DATA_009283]
		cmp eax,[ebp+0xc]
		jng JUMP_008042
	JUMP_008041:			; Pos = 6e876
		mov eax,[ebp+0x8]
		mov edx,[ebp+0xc]
		mov [eax],edx
		jmp short JUMP_008043
	JUMP_008042:			; Pos = 6e880
		mov eax,[ebp+0x8]
		mov edx,[DATA_009283]
		mov [eax],edx
	JUMP_008043:			; Pos = 6e88b
		mov eax,[ebp+0x18]
	JUMP_008044:			; Pos = 6e88e
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_999999:
ret
