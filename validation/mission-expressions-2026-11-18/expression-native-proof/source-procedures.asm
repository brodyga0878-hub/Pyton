FUNC_000020:			; Pos = 11464

		push ebp
		mov ebp,esp
		push ebx
		mov edx,[ebp+0x8]
		mov eax,[edx]
		xor ecx,ecx
		mov cl,[eax]
		xor ebx,ebx
		mov bl,[eax+0x1]
		shl ebx,0x8
		add ecx,ebx
		xor ebx,ebx
		mov bl,[eax+0x2]
		shl ebx,0x10
		add ecx,ebx
		xor ebx,ebx
		mov bl,[eax+0x3]
		shl ebx,0x18
		add ecx,ebx
		add eax,byte +0x4
		mov [edx],eax
		mov eax,ecx
		pop ebx
		pop ebp
		ret




FUNC_000021:			; Pos = 1149c

		push ebp
		mov ebp,esp
		xor eax,eax
		mov edx,[ebp+0x8]
		cmp edx,byte +0x14
		ja near JUMP_000196
		jmp near [edx*4+DATA_000000]


SECTION .data

DATA_000000:			; Pos = 114b4
	dd JUMP_000181
	dd JUMP_000182
	dd JUMP_000183
	dd JUMP_000184
	dd JUMP_000185
	dd JUMP_000186
	dd JUMP_000186
	dd JUMP_000186
	dd JUMP_000186
	dd JUMP_000186
	dd JUMP_000186
	dd JUMP_000186
	dd JUMP_000187
	dd JUMP_000188
	dd JUMP_000189
	dd JUMP_000190
	dd JUMP_000191
	dd JUMP_000192
	dd JUMP_000193
	dd JUMP_000194
	dd JUMP_000195


SECTION .text
	JUMP_000181:			; Pos = 11508
		mov eax,[DATA_008861]
		movzx eax,byte [eax+0x86]
		jmp JUMP_000196
	JUMP_000182:			; Pos = 11519
		mov eax,[DATA_008911]
		jmp JUMP_000196
	JUMP_000183:			; Pos = 11523
		mov eax,[DATA_008888]
		jmp JUMP_000196
	JUMP_000184:			; Pos = 1152d
		mov eax,[DATA_008922]
		jmp JUMP_000196
	JUMP_000185:			; Pos = 11534
		mov eax,[DATA_008885]
		jmp JUMP_000196
	JUMP_000186:			; Pos = 1153b
		mov eax,[DATA_008804]
		mov ecx,0xc22e
		xor edx,edx
		div ecx
		mov edx,[DATA_008807]
		sub edx,0x121cf7
		shl edx,0x7
		lea edx,[edx+edx*2]
		lea edx,[edx+edx*4]
		lea edx,[edx+edx*4]
		lea edx,[edx+edx*8]
		add eax,edx

;		cmp eax, 0
;		jnl JUMP_000196
;		mov eax, 0x7fffffff

		jmp short JUMP_000196
	JUMP_000187:			; Pos = 11568
		movsx eax,byte [DATA_008874]
		jmp short JUMP_000196
	JUMP_000188:			; Pos = 11571
		mov eax,[DATA_008862]
		movzx eax,byte [eax+0x86]
		jmp short JUMP_000196
	JUMP_000189:			; Pos = 1157f
		movsx eax,byte [DATA_008870]
		jmp short JUMP_000196
	JUMP_000190:			; Pos = 11588
		mov eax,[DATA_008890]
		jmp short JUMP_000196
	JUMP_000191:			; Pos = 1158f
		mov eax,[DATA_008892]
		jmp short JUMP_000196
	JUMP_000192:			; Pos = 11596
		mov eax,[DATA_008923]
		jmp short JUMP_000196
	JUMP_000193:			; Pos = 1159d
		mov eax,[DATA_008924]
		jmp short JUMP_000196
	JUMP_000194:			; Pos = 115a4
		mov eax,[DATA_008925]
		jmp short JUMP_000196
	JUMP_000195:			; Pos = 115ab
		mov eax,[DATA_008926]
	JUMP_000196:			; Pos = 115b0
		pop ebp
		ret




FUNC_000022:			; Pos = 115b4

		push ebp
		mov ebp,esp
		push ecx
		push ebx
		mov eax,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov edx,ebx
		cmp edx,byte +0x14
		ja near JUMP_000209
		jmp near [edx*4+DATA_000001]


SECTION .data

DATA_000001:			; Pos = 115d1
	dd JUMP_000209
	dd JUMP_000197
	dd JUMP_000200
	dd JUMP_000201
	dd JUMP_000202
	dd JUMP_000209
	dd JUMP_000209
	dd JUMP_000209
	dd JUMP_000209
	dd JUMP_000209
	dd JUMP_000209
	dd JUMP_000209
	dd JUMP_000203
	dd JUMP_000209
	dd JUMP_000209
	dd JUMP_000204
	dd JUMP_000209
	dd JUMP_000205
	dd JUMP_000206
	dd JUMP_000207
	dd JUMP_000208


SECTION .text
	JUMP_000197:			; Pos = 11625
		test eax,eax
		jnl JUMP_000198
		xor eax,eax
	JUMP_000198:			; Pos = 1162b
		cmp eax,0xfffffff
		jng JUMP_000199
		mov eax,0xfffffff
	JUMP_000199:			; Pos = 11637
		mov [DATA_008911],eax
		jmp short JUMP_000209
	JUMP_000200:			; Pos = 1163e
		mov [DATA_008888],eax
		jmp short JUMP_000209
	JUMP_000201:			; Pos = 11645
		mov [DATA_008922],eax
		jmp short JUMP_000209
	JUMP_000202:			; Pos = 1164c
		mov [ebp-0x4],eax
		push byte +0x0
		mov eax,[ebp-0x4]
		push eax
		call FUNC_000909
		add esp,byte +0x8
		jmp short JUMP_000209
	JUMP_000203:			; Pos = 1165f
		mov [DATA_008874],al
		jmp short JUMP_000209
	JUMP_000204:			; Pos = 11666
		mov [DATA_008892],eax
		jmp short JUMP_000209
	JUMP_000205:			; Pos = 1166d
		mov [DATA_008923],eax
		jmp short JUMP_000209
	JUMP_000206:			; Pos = 11674
		mov [DATA_008924],eax
		jmp short JUMP_000209
	JUMP_000207:			; Pos = 1167b
		mov [DATA_008925],eax
		jmp short JUMP_000209
	JUMP_000208:			; Pos = 11682
		mov [DATA_008926],eax
	JUMP_000209:			; Pos = 11687
		push ebx
		push byte +0x0
		push byte +0x1
		call FUNC_000048
		add esp,byte +0xc
		pop ebx
		pop ecx
		pop ebp
		ret




FUNC_000023:			; Pos = 11698

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov ecx,0x15180
		xor edx,edx
		div ecx
		add eax,0x121cf7
		pop ebp
		ret




FUNC_000024:			; Pos = 116b0

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov ecx,0x15180
		xor edx,edx
		div ecx
		imul eax,edx,0xc22e
		pop ebp
		ret




FUNC_000025:			; Pos = 116c8

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		xor edi,edi
		xor esi,esi
		mov eax,[ebp+0x8]
		mov ebx,eax
		jmp short JUMP_000211
	JUMP_000210:			; Pos = 116d9
		mov eax,esi
		shl eax,0x4
		add eax,esi
		shl eax,0x2
		add eax,[ebp+0x8]
		push eax
		call near [ebp+0xc]
		pop ecx
		add edi,eax
		inc esi
		add ebx,byte +0x44
	JUMP_000211:			; Pos = 116f1
		cmp dword [ebx],byte +0x0
		jnz JUMP_000210
		mov eax,edi
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000026:			; Pos = 11700

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov edi,[ebp+0x8]
		xor ebx,ebx
		mov esi,edi
		jmp short JUMP_000214
	JUMP_000212:			; Pos = 1170f
		mov eax,ebx
		shl eax,0x4
		add eax,ebx
		shl eax,0x2
		add eax,edi
		push eax
		call near [ebp+0xc]
		pop ecx
		test eax,eax
		jz JUMP_000213
		mov eax,[ebp+0x10]
		add dword [ebp+0x10],byte -0x1
		test eax,eax
		jz JUMP_000215
	JUMP_000213:			; Pos = 1172f
		inc ebx
		add esi,byte +0x44
	JUMP_000214:			; Pos = 11733
		cmp dword [esi],byte +0x0
		jnz JUMP_000212
	JUMP_000215:			; Pos = 11738
		mov eax,ebx
		shl eax,0x4
		add eax,ebx
		mov eax,[edi+eax*4+0x4]
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000027:			; Pos = 11748

		push ebp
		mov ebp,esp
		push ebx
		push esi
		push edi
		mov ebx,0x72
		mov eax,[ebp+0x8]
		lea edi,[eax+0x9798]
		mov eax,[ebp+0x8]
		lea esi,[eax+0x72]
	JUMP_000216:			; Pos = 11762
		cmp byte [esi],0x0
		jz JUMP_000217
		lea eax,[ebx+ebx*4]
		lea eax,[ebx+eax*4]
		lea eax,[ebx+eax*8]
		add eax,eax
		add eax,[ebp+0x8]
		add eax,byte +0x74
		push eax
		call near [ebp+0xc]
		pop ecx
		test eax,eax
		jz JUMP_000217
		mov eax,[edi]
		cmp eax,[ebp+0x10]
		jz JUMP_000218
	JUMP_000217:			; Pos = 11788
		dec ebx
		add edi,0xfffffeae
		dec esi
		test ebx,ebx
		jg JUMP_000216
	JUMP_000218:			; Pos = 11794
		mov eax,ebx
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret




FUNC_000028:			; Pos = 1179c

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		test byte [eax+0x14c],0x10
		setnz al
		and eax,byte +0x1
		pop ebp
		ret




FUNC_000029:			; Pos = 117c8

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov edx,[eax+0x82]
		cmp edx,byte +0x76
		jc JUMP_000219
		cmp edx,0x85
		jna JUMP_000220
	JUMP_000219:			; Pos = 117e1
		xor eax,eax
		jmp short JUMP_000221
	JUMP_000220:			; Pos = 117e5
		mov eax,0x1
	JUMP_000221:			; Pos = 117ea
		pop ebp
		ret




FUNC_000030:			; Pos = 117ec

		push ebp
		mov ebp,esp
		mov eax,[ebp+0x8]
		mov dx,[eax+0xc]
		cmp dx,byte +0x76
		jc JUMP_000222
		cmp dx,0x85
		jna JUMP_000223
	JUMP_000222:			; Pos = 11803
		xor eax,eax
		jmp short JUMP_000224
	JUMP_000223:			; Pos = 11807
		mov eax,0x1
	JUMP_000224:			; Pos = 1180c
		pop ebp
		ret
		nop
		nop




FUNC_000031:			; Pos = 11810

		push ebp
		mov ebp,esp
		push eax
		mov eax,0x2
	JUMP_000225:			; Pos = 11819
		add esp,0xfffff004
		push eax
		dec eax
		jnz JUMP_000225
		mov eax,[ebp-0x4]
		push ebx
		push esi
		push edi
		mov esi,[ebp+0xc]
		mov ebx,[ebp+0x8]
		mov eax,[ebx]
		inc dword [ebx]
		movzx eax,byte [eax]
		cmp eax,byte +0x43
		ja near JUMP_000309
		jmp near [eax*4+DATA_000002]


SECTION .data

DATA_000002:			; Pos = 11846
	dd JUMP_000309
	dd JUMP_000309
	dd JUMP_000226
	dd JUMP_000227
	dd JUMP_000228
	dd JUMP_000229
	dd JUMP_000230
	dd JUMP_000231
	dd JUMP_000232
	dd JUMP_000233
	dd JUMP_000234
	dd JUMP_000235
	dd JUMP_000236
	dd JUMP_000237
	dd JUMP_000238
	dd JUMP_000239
	dd JUMP_000240
	dd JUMP_000241
	dd JUMP_000242
	dd JUMP_000243
	dd JUMP_000244
	dd JUMP_000245
	dd JUMP_000246
	dd JUMP_000247
	dd JUMP_000248
	dd JUMP_000249
	dd JUMP_000250
	dd JUMP_000254
	dd JUMP_000257
	dd JUMP_000258
	dd JUMP_000259
	dd JUMP_000260
	dd JUMP_000262
	dd JUMP_000263
	dd JUMP_000264
	dd JUMP_000267
	dd JUMP_000269
	dd JUMP_000270
	dd JUMP_000273
	dd JUMP_000274
	dd JUMP_000275
	dd JUMP_000276
	dd JUMP_000277
	dd JUMP_000278
	dd JUMP_000279
	dd JUMP_000280
	dd JUMP_000281
	dd JUMP_000282
	dd JUMP_000283
	dd JUMP_000285
	dd JUMP_000286
	dd JUMP_000287
	dd JUMP_000288
	dd JUMP_000289
	dd JUMP_000290
	dd JUMP_000291
	dd JUMP_000292
	dd JUMP_000293
	dd JUMP_000294
	dd JUMP_000298
	dd JUMP_000299
	dd JUMP_000300
	dd JUMP_000301
	dd JUMP_000302
	dd JUMP_000304
	dd JUMP_000305
	dd JUMP_000306
	dd JUMP_000308


SECTION .text
	JUMP_000226:			; Pos = 11956
		push ebx
		call FUNC_000020
		pop ecx
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000227:			; Pos = 11965
		push ebx
		call FUNC_000020
		pop ecx
		push eax
		call FUNC_000021
		pop ecx
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000228:			; Pos = 1197b
		push ebx
		call FUNC_000020
		pop ecx
		mov eax,[eax*4+DATA_008548]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000229:			; Pos = 11991
		push ebx
		call FUNC_000020
		pop ecx
		mov edx,[esi+0x1c]
		mov edx,[edx+0x14]
		mov eax,[edx+eax*4]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000230:			; Pos = 119a9
		push ebx
		call FUNC_000020
		pop ecx
		mov edi,eax
		mov eax,[esi+0x20]
		mov eax,[eax+edi*4]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000231:			; Pos = 119c0
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		neg eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000232:			; Pos = 119d4
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		not eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000233:			; Pos = 119e8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		cmp eax,byte +0x1
		sbb eax,eax
		neg eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000234:			; Pos = 11a01
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		imul edi,[ebp-0xc]
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000235:			; Pos = 11a26
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		mov eax,edi
		cdq
		idiv dword [ebp-0xc]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000236:			; Pos = 11a4d
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		mov eax,edi
		cdq
		idiv dword [ebp-0xc]
		mov [ebp-0x8],edx
		jmp JUMP_000309
	JUMP_000237:			; Pos = 11a74
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		add edi,[ebp-0xc]
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000238:			; Pos = 11a98
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		sub edi,[ebp-0xc]
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000239:			; Pos = 11abc
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		mov ecx,[ebp-0xc]
		shl edi,cl
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000240:			; Pos = 11ae2
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		mov ecx,[ebp-0xc]
		sar edi,cl
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000241:			; Pos = 11b08
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		cmp edi,[ebp-0xc]
		setl al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000242:			; Pos = 11b32
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		cmp edi,[ebp-0xc]
		setng al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000243:			; Pos = 11b5c
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		cmp edi,[ebp-0xc]
		setg al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000244:			; Pos = 11b86
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		cmp edi,[ebp-0xc]
		setnl al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000245:			; Pos = 11bb0
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		cmp edi,[ebp-0xc]
		setz al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000246:			; Pos = 11bda
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		cmp edi,[ebp-0xc]
		setnz al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000247:			; Pos = 11c04
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		and edi,[ebp-0xc]
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000248:			; Pos = 11c28
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		xor edi,[ebp-0xc]
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000249:			; Pos = 11c4c
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		or edi,[ebp-0xc]
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000250:			; Pos = 11c70
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		test edi,edi
		jz JUMP_000251
		cmp dword [ebp-0xc],byte +0x0
		jnz JUMP_000252
	JUMP_000251:			; Pos = 11c93
		xor eax,eax
		jmp short JUMP_000253
	JUMP_000252:			; Pos = 11c97
		mov eax,0x1
	JUMP_000253:			; Pos = 11c9c
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000254:			; Pos = 11ca4
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		test edi,edi
		jnz JUMP_000255
		cmp dword [ebp-0xc],byte +0x0
		jnz JUMP_000255
		xor eax,eax
		jmp short JUMP_000256
	JUMP_000255:			; Pos = 11ccb
		mov eax,0x1
	JUMP_000256:			; Pos = 11cd0
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000257:			; Pos = 11cd8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000258:			; Pos = 11ce7
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000259:			; Pos = 11cf6
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000260:			; Pos = 11d0f
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		test edi,edi
		jl JUMP_000261
		cmp edi,byte +0x6
		jnl JUMP_000261
		mov eax,[edi*4+DATA_009093]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000261:			; Pos = 11d33
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000262:			; Pos = 11d3d
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		mov eax,[ebp-0xc]
		push eax
		push edi
		call FUNC_000085
		add esp,byte +0x8
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000263:			; Pos = 11d6b
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000264:			; Pos = 11d7a
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		cmp edi,byte +0x1
		jnz JUMP_000265
		mov eax,[DATA_008913]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000265:			; Pos = 11d98
		cmp edi,byte +0x2
		jnz JUMP_000266
		mov eax,[DATA_008912]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000266:			; Pos = 11daa
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000267:			; Pos = 11db4
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		test edi,edi
		jl JUMP_000268
		cmp edi,byte +0x6
		jnl JUMP_000268
		mov eax,[edi*4+DATA_009095]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000268:			; Pos = 11dd8
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000269:			; Pos = 11de2
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		mov eax,[DATA_009133]
		push eax
		push edi
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov eax,[eax+0x82]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000270:			; Pos = 11e0c
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		cmp dword [ebp-0xc],0x3e8
		jnl JUMP_000271
		sub dword [ebp-0xc],byte +0x64
		mov eax,[ebp-0xc]
		push eax
		mov eax,[DATA_009133]
		push eax
		push edi
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		push eax
		call FUNC_000392
		add esp,byte +0x8
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000271:			; Pos = 11e57
		sub dword [ebp-0xc],0x3e8
		mov eax,[DATA_008861]
		movzx eax,byte [eax+0x86]
		cmp edi,eax
		jnz JUMP_000272
		cmp dword [ebp-0xc],byte +0x26
		jnl JUMP_000272
		mov eax,[ebp-0xc]
		movzx eax,word [eax*2+DATA_008896]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000272:			; Pos = 11e87
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000273:			; Pos = 11e91
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000274:			; Pos = 11ea0
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000275:			; Pos = 11eaf
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000276:			; Pos = 11ec8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000277:			; Pos = 11ee1
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000278:			; Pos = 11efa
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000279:			; Pos = 11f13
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		jmp JUMP_000309
	JUMP_000280:			; Pos = 11f2c
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call FUNC_000106
		pop ecx
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000281:			; Pos = 11f45
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		push ebx
		mov eax,[ebp-0xc]
		push eax
		push edi
		call FUNC_000096
		add esp,byte +0xc
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000282:			; Pos = 11f80
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		mov [ebp-0x4],edi
		mov ax,[ebp-0x4]
		and eax,0x1fff
		shl eax,0x10
		shr edi,0xd
		and edi,0x1fff
		and edi,0xffff
		or eax,edi
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000283:			; Pos = 11fb4
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		test edi,edi
		jl JUMP_000284
		cmp edi,byte +0x6
		jnl JUMP_000284
		mov eax,[edi*4+DATA_008908]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000284:			; Pos = 11fd8
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000285:			; Pos = 11fe2
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x4],eax
		lea eax,[ebp-0x10]
		push eax
		lea eax,[ebp-0x10]
		push eax
		lea eax,[ebp-0x8]
		push eax
		lea eax,[ebp-0x10]
		push eax
		lea eax,[ebp-0x10]
		push eax
		lea eax,[ebp-0x10]
		push eax
		mov eax,[ebp-0x4]
		push eax
		call FUNC_000871
		add esp,byte +0x1c
		jmp JUMP_000309
	JUMP_000286:			; Pos = 12018
		call FUNC_001476
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		pop edx
		xchg eax,edx
		mov ecx,edx
		xor edx,edx
		div ecx
		mov [ebp-0x8],edx
		jmp JUMP_000309
	JUMP_000287:			; Pos = 12038
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push edi
		push dword FUNC_000028
		mov eax,[DATA_009133]
		push eax
		call FUNC_000027
		add esp,byte +0xc
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000288:			; Pos = 12060
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		cmp eax,[DATA_008560]
		setz al
		and eax,byte +0x1
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000289:			; Pos = 1207e
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		lea eax,[ebp-0x12]
		push eax
		push ebx
		call FUNC_000658
		add esp,byte +0x8
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000290:			; Pos = 1209f
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call FUNC_000023
		pop ecx
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000291:			; Pos = 120b8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call FUNC_000024
		pop ecx
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000292:			; Pos = 120d1
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		mov eax,[DATA_009133]
		push eax
		push edi
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov eax,[eax+0xa0]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000293:			; Pos = 120fb
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x4],eax
		push byte +0x3
		call near [DATA_007217]    ; FUNC_000922
		pop ecx
		push eax
		mov eax,[ebp-0x4]
		push eax
		call FUNC_000857
		add esp,byte +0x8
		mov [ebp-0x4],eax
		mov eax,[ebp-0x4]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000294:			; Pos = 1212c
		mov edi,0x1
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x4],eax
		mov eax,[ebp-0x4]
		push eax
		lea eax,[ebp+0xffffefec]
		push eax
		call FUNC_000461
		add esp,byte +0x8
		test eax,eax
		jnz JUMP_000295
		lea eax,[ebp+0xffffefec]
		push eax
		call FUNC_000462
		pop ecx
		mov edi,eax
		test edi,edi
		jnz JUMP_000296
	JUMP_000295:			; Pos = 12168
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000296:			; Pos = 12172
		push edi
		call near [DATA_007217]    ; FUNC_000922
		pop ecx
		push eax
		lea eax,[ebp+0xffffefec]
		push eax
		call FUNC_000463
		add esp,byte +0x8
		test eax,eax
		jnz JUMP_000297
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000297:			; Pos = 12198
		mov eax,[eax+0x4]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000298:			; Pos = 121a3
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0xc],eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov ebx,eax
		add edi,0x1718
		mov eax,[ebp-0xc]
		add eax,0x1524
		shl eax,0xd
		or edi,eax
		shl ebx,0x1a
		or edi,ebx
		mov [ebp-0x8],edi
		jmp JUMP_000309
	JUMP_000299:			; Pos = 121e8
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push edi
		push dword FUNC_000029
		mov eax,[DATA_009133]
		push eax
		call FUNC_000027
		add esp,byte +0xc
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000300:			; Pos = 12210
		mov eax,[DATA_009133]
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		mov eax,[eax+0x82]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000301:			; Pos = 12238
		mov eax,[DATA_009133]
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		movzx eax,byte [eax+0xff]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000302:			; Pos = 12261
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x4],eax
		mov eax,[ebp-0x4]
		push eax
		lea eax,[ebp+0xffffdffc]
		push eax
		call FUNC_000461
		add esp,byte +0x8
		test eax,eax
		jz JUMP_000303
		xor eax,eax
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000303:			; Pos = 1228f
		push dword FUNC_000030
		lea eax,[ebp+0xffffdffc]
		push eax
		call FUNC_000025
		add esp,byte +0x8
		mov [ebp-0x8],eax
		cmp dword [ebp-0x8],byte +0x0
		jz near JUMP_000309
		mov eax,[ebp-0x8]
		push eax
		call near [DATA_007217]    ; FUNC_000922
		pop ecx
		push eax
		push dword FUNC_000030
		lea eax,[ebp+0xffffdffc]
		push eax
		call FUNC_000026
		add esp,byte +0xc
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000304:			; Pos = 122d8
		mov eax,[DATA_009133]
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		movsx eax,byte [eax+0x88]
		mov [ebp-0x8],eax
		jmp JUMP_000309
	JUMP_000305:			; Pos = 12301
		mov eax,[DATA_009133]
		push eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		push eax
		call near [DATA_007754]    ; FUNC_001532
		add esp,byte +0x8
		movzx eax,byte [eax+0xfe]
		mov [ebp-0x8],eax
		jmp short JUMP_000309
	JUMP_000306:			; Pos = 12327
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov edi,eax
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		add eax,0xfffffc18
		mov [ebp-0xc],eax
		push edi
		call FUNC_000649
		pop ecx
		test eax,eax
		jz JUMP_000307
		cmp dword [ebp-0xc],byte +0x0
		jl JUMP_000307
		cmp dword [ebp-0xc],byte +0x26
		jnl JUMP_000307
		mov edx,[ebp-0xc]
		mov eax,[eax+edx*8+0x4]
		mov [ebp-0x8],eax
		jmp short JUMP_000309
	JUMP_000307:			; Pos = 12368
		xor eax,eax
		mov [ebp-0x8],eax
		jmp short JUMP_000309
	JUMP_000308:			; Pos = 1236f
		push esi
		push ebx
		call FUNC_000031
		add esp,byte +0x8
		mov [ebp-0x4],eax
		lea eax,[ebp-0x24]
		push eax
		lea eax,[ebp-0x20]
		push eax
		lea eax,[ebp-0x1c]
		push eax
		lea eax,[ebp-0x18]
		push eax
		mov eax,[ebp-0x4]
		push eax
		call FUNC_000870
		add esp,byte +0x14
		mov eax,[ebp-0x1c]
		mov [ebp-0x8],eax
	JUMP_000309:			; Pos = 1239e
		mov eax,[ebp-0x8]
		pop edi
		pop esi
		pop ebx
		mov esp,ebp
		pop ebp
		ret




FUNC_000462:			; Pos = 24d64

		push ebp
		mov ebp,esp
		xor edx,edx
		mov eax,[ebp+0x8]
		jmp short JUMP_002233
	JUMP_002231:			; Pos = 24d6e
		cmp word [eax+0xa],byte +0x20
		jc JUMP_002232
		inc edx
	JUMP_002232:			; Pos = 24d76
		add eax,byte +0x44
	JUMP_002233:			; Pos = 24d79
		cmp dword [eax],byte +0x0
		jnz JUMP_002231
		mov eax,edx
		pop ebp
		ret




FUNC_000463:			; Pos = 24d84

		push ebp
		mov ebp,esp
		push ebx
		push esi
		mov ecx,[ebp+0xc]
		mov esi,[ebp+0x8]
		xor edx,edx
		mov eax,esi
		jmp short JUMP_002236
	JUMP_002234:			; Pos = 24d95
		cmp word [eax+0xa],byte +0x20
		jc JUMP_002235
		mov ebx,ecx
		add ecx,byte -0x1
		test ebx,ebx
		jnz JUMP_002235
		mov eax,edx
		shl eax,0x4
		add eax,edx
		shl eax,0x2
		add eax,esi
		jmp short JUMP_002237
	JUMP_002235:			; Pos = 24db3
		inc edx
		add eax,byte +0x44
	JUMP_002236:			; Pos = 24db7
		cmp dword [eax],byte +0x0
		jnz JUMP_002234
		xor eax,eax
	JUMP_002237:			; Pos = 24dbe
		pop esi
		pop ebx
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




FUNC_999999:
ret
