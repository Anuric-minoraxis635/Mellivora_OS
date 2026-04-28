; stopwatch.asm - Simple lap stopwatch
; Press Enter to lap, q to quit. Time is shown in HH:MM:SS.cc (centiseconds).

%include "syscalls.inc"

start:
        mov eax, SYS_CLEAR
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, banner
        int 0x80

        mov eax, SYS_GETTIME
        int 0x80
        mov [start_t], eax
        mov [last_t], eax
        mov dword [lap_n], 0

        mov eax, SYS_PRINT
        mov ebx, msg_ready
        int 0x80

.loop:
        mov eax, SYS_GETCHAR
        int 0x80
        cmp al, 'q'
        je .done
        cmp al, 'Q'
        je .done
        cmp al, 27
        je .done

        ; lap
        inc dword [lap_n]
        mov eax, SYS_GETTIME
        int 0x80
        mov [now_t], eax

        mov eax, SYS_PRINT
        mov ebx, str_lap
        int 0x80
        mov eax, [lap_n]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_split
        int 0x80
        mov eax, [now_t]
        sub eax, [last_t]
        call print_time
        mov eax, SYS_PRINT
        mov ebx, str_total
        int 0x80
        mov eax, [now_t]
        sub eax, [start_t]
        call print_time
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80

        mov eax, [now_t]
        mov [last_t], eax
        jmp .loop

.done:
        mov eax, SYS_PRINT
        mov ebx, msg_bye
        int 0x80
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; Print EAX = ticks (100Hz) as HH:MM:SS.cc
print_time:
        push ebx
        push ecx
        push edx
        ; cs = eax % 100
        xor edx, edx
        mov ecx, 100
        div ecx              ; eax=secs total, edx=cs
        mov [tmp_cs], edx
        ; secs split
        xor edx, edx
        mov ecx, 60
        div ecx              ; eax=minutes total, edx=secs
        mov [tmp_s], edx
        xor edx, edx
        mov ecx, 60
        div ecx              ; eax=hours, edx=minutes
        mov [tmp_m], edx
        mov [tmp_h], eax

        mov eax, [tmp_h]
        call print_2
        mov eax, SYS_PUTCHAR
        mov ebx, ':'
        int 0x80
        mov eax, [tmp_m]
        call print_2
        mov eax, SYS_PUTCHAR
        mov ebx, ':'
        int 0x80
        mov eax, [tmp_s]
        call print_2
        mov eax, SYS_PUTCHAR
        mov ebx, '.'
        int 0x80
        mov eax, [tmp_cs]
        call print_2
        pop edx
        pop ecx
        pop ebx
        ret

print_2:
        push ebx
        push ecx
        push edx
        xor edx, edx
        mov ecx, 10
        div ecx
        add al, '0'
        add dl, '0'
        mov [pad2], al
        mov [pad2+1], dl
        mov byte [pad2+2], 0
        mov eax, SYS_PRINT
        mov ebx, pad2
        int 0x80
        pop edx
        pop ecx
        pop ebx
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

;-----------------------------------
banner:    db 'stopwatch - press Enter for a lap, q to quit', 10, 10, 0
msg_ready: db 'started.', 10, 0
msg_bye:   db 10, 'stopped.', 10, 0
str_lap:   db 'lap ', 0
str_split: db ': split ', 0
str_total: db ', total ', 0

start_t: dd 0
last_t:  dd 0
now_t:   dd 0
lap_n:   dd 0
tmp_cs:  dd 0
tmp_s:   dd 0
tmp_m:   dd 0
tmp_h:   dd 0
pad2:    times 4 db 0
numbuf:  times 12 db 0
