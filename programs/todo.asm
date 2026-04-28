; todo.asm - Persistent todo list
; Storage: /home/.todo, one item per line. Items prefixed with 'x ' are done.
;
; Usage:
;   todo                list all items numbered
;   todo add <text>     add a new item
;   todo done <N>       mark item N done

%include "syscalls.inc"

DB_MAX equ 16384

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        call load_db

        mov esi, argbuf
        call skip_ws
        cmp byte [esi], 0
        je do_list

        mov edi, esi
        call word_end_in_edi
        mov al, [edi]
        mov [savech], al
        mov byte [edi], 0

        push edi
        mov edi, esi
        mov esi, str_add
        call streq_ci
        pop edi
        je on_add

        push edi
        mov edi, argbuf
        mov esi, str_done
        call streq_ci
        pop edi
        je on_done

        mov eax, SYS_PRINT
        mov ebx, usage
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

        mov edi, db_buf
        add edi, [db_len]
.cp:
        mov al, [esi]
        test al, al
        jz .nl
        cmp al, 10
        je .nl
        mov [edi], al
        inc esi
        inc edi
        jmp .cp
.nl:
        mov byte [edi], 10
        inc edi
        sub edi, db_buf
        mov [db_len], edi
        call save_db
        mov eax, SYS_PRINT
        mov ebx, msg_added
        int 0x80
        xor ebx, ebx
        jmp exit_app

on_done:
        mov al, [savech]
        mov [edi], al
        mov esi, edi
        call skip_ws
        call parse_uint
        test eax, eax
        jz usage_err
        mov [target], eax

        mov esi, db_buf
        mov ebx, db_buf
        add ebx, [db_len]
        mov dword [counter], 0
.l:
        cmp esi, ebx
        jae .nf
        inc dword [counter]
        mov eax, [counter]
        cmp eax, [target]
        jne .skip
        cmp byte [esi], 'x'
        jne .insert
        cmp byte [esi+1], ' '
        je .saved
.insert:
        mov edi, db_buf
        add edi, [db_len]
        add edi, 2
        mov ecx, db_buf
        add ecx, [db_len]
.sh:
        cmp ecx, esi
        jbe .si
        dec ecx
        dec edi
        mov al, [ecx]
        mov [edi], al
        jmp .sh
.si:
        mov byte [esi], 'x'
        mov byte [esi+1], ' '
        add dword [db_len], 2
        call save_db
.saved:
        mov eax, SYS_PRINT
        mov ebx, msg_done
        int 0x80
        xor ebx, ebx
        jmp exit_app
.skip:
.sn:
        cmp esi, ebx
        jae .nf
        mov al, [esi]
        inc esi
        cmp al, 10
        jne .sn
        jmp .l
.nf:
        mov eax, SYS_PRINT
        mov ebx, msg_notfound
        int 0x80
        mov ebx, 1
        jmp exit_app

do_list:
        mov esi, db_buf
        mov ebx, db_buf
        add ebx, [db_len]
        cmp esi, ebx
        je .empty
        mov dword [counter], 0
.line:
        cmp esi, ebx
        jae .done
        inc dword [counter]
        mov eax, [counter]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, dot_sp
        int 0x80
        cmp byte [esi], 'x'
        jne .open
        cmp byte [esi+1], ' '
        jne .open
        mov eax, SYS_PRINT
        mov ebx, mark_done
        int 0x80
        add esi, 2
        jmp .body
.open:
        mov eax, SYS_PRINT
        mov ebx, mark_open
        int 0x80
.body:
        mov ebx, db_buf
        add ebx, [db_len]
.cb:
        cmp esi, ebx
        jae .nl
        mov al, [esi]
        cmp al, 10
        je .nlskip
        mov [chrbuf], al
        push esi
        mov eax, SYS_PRINT
        mov ebx, chrbuf
        int 0x80
        pop esi
        inc esi
        jmp .cb
.nlskip:
        inc esi
.nl:
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        jmp .line
.done:
        cmp dword [counter], 0
        jne .ok
.empty:
        mov eax, SYS_PRINT
        mov ebx, msg_empty
        int 0x80
.ok:
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

;===================================
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

parse_uint:
        xor eax, eax
        xor ecx, ecx
.l:
        mov cl, [esi]
        cmp cl, '0'
        jb .d
        cmp cl, '9'
        ja .d
        sub cl, '0'
        imul eax, eax, 10
        add eax, ecx
        inc esi
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

load_db:
        mov eax, SYS_FREAD
        mov ebx, db_path
        mov ecx, db_buf
        int 0x80
        cmp eax, 0
        jge .ok
        xor eax, eax
.ok:
        cmp eax, DB_MAX
        jbe .keep
        mov eax, DB_MAX
.keep:
        mov [db_len], eax
        ret

save_db:
        mov eax, SYS_FWRITE
        mov ebx, db_path
        mov ecx, db_buf
        mov edx, [db_len]
        xor esi, esi
        int 0x80
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
db_path:     db '/home/.todo', 0
str_add:     db 'add', 0
str_done:    db 'done', 0
dot_sp:      db '. ', 0
mark_open:   db '[ ] ', 0
mark_done:   db '[x] ', 0
msg_empty:   db 'todo: list is empty (try: todo add buy honey)', 10, 0
msg_added:   db 'todo: added.', 10, 0
msg_done:    db 'todo: marked done.', 10, 0
msg_notfound:db 'todo: no such item.', 10, 0
usage:
        db 'usage:', 10
        db '  todo                  list items', 10
        db '  todo add <text>       add new item', 10
        db '  todo done <N>         mark item N done', 10, 0

argbuf:  times 512 db 0
savech:  db 0
counter: dd 0
target:  dd 0
chrbuf:  times 2 db 0
numbuf:  times 12 db 0
db_len:  dd 0
db_buf:  times DB_MAX db 0
