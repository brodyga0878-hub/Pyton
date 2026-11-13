.intel_syntax noprefix
.code64
.section .bss
.global DATA_008696
DATA_008696: .zero 1
.section .bss
.global DATA_008697
DATA_008697: .zero 1
.section .bss
.global DATA_008698
DATA_008698: .zero 1
.section .bss
.global DATA_008699
DATA_008699: .zero 1
.section .bss
.global DATA_008700
DATA_008700: .zero 1
.section .bss
.global DATA_008701
DATA_008701: .zero 3
.section .bss
.global DATA_008702
DATA_008702: .zero 4
.section .bss
.global DATA_008703
DATA_008703: .zero 4
.section .bss
.global DATA_008704
DATA_008704: .zero 4
.section .bss
.global DATA_008705
DATA_008705: .zero 4
.section .bss
.global DATA_008706
DATA_008706: .zero 4
.section .bss
.global DATA_008707
DATA_008707: .zero 4
.section .bss
.global DATA_008812
DATA_008812: .zero 4
.section .bss
.global DATA_009258
DATA_009258: .zero 4096
.section .bss
.global DATA_009259
DATA_009259: .zero 4
.section .bss
.global DATA_009260
DATA_009260: .zero 512
.section .bss
.global DATA_009261
DATA_009261: .zero 4
.section .bss
.global DATA_009264
DATA_009264: .zero 4
.section .bss
.global DATA_009269
DATA_009269: .zero 4
.section .bss
.global DATA_009270
DATA_009270: .zero 4
.section .bss
.global DATA_009271
DATA_009271: .zero 500
.section .bss
.global DATA_009272
DATA_009272: .zero 4
.section .bss
.global DATA_009273
DATA_009273: .zero 4
.section .bss
.global DATA_009274
DATA_009274: .zero 108000
.section .bss
.global DATA_009275
DATA_009275: .zero 4
.section .bss
.global DATA_009276
DATA_009276: .zero 4
.section .bss
.global DATA_009277
DATA_009277: .zero 48000
.section .bss
.global DATA_009278
DATA_009278: .zero 4
.section .bss
.global DATA_009279
DATA_009279: .zero 4
.section .bss
.global DATA_009280
DATA_009280: .zero 4
.section .bss
.global DATA_009281
DATA_009281: .zero 4
.section .bss
.global DATA_009282
DATA_009282: .zero 4
.section .bss
.global DATA_009283
DATA_009283: .zero 4
.section .bss
.global DATA_009284
DATA_009284: .zero 4
.section .bss
.global DATA_009285
DATA_009285: .zero 8
.section .text
.global FUNC_000580
FUNC_000580:
mov eax,60
mov edi,100
syscall
.section .text
.global FUNC_000583
FUNC_000583:
mov eax,60
mov edi,101
syscall
.section .text
.global FUNC_001479
FUNC_001479:
mov eax,60
mov edi,102
syscall
.section .text
.global FUNC_001532
FUNC_001532:
mov eax,60
mov edi,103
syscall
.section .text
.global FUNC_001691
FUNC_001691:
mov eax,60
mov edi,104
syscall
.section .text
.global FUNC_001692
FUNC_001692:
mov eax,60
mov edi,105
syscall
.section .text
.global FUNC_001715
FUNC_001715:
mov eax,60
mov edi,106
syscall
.section .text
.global FUNC_001716
FUNC_001716:
mov eax,60
mov edi,107
syscall
.section .text
.global FUNC_001835
FUNC_001835:
mov eax,60
mov edi,108
syscall
.section .text
.global FUNC_001840
FUNC_001840:
mov eax,60
mov edi,109
syscall
.section .text
.global FUNC_001842
FUNC_001842:
mov eax,60
mov edi,110
syscall
.section .text
.global FUNC_001844
FUNC_001844:
mov eax,60
mov edi,111
syscall
.section .text
.global FUNC_001845
FUNC_001845:
mov eax,60
mov edi,112
syscall
.section .text
.global FUNC_001847
FUNC_001847:
mov eax,60
mov edi,113
syscall
.section .text
.global FUNC_001877
FUNC_001877:
mov eax,60
mov edi,114
syscall
.section .text
.global _abs
_abs:
push rbp
mov rbp,rsp
mov eax,DWORD PTR [rbp+16]
test eax,eax
jge source_abs_positive
mov edx,eax
neg edx
jmp source_abs_return
source_abs_positive:
mov edx,eax
source_abs_return:
mov eax,edx
pop rbp
ret
.section .text
.global _memcpy
_memcpy:
mov eax,60
mov edi,115
syscall
