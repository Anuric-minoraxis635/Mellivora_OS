; passgen.asm - Generate a random password
;
; Usage:
;   passgen [<length>] [-a]
;     length  4..64 (default 16)
;     -a      alphanumeric only (no symbols)

%include "syscalls.inc"

DEFAULT_LEN equ 16
MIN_LEN     equ 4
MAX_LEN     equ 64

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        mov dword [plen], DEFAULT_LEN
        mov byte [alnum], 0

        mov esi, argbuf
.next:
        ; skip ws
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
        je .done_args
        cmp byte [esi], '-'
        jne .num
        cmp byte [esi+1], 'a'
        jne .skip_tok
        mov byte [alnum], 1
        add esi, 2
        jmp .next
.num:
        cmp byte [esi], '0'
        jb .skip_tok
        cmp byte [esi], '9'
        ja .skip_tok
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
        mov [plen], eax
        jmp .next
.skip_tok:
        ; advance past current token
.st:
        mov al, [esi]
        test al, al
        jz .done_args
        cmp al, ' '
        je .next
        inc esi
        jmp .st

.done_args:
        ; Clamp length
        mov eax, [plen]
        cmp eax, MIN_LEN
        jge .nl
        mov eax, MIN_LEN
.nl:
        cmp eax, MAX_LEN
        jle .nh
        mov eax, MAX_LEN
.nh:
        mov [plen], eax

        ; Seed PRNG from time + PID
        mov eax, SYS_GETTIME
        int 0x80
        mov [seed], eax
        mov eax, SYS_GETPID
        int 0x80
        xor [seed], eax
        mov eax, [seed]
        test eax, eax
        jnz .seeded
        mov dword [seed], 0xC0FFEE01
.seeded:

        ; Generate
        mov ecx, [plen]
        xor edi, edi
.gen:
        test ecx, ecx
        jz .out
        call rand
        ; Pick alphabet
        cmp byte [alnum], 0
        jne .alpha_only
        ; full = 26+26+10+14 = 76
        mov ebx, 76
        xor edx, edx
        div ebx
        mov ebx, edx
        mov al, [chars_full + ebx]
        jmp .put
.alpha_only:
        mov ebx, 62
        xor edx, edx
        div ebx
        mov ebx, edx
        mov al, [chars_alnum + ebx]
.put:
        mov [outbuf + edi], al
        inc edi
        dec ecx
        jmp .gen
.out:
        mov byte [outbuf + edi], 10
        mov byte [outbuf + edi + 1], 0
        mov eax, SYS_PRINT
        mov ebx, outbuf
        int 0x80

        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; xorshift32 PRNG, EAX = next random
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

;-----------------------------------
chars_alnum:
        db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
chars_full:
        db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
        db '!@#$%^&*-_=+?/'

argbuf:  times 64 db 0
plen:    dd 0
alnum:   db 0
seed:    dd 0
outbuf:  times 80 db 0
