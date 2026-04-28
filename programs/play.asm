; play.asm - Play a sequence of notes on the PC speaker
; Suggestion #10: Sound. Notes: c d e f g a b (lower) and C D E F G A B
; (upper octave). Sharps: cs ds fs gs as. r = rest. Each token defaults
; to a quarter note; suffix /1 /2 /4 /8 /16 sets the duration.
;
; Examples:
;   play c e g C
;   play c/8 e/8 g/4 r/8 C/2

%include "syscalls.inc"

QUARTER_TICKS equ 25            ; 250 ms

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        test eax, eax
        jle .usage

        mov esi, argbuf
.tok:
        ; Skip whitespace
.sp:
        mov al, [esi]
        cmp al, ' '
        je .sp_a
        cmp al, 9
        je .sp_a
        cmp al, 10
        je .sp_a
        cmp al, 13
        je .sp_a
        test al, al
        jz .done
        jmp .have
.sp_a:
        inc esi
        jmp .sp
.have:
        ; Parse note letter (lower or upper) and optional 's'
        mov al, [esi]
        inc esi
        ; Build a small index: note letter (a-g, A-G), 'r', or 'cs'-style
        mov [letter], al
        mov byte [sharp], 0
        mov al, [esi]
        cmp al, 's'
        jne .no_sharp
        mov byte [sharp], 1
        inc esi
.no_sharp:
        ; Default duration = quarter
        mov dword [dur_ticks], QUARTER_TICKS
        mov al, [esi]
        cmp al, '/'
        jne .play_it
        inc esi
        ; Parse decimal denominator
        xor eax, eax
.dn:
        mov bl, [esi]
        cmp bl, '0'
        jb .dn_done
        cmp bl, '9'
        ja .dn_done
        sub bl, '0'
        imul eax, eax, 10
        movzx ebx, bl
        add eax, ebx
        inc esi
        jmp .dn
.dn_done:
        test eax, eax
        jz .play_it
        ; ticks = QUARTER_TICKS * 4 / denom
        mov ebx, eax
        mov eax, QUARTER_TICKS * 4
        xor edx, edx
        div ebx
        mov [dur_ticks], eax
.play_it:
        ; Compute frequency from letter+sharp
        movzx eax, byte [letter]
        cmp al, 'r'
        je .rest
        cmp al, 'R'
        je .rest

        ; Map letters to semitone offsets from C (C=0, D=2, E=4, F=5, G=7, A=9, B=11)
        ; Use an LUT indexed by (letter & 31)-1 (a=1)
        mov bl, al
        and bl, 31              ; A->1, B->2, ... a->1, b->2
        dec bl                  ; 0..6
        movzx ebx, bl
        movzx eax, byte [semis + ebx]
        cmp byte [sharp], 0
        je .no_sh
        inc eax
.no_sh:
        ; Octave selection: lowercase = octave 4, uppercase = octave 5
        movzx ebx, byte [letter]
        cmp bl, 'a'
        jb .upper
        ; lowercase
        add eax, 4 * 12
        jmp .has_idx
.upper:
        add eax, 5 * 12
.has_idx:
        ; freq = 16.35 * 2^(idx/12)  -> use a tiny LUT for octaves 4..6
        ; LUT 'note_freq' indexed 0..35 covers C4..B6.
        sub eax, 4 * 12
        cmp eax, 0
        jl .skip
        cmp eax, 36
        jge .skip
        mov ebx, eax
        shl ebx, 1
        movzx eax, word [note_freq + ebx]
        ; Beep
        push esi
        mov ebx, eax
        mov ecx, [dur_ticks]
        mov eax, SYS_BEEP
        int 0x80
        pop esi
        jmp .tok
.rest:
        push esi
        mov eax, SYS_SLEEP
        mov ebx, [dur_ticks]
        int 0x80
        pop esi
        jmp .tok
.skip:
        jmp .tok

.done:
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

.usage:
        mov eax, SYS_PRINT
        mov ebx, msg_usage
        int 0x80
        mov ebx, 1
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; Tables
;-----------------------------------
; Letter A..G -> semitone offset within an octave (C-based)
;   index 0=A, 1=B, 2=C, 3=D, 4=E, 5=F, 6=G
semis: db 9, 11, 0, 2, 4, 5, 7

; Note frequencies in Hz, C4 .. B6 (36 semitones)
note_freq:
        dw 262, 277, 294, 311, 330, 349, 370, 392, 415, 440, 466, 494
        dw 523, 554, 587, 622, 659, 698, 740, 784, 831, 880, 932, 988
        dw 1047,1109,1175,1245,1319,1397,1480,1568,1661,1760,1865,1976

msg_usage:
        db 'usage: play <notes>', 10
        db '  e.g. play c e g C', 10
        db '  durations:  c/8 g/4 (eighth, quarter)', 10
        db '  rest:       r r/8', 10
        db '  sharps:     cs ds fs gs as', 10, 0

argbuf:    times 512 db 0
letter:    db 0
sharp:     db 0
dur_ticks: dd 0
