; histgrep.asm - Search shell history for a pattern
; Suggestion #3: Shell UX. Until reverse-i-search lands in the shell itself,
; this gives an explicit `histgrep <kw>` for the same workflow.
;
; Tries /home/.history and /etc/.history; case-insensitive substring match.

%include "syscalls.inc"

BUF_MAX equ 32768

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle .usage

        ; Lower-case the keyword
        mov esi, argbuf
        mov edi, kwbuf
.lc:
        lodsb
        test al, al
        jz .lc_done
        cmp al, 10
        je .lc_done
        cmp al, 13
        je .lc_done
        cmp al, ' '
        je .lc_done
        cmp al, 'A'
        jb .st
        cmp al, 'Z'
        ja .st
        add al, 32
.st:
        stosb
        jmp .lc
.lc_done:
        mov byte [edi], 0
        cmp byte [kwbuf], 0
        je .usage

        ; Try /home/.history first
        mov eax, SYS_FREAD
        mov ebx, p_home
        mov ecx, filebuf
        int 0x80
        cmp eax, 0
        jg .have

        mov eax, SYS_FREAD
        mov ebx, p_etc
        mov ecx, filebuf
        int 0x80
        cmp eax, 0
        jg .have

        mov eax, SYS_PRINT
        mov ebx, msg_no_hist
        int 0x80
        mov ebx, 1
        jmp .exit

.have:
        mov byte [filebuf + eax], 0
        mov esi, filebuf
.line_loop:
        cmp byte [esi], 0
        je .done
        ; Find end of line
        mov ebx, esi            ; line start
.find_eol:
        mov al, [esi]
        test al, al
        jz .check
        cmp al, 10
        je .check
        inc esi
        jmp .find_eol
.check:
        ; Temporarily NUL-terminate
        mov dl, [esi]
        mov byte [esi], 0
        ; Case-insensitive substring search of EBX for kwbuf
        push esi
        push edx
        mov edi, kwbuf
        call istr_contains
        pop edx
        pop esi
        jne .skip
        ; Print the line
        push esi
        push edx
        mov eax, SYS_PRINT
        ; ebx still holds line ptr
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        pop edx
        pop esi
.skip:
        mov [esi], dl
        cmp byte [esi], 0
        je .done
        inc esi
        jmp .line_loop
.done:
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

;-----------------------------------
; istr_contains - haystack EBX contains needle EDI? ZF=1 if yes
;-----------------------------------
istr_contains:
        push ebx
        push edi
        push esi
.outer:
        mov al, [ebx]
        test al, al
        jz .ne
        mov esi, ebx
        mov edi, kwbuf
.inner:
        mov ah, [edi]
        test ah, ah
        jz .hit
        mov al, [esi]
        test al, al
        jz .miss
        cmp al, 'A'
        jb .ck
        cmp al, 'Z'
        ja .ck
        add al, 32
.ck:
        cmp al, ah
        jne .miss
        inc esi
        inc edi
        jmp .inner
.miss:
        inc ebx
        jmp .outer
.hit:
        pop esi
        pop edi
        pop ebx
        xor al, al
        ret
.ne:
        pop esi
        pop edi
        pop ebx
        or al, 1
        cmp al, 0
        ret

p_home:    db '/home/.history', 0
p_etc:     db '/etc/.history', 0
msg_no_hist: db 'histgrep: no history file found.', 10, 0
msg_usage:   db 'usage: histgrep <keyword>', 10, 0

argbuf:   times 256 db 0
kwbuf:    times 256 db 0
filebuf:  times BUF_MAX + 1 db 0
