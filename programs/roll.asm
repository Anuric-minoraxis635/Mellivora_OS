; roll.asm - Generic random integer in a range
;
; Usage:
;   roll            -> 1..100
;   roll N          -> 1..N
;   roll A B        -> A..B (inclusive)

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        ; seed PRNG: time XOR pid
        mov eax, SYS_GETTIME
        int 0x80
        mov ebx, eax
        mov eax, SYS_GETPID
        int 0x80
        xor eax, ebx
        test eax, eax
        jnz .seedok
        mov eax, 0xC0FFEE03
.seedok:
        mov [seed], eax

        mov esi, argbuf
        call skip_ws
        mov dword [lo], 1
        mov dword [hi], 100
        cmp byte [esi], 0
        je .roll1
        call parse_uint
        mov [hi], eax
        call skip_ws
        cmp byte [esi], 0
        je .roll1
        ; Two-arg: reinterpret prior as lo
        mov ebx, [hi]
        mov [lo], ebx
        call parse_uint
        mov [hi], eax
.roll1:
        mov eax, [lo]
        cmp eax, [hi]
        jg usage_err
        mov eax, [hi]
        sub eax, [lo]
        inc eax                  ; range
        mov [range], eax
        call rand32
        xor edx, edx
        div dword [range]
        add edx, [lo]
        mov eax, edx
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        jmp exit_app

usage_err:
        mov eax, SYS_PRINT
        mov ebx, usage
        int 0x80
        mov ebx, 1
exit_app:
        mov eax, SYS_EXIT
        int 0x80

skip_ws:
.l:     mov al, [esi]
        cmp al, ' '
        je .a
        cmp al, 9
        je .a
        ret
.a:     inc esi
        jmp .l

parse_uint:
        xor eax, eax
.l:     mov bl, [esi]
        cmp bl, '0'
        jb .d
        cmp bl, '9'
        ja .d
        sub bl, '0'
        movzx ecx, bl
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .l
.d:     ret

rand32:
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
.l:     xor edx, edx
        div ebx
        add dl, '0'
        dec edi
        mov [edi], dl
        test eax, eax
        jnz .l
.o:     mov eax, SYS_PRINT
        mov ebx, edi
        int 0x80
        pop edi
        pop edx
        pop ecx
        pop ebx
        ret

usage:  db 'usage: roll [N | A B]   (default 1..100)', 10, 0
argbuf: times 64 db 0
seed:   dd 0
lo:     dd 0
hi:     dd 0
range:  dd 0
numbuf: times 12 db 0
