; pomodoro.asm - 25-minute work timer with beep on completion
;
; Usage: pomodoro [<minutes>]    default 25 minutes

%include "syscalls.inc"

DEFAULT_MIN equ 25

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

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
        xor eax, eax
        xor ecx, ecx
        cmp byte [esi], 0
        je .default
        cmp byte [esi], '0'
        jb .default
        cmp byte [esi], '9'
        ja .default
.dig:
        mov cl, [esi]
        cmp cl, '0'
        jb .pdone
        cmp cl, '9'
        ja .pdone
        sub cl, '0'
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .dig
.default:
        mov eax, DEFAULT_MIN
.pdone:
        test eax, eax
        jnz .ok
        mov eax, DEFAULT_MIN
.ok:
        mov [minutes], eax

        ; Banner
        mov eax, SYS_PRINT
        mov ebx, banner
        int 0x80
        mov eax, [minutes]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, banner_b
        int 0x80

        ; Loop minutes
        mov ecx, [minutes]
.loop:
        test ecx, ecx
        jz .doneloop
        push ecx
        ; Print remaining
        mov eax, SYS_PRINT
        mov ebx, str_left
        int 0x80
        mov eax, ecx
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_min
        int 0x80
        ; Sleep 60 seconds = 6000 ticks at 100Hz; chunk into 1-second waits
        mov edx, 60
.sec:
        mov eax, SYS_SLEEP
        mov ebx, 100
        int 0x80
        dec edx
        jnz .sec
        pop ecx
        dec ecx
        jmp .loop

.doneloop:
        ; Three short beeps
        mov ebp, 3
.bp:
        mov eax, SYS_BEEP
        mov ebx, 880
        mov ecx, 25
        int 0x80
        mov eax, SYS_SLEEP
        mov ebx, 15
        int 0x80
        dec ebp
        jnz .bp

        mov eax, SYS_PRINT
        mov ebx, str_done
        int 0x80

        ; Notify
        mov eax, SYS_NOTIFY
        mov ebx, notify_msg
        mov edx, 0x0E
        int 0x80

        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
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

banner:     db 'pomodoro: focus session for ', 0
banner_b:   db ' minutes. Take a 5-min break afterwards.', 10, 0
str_left:   db '  ', 0
str_min:    db ' minute(s) remaining...', 10, 0
str_done:   db 10, 'pomodoro: time! great work.', 10, 0
notify_msg: db 'Pomodoro complete - take a break!', 0

argbuf:   times 64 db 0
minutes:  dd 0
numbuf:   times 12 db 0
