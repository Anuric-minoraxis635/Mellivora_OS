; peggame.asm - Cracker Barrel Triangle Peg Game for Mellivora OS
;
; Classic 15-hole triangular peg puzzle.  Jump a peg over an adjacent
; peg into an empty hole — the jumped peg is removed.  Goal: leave
; exactly 1 peg.
;
; Controls:
;   Left-click    Select a peg, then click a valid landing hole to jump
;                 (valid landings are shown as green dots)
;                 Click the selected peg again to deselect it.
;   R             Restart (pick a new starting empty hole)
;   U             Undo last move
;   Q / ESC       Quit
;
; Board layout (hole numbers):
;
;           0
;          1 2
;         3 4 5
;        6 7 8 9
;      10 11 12 13 14
;
; VBE 1024×768×32 bpp.
;
%include "syscalls.inc"
%include "lib/vbe_game.inc"
%include "lib/font.inc"
%include "lib/audio.inc"
%include "lib/highscore.inc"

;=======================================================================
; Board geometry
;=======================================================================
NUM_HOLES   equ 15
PEG_R       equ 28          ; filled peg radius
HOLE_R      equ 12          ; empty-hole inner radius
SEL_R       equ 36          ; selection ring radius
VALID_DOT_R equ 10          ; valid-landing green dot radius
HIT_R       equ 32          ; click hit radius

HX_STEP     equ 80          ; horizontal spacing between hole centres
HY_STEP     equ 70          ; vertical spacing between rows

; Apex (hole 0) screen position — board is centred horizontally
APEX_X      equ 512
APEX_Y      equ 130

;=======================================================================
; Colours
;=======================================================================
COL_BG          equ 0x00120800
COL_WOOD        equ 0x00703C10
COL_WOOD_EDGE   equ 0x00501800
COL_HOLE_BG     equ 0x00200C00
COL_HOLE_RIM    equ 0x00A05820
COL_PEG_BODY    equ 0x00E07020
COL_PEG_SHINE   equ 0x00FFB060
COL_SEL_RING    equ 0x0000FFCC
COL_VALID_DOT   equ 0x0066FF44
COL_INVALID_PEG equ 0x00604830
COL_WHITE       equ 0x00FFFFFF
COL_YELLOW      equ 0x00FFE040
COL_GRAY        equ 0x00777777
COL_RED         equ 0x00FF3333
COL_GREEN       equ 0x0033EE55
COL_TITLE       equ 0x00FFCC44

;=======================================================================
; Game states
;=======================================================================
ST_PICK_START   equ 0   ; pick which hole starts empty
ST_SELECT       equ 1   ; choose a peg to move
ST_JUMP         equ 2   ; peg chosen, pick landing hole
ST_WON          equ 3
ST_STUCK        equ 4

;=======================================================================
; Jump table
; For each of 15 holes we store up to 6 (over, land) pairs.
; Unused slots are filled with 0xFF, 0xFF.
; 6 pairs × 2 bytes = 12 bytes per hole entry.
;
; A jump FROM hole H OVER neighbour N to landing L is legal when:
;   board[H]=1, board[N]=1, board[L]=0
;=======================================================================
jumptab:
; h0:  over1→land3, over2→land5
    db  1,3,  2,5,  0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h1:  over0→(invalid—can't jump off edge), over3→land6, over4→land8, over2→land3? No.
;   Enumerate all valid directed jumps starting FROM h1:
;   h1→over3→land6 ; h1→over4→land8 ; h1→over2→land3 (h1 left of h2, first in row)
;   Wait: jump from h1 over h2 lands where? h1(row1 col0),h2(row1 col1): same row,
;   land = h3(row1 col2) which doesn't exist. So only column/diagonal jumps.
;   Diagonals from h1: up-left→h0 is only 1 step, no jump. Up-right: none.
;   Down-left: h1→h3 adj, h1→h6 land  ; h1→h4 adj, h1→h8 land (skip one diag)
;   Horizontal-right: h1→h2 adj, but h1 and h2 are in same row — h1 is col0, h2 col1
;       so land would be col2 in row1, which doesn't exist. No horizontal jump.
;   Also from jumptab perspective: peg at h1 can jump IF there's a valid (over,land).
;   Let me use the authoritative list:
; h1:  (over=3, land=6), (over=4, land=8)
    db  3,6,  4,8,  0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h2:  (over=4, land=7), (over=5, land=9)
    db  4,7,  5,9,  0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h3:  (over=1, land=0), (over=4, land=5), (over=6, land=10), (over=7, land=12)
    db  1,0,  4,5,  6,10, 7,12, 0xFF,0xFF, 0xFF,0xFF
; h4:  (over=7, land=11), (over=8, land=13)
    db  7,11, 8,13, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h5:  (over=2, land=0), (over=4, land=3), (over=8, land=12), (over=9, land=14)
    db  2,0,  4,3,  8,12, 9,14, 0xFF,0xFF, 0xFF,0xFF
; h6:  (over=3, land=1), (over=7, land=8)
    db  3,1,  7,8,  0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h7:  (over=4, land=2), (over=8, land=9)
    db  4,2,  8,9,  0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h8:  (over=4, land=1), (over=7, land=6)
    db  4,1,  7,6,  0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h9:  (over=5, land=2), (over=8, land=7)
    db  5,2,  8,7,  0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h10: (over=6, land=3), (over=11, land=12)
    db  6,3,  11,12, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h11: (over=7, land=4), (over=12, land=13)
    db  7,4,  12,13, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h12: (over=7, land=3), (over=8, land=5), (over=11, land=10), (over=13, land=14)
    db  7,3,  8,5,  11,10, 13,14, 0xFF,0xFF, 0xFF,0xFF
; h13: (over=8, land=4), (over=12, land=11)
    db  8,4,  12,11, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF
; h14: (over=9, land=5), (over=13, land=12)
    db  9,5,  13,12, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF, 0xFF,0xFF

;=======================================================================
; Entry point
;=======================================================================
start:
        VBE_GAME_INIT

        mov esi, hs_name
        call hs_load
        mov [best_score], eax

        call new_game

;-----------------------------------------------------------------------
; Main loop
;-----------------------------------------------------------------------
.main_loop:
        ; ---- keyboard ----
        mov eax, SYS_READ_KEY
        int 0x80
        test eax, eax
        jz .no_key

        cmp al, 'q'
        je .quit
        cmp al, 'Q'
        je .quit
        cmp al, KEY_ESC
        je .quit
        cmp al, 'r'
        je .do_restart
        cmp al, 'R'
        je .do_restart
        cmp al, 'u'
        je .do_undo
        cmp al, 'U'
        je .do_undo
        jmp .no_key

.do_restart:
        call new_game
        jmp .main_loop

.do_undo:
        call undo_move
        jmp .main_loop

.no_key:
        ; ---- mouse ----
        mov eax, SYS_MOUSE
        int 0x80                ; EAX=x  EBX=y  ECX=buttons

        test ecx, ecx
        jz .mouse_up

        cmp byte [last_btn], 0
        jne .main_loop          ; button was already down — no new click
        mov byte [last_btn], 1

        ; Record click position
        mov [click_x], eax
        mov [click_y], ebx

        ; On win/stuck screen, any click restarts
        cmp dword [game_state], ST_WON
        je .do_restart
        cmp dword [game_state], ST_STUCK
        je .do_restart

        ; Find which hole was clicked
        call find_hole_at       ; → EAX = hole index or -1
        cmp eax, -1
        je .main_loop

        mov [hit_hole], eax

        cmp dword [game_state], ST_PICK_START
        je .do_pick_start
        cmp dword [game_state], ST_SELECT
        je .do_select
        cmp dword [game_state], ST_JUMP
        je .do_jump_click
        jmp .main_loop

        ; ---- PICK START: click removes that peg, game begins ----
.do_pick_start:
        mov ecx, [hit_hole]
        mov byte [board + ecx], 0
        mov dword [game_state], ST_SELECT
        call update_peg_count
        call draw_all
        jmp .main_loop

        ; ---- SELECT: choose a peg ----
.do_select:
        mov ecx, [hit_hole]
        movzx eax, byte [board + ecx]
        test eax, eax
        jz .main_loop           ; empty hole — ignore
        call has_any_jump       ; ECX=hole → EAX=1/0
        test eax, eax
        jz .main_loop           ; no valid jumps — ignore
        mov [selected], ecx
        mov dword [game_state], ST_JUMP
        call draw_all
        jmp .main_loop

        ; ---- JUMP: land somewhere ----
.do_jump_click:
        mov ecx, [hit_hole]

        ; Clicking the selected peg again → deselect
        cmp ecx, [selected]
        jne .try_jump
        mov dword [game_state], ST_SELECT
        call draw_all
        jmp .main_loop

.try_jump:
        ; Did they click a different peg? Switch selection
        movzx eax, byte [board + ecx]
        test eax, eax
        jz .check_landing
        call has_any_jump       ; ECX=hole → EAX
        test eax, eax
        jz .main_loop
        mov [selected], ecx
        call draw_all
        jmp .main_loop

.check_landing:
        ; Clicked empty hole — check if it's a valid landing
        mov ebx, [selected]
        call find_jump          ; EBX=from ECX=to → EAX=over or -1
        cmp eax, -1
        je .main_loop           ; not a valid landing

        ; Execute jump
        call push_undo
        mov edx, [selected]
        mov byte [board + edx], 0   ; remove source
        mov byte [board + eax], 0   ; remove jumped
        mov byte [board + ecx], 1   ; place at landing

        inc dword [move_count]
        call update_peg_count

        ; jump SFX
        push eax
        mov eax, SYS_BEEP
        mov ebx, 880
        mov ecx, 5
        int 0x80
        pop eax

        call check_game_over
        call update_best
        call draw_all
        jmp .main_loop

.mouse_up:
        mov byte [last_btn], 0
        jmp .main_loop

.quit:
        mov eax, SYS_FRAMEBUF
        mov ebx, 2
        int 0x80
        xor eax, eax
        int 0x80

;=======================================================================
; new_game — fill board with pegs, enter PICK_START state
;=======================================================================
new_game:
        mov ecx, NUM_HOLES
        mov edi, board
        mov al, 1
        rep stosb
        mov dword [game_state], ST_PICK_START
        mov dword [selected],   -1
        mov dword [move_count],  0
        mov dword [peg_count],   NUM_HOLES
        mov dword [undo_top],    0
        call draw_all
        ret

;=======================================================================
; update_peg_count — recount pegs from board[]
;=======================================================================
update_peg_count:
        push eax
        push ecx
        push esi
        xor ecx, ecx
        xor esi, esi
.upc_loop:
        cmp esi, NUM_HOLES
        jge .upc_done
        movzx eax, byte [board + esi]
        add ecx, eax
        inc esi
        jmp .upc_loop
.upc_done:
        mov [peg_count], ecx
        pop esi
        pop ecx
        pop eax
        ret

;=======================================================================
; hole_screen_pos — ESI = hole index → EBX = screen_x, ECX = screen_y
;
; Row / col layout:
;   row 0: hole  0              (col 0)
;   row 1: holes 1–2            (col 0–1)
;   row 2: holes 3–5            (col 0–2)
;   row 3: holes 6–9            (col 0–3)
;   row 4: holes 10–14          (col 0–4)
;
;   screen_x = APEX_X - row*(HX_STEP/2) + col*HX_STEP
;   screen_y = APEX_Y + row*HY_STEP
;=======================================================================
hole_screen_pos:
        push eax
        push edx

        mov eax, esi            ; hole index
        ; Determine row and col
        cmp eax, 1
        jb  .r0                 ; hole 0
        cmp eax, 3
        jb  .r1                 ; holes 1–2
        cmp eax, 6
        jb  .r2                 ; holes 3–5
        cmp eax, 10
        jb  .r3                 ; holes 6–9
                                ; else row 4, holes 10–14
        mov edx, 4
        sub eax, 10             ; col
        jmp .calc

.r0:    xor edx, edx            ; row=0, col=0
        xor eax, eax
        jmp .calc
.r1:    mov edx, 1
        sub eax, 1
        jmp .calc
.r2:    mov edx, 2
        sub eax, 3
        jmp .calc
.r3:    mov edx, 3
        sub eax, 6

.calc:
        ; EAX = col,  EDX = row
        ; BX = APEX_X - row*(HX_STEP/2) + col*HX_STEP
        mov ebx, APEX_X
        push eax
        mov eax, edx
        imul eax, HX_STEP / 2
        sub ebx, eax
        pop eax
        imul eax, HX_STEP
        add ebx, eax

        ; CX = APEX_Y + row*HY_STEP
        imul edx, HY_STEP
        mov ecx, APEX_Y
        add ecx, edx

        pop edx
        pop eax
        ret

;=======================================================================
; find_hole_at — uses [click_x],[click_y] → EAX = hole (0–14) or -1
;=======================================================================
find_hole_at:
        pushad
        xor esi, esi
.fha_loop:
        cmp esi, NUM_HOLES
        jge .fha_miss

        call hole_screen_pos            ; ESI → EBX=sx, ECX=sy
        mov eax, [click_x]
        sub eax, ebx
        imul eax, eax
        mov edx, [click_y]
        sub edx, ecx
        imul edx, edx
        add eax, edx
        cmp eax, HIT_R * HIT_R
        jbe .fha_hit

        inc esi
        jmp .fha_loop

.fha_miss:
        mov dword [.ret], -1
        jmp .fha_done
.fha_hit:
        mov [.ret], esi
.fha_done:
        popad
        mov eax, [.ret]
        ret
.ret: dd 0

;=======================================================================
; has_any_jump — ECX = hole index → EAX = 1 if that peg can jump
;=======================================================================
has_any_jump:
        pushad
        movzx eax, byte [board + ecx]
        test eax, eax
        jz .no                          ; empty hole

        mov esi, ecx
        imul esi, 12
        add esi, jumptab

        mov ecx, 6
.loop:
        jecxz .no
        movzx eax, byte [esi]
        cmp al, 0xFF
        je  .no
        movzx edx, byte [esi + 1]
        ; over must have peg, land must be empty
        movzx ebx, byte [board + eax]
        test ebx, ebx
        jz  .next
        movzx ebx, byte [board + edx]
        test ebx, ebx
        jnz .next
        jmp .yes
.next:
        add esi, 2
        dec ecx
        jmp .loop
.no:
        mov dword [.ret2], 0
        jmp .done
.yes:
        mov dword [.ret2], 1
.done:
        popad
        mov eax, [.ret2]
        ret
.ret2: dd 0

;=======================================================================
; find_jump — EBX=from, ECX=to → EAX=over-hole or -1
;=======================================================================
find_jump:
        pushad
        mov [.from], ebx
        mov [.to],   ecx

        imul ebx, 12
        add  ebx, jumptab

        mov ecx, 6
.loop:
        jecxz .none
        movzx eax, byte [ebx]
        cmp al, 0xFF
        je  .none
        movzx edx, byte [ebx + 1]
        cmp edx, [.to]
        jne .next
        ; over must have peg, land must be empty
        movzx edi, byte [board + eax]
        test edi, edi
        jz  .next
        movzx edi, byte [board + edx]
        test edi, edi
        jnz .next
        mov [.over], eax
        jmp .done
.next:
        add ebx, 2
        dec ecx
        jmp .loop
.none:
        mov dword [.over], -1
.done:
        popad
        mov eax, [.over]
        ret
.from: dd 0
.to:   dd 0
.over: dd 0

;=======================================================================
; check_game_over — sets game_state if won/stuck; leaves ST_SELECT alone
;=======================================================================
check_game_over:
        pushad
        cmp dword [peg_count], 1
        je .won

        ; Look for any peg that can move
        xor esi, esi
.scan:
        cmp esi, NUM_HOLES
        jge .stuck
        movzx eax, byte [board + esi]
        test eax, eax
        jz  .next
        push esi
        mov ecx, esi
        call has_any_jump
        pop esi
        test eax, eax
        jnz .ok
.next:
        inc esi
        jmp .scan

.ok:
        popad
        ret

.won:
        mov dword [game_state], ST_WON
        ; Ascending fanfare
        mov eax, SYS_BEEP
        mov ebx, 523 ; C5
        mov ecx, 8
        int 0x80
        mov eax, SYS_SLEEP
        mov ebx, 1
        int 0x80
        mov eax, SYS_BEEP
        mov ebx, 659 ; E5
        mov ecx, 8
        int 0x80
        mov eax, SYS_SLEEP
        mov ebx, 1
        int 0x80
        mov eax, SYS_BEEP
        mov ebx, 784 ; G5
        mov ecx, 15
        int 0x80
        popad
        ret

.stuck:
        mov dword [game_state], ST_STUCK
        mov eax, SYS_BEEP
        mov ebx, 220
        mov ecx, 20
        int 0x80
        popad
        ret

;=======================================================================
; update_best — save if pegs_removed > best_score
;=======================================================================
update_best:
        pushad
        mov eax, NUM_HOLES
        sub eax, [peg_count]    ; number of pegs removed so far
        cmp eax, [best_score]
        jle .done
        mov [best_score], eax
        mov esi, hs_name
        mov ebx, eax
        call hs_save
.done:
        popad
        ret

;=======================================================================
; push_undo — snapshot board + state before a jump
; Frame size = NUM_HOLES(15) + 4(state) + 4(selected) + 4(moves) = 27
;=======================================================================
UNDO_FRAME equ 15 + 4 + 4 + 4
MAX_UNDO   equ 20

push_undo:
        pushad
        mov eax, [undo_top]
        cmp eax, MAX_UNDO
        jge .full
        imul eax, UNDO_FRAME
        add eax, undo_stack
        ; copy board
        mov esi, board
        mov edi, eax
        mov ecx, 15
        rep movsb
        ; state
        mov ebx, [game_state]
        mov [edi], ebx
        add edi, 4
        ; selected
        mov ebx, [selected]
        mov [edi], ebx
        add edi, 4
        ; move_count
        mov ebx, [move_count]
        mov [edi], ebx
        inc dword [undo_top]
.full:
        popad
        ret

undo_move:
        pushad
        cmp dword [undo_top], 0
        je .empty
        dec dword [undo_top]
        mov eax, [undo_top]
        imul eax, UNDO_FRAME
        add eax, undo_stack
        mov esi, eax
        mov edi, board
        mov ecx, 15
        rep movsb
        ; restore state (force SELECT, not JUMP)
        mov dword [game_state], ST_SELECT
        add esi, 4
        mov eax, [esi]
        mov [selected], eax
        add esi, 4
        mov eax, [esi]
        mov [move_count], eax
        call update_peg_count
        ; undo SFX
        mov eax, SYS_BEEP
        mov ebx, 440
        mov ecx, 4
        int 0x80
        call draw_all
.empty:
        popad
        ret

;=======================================================================
; draw_all
;=======================================================================
draw_all:
        pushad

        ; Background
        mov edx, COL_BG
        call vbe_clear_screen

        ; Wood board: one horizontal band per row
        call draw_board_bg

        ; All 15 holes
        xor esi, esi
.dloop:
        cmp esi, NUM_HOLES
        jge .ddone
        call draw_hole_n        ; draws hole ESI
        inc esi
        jmp .dloop
.ddone:
        call draw_ui

        VBE_GAME_PRESENT
        popad
        ret

;=======================================================================
; draw_board_bg — five widening wood-coloured horizontal bands
;=======================================================================
draw_board_bg:
        pushad
        xor ebp, ebp            ; row 0..4
.row:
        cmp ebp, 5
        jge .done

        ; left x of band = APEX_X - row*(HX_STEP/2) - PEG_R - 12
        mov eax, ebp
        imul eax, HX_STEP / 2
        mov ebx, APEX_X
        sub ebx, eax
        sub ebx, PEG_R + 14

        ; y of band = APEX_Y + row*HY_STEP - PEG_R - 10
        mov ecx, ebp
        imul ecx, HY_STEP
        add ecx, APEX_Y
        sub ecx, PEG_R + 10

        ; width = row*HX_STEP + (PEG_R+14)*2
        mov edx, ebp
        imul edx, HX_STEP
        add edx, (PEG_R + 14) * 2

        ; height = PEG_R*2 + 20
        mov esi, PEG_R * 2 + 20

        mov edi, COL_WOOD
        call vbe_fill_rect

        inc ebp
        jmp .row
.done:
        popad
        ret

;=======================================================================
; draw_hole_n — draw hole ESI (peg, empty, selected ring, valid dot, etc.)
; ESI must not be clobbered between the call and any drawing sub-call,
; so we keep the index in a local var [dhn_idx].
;=======================================================================
draw_hole_n:
        pushad
        mov [dhn_idx], esi              ; save hole index — ESI gets clobbered

        call hole_screen_pos            ; ESI→ EBX=sx, ECX=sy
        mov [dhn_sx], ebx
        mov [dhn_sy], ecx

        ; ---- PICK_START phase: all holes have pegs, highlight hovered ----
        cmp dword [game_state], ST_PICK_START
        jne .normal

        ; Draw peg
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, PEG_R
        mov esi, COL_PEG_BODY
        call vbe_fill_circle
        ; Shine
        mov ebx, [dhn_sx]
        sub ebx, PEG_R / 3
        mov ecx, [dhn_sy]
        sub ecx, PEG_R / 3
        mov edx, PEG_R / 5
        mov esi, COL_PEG_SHINE
        call vbe_fill_circle
        ; Hover ring
        mov eax, [click_x]
        sub eax, [dhn_sx]
        imul eax, eax
        mov edx, [click_y]
        sub edx, [dhn_sy]
        imul edx, edx
        add eax, edx
        cmp eax, HIT_R * HIT_R
        ja  .done
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, SEL_R
        mov esi, COL_SEL_RING
        call vbe_draw_circle
        jmp .done

.normal:
        mov eax, [dhn_idx]
        movzx eax, byte [board + eax]
        test eax, eax
        jz .empty_hole

        ; ---- Has peg ----
        ; Dim color if peg can't move (in SELECT state)
        cmp dword [game_state], ST_SELECT
        jne .draw_peg
        mov ecx, [dhn_idx]
        call has_any_jump       ; ECX=hole → EAX
        test eax, eax
        jnz .draw_peg
        ; Can't move — draw grey peg
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, PEG_R
        mov esi, COL_INVALID_PEG
        call vbe_fill_circle
        jmp .done

.draw_peg:
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, PEG_R
        mov esi, COL_PEG_BODY
        call vbe_fill_circle
        ; Shine highlight
        mov ebx, [dhn_sx]
        sub ebx, PEG_R / 3
        mov ecx, [dhn_sy]
        sub ecx, PEG_R / 3
        mov edx, PEG_R / 5
        mov esi, COL_PEG_SHINE
        call vbe_fill_circle
        ; Selection ring (JUMP state only)
        cmp dword [game_state], ST_JUMP
        jne .done
        mov eax, [dhn_idx]
        cmp eax, [selected]
        jne .done
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, SEL_R
        mov esi, COL_SEL_RING
        call vbe_draw_circle
        dec edx
        call vbe_draw_circle
        jmp .done

.empty_hole:
        ; Draw hole rim
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, HOLE_R + 2
        mov esi, COL_HOLE_RIM
        call vbe_draw_circle
        ; Dark fill
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, HOLE_R
        mov esi, COL_HOLE_BG
        call vbe_fill_circle
        ; Valid landing dot (JUMP state only)
        cmp dword [game_state], ST_JUMP
        jne .done
        mov ebx, [selected]
        mov ecx, [dhn_idx]
        call find_jump          ; EBX=from ECX=to → EAX=over or -1
        cmp eax, -1
        je  .done
        mov ebx, [dhn_sx]
        mov ecx, [dhn_sy]
        mov edx, VALID_DOT_R
        mov esi, COL_VALID_DOT
        call vbe_fill_circle

.done:
        popad
        ret

; locals for draw_hole_n
dhn_idx: dd 0
dhn_sx:  dd 0
dhn_sy:  dd 0

;=======================================================================
; draw_ui — text overlay
;=======================================================================
draw_ui:
        pushad

        ; ---- Title ----
        mov ebx, 20
        mov ecx, 16
        mov edx, str_title
        mov esi, COL_TITLE
        mov eax, 2
        call vbe_draw_str

        ; ---- Left panel: instructions ----
        mov esi, COL_GRAY
        mov eax, 1

        mov ebx, 20
        mov ecx, 620
        mov edx, str_i1
        call vbe_draw_str

        mov ecx, 638
        mov edx, str_i2
        call vbe_draw_str

        mov ecx, 656
        mov edx, str_i3
        call vbe_draw_str

        mov ecx, 674
        mov edx, str_i4
        call vbe_draw_str

        mov ecx, 692
        mov edx, str_i5
        call vbe_draw_str

        ; ---- Right panel: counters ----
        mov ebx, 700
        mov ecx, 620
        mov edx, str_moves_lbl
        mov esi, COL_WHITE
        mov eax, 1
        call vbe_draw_str
        mov ebx, 790
        mov edx, [move_count]
        call vbe_draw_num

        mov ebx, 700
        mov ecx, 638
        mov edx, str_pegs_lbl
        mov esi, COL_WHITE
        mov eax, 1
        call vbe_draw_str
        mov ebx, 790
        mov edx, [peg_count]
        call vbe_draw_num

        mov ebx, 700
        mov ecx, 656
        mov edx, str_best_lbl
        mov esi, COL_YELLOW
        mov eax, 1
        call vbe_draw_str
        mov ebx, 790
        mov edx, [best_score]
        call vbe_draw_num

        ; ---- Status message (bottom-centre) ----
        cmp dword [game_state], ST_PICK_START
        je .msg_pick
        cmp dword [game_state], ST_SELECT
        je .msg_select
        cmp dword [game_state], ST_JUMP
        je .msg_jump
        cmp dword [game_state], ST_WON
        je .msg_won
        ; ST_STUCK
        mov ebx, 300
        mov ecx, 710
        mov edx, str_stuck
        mov esi, COL_RED
        mov eax, 2
        call vbe_draw_str
        jmp .msg_done

.msg_pick:
        mov ebx, 240
        mov ecx, 716
        mov edx, str_pick
        mov esi, COL_YELLOW
        mov eax, 1
        call vbe_draw_str
        jmp .msg_done

.msg_select:
        mov ebx, 330
        mov ecx, 716
        mov edx, str_select
        mov esi, COL_WHITE
        mov eax, 1
        call vbe_draw_str
        jmp .msg_done

.msg_jump:
        mov ebx, 270
        mov ecx, 716
        mov edx, str_jump
        mov esi, COL_WHITE
        mov eax, 1
        call vbe_draw_str
        jmp .msg_done

.msg_won:
        mov ebx, 372
        mov ecx, 700
        mov edx, str_won1
        mov esi, COL_GREEN
        mov eax, 2
        call vbe_draw_str
        mov ebx, 280
        mov ecx, 738
        mov edx, str_won2
        mov esi, COL_YELLOW
        mov eax, 1
        call vbe_draw_str

.msg_done:
        popad
        ret

;=======================================================================
; BSS / data
;=======================================================================
board:        times NUM_HOLES db 0
game_state:   dd ST_PICK_START
selected:     dd -1
peg_count:    dd NUM_HOLES
move_count:   dd 0
best_score:   dd 0
hit_hole:     dd -1
click_x:      dd 0
click_y:      dd 0
last_btn:     db 0
              align 4, db 0

undo_top:     dd 0
undo_stack:   times MAX_UNDO * UNDO_FRAME db 0

hs_name:      db "peggame", 0

str_title:    db "PEG GAME", 0
str_i1:       db "CLICK A PEG TO SELECT IT", 0
str_i2:       db "GREEN DOTS SHOW VALID LANDINGS", 0
str_i3:       db "CLICK A GREEN DOT TO JUMP", 0
str_i4:       db "R-RESTART  U-UNDO  Q-QUIT", 0
str_i5:       db "GOAL: LEAVE 1 PEG", 0
str_moves_lbl: db "MOVES:", 0
str_pegs_lbl:  db "PEGS:", 0
str_best_lbl:  db "BEST:", 0
str_pick:     db "CLICK ANY PEG TO REMOVE IT AND BEGIN", 0
str_select:   db "SELECT A PEG TO MOVE", 0
str_jump:     db "CLICK A GREEN DOT TO JUMP THERE (OR CLICK PEG TO CANCEL)", 0
str_stuck:    db "NO MOVES - PRESS R TO RESTART", 0
str_won1:     db "YOU WIN!", 0
str_won2:     db "YOU LEFT 1 PEG!   R TO PLAY AGAIN", 0
