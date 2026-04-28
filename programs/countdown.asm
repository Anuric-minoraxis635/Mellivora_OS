; countdown.asm - Countdown timer with finishing beep
;
; Usage:
;   countdown <seconds>
;   countdown <minutes>m
;   countdown <minutes>:<seconds>

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle usage_err

        mov esi, argbuf
.skipws:
        mov al, [esi]
        cmp al, ' '
        je .ws
        cmp al, 9
        je .ws
        jmp .parse
.ws:
        inc esi
        jmp .skipws
.parse:
        cmp byte [esi], 0
        je usage_err

        ; Parse first number
        xor eax, eax
.d1:
        mov bl, [esi]
        cmp bl, '0'
        jb .e1
        cmp bl, '9'
        ja .e1
        sub bl, '0'
        movzx ecx, bl
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .d1
.e1:
        mov [n1], eax
        mov al, [esi]
        cmp al, ':'
        je .colon
        cmp al, 'm'
        je .min
        cmp al, 'M'
        je .min
        ; Plain seconds
        mov eax, [n1]
        mov [secs], eax
        jmp .ready
.min:
        mov eax, [n1]
        mov ebx, 60
        mul ebx
        mov [secs], eax
        jmp .ready
.colon:
        inc esi
        xor eax, eax
.d2:
        mov bl, [esi]
        cmp bl, '0'
        jb .e2
        cmp bl, '9'
        ja .e2
        sub bl, '0'
        movzx ecx, bl
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .d2
.e2:
        mov ecx, [n1]
        mov ebx, 60
        push eax
        mov eax, ecx
        mul ebx
        pop ecx
        add eax, ecx
        mov [secs], eax

.ready:
        cmp dword [secs], 0
        jle usage_err

        mov eax, SYS_PRINT
        mov ebx, msg_start
        int 0x80
        mov eax, [secs]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, msg_secs
        int 0x80

        mov ecx, [secs]
.loop:
        test ecx, ecx
        jz .doneloop
        ; Print remaining
        push ecx
        mov eax, SYS_PRINT
        mov ebx, str_t
        int 0x80
        mov eax, ecx
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_left
        int 0x80
        ; sleep 1s
        mov eax, SYS_SLEEP
        mov ebx, 100
        int 0x80
        pop ecx
        dec ecx
        jmp .loop

.doneloop:
        mov ebp, 4
.bp:
        mov eax, SYS_BEEP
        mov ebx, 1000
        mov ecx, 20
        int 0x80
        mov eax, SYS_SLEEP
        mov ebx, 12
        int 0x80
        dec ebp
        jnz .bp

        mov eax, SYS_PRINT
        mov ebx, msg_done
        int 0x80
        mov eax, SYS_NOTIFY
        mov ebx, notify_msg
        mov edx, 0x4E
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

usage:    db 'usage: countdown <secs> | <min>m | <min>:<secs>', 10, 0
msg_start:db 'countdown: ', 0
msg_secs: db ' seconds', 10, 0
str_t:    db '  ', 0
str_left: db ' ...', 13, 0
msg_done: db 10, 'time!', 10, 0
notify_msg: db 'Countdown finished', 0

argbuf: times 64 db 0
n1:     dd 0
secs:   dd 0
numbuf: times 12 db 0
