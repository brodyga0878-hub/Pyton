
.intel_syntax noprefix
.code64
.section .recorder,"ax"
event_recorder:
 pushfq
 push rax
 push rbx
 push rcx
 push rdx
 push rsi
 push rdi
 push rbp
 mov edx,DWORD PTR [output+44]
 cmp edx,3
 jae failed
 mov eax,DWORD PTR [rsp+72]
 mov ecx,DWORD PTR [rsp+80]
 mov DWORD PTR [output+48+edx*8],eax
 mov DWORD PTR [output+52+edx*8],ecx
 inc DWORD PTR [output+44]
 pop rbp
 pop rdi
 pop rsi
 pop rdx
 pop rcx
 pop rbx
 pop rax
 popfq
 ret
.section .clock,"ax"
clock_entry:
.Ldos_43c5c8:
 mov    eax,ds:0x652c10
.Ldos_43c5cd:
 mov    ds:0x652c0c,eax
.Ldos_43c5d2:
 sub    DWORD PTR ds:0x652c10,eax
.Ldos_43c5d8:
 mov    esi,DWORD PTR [ebx+0x4]
.Ldos_43c5db:
 add    DWORD PTR [ebx],eax
.Ldos_43c5dd:
 cmp    eax,DWORD PTR [ebx]
.Ldos_43c5df:
 jbe .Ldos_43c5e4
.Ldos_43c5e1:
 inc    DWORD PTR [ebx+0x4]
.Ldos_43c5e4:
 mov    eax,DWORD PTR [ebx+0x4]
.Ldos_43c5e7:
 cmp    eax,DWORD PTR [ebx+0x7a]
.Ldos_43c5ea:
 jb .Ldos_43c611
.Ldos_43c5ec:
 mov    eax,DWORD PTR [ebx]
.Ldos_43c5ee:
 cmp    eax,DWORD PTR [ebx+0x76]
.Ldos_43c5f1:
 jb .Ldos_43c611
.Ldos_43c5f3:
 mov    eax,DWORD PTR [ebx+0x76]
.Ldos_43c5f6:
 mov    DWORD PTR [ebx],eax
.Ldos_43c5f8:
 mov    eax,DWORD PTR [ebx+0x7a]
.Ldos_43c5fb:
 mov    DWORD PTR [ebx+0x4],eax
.Ldos_43c5fe:
 push   0x0
.Ldos_43c600:
 push   0x15
.Ldos_43c602:
 call event_recorder
.Ldos_43c607:
 add    rsp,0x10
.Ldos_43c60a:
 mov    DWORD PTR [ebx+0x7a],0xffffffff
.Ldos_43c611:
 mov    ecx,DWORD PTR [ebx+0x4]
.Ldos_43c614:
 .byte 0x3b,0xf1
.Ldos_43c616:
 je .Ldos_43c63f
.Ldos_43c618:
 .byte 0x8b,0xc1
.Ldos_43c61a:
 mov    ecx,0x7
.Ldos_43c61f:
 .byte 0x33,0xd2
.Ldos_43c621:
 div    ecx
.Ldos_43c623:
 test   edx,edx
.Ldos_43c625:
 jne .Ldos_43c633
.Ldos_43c627:
 push   0x0
.Ldos_43c629:
 push   0x10
.Ldos_43c62b:
 call event_recorder
.Ldos_43c630:
 add    rsp,0x10
.Ldos_43c633:
 push   0x0
.Ldos_43c635:
 push   0xf
.Ldos_43c637:
 call event_recorder
.Ldos_43c63c:
 add    rsp,0x10
.Ldos_43c63f:
 mov    eax,ds:0x652c14
.Ldos_43c644:
 mov    ds:0x6476a8,eax
.Ldos_43c649:
 .byte 0x33,0xd2
.Ldos_43c64b:
 mov    DWORD PTR ds:0x652c14,edx
.Ldos_43c651:
 add    DWORD PTR ds:0x6388a0,eax
 ret

.section .systemtotal,"aw",@nobits
systemtotal_before: .zero 8
system_total: .zero 4
systemtotal_after: .zero 8
.section .game,"aw",@nobits
game_before: .zero 8
game: .zero 128
game_after: .zero 8
.section .systemframe,"aw",@nobits
systemframe_before: .zero 8
system_frame: .zero 4
systemframe_after: .zero 8
.section .raw,"aw",@nobits
raw_before: .zero 8
frame_ticks: .zero 4
accelerated_counter: .zero 4
system_counter: .zero 4
raw_after: .zero 8
.section .text,"ax"
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,36
 sub edx,r8d
 syscall
 test eax,eax
 js failed
 jnz got_input
 test r8d,r8d
 jnz failed
 mov eax,60
 xor edi,edi
 syscall
got_input:
 add r8d,eax
 cmp r8d,36
 jb read_more
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,256
 rep stosb
 mov edi,OFFSET FLAT:game
 mov eax,0xa5
 mov ecx,128
 rep stosb
 mov DWORD PTR [systemtotal_before],0x4b444f53
 mov DWORD PTR [systemtotal_before+4],0x434c4f43
 mov DWORD PTR [systemtotal_after],0x4b444f53
 mov DWORD PTR [systemtotal_after+4],0x434c4f43
 mov DWORD PTR [game_before],0x4b444f53
 mov DWORD PTR [game_before+4],0x434c4f43
 mov DWORD PTR [game_after],0x4b444f53
 mov DWORD PTR [game_after+4],0x434c4f43
 mov DWORD PTR [systemframe_before],0x4b444f53
 mov DWORD PTR [systemframe_before+4],0x434c4f43
 mov DWORD PTR [systemframe_after],0x4b444f53
 mov DWORD PTR [systemframe_after+4],0x434c4f43
 mov DWORD PTR [raw_before],0x4b444f53
 mov DWORD PTR [raw_before+4],0x434c4f43
 mov DWORD PTR [raw_after],0x4b444f53
 mov DWORD PTR [raw_after+4],0x434c4f43
 mov DWORD PTR [output],0x4b444f53
 mov DWORD PTR [output+4],0x434c4f43
 mov DWORD PTR [output+248],0x4b444f53
 mov DWORD PTR [output+248+4],0x434c4f43
 mov eax,DWORD PTR [input+0]
 mov DWORD PTR [game],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [game+4],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [game+0x76],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [game+0x7a],eax
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [accelerated_counter],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [frame_ticks],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [system_counter],eax
 mov eax,DWORD PTR [input+28]
 mov DWORD PTR [system_frame],eax
 mov eax,DWORD PTR [input+32]
 mov DWORD PTR [system_total],eax
 mov ebx,OFFSET FLAT:game
 call clock_entry
 cmp DWORD PTR [systemtotal_before],0x4b444f53
 jne failed
 cmp DWORD PTR [systemtotal_before+4],0x434c4f43
 jne failed
 cmp DWORD PTR [systemtotal_after],0x4b444f53
 jne failed
 cmp DWORD PTR [systemtotal_after+4],0x434c4f43
 jne failed
 cmp DWORD PTR [game_before],0x4b444f53
 jne failed
 cmp DWORD PTR [game_before+4],0x434c4f43
 jne failed
 cmp DWORD PTR [game_after],0x4b444f53
 jne failed
 cmp DWORD PTR [game_after+4],0x434c4f43
 jne failed
 cmp DWORD PTR [systemframe_before],0x4b444f53
 jne failed
 cmp DWORD PTR [systemframe_before+4],0x434c4f43
 jne failed
 cmp DWORD PTR [systemframe_after],0x4b444f53
 jne failed
 cmp DWORD PTR [systemframe_after+4],0x434c4f43
 jne failed
 cmp DWORD PTR [raw_before],0x4b444f53
 jne failed
 cmp DWORD PTR [raw_before+4],0x434c4f43
 jne failed
 cmp DWORD PTR [raw_after],0x4b444f53
 jne failed
 cmp DWORD PTR [raw_after+4],0x434c4f43
 jne failed
 mov eax,DWORD PTR [game]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [game+4]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [game+0x76]
 mov DWORD PTR [output+16],eax
 mov eax,DWORD PTR [game+0x7a]
 mov DWORD PTR [output+20],eax
 mov eax,DWORD PTR [accelerated_counter]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [frame_ticks]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [system_counter]
 mov DWORD PTR [output+32],eax
 mov eax,DWORD PTR [system_frame]
 mov DWORD PTR [output+36],eax
 mov eax,DWORD PTR [system_total]
 mov DWORD PTR [output+40],eax

 mov esi,OFFSET FLAT:game
 mov edi,OFFSET FLAT:output+72
 mov ecx,128
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,256
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,256
 jb write_more
 jmp next_case
failed:
 mov eax,60
 mov edi,93
 syscall
.section .bss,"aw",@nobits
input: .zero 36
output: .zero 256
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
