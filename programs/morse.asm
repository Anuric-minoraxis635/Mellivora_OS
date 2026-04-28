; morse.asm - Convert ASCII to Morse code (printed and beeped)
;
; Usage:
;   morse <text...>            print + beep
;   morse -p <text...>         print only (no beeps)

%include "syscalls.inc"

DOT_MS  equ 12          ; 12 ticks ~ 120 ms
DASH_MS equ 36
GAP_INTRA equ 8         ; gap between dot/dash inside a letter
GAP_LETTER equ 24       ; gap between letters
GAP_WORD equ 56         ; gap between words
TONE_HZ equ 700

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        mov esi, argbuf
        mov byte [silent], 0
.tr:
        mov al, [esi]
        cmp al, ' '
        je .ws
        cmp al, 9
        je .ws
        jmp .check
.ws:
        inc esi
        jmp .tr
.check:
        cmp byte [esi], '-'
        jne .body
        cmp byte [esi+1], 'p'
        jne .body
        mov byte [silent], 1
        add esi, 2
.swsk:
        mov al, [esi]
        cmp al, ' '
        je .swadv
        cmp al, 9
        je .swadv
        jmp .body
.swadv:
        inc esi
        jmp .swsk

.body:
        cmp byte [esi], 0
        jne .loop
        mov eax, SYS_PRINT
        mov ebx, usage
        int 0x80
        mov ebx, 1
        jmp .exit

.loop:
        mov al, [esi]
        test al, al
        jz .done
        inc esi
        ; Upcase
        cmp al, 'a'
        jb .ok
        cmp al, 'z'
        ja .ok
        sub al, 32
.ok:
        cmp al, ' '
        je .space
        cmp al, 'A'
        jb .skip
        cmp al, 'Z'
        jbe .alpha
        cmp al, '0'
        jb .skip
        cmp al, '9'
        jbe .digit
        jmp .skip
.alpha:
        sub al, 'A'
        movzx ebx, al
        mov eax, [letters + ebx*4]
        call emit
        call letter_gap
        jmp .loop
.digit:
        sub al, '0'
        movzx ebx, al
        mov eax, [digits + ebx*4]
        call emit
        call letter_gap
        jmp .loop
.space:
        ; Word break
        mov eax, SYS_PUTCHAR
        mov ebx, ' '
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, '/'
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, ' '
        int 0x80
        cmp byte [silent], 0
        jne .loop
        mov eax, SYS_SLEEP
        mov ebx, GAP_WORD
        int 0x80
        jmp .loop
.skip:
        jmp .loop
.done:
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
.exit:
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; emit: EAX = pointer to ".-"-style null-terminated pattern. Print + beep.
emit:
        push esi
        mov esi, eax
.l:
        mov al, [esi]
        test al, al
        jz .d
        push esi
        ; print char
        mov [chrbuf], al
        mov eax, SYS_PRINT
        mov ebx, chrbuf
        int 0x80
        pop esi
        cmp byte [silent], 0
        jne .skip_b
        push esi
        mov al, [esi]
        cmp al, '.'
        je .dot
        mov ecx, DASH_MS
        jmp .doit
.dot:
        mov ecx, DOT_MS
.doit:
        mov eax, SYS_BEEP
        mov ebx, TONE_HZ
        int 0x80
        mov eax, SYS_SLEEP
        mov ebx, GAP_INTRA
        int 0x80
        pop esi
.skip_b:
        inc esi
        jmp .l
.d:
        mov eax, SYS_PUTCHAR
        mov ebx, ' '
        int 0x80
        pop esi
        ret

letter_gap:
        cmp byte [silent], 0
        jne .r
        mov eax, SYS_SLEEP
        mov ebx, GAP_LETTER
        int 0x80
.r:
        ret

;-----------------------------------
letters:
        dd m_a, m_b, m_c, m_d, m_e, m_f, m_g, m_h
        dd m_i, m_j, m_k, m_l, m_m, m_n, m_o, m_p
        dd m_q, m_r, m_s, m_t, m_u, m_v, m_w, m_x
        dd m_y, m_z

digits:
        dd m_0, m_1, m_2, m_3, m_4, m_5, m_6, m_7, m_8, m_9

m_a: db '.-', 0
m_b: db '-...', 0
m_c: db '-.-.', 0
m_d: db '-..', 0
m_e: db '.', 0
m_f: db '..-.', 0
m_g: db '--.', 0
m_h: db '....', 0
m_i: db '..', 0
m_j: db '.---', 0
m_k: db '-.-', 0
m_l: db '.-..', 0
m_m: db '--', 0
m_n: db '-.', 0
m_o: db '---', 0
m_p: db '.--.', 0
m_q: db '--.-', 0
m_r: db '.-.', 0
m_s: db '...', 0
m_t: db '-', 0
m_u: db '..-', 0
m_v: db '...-', 0
m_w: db '.--', 0
m_x: db '-..-', 0
m_y: db '-.--', 0
m_z: db '--..', 0
m_0: db '-----', 0
m_1: db '.----', 0
m_2: db '..---', 0
m_3: db '...--', 0
m_4: db '....-', 0
m_5: db '.....', 0
m_6: db '-....', 0
m_7: db '--...', 0
m_8: db '---..', 0
m_9: db '----.', 0

usage:  db 'usage: morse [-p] <text...>', 10, 0
chrbuf: times 2 db 0
silent: db 0
argbuf: times 256 db 0
