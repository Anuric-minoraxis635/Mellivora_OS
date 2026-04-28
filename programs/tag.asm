; tag.asm - Lightweight file tagging (HBFS xattr surrogate)
; Suggestion #2: filesystem metadata.
;
; Usage:
;   tag add <file> <tag>     append "<file>:<tag>" to /home/.tags.db
;   tag list                 print all tag entries
;   tag find <tag>           print files whose tags contain <tag>
;
; A pragmatic, userspace-only implementation: no kernel changes, no risk to
; the regression baseline. Database lives in /home/.tags.db so it persists
; in the user's home directory.

%include "syscalls.inc"

DB_MAX equ 16384

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle .usage

        mov esi, argbuf
        mov edi, kw_add
        call str_starts
        je .do_add
        mov esi, argbuf
        mov edi, kw_list
        call str_starts
        je .do_list
        mov esi, argbuf
        mov edi, kw_find
        call str_starts
        je .do_find
        jmp .usage

;-----------------------------------
.do_add:
        ; Skip "add " then read <file> <tag>
        mov esi, argbuf
        add esi, 3
        call skip_ws
        mov edi, file_buf
        call copy_word
        call skip_ws
        mov edi, tag_buf
        call copy_word
        cmp byte [file_buf], 0
        je .usage
        cmp byte [tag_buf], 0
        je .usage
        ; Load existing DB (ignore errors)
        mov eax, SYS_FREAD
        mov ebx, db_path
        mov ecx, dbbuf
        int 0x80
        mov edi, dbbuf
        cmp eax, 0
        jge .have_size
        xor eax, eax
.have_size:
        add edi, eax
        ; Append "<file>:<tag>\n"
        mov esi, file_buf
        call append_str
        mov al, ':'
        stosb
        mov esi, tag_buf
        call append_str
        mov al, 10
        stosb
        ; Compute new size
        mov ecx, edi
        sub ecx, dbbuf
        mov eax, SYS_FWRITE
        mov ebx, db_path
        mov edx, ecx
        mov ecx, dbbuf
        xor esi, esi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_added
        int 0x80
        xor ebx, ebx
        jmp .exit

.do_list:
        mov eax, SYS_FREAD
        mov ebx, db_path
        mov ecx, dbbuf
        int 0x80
        cmp eax, 0
        jle .empty
        mov byte [dbbuf + eax], 0
        mov eax, SYS_PRINT
        mov ebx, dbbuf
        int 0x80
        xor ebx, ebx
        jmp .exit

.do_find:
        mov esi, argbuf
        add esi, 4              ; past "find"
        call skip_ws
        cmp byte [esi], 0
        je .usage
        mov edi, tag_buf
        call copy_word
        mov eax, SYS_FREAD
        mov ebx, db_path
        mov ecx, dbbuf
        int 0x80
        cmp eax, 0
        jle .empty
        mov byte [dbbuf + eax], 0

        ; For each line "file:tag", if tag matches print "file"
        mov esi, dbbuf
.fl:
        cmp byte [esi], 0
        je .fl_done
        mov ebx, esi            ; line start
.scan_colon:
        mov al, [esi]
        test al, al
        jz .fl_done
        cmp al, 10
        je .next
        cmp al, ':'
        je .at_colon
        inc esi
        jmp .scan_colon
.at_colon:
        ; Tag begins at ESI+1, runs until \n or 0
        mov edx, esi            ; remember colon
        inc esi
        mov edi, tag_buf
        call cmp_until_nl       ; ZF if tag matches and same length
        jne .skip_line
        ; Print file name (ebx..edx-1) followed by newline
        mov al, [edx]
        push eax
        mov byte [edx], 0
        push edx
        mov eax, SYS_PRINT
        ; ebx already file ptr
        int 0x80
        pop edx
        pop eax
        mov [edx], al
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
.skip_line:
        ; advance to next newline
.adv:
        mov al, [esi]
        test al, al
        jz .fl_done
        inc esi
        cmp al, 10
        jne .adv
        jmp .fl
.next:
        inc esi
        jmp .fl
.fl_done:
        xor ebx, ebx
        jmp .exit

.empty:
        mov eax, SYS_PRINT
        mov ebx, msg_empty
        int 0x80
        xor ebx, ebx
        jmp .exit

.usage:
        mov eax, SYS_PRINT
        mov ebx, usage_msg
        int 0x80
        mov ebx, 1
.exit:
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; Helpers
;-----------------------------------
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

copy_word:
        ; Copy non-whitespace chars from ESI to EDI, NUL-terminate.
.l:
        mov al, [esi]
        test al, al
        jz .d
        cmp al, ' '
        je .d
        cmp al, 9
        je .d
        cmp al, 10
        je .d
        stosb
        inc esi
        jmp .l
.d:
        mov byte [edi], 0
        ret

append_str:
        ; ESI -> EDI until ESI hits NUL
.l:
        lodsb
        test al, al
        jz .d
        stosb
        jmp .l
.d:
        ret

str_starts:
        ; ZF set if ESI starts with EDI (NUL-terminated needle)
        push esi
        push edi
.l:
        mov al, [edi]
        test al, al
        jz .eq
        mov ah, [esi]
        cmp al, ah
        jne .ne
        inc esi
        inc edi
        jmp .l
.eq:
        pop edi
        pop esi
        xor al, al
        ret
.ne:
        pop edi
        pop esi
        or al, 1
        cmp al, 0
        ret

cmp_until_nl:
        ; Compare ESI (haystack, until \n or 0) against EDI (needle NUL-terminated)
        ; ZF set if the haystack run equals needle.
        push esi
        push edi
.l:
        mov ah, [edi]
        mov al, [esi]
        ; needle end?
        test ah, ah
        jz .needle_end
        ; haystack end?
        test al, al
        jz .ne
        cmp al, 10
        je .ne
        cmp al, ah
        jne .ne
        inc esi
        inc edi
        jmp .l
.needle_end:
        ; haystack must also be at end of word
        test al, al
        jz .eq
        cmp al, 10
        je .eq
.ne:
        pop edi
        pop esi
        or al, 1
        cmp al, 0
        ret
.eq:
        pop edi
        pop esi
        xor al, al
        ret

kw_add:    db 'add', 0
kw_list:   db 'list', 0
kw_find:   db 'find', 0
db_path:   db '/home/.tags.db', 0
msg_added: db 'tag: added.', 10, 0
msg_empty: db 'tag: no tags yet.', 10, 0
usage_msg:
        db 'usage:', 10
        db '  tag add <file> <tag>   record a tag for a file', 10
        db '  tag list               show every tag entry', 10
        db '  tag find <tag>         list files with a tag', 10, 0

argbuf:    times 512 db 0
file_buf:  times 256 db 0
tag_buf:   times 128 db 0
dbbuf:     times DB_MAX + 1 db 0
