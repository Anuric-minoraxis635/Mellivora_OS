; bcal.asm - Personal agenda / calendar dashboard
; Suggestion #5: Burrows-native productivity app (terminal version).
;
; Shows today's date, day-of-week, and any events stored in
; /home/.events  (one per line: "YYYY-MM-DD  <text>").
;
; Usage:
;   bcal               show today + upcoming events
;   bcal add YYYY-MM-DD <text>     append an event
;   bcal list                       list every event

%include "syscalls.inc"

EV_MAX equ 8192

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jz .show_today

        mov esi, argbuf
        mov edi, kw_add
        call str_starts
        je .do_add
        mov esi, argbuf
        mov edi, kw_list
        call str_starts
        je .do_list

.show_today:
        ; Today header
        mov eax, SYS_DATE
        mov ebx, date_buf
        int 0x80
        mov [year], eax

        mov eax, SYS_PRINT
        mov ebx, hdr1
        int 0x80
        movzx eax, byte [date_buf + 4]      ; month
        call print_month_name
        mov eax, SYS_PUTCHAR
        mov ebx, ' '
        int 0x80
        movzx eax, byte [date_buf + 3]      ; day
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_comma
        int 0x80
        mov eax, [year]
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80

        ; Events
        mov eax, SYS_PRINT
        mov ebx, hdr2
        int 0x80
        mov eax, SYS_FREAD
        mov ebx, ev_path
        mov ecx, evbuf
        int 0x80
        cmp eax, 0
        jle .no_events
        mov byte [evbuf + eax], 0
        mov eax, SYS_PRINT
        mov ebx, evbuf
        int 0x80
        xor ebx, ebx
        jmp .exit
.no_events:
        mov eax, SYS_PRINT
        mov ebx, msg_no_events
        int 0x80
        xor ebx, ebx
        jmp .exit

.do_list:
        mov eax, SYS_FREAD
        mov ebx, ev_path
        mov ecx, evbuf
        int 0x80
        cmp eax, 0
        jle .no_events
        mov byte [evbuf + eax], 0
        mov eax, SYS_PRINT
        mov ebx, evbuf
        int 0x80
        xor ebx, ebx
        jmp .exit

.do_add:
        ; argbuf = "add YYYY-MM-DD <text>"
        mov esi, argbuf
        add esi, 3              ; past "add"
        ; skip spaces
.sp:
        mov al, [esi]
        cmp al, ' '
        je .sp_a
        cmp al, 9
        je .sp_a
        jmp .have
.sp_a:
        inc esi
        jmp .sp
.have:
        cmp byte [esi], 0
        je .usage
        ; Read existing
        mov eax, SYS_FREAD
        mov ebx, ev_path
        mov ecx, evbuf
        int 0x80
        mov edi, evbuf
        cmp eax, 0
        jge .ok
        xor eax, eax
.ok:
        add edi, eax
        ; Append the rest of argbuf + newline
.cp:
        lodsb
        test al, al
        jz .cp_done
        stosb
        jmp .cp
.cp_done:
        mov al, 10
        stosb
        mov ecx, edi
        sub ecx, evbuf
        mov eax, SYS_FWRITE
        mov ebx, ev_path
        mov edx, ecx
        mov ecx, evbuf
        xor esi, esi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_added
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

;-----------------------------------
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

print_month_name:
        ; EAX = 1..12
        cmp eax, 1
        jb .out
        cmp eax, 12
        ja .out
        dec eax
        mov ecx, eax
        shl ecx, 2              ; 4 chars per name
        lea ebx, [months + ecx]
        mov eax, SYS_PRINT
        int 0x80
.out:
        ret

str_starts:
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

months:
        db 'Jan', 0
        db 'Feb', 0
        db 'Mar', 0
        db 'Apr', 0
        db 'May', 0
        db 'Jun', 0
        db 'Jul', 0
        db 'Aug', 0
        db 'Sep', 0
        db 'Oct', 0
        db 'Nov', 0
        db 'Dec', 0

hdr1:        db 'Today: ', 0
hdr2:        db 0x0A, 'Upcoming Events', 0x0A, '---------------', 0x0A, 0
str_comma:   db ', ', 0
ev_path:     db '/home/.events', 0
kw_add:      db 'add', 0
kw_list:     db 'list', 0
msg_no_events: db '(no events scheduled)', 10, 0
msg_added:   db 'event added.', 10, 0
msg_usage:
        db 'usage:', 10
        db '  bcal                          show today + events', 10
        db '  bcal add YYYY-MM-DD <text>    schedule an event', 10
        db '  bcal list                     list every event', 10, 0

date_buf:    times 8 db 0
year:        dd 0
numbuf:      times 12 db 0
argbuf:      times 512 db 0
evbuf:       times EV_MAX + 1 db 0
