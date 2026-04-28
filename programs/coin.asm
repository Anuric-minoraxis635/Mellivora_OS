; coin.asm - Flip one or more coins
;
; Usage:
;   coin            flip 1
;   coin <N>        flip N coins (1..1000)

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        mov dword [n], 1
        mov esi, argbuf
.sw:
        mov al, [esi]
        cmp al, ' '
        je .swa
        cmp al, 9
        je .swa
        jmp .check
.swa:
        inc esi
        jmp .sw
.check:
        cmp byte [esi], 0
        je .seedit
        xor eax, eax
.dl:
        mov bl, [esi]
        cmp bl, '0'
        jb .ed
        cmp bl, '9'
        ja .ed
        sub bl, '0'
        movzx ecx, bl
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .dl
.ed:
        cmp eax, 1
        jl .seedit
        cmp eax, 1000
        jg .seedit
        mov [n], eax
.seedit:
        mov eax, SYS_GETTIME
        int 0x80
        mov [seed], eax
        mov eax, SYS_GETPID
        int 0x80
        xor [seed], eax
        cmp dword [seed], 0
        jne .ok
        mov dword [seed], 0xCAFEBABE
.ok:

        mov ecx, [n]
        xor edi, edi          ; heads count
.flip:
        test ecx, ecx
        jz .donef
        push ecx
        call rand
        and eax, 1
        jz .tails
        ; heads
        inc edi
        push edi
        mov eax, SYS_PRINT
        mov ebx, str_h
        int 0x80
        pop edi
        jmp .nx
.tails:
        push edi
        mov eax, SYS_PRINT
        mov ebx, str_t
        int 0x80
        pop edi
.nx:
        pop ecx
        dec ecx
        jmp .flip
.donef:
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        ; Show summary if N>1
        cmp dword [n], 1
        jle .out
        mov eax, SYS_PRINT
        mov ebx, str_heads
        int 0x80
        mov eax, edi
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_of
        int 0x80
        mov eax, [n]
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
.out:
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

rand:
        mov eax, [seed]
        mov ebx, eax
        shl ebx, 13
        xor eax, ebx
        mov ebx, eax
        shr ebx, 17
        xor eax, ebx
        mov ebx, eax
        shl ebx, 5
        xor eax, ebx
        mov [seed], eax
        ret

print_uint:
        push ebx
        push ecx
        push edx
        push edi
        mov edi, numbuf + 11
        mov byte [edi], 0
        mov ebx, 10
        test eax, eax
        jnz .l
        dec edi
        mov byte [edi], '0'
        jmp .o
.l:
        xor edx, edx
        div ebx
        add dl, '0'
        dec edi
        mov [edi], dl
        test eax, eax
        jnz .l
.o:
        mov eax, SYS_PRINT
        mov ebx, edi
        int 0x80
        pop edi
        pop edx
        pop ecx
        pop ebx
        ret

str_h:     db 'H ', 0
str_t:     db 'T ', 0
str_heads: db 'heads: ', 0
str_of:    db ' / ', 0

argbuf: times 64 db 0
n:      dd 0
seed:   dd 0
numbuf: times 12 db 0
