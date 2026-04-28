; journal.asm - Simple timestamped daily journal
; Suggestion #11: Productivity. Append entries to /home/journal.txt with
; an ISO date prefix. With no args, prints all entries.
;
; Usage:
;   journal              show every entry
;   journal <text>       append "YYYY-MM-DD HH:MM  <text>" to the journal

%include "syscalls.inc"

JBUF_MAX equ 65536

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle .show

        ; Append entry
        mov eax, SYS_DATE
        mov ebx, date_buf
        int 0x80
        mov [year], eax
        ; Build prefix in line_buf: "YYYY-MM-DD HH:MM  "
        mov edi, line_buf
        mov eax, [year]
        call put_uint4
        mov al, '-'
        stosb
        movzx eax, byte [date_buf + 4]      ; month
        call put_uint2
        mov al, '-'
        stosb
        movzx eax, byte [date_buf + 3]      ; day
        call put_uint2
        mov al, ' '
        stosb
        movzx eax, byte [date_buf + 2]      ; hour
        call put_uint2
        mov al, ':'
        stosb
        movzx eax, byte [date_buf + 1]      ; min
        call put_uint2
        mov al, ' '
        stosb
        mov al, ' '
        stosb
        ; Append message
        mov esi, argbuf
.cp:
        lodsb
        test al, al
        jz .cp_done
        cmp al, 13
        je .cp
        stosb
        jmp .cp
.cp_done:
        mov al, 10
        stosb
        mov ecx, edi
        sub ecx, line_buf

        ; Read existing journal
        mov eax, SYS_FREAD
        mov ebx, j_path
        mov ecx, jbuf
        int 0x80
        cmp eax, 0
        jge .have_old
        xor eax, eax
.have_old:
        mov edi, jbuf
        add edi, eax
        ; Append line_buf
        mov esi, line_buf
.app:
        lodsb
        test al, al
        jz .app_done
        stosb
        jmp .app
.app_done:
        mov ecx, edi
        sub ecx, jbuf
        mov eax, SYS_FWRITE
        mov ebx, j_path
        mov edx, ecx
        mov ecx, jbuf
        xor esi, esi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_added
        int 0x80
        xor ebx, ebx
        jmp .exit

.show:
        mov eax, SYS_FREAD
        mov ebx, j_path
        mov ecx, jbuf
        int 0x80
        cmp eax, 0
        jle .none
        mov byte [jbuf + eax], 0
        mov eax, SYS_PRINT
        mov ebx, jbuf
        int 0x80
        xor ebx, ebx
        jmp .exit
.none:
        mov eax, SYS_PRINT
        mov ebx, msg_none
        int 0x80
        xor ebx, ebx
.exit:
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
put_uint4:
        ; Write EAX as 4-digit zero-padded decimal at EDI
        push ebx
        push edx
        mov ebx, 1000
        xor edx, edx
        div ebx
        add al, '0'
        stosb
        mov eax, edx
        mov ebx, 100
        xor edx, edx
        div ebx
        add al, '0'
        stosb
        mov eax, edx
        mov ebx, 10
        xor edx, edx
        div ebx
        add al, '0'
        stosb
        mov al, dl
        add al, '0'
        stosb
        pop edx
        pop ebx
        ret

put_uint2:
        push ebx
        push edx
        mov ebx, 10
        xor edx, edx
        div ebx
        add al, '0'
        stosb
        mov al, dl
        add al, '0'
        stosb
        pop edx
        pop ebx
        ret

j_path:    db '/home/journal.txt', 0
msg_added: db 'journal: entry recorded.', 10, 0
msg_none:  db '(no journal entries yet)', 10, 0

date_buf:  times 8 db 0
year:      dd 0
argbuf:    times 1024 db 0
line_buf:  times 1100 db 0
jbuf:      times JBUF_MAX + 1 db 0
