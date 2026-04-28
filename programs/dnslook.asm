; dnslook.asm - Resolve a hostname via SYS_DNS
; Suggestion #9: Networking. Tiny CLI exposing the DNS syscall.
;
; Usage: dnslook <hostname>

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle .usage

        ; Trim trailing whitespace
        mov esi, argbuf
.trim:
        mov al, [esi]
        test al, al
        jz .resolve
        cmp al, ' '
        je .cut
        cmp al, 9
        je .cut
        cmp al, 10
        je .cut
        cmp al, 13
        je .cut
        inc esi
        jmp .trim
.cut:
        mov byte [esi], 0
.resolve:
        mov eax, SYS_DNS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jz .fail
        mov [ip], eax

        mov eax, SYS_PRINT
        mov ebx, argbuf
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, sep
        int 0x80
        mov eax, [ip]
        call print_ip
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        jmp .exit

.fail:
        mov eax, SYS_PRINT
        mov ebx, msg_fail
        int 0x80
        mov ebx, 1
        jmp .exit

.usage:
        mov eax, SYS_PRINT
        mov ebx, msg_usage
        int 0x80
        mov ebx, 1
.exit:
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
print_ip:
        ; EAX = packed IP (network byte order assumed: byte0 = first octet)
        push eax
        movzx eax, al
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, '.'
        int 0x80
        pop eax
        push eax
        shr eax, 8
        movzx eax, al
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, '.'
        int 0x80
        pop eax
        push eax
        shr eax, 16
        movzx eax, al
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, '.'
        int 0x80
        pop eax
        shr eax, 24
        movzx eax, al
        call print_uint
        ret

print_uint:
        push ebx
        push ecx
        push edx
        push edi
        mov edi, numbuf + 7
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

sep:        db ' -> ', 0
msg_fail:   db 'dnslook: resolution failed', 10, 0
msg_usage:  db 'usage: dnslook <hostname>', 10, 0

argbuf:   times 256 db 0
ip:       dd 0
numbuf:   times 8 db 0
