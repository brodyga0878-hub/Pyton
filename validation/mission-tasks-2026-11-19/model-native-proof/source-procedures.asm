FUNC_000036:			; Pos = 12528

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		push esi
		mov eax,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov [ebx+0x82],eax
		push eax
		call near [DATA_007756]    ; FUNC_001538
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

		xor edx,edx
		mov dl,[esi+0x24]
		sar edx,0x4
		and dl,0x7
		mov eax,[esi+0x34]
		test eax,eax
		jz JUMP_000326
		cmp byte [eax],0x0
		jz JUMP_000326
		mov al,0x80
		jmp short JUMP_000327
	JUMP_000326:			; Pos = 125b7
		xor eax,eax
	JUMP_000327:			; Pos = 125b9
		or dl,al
		mov [ebx+0x14c],dl

		mov eax,[esi+0x38]
		test eax,eax
		jz near JUMP_000332
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
		jl JUMP_000328
		mov byte [ebx+0x101],0x2
		jmp short JUMP_000330
	JUMP_000328:			; Pos = 12615
		cmp word [ebx+0xbc],0xaa5
		jl JUMP_000329
		mov byte [ebx+0x101],0x1
		jmp short JUMP_000330
	JUMP_000329:			; Pos = 12629
		mov byte [ebx+0x101],0x0
	JUMP_000330:			; Pos = 12630
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
		jnl JUMP_000331
		mov edx,esi
		mov [ebx+0xd0],dl
		movsx edx,dl
		sub eax,[edx*4+DATA_007210]
	JUMP_000331:			; Pos = 1266f
		mov [ebx+0x116],ax
	JUMP_000332:			; Pos = 12676
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


FUNC_001345_StringExpandFF40Code:			; Pos = 4ee2b

		push ebp
		mov ebp,esp
		mov eax,[ebp+0xc]
		and eax,0x3fff
		push dword [eax*4+DATA_004682]
		push dword [ebp+0x8]
		call near [DATA_007642]    ; FUNC_001348_StringExpand
		add esp,byte +0x8
		pop ebp
		ret



; char *F1346 (char *dest, int ffcode, StrVars *vars) 
; Expands FF80 codes only, no '[' expansion.
; Writes vars to [D9149]


FUNC_999999:
ret
