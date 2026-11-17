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
