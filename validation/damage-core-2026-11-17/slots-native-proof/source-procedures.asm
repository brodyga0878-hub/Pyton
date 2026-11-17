FUNC_000928:			; Pos = 3ccd0

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edx,[ebp+0x10]
		mov esi,[ebp+0x8]

		mov ebx,0x72
		lea edi,[esi+0x977e]
		lea eax,[esi+0x72]
	JUMP_003878:			; Pos = 3ccea
		cmp byte [eax],0x0
		jnz JUMP_003880
		mov [eax],dl
		test dl,0x20
		jz JUMP_003879
		inc dword [DATA_008834]
	JUMP_003879:			; Pos = 3ccfc
		mov eax,[ebp+0x18]
		mov [eax],ebx
		mov eax,[ebp+0x14]
		push eax
		mov eax,[ebp+0xc]
		push eax
		lea eax,[ebx+ebx*4]
		lea eax,[ebx+eax*4]
		lea eax,[ebx+eax*8]
		add eax,eax
		add eax,esi
		add eax,byte +0x74
		push eax
		call near [DATA_007755]    ; FUNC_001533
		add esp,byte +0xc
		mov [edi],bl
		lea eax,[ebx+ebx*4]
		lea eax,[ebx+eax*4]
		lea eax,[ebx+eax*8]
		add eax,eax
		add eax,esi
		add eax,byte +0x74
		jmp JUMP_003884
	JUMP_003880:			; Pos = 3cd3a
		dec ebx
		add edi,0xfffffeae
		dec eax
		test ebx,ebx
		jg JUMP_003878

		mov ebx,0x72
		lea edi,[esi+0x977e]
		lea eax,[esi+0x72]
	JUMP_003881:			; Pos = 3cd54
		test byte [eax],0x20
		jz JUMP_003883
		dec dword [DATA_008834]
		mov [eax],dl
		test dl,0x20
		jz JUMP_003882
		inc dword [DATA_008834]
	JUMP_003882:			; Pos = 3cd6c
		mov eax,[ebp+0x18]
		mov [eax],ebx
		mov eax,[ebp+0x14]
		push eax
		mov eax,[ebp+0xc]
		push eax
		lea eax,[ebx+ebx*4]
		lea eax,[ebx+eax*4]
		lea eax,[ebx+eax*8]
		add eax,eax
		add eax,esi
		add eax,byte +0x74
		push eax
		call near [DATA_007755]    ; FUNC_001533
		add esp,byte +0xc
		mov [edi],bl
		lea eax,[ebx+ebx*4]
		lea eax,[ebx+eax*4]
		lea eax,[ebx+eax*8]
		add eax,eax
		add eax,esi
		add eax,byte +0x74
		jmp short JUMP_003884
	JUMP_003883:			; Pos = 3cda7
		dec ebx
		add edi,0xfffffeae
		dec eax
		test ebx,ebx
		jg JUMP_003881

		mov eax,[ebp+0x18]
		xor edx,edx
		mov [eax],edx
		xor eax,eax
	JUMP_003884:			; Pos = 3cdbc
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000924:			; Pos = 3ca84

		push ebp
		mov ebp,esp
		add esp,byte -0xc
		push ebx
		push esi
		push edi
		mov eax,[ebp+0x8]
		movzx edi,byte [eax+0x86]
		mov eax,[DATA_007758]
		test byte [eax+edi],0x20
		jz JUMP_003860
		dec dword [DATA_008834]
		mov byte [eax+edi],0x0
		jmp short JUMP_003864
	JUMP_003860:			; Pos = 3caae
		xor ebx,ebx
		mov esi,DATA_008623
		jmp short JUMP_003863
	JUMP_003861:			; Pos = 3cab7
		test byte [esi],0x4
		jz JUMP_003862
		xor eax,eax
		mov [ebp-0xc],eax
		mov eax,[ebp+0x8]
		mov [ebp-0x8],eax
		mov eax,edi
		mov [ebp-0x4],al
		mov al,[ebp+0xc]
		mov [ebp-0x3],al
		lea eax,[ebp-0xc]
		push eax
		push byte +0xb
		push ebx
		call FUNC_000144
		add esp,byte +0xc
	JUMP_003862:			; Pos = 3cae1
		inc ebx
		add esi,byte +0x8
	JUMP_003863:			; Pos = 3cae5
		cmp ebx,[DATA_008621]
		jng JUMP_003861
		mov eax,[DATA_007758]
		mov byte [eax+edi],0x0
	JUMP_003864:			; Pos = 3caf6
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000925:			; Pos = 3cb00

		push ebp
		mov ebp,esp
		push byte +0x0
		mov eax,[ebp+0x8]
		push eax
		call FUNC_000924
		add esp,byte +0x8
		pop ebp
		ret




FUNC_001533:			; Pos = 53a70

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
		push edi
		mov esi,[ebp+0x10]
		mov eax,[ebp+0xc]
		mov ebx,[ebp+0x8]
		movzx edi,byte [ebx+0x86]
		cmp eax,ebx
		jz JUMP_005711
		push dword 0x152
		push eax
		push ebx
		call _memcpy
		add esp,byte +0xc
		test esi,esi
		jz JUMP_005710
		mov eax,edi
		mov [ebx+0x86],al
		jmp short JUMP_005711
	JUMP_005710:			; Pos = 53aa8
		mov byte [ebx+0x86],0x0
	JUMP_005711:			; Pos = 53aaf
		test esi,esi
		jz near JUMP_005718
		mov eax,[DATA_008804]
		mov [ebx+0xa8],eax
		mov eax,[DATA_008807]
		mov [ebx+0xac],eax
		mov [ebx+0x82],esi
		push esi
		call FUNC_001538
		pop ecx
		mov esi,eax
		mov ax,[esi+0x2c]
		mov [ebp-0x4],ax
		mov ax,[esi+0x14]
		add ax,[esi+0x18]
		add ax,byte +0x7
		mov [ebp-0x2],ax
		mov eax,[ebp-0x4]
		push eax
		lea eax,[ebx+0x138]
		push eax
		call near [DATA_007734]    ; FUNC_001495
		add esp,byte +0x8
		mov ax,[esi+0x30]
		mov [ebp-0x4],ax
		mov ax,[esi+0x14]
		add ax,[esi+0x18]
		add ax,byte +0x7
		mov [ebp-0x2],ax
		mov eax,[ebp-0x4]
		push eax
		lea eax,[ebx+0x140]
		push eax
		call near [DATA_007734]    ; FUNC_001495
		add esp,byte +0x8
		mov byte [ebx+0x151],0x0
		mov byte [ebx+0x25],0x0
		mov byte [ebx+0x124],0x0
		xor edx,edx
		mov dl,[esi+0x24]
		sar edx,0x4
		and dl,0x7
		mov eax,[esi+0x34]
		test eax,eax
		jz JUMP_005712
		cmp byte [eax],0x0
		jz JUMP_005712
		mov al,0x80
		jmp short JUMP_005713
	JUMP_005712:			; Pos = 53b61
		xor eax,eax
	JUMP_005713:			; Pos = 53b63
		or dl,al
		mov [ebx+0x14c],dl
		mov byte [ebx+0x88],0xff
		mov eax,[esi+0x38]
		test eax,eax
		jz near JUMP_005718
		mov ax,[eax]
		mov [ebx+0xc4],ax
		mov eax,[esi+0x38]
		mov ax,[eax+0x2]
		mov [ebx+0xc6],ax
		mov [ebx+0xc2],ax
		mov [ebx+0xbe],ax
		neg ax
		mov [ebx+0xc0],ax
		mov edx,eax
		mov [ebx+0xbc],dx
		cmp dx,0x1329
		jl JUMP_005714
		mov byte [ebx+0x101],0x2
		jmp short JUMP_005716
	JUMP_005714:			; Pos = 53bc6
		cmp word [ebx+0xbc],0xaa5
		jl JUMP_005715
		mov byte [ebx+0x101],0x1
		jmp short JUMP_005716
	JUMP_005715:			; Pos = 53bda
		mov byte [ebx+0x101],0x0
	JUMP_005716:			; Pos = 53be1
		mov eax,[esi+0x38]
		mov al,[eax+0x4]
		mov [ebx+0xd1],al
		mov eax,[esi+0x38]
		mov ax,[eax+0x6]
		shl eax,0x2
		mov [ebx+0xe4],ax
		mov edx,[esi+0x38]
		movsx eax,word [edx+0x8]
		mov si,[edx+0x14]
		test si,si
		jnl JUMP_005717
		mov edx,esi
		mov [ebx+0xd0],dl
		movsx edx,dl
		sub eax,[edx*4+DATA_007210]
	JUMP_005717:			; Pos = 53c20
		mov [ebx+0x116],ax
		mov word [ebx+0xe0],0x0
		mov word [ebx+0xe2],0x0
	JUMP_005718:			; Pos = 53c39
		pop edi
		pop esi
		pop ebx
		pop ecx
		pop ebp
		ret




FUNC_001538:			; Pos = 53f88

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov eax,[eax*4+DATA_004681]
		pop ebp
		ret




FUNC_001495:			; Pos = 52d02

		push ebp
		mov ebp,esp
		add esp,byte -0x8
		push ebx
		mov ebx,[ebp+0x8]
		movsx eax,word [ebp+0xc]
		mov [ebp-0x8],eax
		movsx eax,word [ebp+0xc]
		sar eax,0x1f
		mov [ebp-0x4],eax
		movsx eax,word [ebp+0xe]
		add eax,byte -0xf
		push eax
		lea eax,[ebp-0x8]
		push eax
		call FUNC_001341_Int64ArithShift
		add esp,byte +0x8
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

