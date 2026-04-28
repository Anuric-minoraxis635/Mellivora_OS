; nim.asm - Single-pile Nim against the computer
; Suggestion #7: Games. Two-player rules: 21 sticks, take 1-3 each turn,
; whoever takes the last stick LOSES. Computer plays the perfect strategy
; (leave a multiple of 4 to the opponent).

%include "syscalls.inc"

START_STICKS equ 21

start:
        mov dword [sticks], START_STICKS

        mov eax, SYS_PRINT
        mov ebx, intro
        int 0x80

.round:
        ; Show pile
        call show_pile
        cmp dword [sticks], 0
        jne .player
        ; Pile empty - whoever just took the last stick loses.
        ; If we just exited via player taking the last, [last_taker]==1
        ; Print result
        mov eax, SYS_PRINT
        mov ebx, [winner_msg]
        int 0x80
        jmp .end

.player:
        mov eax, SYS_PRINT
        mov ebx, prompt
        int 0x80
.read:
        mov eax, SYS_GETCHAR
        int 0x80
        cmp al, 'q'
        je .quit
        cmp al, 'Q'
        je .quit
        cmp al, '1'
        jb .read
        cmp al, '3'
        ja .read
        sub al, '0'
        movzx ebx, al
        cmp ebx, [sticks]
        jg .read
        ; Echo the digit + newline
        push ebx
        movzx ebx, al
        add ebx, '0'
        mov eax, SYS_PUTCHAR
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        pop ebx
        sub [sticks], ebx
        cmp dword [sticks], 0
        jne .ai_turn
        ; Player took the last stick -> player LOSES
        mov dword [winner_msg], lose_msg
        jmp .round

.ai_turn:
        ; Compute move: target = sticks - ((sticks - 1) % 4)
        mov eax, [sticks]
        dec eax
        xor edx, edx
        mov ecx, 4
        div ecx                 ; edx = (sticks-1) mod 4
        ; Computer takes max(1, edx) sticks, but cap at sticks
        mov eax, edx
        test eax, eax
        jnz .have_move
        mov eax, 1
.have_move:
        cmp eax, [sticks]
        jle .ok
        mov eax, [sticks]
.ok:
        mov [ai_move], eax
        push eax
        mov eax, SYS_PRINT
        mov ebx, ai_msg
        int 0x80
        pop eax
        ; print digit
        push eax
        add al, '0'
        movzx ebx, al
        mov eax, SYS_PUTCHAR
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        pop eax
        sub [sticks], eax
        cmp dword [sticks], 0
        jne .round
        ; Computer took the last stick -> player WINS
        mov dword [winner_msg], win_msg
        jmp .round

.quit:
        mov eax, SYS_PRINT
        mov ebx, bye
        int 0x80
.end:
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
show_pile:
        mov eax, SYS_PRINT
        mov ebx, pile_lbl
        int 0x80
        mov ecx, [sticks]
        test ecx, ecx
        jz .nl
.l:
        mov eax, SYS_PUTCHAR
        mov ebx, '|'
        int 0x80
        loop .l
.nl:
        mov eax, SYS_PUTCHAR
        mov ebx, ' '
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, '('
        int 0x80
        mov eax, [sticks]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_left
        int 0x80
        ret

print_uint:
        push ebx
        push ecx
        push edx
        push edi
        mov edi, numbuf + 7
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

intro:
        db 'NIM - take 1, 2, or 3 sticks per turn.', 10
        db 'Whoever takes the LAST stick loses.', 10
        db 'Press q to quit.', 10, 10, 0
prompt:    db 'Your move (1-3): ', 0
ai_msg:    db 'Computer takes ', 0
pile_lbl:  db 'Pile: ', 0
str_left:  db ' left)', 10, 0
win_msg:   db 10, '*** You WIN! ***', 10, 0
lose_msg:  db 10, '*** You LOSE. ***', 10, 0
bye:       db 'bye.', 10, 0

sticks:      dd 0
ai_move:     dd 0
winner_msg:  dd 0
numbuf:      times 8 db 0
