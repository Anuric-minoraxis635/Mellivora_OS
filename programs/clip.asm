; clip.asm - Command-line clipboard utility
;
; Usage:
;   clip copy <text...>     Copy text args to system clipboard
;   clip paste              Print clipboard contents to stdout
;   echo hello | clip       Copy stdin to clipboard (no args)
;
; Wraps the existing SYS_CLIPBOARD_COPY / SYS_CLIPBOARD_PASTE syscalls.
; Makes the clipboard scriptable from the shell — basis for "pipe to GUI"
; workflows like:  ls /bin | clip   then paste in burrows apps.

%include "syscalls.inc"

CLIP_MAX equ 4096

start:
        ; Read args
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        mov [arg_len], eax

        cmp eax, 0
        jle .from_stdin         ; no args: try stdin pipe

        ; Match first word: "paste" or "copy"
        mov esi, argbuf
        mov edi, paste_kw
        call streq
        je .do_paste
        mov esi, argbuf
        mov edi, copy_kw
        call streq
        jne .copy_args_raw      ; no recognised verb -> copy whole arg string

        ; "copy <text>": skip past "copy " and the space
        mov esi, argbuf
.skip_word:
        lodsb
        test al, al
        jz .copy_empty
        cmp al, ' '
        jne .skip_word
        ; ESI now points after the space
        mov ebx, esi
        ; Compute length
        xor ecx, ecx
.len_loop:
        cmp byte [esi + ecx], 0
        je .copy_call
        inc ecx
        cmp ecx, CLIP_MAX
        jge .copy_call
        jmp .len_loop
.copy_call:
        mov eax, SYS_CLIPBOARD_COPY
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_copied
        int 0x80
        xor ebx, ebx
        jmp .exit
.copy_empty:
        mov eax, SYS_PRINT
        mov ebx, msg_empty
        int 0x80
        mov ebx, 1
        jmp .exit

.copy_args_raw:
        ; No verb — treat the whole argbuf as the text to copy
        mov ebx, argbuf
        mov ecx, [arg_len]
        mov eax, SYS_CLIPBOARD_COPY
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_copied
        int 0x80
        xor ebx, ebx
        jmp .exit

.do_paste:
        mov eax, SYS_CLIPBOARD_PASTE
        mov ebx, pastebuf
        mov ecx, CLIP_MAX
        int 0x80
        test eax, eax
        jle .empty_clip
        mov [pastebuf + eax], byte 0
        mov eax, SYS_PRINT
        mov ebx, pastebuf
        int 0x80
        ; Trailing newline only if last byte wasn't already one
        mov esi, pastebuf
        add esi, [pastebuf_end]
        xor ebx, ebx
        jmp .nl_then_exit

.empty_clip:
        ; nothing in clipboard; exit 1 silently for script-friendliness
        mov ebx, 1
        jmp .exit

.from_stdin:
        ; Try to read piped input
        mov eax, SYS_STDIN_READ
        mov ebx, pastebuf
        int 0x80
        cmp eax, 0
        jle .usage
        mov ecx, eax
        mov ebx, pastebuf
        mov eax, SYS_CLIPBOARD_COPY
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, msg_copied
        int 0x80
        xor ebx, ebx
        jmp .exit

.nl_then_exit:
        mov eax, SYS_PUTCHAR
        mov ebx, 10
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
; streq - null-terminated string compare ESI vs EDI; ZF set if equal
;-----------------------------------
streq:
        push esi
        push edi
.l:
        mov al, [esi]
        mov ah, [edi]
        cmp al, ah
        jne .ne
        test al, al
        jz .eq
        inc esi
        inc edi
        jmp .l
.eq:
        pop edi
        pop esi
        xor al, al              ; ZF=1
        ret
.ne:
        pop edi
        pop esi
        or al, 1
        cmp al, 0               ; ZF=0
        ret

copy_kw:   db 'copy', 0
paste_kw:  db 'paste', 0
msg_copied: db '(clipboard updated)', 10, 0
msg_empty:  db 'clip: nothing to copy', 10, 0
usage_msg:
        db 'usage: clip <verb> [text]', 10
        db '  clip copy <text>   copy text to clipboard', 10
        db '  clip paste         print clipboard to stdout', 10
        db '  echo X | clip      copy stdin to clipboard', 10, 0

argbuf:    times 1024 db 0
arg_len:   dd 0
pastebuf:  times CLIP_MAX + 1 db 0
pastebuf_end: dd 0
