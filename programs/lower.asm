; lower.asm - Lowercase the argument string
%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        mov esi, argbuf
.l:     mov al, [esi]
        test al, al
        jz .nl
        cmp al, 'A'
        jb .pr
        cmp al, 'Z'
        ja .pr
        add al, 32
.pr:
        movzx ebx, al
        push esi
        mov eax, SYS_PUTCHAR
        int 0x80
        pop esi
        inc esi
        jmp .l
.nl:
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

argbuf: times 512 db 0
