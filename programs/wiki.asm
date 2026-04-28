; wiki.asm - Personal knowledge base in /home/wiki/<topic>.txt
;
; Usage:
;   wiki                       list every page
;   wiki list                  list every page
;   wiki show <topic>          print a page
;   wiki <topic>               same as: wiki show <topic>
;   wiki add <topic> <text...> append a line to a page (creates if missing)

%include "syscalls.inc"

PAGE_MAX equ 32768

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        mov esi, argbuf
        call skip_ws
        cmp byte [esi], 0
        je do_list

        mov edi, esi
        call word_end_in_edi
        mov al, [edi]
        mov [savech], al
        mov byte [edi], 0

        ; "list"
        push edi
        mov edi, esi
        push esi
        mov esi, str_list
        call streq_ci
        pop esi
        pop edi
        je do_list

        ; "show"
        push edi
        mov edi, esi
        push esi
        mov esi, str_show
        call streq_ci
        pop esi
        pop edi
        je on_show

        ; "add"
        push edi
        mov edi, esi
        push esi
        mov esi, str_add
        call streq_ci
        pop esi
        pop edi
        je on_add

        ; treat first word as topic (implicit show)
        mov al, [savech]
        mov [edi], al
        mov esi, argbuf
        jmp do_show

on_show:
        mov al, [savech]
        mov [edi], al
        mov esi, edi
        call skip_ws
        cmp byte [esi], 0
        je usage_err
do_show:
        ; build path /home/wiki/<topic>.txt
        call build_path
        mov eax, SYS_FREAD
        mov ebx, path_buf
        mov ecx, page_buf
        int 0x80
        cmp eax, 0
        jle .nf
        ; Null-terminate
        cmp eax, PAGE_MAX
        jb .lt
        mov eax, PAGE_MAX - 1
.lt:
        mov byte [page_buf + eax], 0
        mov eax, SYS_PRINT
        mov ebx, page_buf
        int 0x80
        ; Trailing newline if missing
        xor ebx, ebx
        jmp exit_app
.nf:
        mov eax, SYS_PRINT
        mov ebx, msg_nopage
        int 0x80
        mov ebx, 1
        jmp exit_app

on_add:
        mov al, [savech]
        mov [edi], al
        mov esi, edi
        call skip_ws
        cmp byte [esi], 0
        je usage_err

        ; topic = next word
        mov edi, esi
        call word_end_in_edi
        mov al, [edi]
        mov [savech2], al
        mov byte [edi], 0

        ; build path
        call build_path

        ; restore + advance to body
        mov al, [savech2]
        mov [edi], al
        mov esi, edi
        call skip_ws
        cmp byte [esi], 0
        je usage_err

        ; Load existing
        mov eax, SYS_FREAD
        mov ebx, path_buf
        mov ecx, page_buf
        int 0x80
        cmp eax, 0
        jge .lh
        xor eax, eax
.lh:
        cmp eax, PAGE_MAX - 256
        jbe .keep
        mov eax, PAGE_MAX - 256
.keep:
        mov [page_len], eax

        ; Append body + newline
        mov edi, page_buf
        add edi, [page_len]
.cp:
        mov al, [esi]
        test al, al
        jz .nl
        mov [edi], al
        inc esi
        inc edi
        jmp .cp
.nl:
        mov byte [edi], 10
        inc edi
        sub edi, page_buf
        mov [page_len], edi

        mov eax, SYS_FWRITE
        mov ebx, path_buf
        mov ecx, page_buf
        mov edx, [page_len]
        xor esi, esi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_added
        int 0x80
        xor ebx, ebx
        jmp exit_app

do_list:
        mov eax, SYS_PRINT
        mov ebx, msg_listhdr
        int 0x80
        ; Best-effort: try a small set of common page names. Without an
        ; opendir() syscall in this profile we simply tell the user where
        ; pages live.
        mov eax, SYS_PRINT
        mov ebx, msg_listinfo
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

;-----------------------------------
build_path:
        ; Topic at [esi] (null-terminated, no spaces). Build /home/wiki/<topic>.txt
        push esi
        push edi
        ; copy prefix
        mov edi, path_buf
        mov ecx, esi
        mov esi, prefix
.cp1:
        mov al, [esi]
        test al, al
        jz .pdone
        mov [edi], al
        inc esi
        inc edi
        jmp .cp1
.pdone:
        ; copy topic (saved in ecx)
        mov esi, ecx
.cp2:
        mov al, [esi]
        test al, al
        jz .topdone
        mov [edi], al
        inc esi
        inc edi
        jmp .cp2
.topdone:
        ; append .txt
        mov dword [edi], '.txt'
        mov byte [edi+4], 0
        pop edi
        pop esi
        ret

skip_ws:
.l:
        mov al, [esi]
        cmp al, ' '
        je .a
        cmp al, 9
        je .a
        ret
.a:
        inc esi
        jmp .l

word_end_in_edi:
        mov edi, esi
.l:
        mov al, [edi]
        test al, al
        jz .d
        cmp al, ' '
        je .d
        cmp al, 9
        je .d
        cmp al, 10
        je .d
        cmp al, 13
        je .d
        inc edi
        jmp .l
.d:
        ret

streq_ci:
.l:
        mov al, [esi]
        mov ah, [edi]
        cmp al, 'A'
        jb .a1
        cmp al, 'Z'
        ja .a1
        add al, 32
.a1:
        cmp ah, 'A'
        jb .a2
        cmp ah, 'Z'
        ja .a2
        add ah, 32
.a2:
        cmp al, ah
        jne .ne
        test al, al
        jz .eq
        inc esi
        inc edi
        jmp .l
.eq:
        xor al, al
        ret
.ne:
        or al, 1
        cmp al, 0
        ret

;-----------------------------------
prefix:     db '/home/wiki/', 0
str_list:   db 'list', 0
str_show:   db 'show', 0
str_add:    db 'add', 0
msg_nopage: db 'wiki: page not found.', 10, 0
msg_added:  db 'wiki: appended.', 10, 0
msg_listhdr: db 'wiki: pages live in /home/wiki/<topic>.txt', 10, 0
msg_listinfo: db '       use:  ls /home/wiki    to enumerate them.', 10, 0
usage:
        db 'usage:', 10
        db '  wiki list                  list pages', 10
        db '  wiki show <topic>          read a page', 10
        db '  wiki <topic>               same as show', 10
        db '  wiki add <topic> <text>    append a line', 10, 0

argbuf:    times 1024 db 0
savech:    db 0
savech2:   db 0
path_buf:  times 320 db 0
page_len:  dd 0
page_buf:  times PAGE_MAX db 0
