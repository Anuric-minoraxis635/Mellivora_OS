; bnotify.asm - Fire a desktop notification from the shell
; Suggestion #4: Burrows GUI - notification daemon front-end.
;
; Usage: bnotify [-c color] <message>
;   -c color  attribute byte in hex/decimal (default 0x0E = bright yellow)

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle .usage

        mov esi, argbuf
        mov dword [color], 0x0E

        ; Optional "-c <num>"
        cmp byte [esi], '-'
        jne .have_msg
        inc esi
        cmp byte [esi], 'c'
        jne .usage
        inc esi
        ; skip space(s)
.sp:
        mov al, [esi]
        cmp al, ' '
        je .a
        cmp al, 9
        je .a
        jmp .num
.a:
        inc esi
        jmp .sp
.num:
        ; parse number (decimal, or 0xHH)
        xor eax, eax
        cmp byte [esi], '0'
        jne .dec
        inc esi
        cmp byte [esi], 'x'
        jne .dec_after_zero
        inc esi
.hex:
        mov bl, [esi]
        test bl, bl
        jz .num_done
        cmp bl, ' '
        je .num_done
        cmp bl, '0'
        jb .num_done
        cmp bl, '9'
        jbe .hd
        cmp bl, 'a'
        jb .upper
        cmp bl, 'f'
        ja .num_done
        sub bl, 'a' - 10
        jmp .hadd
.upper:
        cmp bl, 'A'
        jb .num_done
        cmp bl, 'F'
        ja .num_done
        sub bl, 'A' - 10
        jmp .hadd
.hd:
        sub bl, '0'
.hadd:
        shl eax, 4
        movzx ebx, bl
        or eax, ebx
        inc esi
        jmp .hex
.dec_after_zero:
        ; "0" alone is fine - eax already 0
.dec:
        mov bl, [esi]
        test bl, bl
        jz .num_done
        cmp bl, ' '
        je .num_done
        cmp bl, '0'
        jb .num_done
        cmp bl, '9'
        ja .num_done
        sub bl, '0'
        imul eax, eax, 10
        movzx ebx, bl
        add eax, ebx
        inc esi
        jmp .dec
.num_done:
        mov [color], eax
.skip_sp:
        mov al, [esi]
        cmp al, ' '
        je .skip_sp_inc
        cmp al, 9
        je .skip_sp_inc
        jmp .have_msg
.skip_sp_inc:
        inc esi
        jmp .skip_sp

.have_msg:
        cmp byte [esi], 0
        je .usage
        mov eax, SYS_NOTIFY
        mov ebx, esi
        mov edx, [color]
        int 0x80
        xor ebx, ebx
        jmp .exit

.usage:
        mov eax, SYS_PRINT
        mov ebx, msg_usage
        int 0x80
        mov ebx, 1
.exit:
        mov eax, SYS_EXIT
        int 0x80

msg_usage:
        db 'usage: bnotify [-c color] <message>', 10
        db '  color = attr byte (default 0x0E)', 10, 0

color:    dd 0
argbuf:   times 512 db 0
