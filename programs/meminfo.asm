; meminfo.asm - Print kernel memory and uptime info
; Suggestion #1: Kernel & runtime visibility.

%include "syscalls.inc"

PAGE_KB equ 4

start:
        mov eax, SYS_MEMINFO
        int 0x80
        mov [free_pages], eax
        mov [boot_pages], ebx

        mov eax, SYS_GETTIME
        int 0x80
        mov [ticks], eax

        mov eax, SYS_GETPID
        int 0x80
        mov [pid], eax

        mov eax, SYS_PRINT
        mov ebx, hdr
        int 0x80

        ; Free memory
        mov eax, SYS_PRINT
        mov ebx, lbl_free
        int 0x80
        mov eax, [free_pages]
        mov ecx, PAGE_KB
        mul ecx
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_kb
        int 0x80

        ; Boot-time free
        mov eax, SYS_PRINT
        mov ebx, lbl_boot
        int 0x80
        mov eax, [boot_pages]
        mov ecx, PAGE_KB
        mul ecx
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_kb
        int 0x80

        ; Used = boot - free
        mov eax, SYS_PRINT
        mov ebx, lbl_used
        int 0x80
        mov eax, [boot_pages]
        sub eax, [free_pages]
        mov ecx, PAGE_KB
        mul ecx
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_kb
        int 0x80

        ; Uptime
        mov eax, SYS_PRINT
        mov ebx, lbl_up
        int 0x80
        mov eax, [ticks]
        mov ecx, 100
        xor edx, edx
        div ecx                 ; EAX = total seconds
        mov esi, eax
        ; HH
        xor edx, edx
        mov ecx, 3600
        div ecx
        call print_pad2
        mov eax, SYS_PUTCHAR
        mov ebx, ':'
        int 0x80
        mov eax, edx
        xor edx, edx
        mov ecx, 60
        div ecx
        call print_pad2
        mov eax, SYS_PUTCHAR
        mov ebx, ':'
        int 0x80
        mov eax, edx
        call print_pad2
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80

        ; PID
        mov eax, SYS_PRINT
        mov ebx, lbl_pid
        int 0x80
        mov eax, [pid]
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80

        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; print_uint - decimal print of EAX
;-----------------------------------
print_uint:
        push ebx
        push ecx
        push edx
        push edi
        mov edi, numbuf + 15
        mov byte [edi], 0
        mov ebx, 10
        test eax, eax
        jnz .l
        dec edi
        mov byte [edi], '0'
        jmp .out
.l:
        xor edx, edx
        div ebx
        add dl, '0'
        dec edi
        mov [edi], dl
        test eax, eax
        jnz .l
.out:
        mov eax, SYS_PRINT
        mov ebx, edi
        int 0x80
        pop edi
        pop edx
        pop ecx
        pop ebx
        ret

print_pad2:
        ; print EAX as two-digit zero-padded
        push eax
        cmp eax, 10
        jge .ok
        mov eax, SYS_PUTCHAR
        mov ebx, '0'
        int 0x80
.ok:
        pop eax
        jmp print_uint

hdr:       db 'Mellivora System Memory', 10, '-----------------------', 10, 0
lbl_free:  db 'Free:   ', 0
lbl_boot:  db 'Boot:   ', 0
lbl_used:  db 'Used:   ', 0
lbl_up:    db 'Uptime: ', 0
lbl_pid:   db 'My PID: ', 0
str_kb:    db ' KB', 10, 0

free_pages:  dd 0
boot_pages:  dd 0
ticks:       dd 0
pid:         dd 0
numbuf:      times 16 db 0
