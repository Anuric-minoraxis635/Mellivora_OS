; pick.asm - Pick a random line from stdin args (space-separated tokens)
;
; Usage:
;   pick alice bob carol dave
;
; Prints one of the tokens at random.

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        ; First pass: count tokens and store start offsets
        mov esi, argbuf
        xor ecx, ecx                ; token count
        xor ebx, ebx                ; in-token flag
.scan:
        mov al, [esi]
        test al, al
        jz .done
        cmp al, ' '
        je .ws
        cmp al, 9
        je .ws
        cmp al, 10
        je .ws
        ; non-ws
        test ebx, ebx
        jnz .next
        ; start of token
        mov [offsets + ecx*4], esi
        inc ecx
        mov ebx, 1
        jmp .next
.ws:
        test ebx, ebx
        jz .next
        mov byte [esi], 0           ; terminate token
        xor ebx, ebx
.next:
        inc esi
        jmp .scan
.done:
        test ecx, ecx
        jz usage_err

        ; seed
        mov eax, SYS_GETTIME
        int 0x80
        mov edx, eax
        mov eax, SYS_GETPID
        int 0x80
        xor eax, edx
        test eax, eax
        jnz .sok
        mov eax, 0xDEADBEEF
.sok:
        mov [seed], eax

        ; pick index
        mov [count], ecx
        call rand32
        xor edx, edx
        div dword [count]           ; edx = index
        mov eax, [offsets + edx*4]
        mov ebx, eax
        mov eax, SYS_PRINT
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
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

rand32:
        mov eax, [seed]
        mov ebx, eax
        shl ebx, 13
        xor eax, ebx
        mov ebx, eax
        shr ebx, 17
        xor eax, ebx
        mov ebx, eax
        shl ebx, 5
        xor eax, ebx
        mov [seed], eax
        ret

usage:   db 'usage: pick item1 item2 ...', 10, 0
argbuf:  times 256 db 0
offsets: times 64 dd 0
count:   dd 0
seed:    dd 0
