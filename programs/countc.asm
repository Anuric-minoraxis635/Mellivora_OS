; countc.asm - Count chars/words/lines in the argument string
;
; Usage:
;   countc some text here
;   ->  chars: 14  words: 3  lines: 1

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        mov esi, argbuf
        xor ecx, ecx                ; chars
        xor edx, edx                ; words
        mov edi, 1                  ; lines (>=1 if any input, else 0)
        xor ebx, ebx                ; in-word flag
        mov bl, [esi]
        test bl, bl
        jnz .has
        xor edi, edi
.has:
        mov esi, argbuf
        xor ebx, ebx
.l:
        mov al, [esi]
        test al, al
        jz .out
        inc ecx
        cmp al, 10
        jne .nlchk
        inc edi
        xor ebx, ebx
        jmp .next
.nlchk:
        cmp al, ' '
        je .ws
        cmp al, 9
        je .ws
        cmp al, 13
        je .next
        ; word char
        test ebx, ebx
        jnz .next
        inc edx
        mov ebx, 1
        jmp .next
.ws:
        xor ebx, ebx
.next:
        inc esi
        jmp .l
.out:
        mov [n_chars], ecx
        mov [n_words], edx
        mov [n_lines], edi

        mov eax, SYS_PRINT
        mov ebx, s_chars
        int 0x80
        mov eax, [n_chars]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, s_words
        int 0x80
        mov eax, [n_words]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, s_lines
        int 0x80
        mov eax, [n_lines]
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

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

s_chars: db 'chars: ', 0
s_words: db '  words: ', 0
s_lines: db '  lines: ', 0
argbuf:  times 1024 db 0
n_chars: dd 0
n_words: dd 0
n_lines: dd 0
numbuf:  times 12 db 0
