; mkprog.asm - Generate a hello-world template .asm file
; Suggestion #8: Developer tooling. Lowers the floor for new contributors.
;
; Usage: mkprog <name>
;        Creates ./<name>.asm with a runnable Mellivora program skeleton.

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
        jz .build_path
        cmp al, ' '
        je .cut
        cmp al, 9
        je .cut
        cmp al, 10
        je .cut
        inc esi
        jmp .trim
.cut:
        mov byte [esi], 0
.build_path:
        cmp byte [argbuf], 0
        je .usage

        ; Build "<name>.asm"
        mov esi, argbuf
        mov edi, path
.cp:
        lodsb
        test al, al
        jz .pdone
        stosb
        jmp .cp
.pdone:
        mov dword [edi], '.asm'
        mov byte [edi + 4], 0

        ; Compose template body in tmpl_buf, substituting the name where
        ; "@@NAME@@" appears.
        mov esi, template
        mov edi, tmpl_buf
.exp:
        mov al, [esi]
        test al, al
        jz .exp_done
        cmp al, '@'
        jne .copy
        cmp byte [esi + 1], '@'
        jne .copy
        cmp byte [esi + 2], 'N'
        jne .copy
        cmp byte [esi + 3], 'A'
        jne .copy
        cmp byte [esi + 4], 'M'
        jne .copy
        cmp byte [esi + 5], 'E'
        jne .copy
        cmp byte [esi + 6], '@'
        jne .copy
        cmp byte [esi + 7], '@'
        jne .copy
        ; Substitute name
        add esi, 8
        push esi
        mov esi, argbuf
.sub:
        lodsb
        test al, al
        jz .sub_done
        stosb
        jmp .sub
.sub_done:
        pop esi
        jmp .exp
.copy:
        movsb
        jmp .exp
.exp_done:
        mov ecx, edi
        sub ecx, tmpl_buf

        mov eax, SYS_FWRITE
        mov ebx, path
        mov edx, ecx
        mov ecx, tmpl_buf
        xor esi, esi
        int 0x80
        cmp eax, 0
        jl .write_err

        mov eax, SYS_PRINT
        mov ebx, msg_ok
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, path
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_ok2
        int 0x80
        xor ebx, ebx
        jmp .exit

.write_err:
        mov eax, SYS_PRINT
        mov ebx, msg_err
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
template:
        db '; @@NAME@@.asm - one-line description here', 10
        db '; Build with: asm @@NAME@@.asm', 10, 10
        db '%include "syscalls.inc"', 10, 10
        db 'start:', 10
        db '        mov eax, SYS_PRINT', 10
        db '        mov ebx, msg', 10
        db '        int 0x80', 10, 10
        db '        xor ebx, ebx', 10
        db '        mov eax, SYS_EXIT', 10
        db '        int 0x80', 10, 10
        db 'msg:    db "Hello from @@NAME@@!", 10, 0', 10, 0

msg_usage: db 'usage: mkprog <name>', 10, 0
msg_ok:    db 'wrote ', 0
msg_ok2:   db 10, "edit it, then 'asm <name>.asm' to build.", 10, 0
msg_err:   db 'mkprog: write failed', 10, 0

argbuf:   times 128 db 0
path:     times 144 db 0
tmpl_buf: times 1024 db 0
