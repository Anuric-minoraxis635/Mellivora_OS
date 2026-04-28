; bdialog.asm - Scriptable dialog boxes for Mellivora shell scripts
;
; Usage:
;   bdialog msg <message>           Print message, wait for any key
;   bdialog yesno <question>        Prompt y/n, exit 0 (yes) or 1 (no)
;   bdialog input <prompt>          Read a line, print it on stdout, exit 0
;   bdialog notify <message>        Send a system notification (no UI block)
;
; Designed so shell scripts can do:
;     if bdialog yesno "Continue?"; then ...
;     name=$(bdialog input "Your name:")
;
; Why: every interactive program currently rolls its own prompt. A single
; well-tested helper saves a kilobyte per program and standardises UX.

%include "syscalls.inc"

INPUT_MAX equ 256

start:
        ; Read full argument string (mode + payload separated by space)
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle .usage

        ; Split argbuf at first space: ESI = mode, EDI = rest
        mov esi, argbuf
        mov edi, argbuf
.find_space:
        mov al, [edi]
        test al, al
        jz .no_payload
        cmp al, ' '
        je .split_here
        inc edi
        jmp .find_space
.split_here:
        mov byte [edi], 0
        inc edi
        jmp .dispatch
.no_payload:
        ; mode with no payload — point payload at empty string
        mov edi, empty_str

.dispatch:
        ; Match mode
        mov ebx, msg_mode
        call streq
        je .do_msg
        mov ebx, yesno_mode
        call streq
        je .do_yesno
        mov ebx, input_mode
        call streq
        je .do_input
        mov ebx, notify_mode
        call streq
        je .do_notify
        jmp .usage

;-----------------------------------
; msg: print, wait for key, exit 0
;-----------------------------------
.do_msg:
        mov eax, SYS_PRINT
        mov ebx, edi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_press
        int 0x80
        mov eax, SYS_GETCHAR
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        jmp .exit

;-----------------------------------
; yesno: print "<q> [y/N]: ", read one char
;-----------------------------------
.do_yesno:
        mov eax, SYS_PRINT
        mov ebx, edi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, yn_prompt
        int 0x80
        mov eax, SYS_GETCHAR
        int 0x80
        mov ah, al
        mov eax, SYS_PUTCHAR
        movzx ebx, ah
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        cmp ah, 'y'
        je .yes
        cmp ah, 'Y'
        je .yes
        mov ebx, 1
        jmp .exit
.yes:
        xor ebx, ebx
        jmp .exit

;-----------------------------------
; input: print prompt, read line, echo on stdout
;-----------------------------------
.do_input:
        mov eax, SYS_PRINT
        mov ebx, edi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, in_sep
        int 0x80
        ; Read a line via SYS_GETCHAR (no kernel readline syscall in stable ABI)
        xor ecx, ecx
        mov edi, linebuf
.in_loop:
        mov eax, SYS_GETCHAR
        int 0x80
        cmp al, 10              ; LF
        je .in_done
        cmp al, 13              ; CR
        je .in_done
        cmp al, 8               ; BS
        je .in_bs
        cmp al, 0x7F            ; DEL
        je .in_bs
        cmp ecx, INPUT_MAX - 1
        jge .in_loop            ; ignore past cap
        mov [edi + ecx], al
        inc ecx
        push ecx
        movzx ebx, al
        mov eax, SYS_PUTCHAR
        int 0x80
        pop ecx
        jmp .in_loop
.in_bs:
        test ecx, ecx
        jz .in_loop
        dec ecx
        push ecx
        mov eax, SYS_PUTCHAR
        mov ebx, 8
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, ' '
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 8
        int 0x80
        pop ecx
        jmp .in_loop
.in_done:
        mov byte [edi + ecx], 0
        ; Newline + echo line on stdout
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, linebuf
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        jmp .exit

;-----------------------------------
; notify: fire SYS_NOTIFY, no UI block
;-----------------------------------
.do_notify:
        mov eax, SYS_NOTIFY
        mov ebx, edi
        mov edx, 0x0E           ; bright yellow on black (text-mode default)
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
; streq - compare null-terminated strings ESI vs EBX
;   Sets ZF if equal. Preserves ESI/EBX.
;-----------------------------------
streq:
        push esi
        push ebx
.eq_loop:
        mov al, [esi]
        mov ah, [ebx]
        cmp al, ah
        jne .eq_no
        test al, al
        jz .eq_yes
        inc esi
        inc ebx
        jmp .eq_loop
.eq_yes:
        pop ebx
        pop esi
        cmp al, al              ; ZF=1
        ret
.eq_no:
        pop ebx
        pop esi
        or al, 1                ; clear ZF (al already non-zero or set bit 0)
        cmp al, 0               ; ZF=0
        ret

msg_mode:    db 'msg', 0
yesno_mode:  db 'yesno', 0
input_mode:  db 'input', 0
notify_mode: db 'notify', 0
empty_str:   db 0
yn_prompt:   db ' [y/N]: ', 0
in_sep:      db ' ', 0
msg_press:   db 10, '(press any key)', 0
usage_msg:
        db 'usage: bdialog <mode> <text>', 10
        db '  msg <text>     show text, wait for key (exit 0)', 10
        db '  yesno <q>      prompt y/n (exit 0 = yes, 1 = no)', 10
        db '  input <prompt> read a line, echo to stdout', 10
        db '  notify <text>  send a system notification', 10, 0

argbuf:    times 512 db 0
linebuf:   times INPUT_MAX db 0
