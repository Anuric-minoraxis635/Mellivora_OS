; reverse.asm - Reverse the argument string and print it
;
; Usage:
;   reverse hello world   ->   "dlrow olleh"

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        ; find length
        mov esi, argbuf
        xor ecx, ecx
.l:     mov al, [esi]
        test al, al
        jz .done
        ; trim trailing newline/cr
        inc ecx
        inc esi
        jmp .l
.done:
        ; strip trailing whitespace
.tt:    test ecx, ecx
        jz .empty
        mov al, [argbuf + ecx - 1]
        cmp al, ' '
        je .pop
        cmp al, 9
        je .pop
        cmp al, 10
        je .pop
        cmp al, 13
        je .pop
        jmp .ok
.pop:
        dec ecx
        jmp .tt
.ok:
        ; print in reverse
.p:     test ecx, ecx
        jz .nl
        dec ecx
        movzx ebx, byte [argbuf + ecx]
        mov eax, SYS_PUTCHAR
        int 0x80
        jmp .p
.nl:
.empty:
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

argbuf: times 512 db 0
