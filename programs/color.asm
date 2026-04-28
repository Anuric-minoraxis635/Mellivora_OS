; color.asm - Display all 256 VGA text-mode color attributes
; Renders a 16x16 grid where row=background, column=foreground, cell shows
; the attribute byte in hex. Useful for picking a theme value.

%include "syscalls.inc"

VGA_BASE equ 0xB8000
ROWS     equ 16
COLS     equ 16

start:
        mov eax, SYS_CLEAR
        int 0x80

        ; Header line
        mov eax, SYS_PRINT
        mov ebx, banner
        int 0x80

        ; Render grid directly to VGA framebuffer starting at row 2.
        ; Each cell is 4 chars wide (e.g. " 0E ") = 8 bytes per cell in VRAM.
        ; Grid origin: row 2, col 4 -> offset = (2*80 + 4)*2
        mov edi, VGA_BASE + (2*80 + 4) * 2
        xor ebp, ebp           ; bg = 0..15
.row:
        cmp ebp, ROWS
        jge .grid_done
        push edi
        xor esi, esi           ; fg = 0..15
.col:
        cmp esi, COLS
        jge .col_done
        ; attr = (bg<<4) | fg
        mov eax, ebp
        shl eax, 4
        or eax, esi
        mov bl, al             ; attr byte
        ; Compose " HH " in 4 cells
        ; Space
        mov byte [edi], ' '
        mov [edi+1], bl
        ; High nybble
        mov al, bl
        shr al, 4
        and al, 0x0F
        call hex_digit
        mov [edi+2], al
        mov [edi+3], bl
        ; Low nybble
        mov al, bl
        and al, 0x0F
        call hex_digit
        mov [edi+4], al
        mov [edi+5], bl
        ; Space
        mov byte [edi+6], ' '
        mov [edi+7], bl
        add edi, 8
        inc esi
        jmp .col
.col_done:
        pop edi
        ; Next row: + 80*2 bytes (one full text row)
        add edi, 80*2
        inc ebp
        jmp .row
.grid_done:

        ; Footer hint at row 19
        mov edi, VGA_BASE + (19*80) * 2
        mov esi, footer
        mov bl, 0x07
.fp:
        mov al, [esi]
        test al, al
        jz .fdone
        mov [edi], al
        mov [edi+1], bl
        add edi, 2
        inc esi
        jmp .fp
.fdone:

        ; Wait for keypress
        mov eax, SYS_GETCHAR
        int 0x80

        mov eax, SYS_CLEAR
        int 0x80
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
; AL = 0..15 -> ASCII '0'..'F'
hex_digit:
        cmp al, 10
        jb .d
        add al, 'A' - 10
        ret
.d:
        add al, '0'
        ret

banner:
        db 'VGA color attributes - row=bg, col=fg, hex byte = use with theme/SYS_SETCOLOR', 10
        db 'Press any key to exit.', 10, 0
footer:
        db 'Example:  theme apply attr 0x4E   (yellow on red)', 0
