.intel_syntax noprefix
.code64
.section .text
.global _start
FUNC_000578:
DOS_PAIR_4281b8:
push rbp
DOS_PAIR_4281b9:
mov rbp,rsp
DOS_PAIR_4281bb:
push rbx
DOS_PAIR_4281bc:
push rsi
DOS_PAIR_4281bd:
mov esi,DWORD PTR [rbp+24]
DOS_PAIR_4281c0:
mov ebx,DWORD PTR [rbp+16]
DOS_PAIR_4281c3:
or BYTE PTR [DATA_008696],0x80
DOS_PAIR_4281ca:
mov al,BYTE PTR [ebx+0x56]
DOS_PAIR_4281cd:
cmp al,BYTE PTR [esi+0x86]
DOS_PAIR_4281d3:
je DOS_PAIR_4281e2
DOS_PAIR_4281d5:
cmp BYTE PTR [esi+0x87],0x1
DOS_PAIR_4281dc:
jne DOS_PAIR_428265
DOS_PAIR_4281e2:
mov eax,DWORD PTR [ebx+0x8c]
DOS_PAIR_4281e8:
sar eax,0x2
DOS_PAIR_4281eb:
neg eax
DOS_PAIR_4281ed:
mov DWORD PTR [ebx+0x8c],eax
DOS_PAIR_4281f3:
mov eax,DWORD PTR [ebx+0x90]
DOS_PAIR_4281f9:
sar eax,0x2
DOS_PAIR_4281fc:
neg eax
DOS_PAIR_4281fe:
mov DWORD PTR [ebx+0x90],eax
DOS_PAIR_428204:
mov eax,DWORD PTR [ebx+0x94]
DOS_PAIR_42820a:
sar eax,0x2
DOS_PAIR_42820d:
neg eax
DOS_PAIR_42820f:
mov DWORD PTR [ebx+0x94],eax
DOS_PAIR_428215:
mov eax,DWORD PTR [ebx+0x8c]
DOS_PAIR_42821b:
push rax
DOS_PAIR_42821c:
call _abs
DOS_PAIR_428221:
pop rcx
DOS_PAIR_428222:
mov esi,eax
DOS_PAIR_428224:
mov eax,DWORD PTR [ebx+0x90]
DOS_PAIR_42822a:
push rax
DOS_PAIR_42822b:
call _abs
DOS_PAIR_428230:
pop rcx
DOS_PAIR_428231:
add esi,eax
DOS_PAIR_428233:
mov eax,DWORD PTR [ebx+0x94]
DOS_PAIR_428239:
push rax
DOS_PAIR_42823a:
call _abs
DOS_PAIR_42823f:
pop rcx
DOS_PAIR_428240:
add esi,eax
DOS_PAIR_428242:
mov eax,esi
DOS_PAIR_428244:
add eax,0xa
DOS_PAIR_428247:
cmp DWORD PTR [ebx+0x82],0xd
DOS_PAIR_42824e:
jbe DOS_PAIR_428354
DOS_PAIR_428254:
push 0x0
DOS_PAIR_428256:
push rax
DOS_PAIR_428257:
push rbx
DOS_PAIR_428258:
call FUNC_000953
DOS_PAIR_42825d:
add rsp,24
DOS_PAIR_428260:
jmp DOS_PAIR_428354
DOS_PAIR_428265:
mov eax,DWORD PTR [ebx+0x8c]
DOS_PAIR_42826b:
add eax,DWORD PTR [esi+0x8c]
DOS_PAIR_428271:
sar eax,1
DOS_PAIR_428273:
mov DWORD PTR [esi+0x8c],eax
DOS_PAIR_428279:
mov DWORD PTR [ebx+0x8c],eax
DOS_PAIR_42827f:
mov eax,DWORD PTR [ebx+0x90]
DOS_PAIR_428285:
add eax,DWORD PTR [esi+0x90]
DOS_PAIR_42828b:
sar eax,1
DOS_PAIR_42828d:
mov DWORD PTR [esi+0x90],eax
DOS_PAIR_428293:
mov DWORD PTR [ebx+0x90],eax
DOS_PAIR_428299:
mov eax,DWORD PTR [ebx+0x94]
DOS_PAIR_42829f:
add eax,DWORD PTR [esi+0x94]
DOS_PAIR_4282a5:
sar eax,1
DOS_PAIR_4282a7:
mov DWORD PTR [esi+0x94],eax
DOS_PAIR_4282ad:
mov DWORD PTR [ebx+0x94],eax
DOS_PAIR_4282b3:
cmp BYTE PTR [DATA_008700],0x0
DOS_PAIR_4282ba:
je DOS_PAIR_428354
DOS_PAIR_4282c0:
cmp DWORD PTR [ebx+0x82],0xd
DOS_PAIR_4282c7:
jbe DOS_PAIR_428354
DOS_PAIR_4282cd:
cmp DWORD PTR [esi+0x82],0xd
DOS_PAIR_4282d4:
jbe DOS_PAIR_428354
DOS_PAIR_4282d6:
mov ax,WORD PTR [esi+0xe4]
DOS_PAIR_4282dd:
cmp ax,WORD PTR [ebx+0xe4]
DOS_PAIR_4282e4:
ja DOS_PAIR_42831c
DOS_PAIR_4282e6:
xor edx,edx
DOS_PAIR_4282e8:
mov dl,BYTE PTR [ebx+0x86]
DOS_PAIR_4282ee:
push rdx
DOS_PAIR_4282ef:
movzx eax,ax
DOS_PAIR_4282f2:
add eax,eax
DOS_PAIR_4282f4:
push rax
DOS_PAIR_4282f5:
push rsi
DOS_PAIR_4282f6:
call FUNC_000953
DOS_PAIR_4282fb:
add rsp,24
DOS_PAIR_4282fe:
xor eax,eax
DOS_PAIR_428300:
mov al,BYTE PTR [esi+0x86]
DOS_PAIR_428306:
push rax
DOS_PAIR_428307:
movzx eax,WORD PTR [esi+0xe4]
DOS_PAIR_42830e:
add eax,eax
DOS_PAIR_428310:
push rax
DOS_PAIR_428311:
push rbx
DOS_PAIR_428312:
call FUNC_000953
DOS_PAIR_428317:
add rsp,24
DOS_PAIR_42831a:
jmp DOS_PAIR_428354
DOS_PAIR_42831c:
xor eax,eax
DOS_PAIR_42831e:
mov al,BYTE PTR [ebx+0x86]
DOS_PAIR_428324:
push rax
DOS_PAIR_428325:
movzx eax,WORD PTR [ebx+0xe4]
DOS_PAIR_42832c:
add eax,eax
DOS_PAIR_42832e:
push rax
DOS_PAIR_42832f:
push rsi
DOS_PAIR_428330:
call FUNC_000953
DOS_PAIR_428335:
add rsp,24
DOS_PAIR_428338:
xor eax,eax
DOS_PAIR_42833a:
mov al,BYTE PTR [esi+0x86]
DOS_PAIR_428340:
push rax
DOS_PAIR_428341:
movzx eax,WORD PTR [ebx+0xe4]
DOS_PAIR_428348:
add eax,eax
DOS_PAIR_42834a:
push rax
DOS_PAIR_42834b:
push rbx
DOS_PAIR_42834c:
call FUNC_000953
DOS_PAIR_428351:
add rsp,24
DOS_PAIR_428354:
pop rsi
DOS_PAIR_428355:
pop rbx
DOS_PAIR_428356:
pop rbp
DOS_PAIR_428357:
ret

_abs:
 push rbp
 mov rbp,rsp
 inc DWORD PTR [abs_count]
 mov eax,DWORD PTR [rbp+16]
 test eax,eax
 jge abs_positive
 mov edx,eax
 neg edx
 jmp abs_done
abs_positive:
 mov edx,eax
abs_done:
 mov eax,edx
 pop rbp
 ret
FUNC_000953:
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 push rbx
 push rcx
 push rdx
 push rsi
 push rdi
 mov ecx,DWORD PTR [request_count]
 cmp ecx,2
 jae failed
 imul ecx,ecx,1384
 lea rdi,[output+16+684+rcx]
 mov eax,DWORD PTR [rbp+16]
 cmp eax,OFFSET FLAT:body
 je target_body
 cmp eax,OFFSET FLAT:collider
 jne failed
 mov DWORD PTR [rdi],2
 jmp target_ready
target_body:
 mov DWORD PTR [rdi],1
target_ready:
 mov eax,DWORD PTR [rbp+24]
 mov DWORD PTR [rdi+4],eax
 mov eax,DWORD PTR [rbp+32]
 mov DWORD PTR [rdi+8],eax
 mov QWORD PTR [record_pointer],rdi
 add rdi,16
 mov esi,OFFSET FLAT:live
 mov ecx,684
 rep movsb
 mov ecx,DWORD PTR [request_count]
 shl ecx,7
 lea rsi,[input+684+rcx]
 mov ecx,16
patch_more:
 mov eax,DWORD PTR [rsi]
 cmp eax,0xffffffff
 je patch_skip
 cmp eax,684
 jae failed
 mov dl,BYTE PTR [rsi+4]
 mov BYTE PTR [live+rax],dl
patch_skip:
 add rsi,8
 loop patch_more
 mov rdi,QWORD PTR [record_pointer]
 add rdi,16+684
 mov esi,OFFSET FLAT:live
 mov ecx,684
 rep movsb
 inc DWORD PTR [request_count]
 pop rdi
 pop rsi
 pop rdx
 pop rcx
 pop rbx
 pop rax
 popfq
 pop rbp
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,940
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,940
 jb read_more
 mov edi,OFFSET FLAT:output
 mov ecx,3532
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,16+684+2*1384
 xor eax,eax
 rep stosb
 mov DWORD PTR [request_count],0
 mov DWORD PTR [abs_count],0
 mov esi,OFFSET FLAT:input+8
 mov edi,OFFSET FLAT:live
 mov ecx,676
 rep movsb
 mov eax,DWORD PTR [input]
 mov DWORD PTR [DATA_008696],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_008700],eax
 mov rax,0xa5a5a5a5a5a5a5a5
 mov QWORD PTR [live_before],rax
 mov QWORD PTR [live_after],rax
 push OFFSET FLAT:collider
 push OFFSET FLAT:body
 call FUNC_000578
 add rsp,16
 mov rax,0xa5a5a5a5a5a5a5a5
 cmp QWORD PTR [live_before],rax
 jne failed
 cmp QWORD PTR [live_after],rax
 jne failed
 mov DWORD PTR [output],0x50414952
 mov eax,DWORD PTR [request_count]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [abs_count]
 mov DWORD PTR [output+8],eax
 mov esi,OFFSET FLAT:live
 mov edi,OFFSET FLAT:output+16
 mov ecx,684
 rep movsb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,3532
 syscall
 cmp eax,3532
 jne failed
 jmp next_case
finished:
 test r8d,r8d
 jne failed
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,87
 syscall
.section .bss
.balign 16
input:.skip 940
output:.skip 3532
live_before:.skip 8
live:.skip 684
live_after:.skip 8
.set body,live
.set collider,live+338
.set DATA_008696,live+676
.set DATA_008700,live+680
request_count:.skip 4
abs_count:.skip 4
record_pointer:.skip 8
.balign 16
stack:.skip 65536
stack_end:
