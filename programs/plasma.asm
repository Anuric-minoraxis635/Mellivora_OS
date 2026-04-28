; plasma.asm - Animated text-mode plasma demo
; Suggestion #6: Showpiece demos. Press any key to exit.
;
; Math is intentionally cheap: a per-cell index into a 64-entry sine LUT
; combined with a time offset. Result is a smooth, scrolling colour field.

%include "syscalls.inc"

VGA_BASE  equ 0x000B8000
COLS      equ 80
ROWS      equ 25
FRAMES    equ 600

start:
        mov eax, SYS_CLEAR
        int 0x80
        xor eax, eax
        mov [tick], eax

.frame:
        ; For each cell compute a colour index
        mov edi, VGA_BASE
        xor edx, edx            ; row 0
.row:
        xor ecx, ecx            ; col 0
.col:
        ; idx = (col + tick) ^ (row + tick/2) -> sine table
        mov eax, ecx
        add eax, [tick]
        mov ebx, edx
        mov esi, [tick]
        shr esi, 1
        add ebx, esi
        xor eax, ebx
        and eax, 63
        movzx eax, byte [sine + eax]
        ; Choose colour from palette by upper bits
        shr eax, 4              ; 0..15
        and al, 0x0F
        ; Build VGA cell: char + attr
        mov ah, al
        shl ah, 4               ; bg = colour
        or ah, 0x0F             ; fg = white
        mov al, 0xB1            ; medium shade
        mov [edi], ax
        add edi, 2
        inc ecx
        cmp ecx, COLS
        jl .col
        inc edx
        cmp edx, ROWS
        jl .row

        ; Advance time
        inc dword [tick]

        ; Sleep ~50 ms (5 ticks)
        mov eax, SYS_SLEEP
        mov ebx, 5
        int 0x80

        ; Quit on any key
        mov eax, SYS_READ_KEY
        int 0x80
        test eax, eax
        jnz .done

        mov eax, [tick]
        cmp eax, FRAMES
        jl .frame
.done:
        mov eax, SYS_CLEAR
        int 0x80
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; 64-entry sine table, range 0..255
;-----------------------------------
sine:
        db 128,140,152,165,176,188,198,208
        db 218,226,234,240,245,250,253,254
        db 255,254,253,250,245,240,234,226
        db 218,208,198,188,176,165,152,140
        db 128,115,103, 90, 79, 67, 57, 47
        db  37, 29, 21, 15, 10,  5,  2,  1
        db   0,  1,  2,  5, 10, 15, 21, 29
        db  37, 47, 57, 67, 79, 90,103,115

tick: dd 0
