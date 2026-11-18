.intel_syntax noprefix
.code64
.section .text
FUNC_000020:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],20
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
mov edx,[rbp+16]
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
add eax,+0x4
mov [edx],eax
mov eax,ecx
pop rbx
pop rbp
ret
FUNC_000021:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],21
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
xor eax,eax
mov edx,[rbp+16]
cmp edx,+0x14
ja JUMP_000196
mov r11d,DWORD PTR [rdx*4+DATA_000000]
jmp r11
.section .rodata
DATA_000000:
.long JUMP_000181
.long JUMP_000182
.long JUMP_000183
.long JUMP_000184
.long JUMP_000185
.long JUMP_000186
.long JUMP_000186
.long JUMP_000186
.long JUMP_000186
.long JUMP_000186
.long JUMP_000186
.long JUMP_000186
.long JUMP_000187
.long JUMP_000188
.long JUMP_000189
.long JUMP_000190
.long JUMP_000191
.long JUMP_000192
.long JUMP_000193
.long JUMP_000194
.long JUMP_000195
.section .text
JUMP_000181:
mov eax,[DATA_008861]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000196
JUMP_000182:
mov eax,[DATA_008911]
jmp JUMP_000196
JUMP_000183:
mov eax,[DATA_008888]
jmp JUMP_000196
JUMP_000184:
mov eax,[DATA_008922]
jmp JUMP_000196
JUMP_000185:
mov eax,[DATA_008885]
jmp JUMP_000196
JUMP_000186:
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
jmp JUMP_000196
JUMP_000187:
movsx eax,BYTE PTR [DATA_008874]
jmp JUMP_000196
JUMP_000188:
mov eax,[DATA_008862]
movzx eax,BYTE PTR [eax+0x86]
jmp JUMP_000196
JUMP_000189:
movsx eax,BYTE PTR [DATA_008870]
jmp JUMP_000196
JUMP_000190:
mov eax,[DATA_008890]
jmp JUMP_000196
JUMP_000191:
mov eax,[DATA_008892]
jmp JUMP_000196
JUMP_000192:
mov eax,[DATA_008923]
jmp JUMP_000196
JUMP_000193:
mov eax,[DATA_008924]
jmp JUMP_000196
JUMP_000194:
mov eax,[DATA_008925]
jmp JUMP_000196
JUMP_000195:
mov eax,[DATA_008926]
JUMP_000196:
pop rbp
ret
FUNC_000022:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],22
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rcx
push rbx
mov eax,[rbp+24]
mov ebx,[rbp+16]
mov edx,ebx
cmp edx,+0x14
ja JUMP_000209
mov r11d,DWORD PTR [rdx*4+DATA_000001]
jmp r11
.section .rodata
DATA_000001:
.long JUMP_000209
.long JUMP_000197
.long JUMP_000200
.long JUMP_000201
.long JUMP_000202
.long JUMP_000209
.long JUMP_000209
.long JUMP_000209
.long JUMP_000209
.long JUMP_000209
.long JUMP_000209
.long JUMP_000209
.long JUMP_000203
.long JUMP_000209
.long JUMP_000209
.long JUMP_000204
.long JUMP_000209
.long JUMP_000205
.long JUMP_000206
.long JUMP_000207
.long JUMP_000208
.section .text
JUMP_000197:
test eax,eax
jnl JUMP_000198
xor eax,eax
JUMP_000198:
cmp eax,0xfffffff
jng JUMP_000199
mov eax,0xfffffff
JUMP_000199:
mov [DATA_008911],eax
jmp JUMP_000209
JUMP_000200:
mov [DATA_008888],eax
jmp JUMP_000209
JUMP_000201:
mov [DATA_008922],eax
jmp JUMP_000209
JUMP_000202:
mov [rbp-0x4],eax
push +0x0
mov eax,[rbp-0x4]
push rax
call FUNC_000909
add rsp,16
jmp JUMP_000209
JUMP_000203:
mov [DATA_008874],al
jmp JUMP_000209
JUMP_000204:
mov [DATA_008892],eax
jmp JUMP_000209
JUMP_000205:
mov [DATA_008923],eax
jmp JUMP_000209
JUMP_000206:
mov [DATA_008924],eax
jmp JUMP_000209
JUMP_000207:
mov [DATA_008925],eax
jmp JUMP_000209
JUMP_000208:
mov [DATA_008926],eax
JUMP_000209:
push rbx
push +0x0
push +0x1
call FUNC_000048
add rsp,24
pop rbx
pop rcx
pop rbp
ret
FUNC_000023:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],23
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov ecx,0x15180
xor edx,edx
div ecx
add eax,0x121cf7
pop rbp
ret
FUNC_000024:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],24
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov ecx,0x15180
xor edx,edx
div ecx
imul eax,edx,0xc22e
pop rbp
ret
FUNC_000025:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],25
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor edi,edi
xor esi,esi
mov eax,[rbp+16]
mov ebx,eax
jmp JUMP_000211
JUMP_000210:
mov eax,esi
shl eax,0x4
add eax,esi
shl eax,0x2
add eax,[rbp+16]
push rax
call QWORD PTR [rbp+24]
pop rcx
add edi,eax
inc esi
add ebx,+0x44
JUMP_000211:
cmp DWORD PTR [ebx],+0x0
jnz JUMP_000210
mov eax,edi
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000026:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],26
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov edi,[rbp+16]
xor ebx,ebx
mov esi,edi
jmp JUMP_000214
JUMP_000212:
mov eax,ebx
shl eax,0x4
add eax,ebx
shl eax,0x2
add eax,edi
push rax
call QWORD PTR [rbp+24]
pop rcx
test eax,eax
jz JUMP_000213
mov eax,[rbp+32]
add DWORD PTR [rbp+32],-0x1
test eax,eax
jz JUMP_000215
JUMP_000213:
inc ebx
add esi,+0x44
JUMP_000214:
cmp DWORD PTR [esi],+0x0
jnz JUMP_000212
JUMP_000215:
mov eax,ebx
shl eax,0x4
add eax,ebx
mov eax,[edi+eax*4+0x4]
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000027:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],27
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov ebx,0x72
mov eax,[rbp+16]
lea edi,[eax+0x9798]
mov eax,[rbp+16]
lea esi,[eax+0x72]
JUMP_000216:
cmp BYTE PTR [esi],0x0
jz JUMP_000217
lea eax,[ebx+ebx*4]
lea eax,[ebx+eax*4]
lea eax,[ebx+eax*8]
add eax,eax
add eax,[rbp+16]
add eax,+0x74
push rax
call QWORD PTR [rbp+24]
pop rcx
test eax,eax
jz JUMP_000217
mov eax,[edi]
cmp eax,[rbp+32]
jz JUMP_000218
JUMP_000217:
dec ebx
add edi,0xfffffeae
dec esi
test ebx,ebx
jg JUMP_000216
JUMP_000218:
mov eax,ebx
pop rdi
pop rsi
pop rbx
pop rbp
ret
FUNC_000028:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],28
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
test BYTE PTR [eax+0x14c],0x10
setnz al
and eax,+0x1
pop rbp
ret
FUNC_000029:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],29
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,[eax+0x82]
cmp edx,+0x76
jc JUMP_000219
cmp edx,0x85
jna JUMP_000220
JUMP_000219:
xor eax,eax
jmp JUMP_000221
JUMP_000220:
mov eax,0x1
JUMP_000221:
pop rbp
ret
FUNC_000030:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],30
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov dx,[eax+0xc]
cmp dx,+0x76
jc JUMP_000222
cmp dx,0x85
jna JUMP_000223
JUMP_000222:
xor eax,eax
jmp JUMP_000224
JUMP_000223:
mov eax,0x1
JUMP_000224:
pop rbp
ret
nop
nop
FUNC_000031:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],31
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rax
mov eax,0x2
JUMP_000225:
add rsp,-4092
push rax
dec eax
jnz JUMP_000225
mov eax,[rbp-0x4]
push rbx
push rsi
push rdi
mov esi,[rbp+24]
mov ebx,[rbp+16]
mov eax,[ebx]
inc DWORD PTR [ebx]
movzx eax,BYTE PTR [eax]
cmp eax,+0x43
ja JUMP_000309
mov r11d,DWORD PTR [rax*4+DATA_000002]
jmp r11
.section .rodata
DATA_000002:
.long JUMP_000309
.long JUMP_000309
.long JUMP_000226
.long JUMP_000227
.long JUMP_000228
.long JUMP_000229
.long JUMP_000230
.long JUMP_000231
.long JUMP_000232
.long JUMP_000233
.long JUMP_000234
.long JUMP_000235
.long JUMP_000236
.long JUMP_000237
.long JUMP_000238
.long JUMP_000239
.long JUMP_000240
.long JUMP_000241
.long JUMP_000242
.long JUMP_000243
.long JUMP_000244
.long JUMP_000245
.long JUMP_000246
.long JUMP_000247
.long JUMP_000248
.long JUMP_000249
.long JUMP_000250
.long JUMP_000254
.long JUMP_000257
.long JUMP_000258
.long JUMP_000259
.long JUMP_000260
.long JUMP_000262
.long JUMP_000263
.long JUMP_000264
.long JUMP_000267
.long JUMP_000269
.long JUMP_000270
.long JUMP_000273
.long JUMP_000274
.long JUMP_000275
.long JUMP_000276
.long JUMP_000277
.long JUMP_000278
.long JUMP_000279
.long JUMP_000280
.long JUMP_000281
.long JUMP_000282
.long JUMP_000283
.long JUMP_000285
.long JUMP_000286
.long JUMP_000287
.long JUMP_000288
.long JUMP_000289
.long JUMP_000290
.long JUMP_000291
.long JUMP_000292
.long JUMP_000293
.long JUMP_000294
.long JUMP_000298
.long JUMP_000299
.long JUMP_000300
.long JUMP_000301
.long JUMP_000302
.long JUMP_000304
.long JUMP_000305
.long JUMP_000306
.long JUMP_000308
.section .text
JUMP_000226:
push rbx
call FUNC_000020
pop rcx
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000227:
push rbx
call FUNC_000020
pop rcx
push rax
call FUNC_000021
pop rcx
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000228:
push rbx
call FUNC_000020
pop rcx
mov eax,[eax*4+DATA_008548]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000229:
push rbx
call FUNC_000020
pop rcx
mov edx,[esi+0x1c]
mov edx,[edx+0x14]
mov eax,[edx+eax*4]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000230:
push rbx
call FUNC_000020
pop rcx
mov edi,eax
mov eax,[esi+0x20]
mov eax,[eax+edi*4]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000231:
push rsi
push rbx
call FUNC_000031
add rsp,16
neg eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000232:
push rsi
push rbx
call FUNC_000031
add rsp,16
not eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000233:
push rsi
push rbx
call FUNC_000031
add rsp,16
cmp eax,+0x1
sbb eax,eax
neg eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000234:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
imul edi,[rbp-0xc]
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000235:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
mov eax,edi
cdq
idiv DWORD PTR [rbp-0xc]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000236:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
mov eax,edi
cdq
idiv DWORD PTR [rbp-0xc]
mov [rbp-0x8],edx
jmp JUMP_000309
JUMP_000237:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
add edi,[rbp-0xc]
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000238:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
sub edi,[rbp-0xc]
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000239:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
mov ecx,[rbp-0xc]
shl edi,cl
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000240:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
mov ecx,[rbp-0xc]
sar edi,cl
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000241:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
cmp edi,[rbp-0xc]
setl al
and eax,+0x1
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000242:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
cmp edi,[rbp-0xc]
setng al
and eax,+0x1
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000243:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
cmp edi,[rbp-0xc]
setg al
and eax,+0x1
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000244:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
cmp edi,[rbp-0xc]
setnl al
and eax,+0x1
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000245:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
cmp edi,[rbp-0xc]
setz al
and eax,+0x1
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000246:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
cmp edi,[rbp-0xc]
setnz al
and eax,+0x1
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000247:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
and edi,[rbp-0xc]
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000248:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
xor edi,[rbp-0xc]
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000249:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
or edi,[rbp-0xc]
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000250:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
test edi,edi
jz JUMP_000251
cmp DWORD PTR [rbp-0xc],+0x0
jnz JUMP_000252
JUMP_000251:
xor eax,eax
jmp JUMP_000253
JUMP_000252:
mov eax,0x1
JUMP_000253:
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000254:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
test edi,edi
jnz JUMP_000255
cmp DWORD PTR [rbp-0xc],+0x0
jnz JUMP_000255
xor eax,eax
jmp JUMP_000256
JUMP_000255:
mov eax,0x1
JUMP_000256:
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000257:
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000258:
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000259:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000260:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
test edi,edi
jl JUMP_000261
cmp edi,+0x6
jnl JUMP_000261
mov eax,[edi*4+DATA_009093]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000261:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000262:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
mov eax,[rbp-0xc]
push rax
push rdi
call FUNC_000085
add rsp,16
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000263:
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000264:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
cmp edi,+0x1
jnz JUMP_000265
mov eax,[DATA_008913]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000265:
cmp edi,+0x2
jnz JUMP_000266
mov eax,[DATA_008912]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000266:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000267:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
test edi,edi
jl JUMP_000268
cmp edi,+0x6
jnl JUMP_000268
mov eax,[edi*4+DATA_009095]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000268:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000269:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
mov eax,[DATA_009133]
push rax
push rdi
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov eax,[eax+0x82]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000270:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
cmp DWORD PTR [rbp-0xc],0x3e8
jnl JUMP_000271
sub DWORD PTR [rbp-0xc],+0x64
mov eax,[rbp-0xc]
push rax
mov eax,[DATA_009133]
push rax
push rdi
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
push rax
call FUNC_000392
add rsp,16
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000271:
sub DWORD PTR [rbp-0xc],0x3e8
mov eax,[DATA_008861]
movzx eax,BYTE PTR [eax+0x86]
cmp edi,eax
jnz JUMP_000272
cmp DWORD PTR [rbp-0xc],+0x26
jnl JUMP_000272
mov eax,[rbp-0xc]
movzx eax,WORD PTR [eax*2+DATA_008896]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000272:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000273:
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000274:
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000275:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000276:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000277:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000278:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000279:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rsi
push rbx
call FUNC_000031
add rsp,16
jmp JUMP_000309
JUMP_000280:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
call FUNC_000106
pop rcx
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000281:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov ebx,eax
push rbx
mov eax,[rbp-0xc]
push rax
push rdi
call FUNC_000096
add rsp,24
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000282:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
mov [rbp-0x4],edi
mov ax,[rbp-0x4]
and eax,0x1fff
shl eax,0x10
shr edi,0xd
and edi,0x1fff
and edi,0xffff
or eax,edi
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000283:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
test edi,edi
jl JUMP_000284
cmp edi,+0x6
jnl JUMP_000284
mov eax,[edi*4+DATA_008908]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000284:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000285:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x4],eax
lea eax,[rbp-0x10]
push rax
lea eax,[rbp-0x10]
push rax
lea eax,[rbp-0x8]
push rax
lea eax,[rbp-0x10]
push rax
lea eax,[rbp-0x10]
push rax
lea eax,[rbp-0x10]
push rax
mov eax,[rbp-0x4]
push rax
call FUNC_000871
add rsp,56
jmp JUMP_000309
JUMP_000286:
call FUNC_001476
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
pop rdx
xchg eax,edx
mov ecx,edx
xor edx,edx
div ecx
mov [rbp-0x8],edx
jmp JUMP_000309
JUMP_000287:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rdi
push OFFSET FLAT:FUNC_000028
mov eax,[DATA_009133]
push rax
call FUNC_000027
add rsp,24
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000288:
push rsi
push rbx
call FUNC_000031
add rsp,16
cmp eax,[DATA_008560]
setz al
and eax,+0x1
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000289:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov ebx,eax
lea eax,[rbp-0x12]
push rax
push rbx
call FUNC_000658
add rsp,16
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000290:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
call FUNC_000023
pop rcx
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000291:
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
call FUNC_000024
pop rcx
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000292:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
mov eax,[DATA_009133]
push rax
push rdi
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov eax,[eax+0xa0]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000293:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x4],eax
push +0x3
mov r11d,DWORD PTR [DATA_007217]
call r11
pop rcx
push rax
mov eax,[rbp-0x4]
push rax
call FUNC_000857
add rsp,16
mov [rbp-0x4],eax
mov eax,[rbp-0x4]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000294:
mov edi,0x1
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x4],eax
mov eax,[rbp-0x4]
push rax
lea eax,[rbp-0x1014]
push rax
call FUNC_000461
add rsp,16
test eax,eax
jnz JUMP_000295
lea eax,[rbp-0x1014]
push rax
call FUNC_000462
pop rcx
mov edi,eax
test edi,edi
jnz JUMP_000296
JUMP_000295:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000296:
push rdi
mov r11d,DWORD PTR [DATA_007217]
call r11
pop rcx
push rax
lea eax,[rbp-0x1014]
push rax
call FUNC_000463
add rsp,16
test eax,eax
jnz JUMP_000297
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000297:
mov eax,[eax+0x4]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000298:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0xc],eax
push rsi
push rbx
call FUNC_000031
add rsp,16
mov ebx,eax
add edi,0x1718
mov eax,[rbp-0xc]
add eax,0x1524
shl eax,0xd
or edi,eax
shl ebx,0x1a
or edi,ebx
mov [rbp-0x8],edi
jmp JUMP_000309
JUMP_000299:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rdi
push OFFSET FLAT:FUNC_000029
mov eax,[DATA_009133]
push rax
call FUNC_000027
add rsp,24
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000300:
mov eax,[DATA_009133]
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
mov eax,[eax+0x82]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000301:
mov eax,[DATA_009133]
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
movzx eax,BYTE PTR [eax+0xff]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000302:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x4],eax
mov eax,[rbp-0x4]
push rax
lea eax,[rbp-0x2004]
push rax
call FUNC_000461
add rsp,16
test eax,eax
jz JUMP_000303
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000303:
push OFFSET FLAT:FUNC_000030
lea eax,[rbp-0x2004]
push rax
call FUNC_000025
add rsp,16
mov [rbp-0x8],eax
cmp DWORD PTR [rbp-0x8],+0x0
jz JUMP_000309
mov eax,[rbp-0x8]
push rax
mov r11d,DWORD PTR [DATA_007217]
call r11
pop rcx
push rax
push OFFSET FLAT:FUNC_000030
lea eax,[rbp-0x2004]
push rax
call FUNC_000026
add rsp,24
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000304:
mov eax,[DATA_009133]
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
movsx eax,BYTE PTR [eax+0x88]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000305:
mov eax,[DATA_009133]
push rax
push rsi
push rbx
call FUNC_000031
add rsp,16
push rax
mov r11d,DWORD PTR [DATA_007754]
call r11
add rsp,16
movzx eax,BYTE PTR [eax+0xfe]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000306:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov edi,eax
push rsi
push rbx
call FUNC_000031
add rsp,16
add eax,0xfffffc18
mov [rbp-0xc],eax
push rdi
call FUNC_000649
pop rcx
test eax,eax
jz JUMP_000307
cmp DWORD PTR [rbp-0xc],+0x0
jl JUMP_000307
cmp DWORD PTR [rbp-0xc],+0x26
jnl JUMP_000307
mov edx,[rbp-0xc]
mov eax,[eax+edx*8+0x4]
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000307:
xor eax,eax
mov [rbp-0x8],eax
jmp JUMP_000309
JUMP_000308:
push rsi
push rbx
call FUNC_000031
add rsp,16
mov [rbp-0x4],eax
lea eax,[rbp-0x24]
push rax
lea eax,[rbp-0x20]
push rax
lea eax,[rbp-0x1c]
push rax
lea eax,[rbp-0x18]
push rax
mov eax,[rbp-0x4]
push rax
call FUNC_000870
add rsp,40
mov eax,[rbp-0x1c]
mov [rbp-0x8],eax
JUMP_000309:
mov eax,[rbp-0x8]
pop rdi
pop rsi
pop rbx
mov rsp,rbp
pop rbp
ret
FUNC_000462:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],462
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
xor edx,edx
mov eax,[rbp+16]
jmp JUMP_002233
JUMP_002231:
cmp WORD PTR [eax+0xa],+0x20
jc JUMP_002232
inc edx
JUMP_002232:
add eax,+0x44
JUMP_002233:
cmp DWORD PTR [eax],+0x0
jnz JUMP_002231
mov eax,edx
pop rbp
ret
FUNC_000463:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],463
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
mov ecx,[rbp+24]
mov esi,[rbp+16]
xor edx,edx
mov eax,esi
jmp JUMP_002236
JUMP_002234:
cmp WORD PTR [eax+0xa],+0x20
jc JUMP_002235
mov ebx,ecx
add ecx,-0x1
test ebx,ebx
jnz JUMP_002235
mov eax,edx
shl eax,0x4
add eax,edx
shl eax,0x2
add eax,esi
jmp JUMP_002237
JUMP_002235:
inc edx
add eax,+0x44
JUMP_002236:
cmp DWORD PTR [eax],+0x0
jnz JUMP_002234
xor eax,eax
JUMP_002237:
pop rsi
pop rbx
pop rbp
ret
FUNC_000922:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],922
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
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
mov edx,[rbp+16]
imul edx,eax
mov eax,edx
shr eax,0x10
pop rbp
ret
FUNC_001530:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],1530
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
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
FUNC_001532:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],1532
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
mov eax,[rbp+16]
mov edx,eax
lea eax,[edx+eax*4]
lea eax,[edx+eax*4]
lea eax,[edx+eax*8]
add eax,eax
add eax,[rbp+24]
add eax,+0x74
pop rbp
ret
.section .text

.global call_kernel
call_kernel:
mov [e_saved_rsp],rsp
mov esp,OFFSET FLAT:e_stack_end
cmp edi,0
je e_call20
cmp edi,1
je e_call21
cmp edi,2
je e_call22
cmp edi,3
je e_call23
cmp edi,4
je e_call24
cmp edi,5
je e_call25
cmp edi,6
je e_call26
cmp edi,7
je e_call27
cmp edi,8
je e_call28
cmp edi,9
je e_call29
cmp edi,10
je e_call30
cmp edi,11
je e_call31
cmp edi,12
je e_call462
cmp edi,13
je e_call463
cmp edi,14
je e_call922
cmp edi,15
je e_call1530
cmp edi,16
je e_call1532
jmp e_abort
e_call20:
push OFFSET FLAT:e_ip
call FUNC_000020
jmp e_called
e_call21:
push rsi
call FUNC_000021
jmp e_called
e_call22:
push rdx
push rsi
call FUNC_000022
xor eax,eax
jmp e_called
e_call23:
push rsi
call FUNC_000023
jmp e_called
e_call24:
push rsi
call FUNC_000024
jmp e_called
e_call25:
push OFFSET FLAT:FUNC_000030
push OFFSET FLAT:e_program
call FUNC_000025
jmp e_called
e_call26:
push rdx
push OFFSET FLAT:FUNC_000030
push OFFSET FLAT:e_program
call FUNC_000026
jmp e_called
e_call27:
push rdx
mov eax,OFFSET FLAT:FUNC_000028
cmp esi,29
jne e_pred_ready
mov eax,OFFSET FLAT:FUNC_000029
e_pred_ready:
push rax
push OFFSET FLAT:e_bank
call FUNC_000027
jmp e_called
e_call28:
imul esi,esi,338
add esi,OFFSET FLAT:e_bank+116
push rsi
call FUNC_000028
jmp e_called
e_call29:
imul esi,esi,338
add esi,OFFSET FLAT:e_bank+116
push rsi
call FUNC_000029
jmp e_called
e_call30:
add esi,OFFSET FLAT:e_program
push rsi
call FUNC_000030
jmp e_called
e_call31:
push OFFSET FLAT:e_task
push OFFSET FLAT:e_ip
call FUNC_000031
jmp e_called
e_call462:
push OFFSET FLAT:e_program
call FUNC_000462
jmp e_called
e_call463:
push rsi
push OFFSET FLAT:e_program
call FUNC_000463
test eax,eax
jz e_called
sub eax,OFFSET FLAT:e_program
inc eax
jmp e_called
e_call922:
push rsi
call FUNC_000922
jmp e_called
e_call1530:
call FUNC_001530
jmp e_called
e_call1532:
push OFFSET FLAT:e_bank
push rsi
call FUNC_001532
sub eax,OFFSET FLAT:e_bank
e_called:
mov rsp,[e_saved_rsp]
ret
e_abort:
mov edi,97
mov eax,60
syscall

FUNC_000048:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],48
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov edi,48
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000085:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],85
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov edi,85
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000096:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],96
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov edi,96
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000106:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],106
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edi,106
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000392:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],392
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov edi,392
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000461:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],461
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov esi,DWORD PTR [rbp+24]
mov r8d,DWORD PTR [rbp+16]
mov edi,461
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000649:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],649
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edi,649
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000658:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],658
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov r8d,DWORD PTR [rbp+24]
mov edi,658
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000857:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],857
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov edi,857
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000870:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],870
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov r8d,DWORD PTR [rbp+24]
mov r9d,DWORD PTR [rbp+32]
mov eax,DWORD PTR [rbp+40]
mov [e_extra3],rax
mov eax,DWORD PTR [rbp+48]
mov [e_extra4],rax
mov edi,870
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000871:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],871
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov r8d,DWORD PTR [rbp+24]
mov r9d,DWORD PTR [rbp+48]
mov edi,871
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_000909:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],909
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov edi,909
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

FUNC_001476:
pushfq
push rax
push rcx
mov ecx,DWORD PTR [e_trace_count]
cmp ecx,512
jae e_abort
mov DWORD PTR [e_trace+rcx*4],1476
inc DWORD PTR [e_trace_count]
pop rcx
pop rax
popfq
push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
xor esi,esi
xor edx,edx
xor ecx,ecx
xor r8d,r8d
xor r9d,r9d
mov QWORD PTR [e_extra3],0
mov QWORD PTR [e_extra4],0
mov edi,1476
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret

.section .data
DATA_007217:.long FUNC_000922
DATA_007754:.long FUNC_001532
DATA_008804=e_root+0
DATA_008807=e_root+4
DATA_008818=e_root+36
DATA_008820=e_root+40
DATA_008861=e_root+200
DATA_008862=e_root+204
DATA_008870=e_root+232
DATA_008874=e_root+236
DATA_008885=e_root+266
DATA_008888=e_root+276
DATA_008890=e_root+284
DATA_008892=e_root+292
DATA_008896=e_root+308
DATA_008908=e_root+388
DATA_008911=e_root+412
DATA_008912=e_root+416
DATA_008913=e_root+420
DATA_008922=e_root+496
DATA_008923=e_root+500
DATA_008924=e_root+504
DATA_008925=e_root+508
DATA_008926=e_root+512
DATA_009093=e_root+20704
DATA_009095=e_root+20728
DATA_009133=e_root+22540
DATA_008548=e_events
DATA_008560=e_temporary
.section .bss
.balign 16
e_stack:.zero 4194304
e_stack_end:
e_saved_rsp:.zero 8
 .global e_extra3,e_extra4
e_extra3:.zero 8
e_extra4:.zero 8

.section .note.GNU-stack,"",@progbits
