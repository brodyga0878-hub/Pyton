.intel_syntax noprefix
.code32
.section .clock,"ax"
.equ event_recorder,0x41942c
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
 add    esp,0x8
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
 add    esp,0x8
.Ldos_43c633:
 push   0x0
.Ldos_43c635:
 push   0xf
.Ldos_43c637:
 call event_recorder
.Ldos_43c63c:
 add    esp,0x8
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
