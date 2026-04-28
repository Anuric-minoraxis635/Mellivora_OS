; robotown.asm  –  Robot Town: a logic-puzzle adventure
;
; Inspired by Robot Odyssey (The Learning Company, 1984).
;
; Five single-screen puzzle rooms.  Each room contains toggle SWITCH
; tiles and chip-socket tiles.  Logic chips (AND / OR / NOT) are
; picked up or placed from/to sockets.  Chip outputs drive node
; signals; nodes control doors.  Reach the EXIT tile once every door
; in the room is open.
;
; Controls
;   Arrow keys     move player
;   E              interact: pick up placed chip, place held chip on
;                  socket, or toggle a SWITCH chip in-place
;   R              restart current level
;   ESC / Q        quit
;   ?              help overlay
;
; VBE 1024 × 768 × 32-bpp (via lib/vbe_game.inc)

%include "syscalls.inc"
%include "lib/vbe_game.inc"
%include "lib/font.inc"

;=======================================================================
; DISPLAY
;=======================================================================
SCR_W           equ 1024
SCR_H           equ 768
T               equ 32          ; tile pixel size
MAP_COLS        equ 23          ; tiles across play area
MAP_ROWS        equ 21          ; tiles down play area
MAP_DRAW_X      equ 0
MAP_DRAW_Y      equ 48          ; HUD bar height
PANEL_X         equ MAP_COLS * T   ; = 736
PANEL_W         equ SCR_W - PANEL_X ; = 288

;=======================================================================
; GAME LIMITS
;=======================================================================
MAX_LEVELS      equ 5
MAX_CHIPS       equ 8
MAX_DOORS       equ 4
MAX_NODES       equ 16          ; logical net nodes (0..15)

; Tile types
TILE_VOID       equ 0
TILE_FLOOR      equ 1
TILE_WALL       equ 2
TILE_DOOR_CL    equ 3
TILE_DOOR_OP    equ 4
TILE_EXIT       equ 5
TILE_SLOT       equ 6           ; chip socket on floor

; Chip types
CHIP_NONE       equ 0
CHIP_SWITCH     equ 1           ; player-togglable source
CHIP_AND        equ 2
CHIP_OR         equ 3
CHIP_NOT        equ 4

; ── Chip record: 12 bytes ──────────────────────────────────────────
;  [0]  type      CHIP_xxx
;  [1]  placed    0 = inventory  1 = on board
;  [2]  state     current output (0 or 1)
;  [3]  in0       node index for first input  (0xFF = none)
;  [4]  in1       node index for second input (0xFF = none / NOT only uses in0)
;  [5]  out       node index driven by output (0xFF = none)
;  [6]  col       board column when placed
;  [7]  row       board row    when placed
;  [8-11] reserved
CREC            equ 12

; ── Door record: 6 bytes ──────────────────────────────────────────
;  [0]  col       board column
;  [1]  row       board row
;  [2]  node      controlling node (0xFF = never opens)
;  [3]  state     0 = closed  1 = open
;  [4-5] reserved
DREC            equ 6

;=======================================================================
; COLOURS
;=======================================================================
C_BG            equ 0x000000
C_VOID          equ 0x060609
C_FLOOR         equ 0x181828
C_WALL          equ 0x3A3260
C_WALL_HL       equ 0x5A4FAA
C_DOOR_CL       equ 0x880000
C_DOOR_OP       equ 0x005500
C_EXIT          equ 0x008080
C_SLOT          equ 0x1E3030
C_PLAYER        equ 0xFFCC00
C_PLAYER_C      equ 0xFFFF88
C_HUD_BG        equ 0x0A0A18
C_HUD_TXT       equ 0xCCCCCC
C_PANEL_BG      equ 0x0D0D22
C_PANEL_HL      equ 0x00EE88
C_PANEL_TXT     equ 0xAAAAAA
C_CHIP_SW       equ 0xFFFF44
C_CHIP_AND      equ 0x4488FF
C_CHIP_OR       equ 0xFF8844
C_CHIP_NOT      equ 0xFF44AA
C_WIRE_HI       equ 0x00FF88
C_WIRE_LO       equ 0x333333
C_MSG_OK        equ 0x00DD44
C_MSG_ERR       equ 0xFF4444
C_MSG_INF       equ 0x44BBFF

;=======================================================================
; MACROS
;=======================================================================

; CHIP_PTR  reg, idx_reg
;   Puts address of chip_arr[idx_reg] into reg.
;   Clobbers: reg.  idx_reg must be a dword register.
%macro CHIP_PTR 2
        mov %1, %2
        imul %1, CREC
        add %1, chip_arr
%endmacro

; DOOR_PTR  reg, idx_reg
%macro DOOR_PTR 2
        mov %1, %2
        imul %1, DREC
        add %1, door_arr
%endmacro

;=======================================================================
; start
;=======================================================================
start:
        VBE_GAME_INIT

        mov eax, SYS_GETTIME
        int 0x80
        mov [rand_seed], eax

        mov dword [score], 0
        mov dword [cur_level], 0
        call load_level
        call full_redraw

;=======================================================================
; MAIN LOOP
;=======================================================================
.loop:
        VBE_GAME_POLL_KEY
        cmp eax, -1
        je .tick

        movzx eax, al

        cmp al, KEY_ESC
        je .quit
        cmp al, 'q'
        je .quit
        cmp al, 'Q'
        je .quit
        cmp al, 'r'
        je .restart
        cmp al, 'R'
        je .restart
        cmp al, '?'
        je .help

        cmp dword [game_won], 1
        je .tick

        cmp al, KEY_UP
        jne .ck_dn
        mov ebx, 0
        mov ecx, -1
        call try_move
        jmp .tick
.ck_dn:
        cmp al, KEY_DOWN
        jne .ck_lf
        mov ebx, 0
        mov ecx, 1
        call try_move
        jmp .tick
.ck_lf:
        cmp al, KEY_LEFT
        jne .ck_rt
        mov ebx, -1
        mov ecx, 0
        call try_move
        jmp .tick
.ck_rt:
        cmp al, KEY_RIGHT
        jne .ck_e
        mov ebx, 1
        mov ecx, 0
        call try_move
        jmp .tick
.ck_e:
        cmp al, 'e'
        je .do_e
        cmp al, 'E'
        jne .tick
.do_e:
        call do_interact
        jmp .tick
.help:
        call show_help
        jmp .loop
.restart:
        call load_level
        call full_redraw
        jmp .loop
.tick:
        call simulate_logic
        call full_redraw
        mov eax, SYS_SLEEP
        mov ebx, 3
        int 0x80
        jmp .loop
.quit:
        mov eax, SYS_FRAMEBUF
        mov ebx, 2
        int 0x80
        mov eax, SYS_EXIT
        xor ebx, ebx
        int 0x80

;=======================================================================
; try_move  EBX=dx  ECX=dy
;=======================================================================
try_move:
        pushad
        mov eax, [player_x]
        add eax, ebx            ; nx
        mov edx, [player_y]
        add edx, ecx            ; ny

        ; Bounds
        cmp eax, 0
        jl .done
        cmp eax, MAP_COLS - 1
        jg .done
        cmp edx, 0
        jl .done
        cmp edx, MAP_ROWS - 1
        jg .done

        ; Tile lookup
        mov esi, edx
        imul esi, MAP_COLS
        add esi, eax
        movzx edi, byte [level_map + esi]

        cmp edi, TILE_WALL
        je .done
        cmp edi, TILE_VOID
        je .done

        ; Closed door – check if open in door array
        cmp edi, TILE_DOOR_CL
        jne .walkable

        ; Search door array for (eax,edx)
        push eax
        push edx
        call find_door          ; returns door index in EAX, or -1
        cmp eax, -1
        je .door_blocked
        DOOR_PTR esi, eax
        movzx edi, byte [esi + 3]   ; state
        test edi, edi
        jz .door_blocked
        pop edx
        pop eax
        jmp .walkable

.door_blocked:
        pop edx
        pop eax
        jmp .done

.walkable:
        mov [player_x], eax
        mov [player_y], edx

        ; Check exit
        cmp edi, TILE_EXIT
        jne .done
        call on_exit

.done:
        popad
        ret

;=======================================================================
; find_door  EAX=col  EDX=row  →  EAX=door_idx or -1
;=======================================================================
find_door:
        push ebx
        push ecx
        push esi
        xor ecx, ecx
.fd_lp:
        cmp ecx, [num_doors]
        jge .fd_miss
        DOOR_PTR esi, ecx
        movzx ebx, byte [esi]       ; col
        cmp bl, al
        jne .fd_next
        movzx ebx, byte [esi + 1]   ; row
        cmp bl, dl
        je .fd_found
.fd_next:
        inc ecx
        jmp .fd_lp
.fd_miss:
        mov eax, -1
        pop esi
        pop ecx
        pop ebx
        ret
.fd_found:
        mov eax, ecx
        pop esi
        pop ecx
        pop ebx
        ret

;=======================================================================
; simulate_logic  —  evaluate chips, propagate nodes, update doors
;=======================================================================
simulate_logic:
        pushad

        ; Clear node signals
        mov edi, node_sig
        mov ecx, MAX_NODES
        xor al, al
        rep stosb

        ; Pass 1: SWITCH chips drive their output node
        xor esi, esi
.sw_pass:
        cmp esi, [num_chips]
        jge .chip_pass
        CHIP_PTR edi, esi
        movzx eax, byte [edi]       ; type
        cmp al, CHIP_SWITCH
        jne .sw_next
        movzx eax, byte [edi + 1]   ; placed?
        test eax, eax
        jz .sw_next
        movzx ecx, byte [edi + 5]   ; out node
        cmp cl, 0xFF
        je .sw_next
        movzx eax, byte [edi + 2]   ; state (0/1)
        mov [node_sig + ecx], al
.sw_next:
        inc esi
        jmp .sw_pass

        ; Pass 2: logic chips
.chip_pass:
        xor esi, esi
.cp_lp:
        cmp esi, [num_chips]
        jge .door_pass
        CHIP_PTR edi, esi
        movzx eax, byte [edi]       ; type
        cmp al, CHIP_SWITCH
        je .cp_next
        movzx eax, byte [edi + 1]   ; placed?
        test eax, eax
        jz .cp_next

        ; in0
        movzx ecx, byte [edi + 3]
        cmp cl, 0xFF
        je .cp_in0_lo
        movzx ebx, byte [node_sig + ecx]
        jmp .cp_in0_ok
.cp_in0_lo:
        xor ebx, ebx
.cp_in0_ok:
        ; in1
        movzx ecx, byte [edi + 4]
        cmp cl, 0xFF
        je .cp_in1_lo
        movzx edx, byte [node_sig + ecx]
        jmp .cp_in1_ok
.cp_in1_lo:
        xor edx, edx
.cp_in1_ok:
        ; evaluate
        movzx eax, byte [edi]       ; type
        cmp al, CHIP_AND
        jne .cp_or
        and ebx, edx
        jmp .cp_result
.cp_or:
        cmp al, CHIP_OR
        jne .cp_not
        or ebx, edx
        jmp .cp_result
.cp_not:
        ; NOT: invert in0
        xor ebx, 1
.cp_result:
        mov byte [edi + 2], bl      ; save chip output state
        movzx ecx, byte [edi + 5]   ; out node
        cmp cl, 0xFF
        je .cp_next
        mov [node_sig + ecx], bl
.cp_next:
        inc esi
        jmp .cp_lp

        ; Pass 3: update doors
.door_pass:
        xor esi, esi
.dp_lp:
        cmp esi, [num_doors]
        jge .done
        DOOR_PTR edi, esi
        movzx ecx, byte [edi + 2]   ; controlling node
        cmp cl, 0xFF
        je .dp_next
        movzx ebx, byte [node_sig + ecx]
        mov byte [edi + 3], bl      ; door state
        ; Sync tile
        movzx eax, byte [edi]       ; col
        movzx edx, byte [edi + 1]   ; row
        push eax
        imul edx, MAP_COLS
        add edx, eax
        pop eax
        test bl, bl
        jz .dp_close
        mov byte [level_map + edx], TILE_DOOR_OP
        jmp .dp_next
.dp_close:
        mov byte [level_map + edx], TILE_DOOR_CL
.dp_next:
        inc esi
        jmp .dp_lp
.done:
        popad
        ret

;=======================================================================
; do_interact  —  E key handler
;=======================================================================
do_interact:
        pushad
        mov eax, [player_x]
        mov edx, [player_y]

        ; Look for a SWITCH chip at player position
        call find_switch_at     ; EAX=chip_idx or -1
        cmp eax, -1
        jne .toggle_sw

        ; Look for a non-switch chip at player position (pick up)
        call find_chip_at       ; EAX=chip_idx or -1
        cmp eax, -1
        jne .pick_up

        ; If holding a chip, try to place it on a SLOT tile
        cmp dword [held_chip], -1
        je .done

        ; Is current tile a SLOT?
        mov esi, edx
        imul esi, MAP_COLS
        add esi, eax
        movzx edi, byte [level_map + esi]
        cmp edi, TILE_SLOT
        jne .done
        call place_chip
        jmp .done

.toggle_sw:
        CHIP_PTR edi, eax
        movzx ecx, byte [edi + 2]
        xor ecx, 1
        mov byte [edi + 2], cl
        ; beep
        push eax
        mov eax, SYS_BEEP
        mov ebx, 660
        mov ecx, 2
        int 0x80
        pop eax
        jmp .done

.pick_up:
        CHIP_PTR edi, eax
        mov byte [edi + 1], 0       ; unplace
        mov [held_chip], eax
        mov esi, msg_picked
        call set_msg
        jmp .done

.done:
        popad
        ret

;-----------------------------------------------------------------------
; find_switch_at  EAX=col  EDX=row  → EAX=chip_idx/-1
;-----------------------------------------------------------------------
find_switch_at:
        push ebx
        push ecx
        push esi
        xor ecx, ecx
.fsa_lp:
        cmp ecx, [num_chips]
        jge .fsa_miss
        CHIP_PTR esi, ecx
        movzx ebx, byte [esi]       ; type
        cmp bl, CHIP_SWITCH
        jne .fsa_next
        movzx ebx, byte [esi + 1]   ; placed
        test ebx, ebx
        jz .fsa_next
        movzx ebx, byte [esi + 6]   ; col
        cmp bl, al
        jne .fsa_next
        movzx ebx, byte [esi + 7]   ; row
        cmp bl, dl
        je .fsa_found
.fsa_next:
        inc ecx
        jmp .fsa_lp
.fsa_miss:
        mov eax, -1
        pop esi
        pop ecx
        pop ebx
        ret
.fsa_found:
        mov eax, ecx
        pop esi
        pop ecx
        pop ebx
        ret

;-----------------------------------------------------------------------
; find_chip_at  EAX=col  EDX=row  → EAX=chip_idx/-1  (non-switch only)
;-----------------------------------------------------------------------
find_chip_at:
        push ebx
        push ecx
        push esi
        xor ecx, ecx
.fca_lp:
        cmp ecx, [num_chips]
        jge .fca_miss
        CHIP_PTR esi, ecx
        movzx ebx, byte [esi]       ; type
        cmp bl, CHIP_SWITCH
        je .fca_next
        movzx ebx, byte [esi + 1]   ; placed
        test ebx, ebx
        jz .fca_next
        movzx ebx, byte [esi + 6]   ; col
        cmp bl, al
        jne .fca_next
        movzx ebx, byte [esi + 7]   ; row
        cmp bl, dl
        je .fca_found
.fca_next:
        inc ecx
        jmp .fca_lp
.fca_miss:
        mov eax, -1
        pop esi
        pop ecx
        pop ebx
        ret
.fca_found:
        mov eax, ecx
        pop esi
        pop ecx
        pop ebx
        ret

;-----------------------------------------------------------------------
; place_chip  —  place [held_chip] at [player_x],[player_y]
;-----------------------------------------------------------------------
place_chip:
        push eax
        push edi
        mov eax, [held_chip]
        CHIP_PTR edi, eax
        push dword [player_x]
        pop ecx
        mov byte [edi + 6], cl
        push dword [player_y]
        pop ecx
        mov byte [edi + 7], cl
        mov byte [edi + 1], 1       ; placed
        mov dword [held_chip], -1
        mov esi, msg_placed
        call set_msg
        ; beep
        push eax
        mov eax, SYS_BEEP
        mov ebx, 440
        mov ecx, 3
        int 0x80
        pop eax
        pop edi
        pop eax
        ret

;=======================================================================
; on_exit  —  player stepped on EXIT tile
;=======================================================================
on_exit:
        pushad

        ; Check all doors open
        xor esi, esi
.oe_chk:
        cmp esi, [num_doors]
        jge .oe_win
        DOOR_PTR edi, esi
        movzx eax, byte [edi + 3]
        test eax, eax
        jz .oe_locked
        inc esi
        jmp .oe_chk
.oe_locked:
        mov esi, msg_locked
        call set_msg
        jmp .oe_done

.oe_win:
        add dword [score], 1000
        call play_fanfare

        inc dword [cur_level]
        cmp dword [cur_level], MAX_LEVELS
        jl .oe_next_level

        mov dword [game_won], 1
        mov esi, msg_youwin
        call set_msg
        jmp .oe_done

.oe_next_level:
        call load_level
.oe_done:
        popad
        ret

;=======================================================================
; set_msg  ESI = source NUL-terminated string → msg_buf
;=======================================================================
set_msg:
        push esi
        push edi
        push ecx
        mov edi, msg_buf
        mov ecx, 80
.sm_lp:
        lodsb
        stosb
        test al, al
        jz .sm_done
        dec ecx
        jnz .sm_lp
        mov byte [edi - 1], 0
.sm_done:
        pop ecx
        pop edi
        pop esi
        ret

;=======================================================================
; play_fanfare
;=======================================================================
play_fanfare:
        pushad
        mov eax, SYS_BEEP
        mov ebx, 523
        mov ecx, 8
        int 0x80
        mov eax, SYS_BEEP
        mov ebx, 659
        mov ecx, 8
        int 0x80
        mov eax, SYS_BEEP
        mov ebx, 784
        mov ecx, 12
        int 0x80
        popad
        ret

;=======================================================================
; LEVEL LOADING
;=======================================================================
load_level:
        pushad

        ; Zero arrays
        mov edi, chip_arr
        mov ecx, MAX_CHIPS * CREC
        xor al, al
        rep stosb

        mov edi, door_arr
        mov ecx, MAX_DOORS * DREC
        xor al, al
        rep stosb

        mov edi, node_sig
        mov ecx, MAX_NODES
        xor al, al
        rep stosb

        mov dword [held_chip], -1
        mov dword [game_won], 0

        mov eax, [cur_level]
        cmp eax, 0
        je .l0
        cmp eax, 1
        je .l1
        cmp eax, 2
        je .l2
        cmp eax, 3
        je .l3
        cmp eax, 4
        je .l4
        jmp .l0
.l0:    call init_level0
        jmp .done
.l1:    call init_level1
        jmp .done
.l2:    call init_level2
        jmp .done
.l3:    call init_level3
        jmp .done
.l4:    call init_level4
.done:
        popad
        ret

;-----------------------------------------------------------------------
; copy_map  ESI = source map bytes (MAP_COLS*MAP_ROWS)
;-----------------------------------------------------------------------
copy_map:
        push esi
        push edi
        push ecx
        mov edi, level_map
        mov ecx, MAP_COLS * MAP_ROWS
        rep movsb
        pop ecx
        pop edi
        pop esi
        ret

;-----------------------------------------------------------------------
; add_door  AL=col  AH=row  BL=node  BH=state
;-----------------------------------------------------------------------
add_door:
        push edi
        push eax
        push ebx
        mov ecx, [num_doors]
        DOOR_PTR edi, ecx
        mov [edi],     al           ; col
        mov [edi + 1], ah           ; row
        mov [edi + 2], bl           ; node
        mov [edi + 3], bh           ; state
        inc dword [num_doors]
        pop ebx
        pop eax
        pop edi
        ret

;-----------------------------------------------------------------------
; add_chip  AL=type  AH=placed  BL=in0  BH=in1  CL=out  CH=col  DL=row  DH=state
;-----------------------------------------------------------------------
add_chip:
        push edi
        push eax
        push ecx
        push edx
        mov esi, [num_chips]
        CHIP_PTR edi, esi
        mov [edi],     al           ; type
        mov [edi + 1], ah           ; placed
        mov [edi + 2], dh           ; state (initial output)
        mov [edi + 3], bl           ; in0
        mov [edi + 4], bh           ; in1
        mov [edi + 5], cl           ; out node
        mov [edi + 6], ch           ; col
        mov [edi + 7], dl           ; row
        inc dword [num_chips]
        pop edx
        pop ecx
        pop eax
        pop edi
        ret

;=======================================================================
; LEVEL 0 — Tutorial
;
;  Room:  left half has a SWITCH (col 5, row 10) and a socket (col 9, row 10).
;         NOT chip is in inventory.  Door at col 13, row 10, node 1.
;         Switch OFF → NOT → HIGH → door opens.
;         Hint: switch is OFF by default, so placing NOT immediately opens door.
;=======================================================================
init_level0:
        pushad
        mov dword [num_chips], 0
        mov dword [num_doors], 0
        mov dword [player_x], 2
        mov dword [player_y], 10

        mov esi, map_l0
        call copy_map

        ; SWITCH at (5,10), placed, out=node0, starts OFF
        ;  add_chip: AL=type AH=placed BL=in0 BH=in1 CL=out CH=col DL=row DH=state
        mov al, CHIP_SWITCH
        mov ah, 1               ; placed
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 0               ; drives node 0
        mov ch, 5               ; col
        mov dl, 10              ; row
        mov dh, 0               ; state=OFF
        call add_chip

        ; NOT chip in inventory: in0=node0, out=node1
        mov al, CHIP_NOT
        mov ah, 0               ; in inventory
        mov bl, 0               ; in0=node0
        mov bh, 0xFF
        mov cl, 1               ; out=node1
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        ; Door at (13,10), node 1
        mov al, 13              ; col
        mov ah, 10              ; row
        mov bl, 1               ; node
        mov bh, 0               ; closed
        call add_door

        mov esi, msg_l0
        call set_msg
        popad
        ret

;=======================================================================
; LEVEL 1 — AND gate
;  Two switches (col 5,row 8) and (col 5,row 12).
;  AND chip in inventory: in0=node0, in1=node1, out=node2.
;  Socket at (10,10).  Door at (16,10), node 2.
;=======================================================================
init_level1:
        pushad
        mov dword [num_chips], 0
        mov dword [num_doors], 0
        mov dword [player_x], 2
        mov dword [player_y], 10

        mov esi, map_l1
        call copy_map

        ; SWITCH A at (5,8), out=node0, OFF
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 0
        mov ch, 5
        mov dl, 8
        mov dh, 0
        call add_chip

        ; SWITCH B at (5,12), out=node1, OFF
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 1
        mov ch, 5
        mov dl, 12
        mov dh, 0
        call add_chip

        ; AND chip in inventory: in0=0, in1=1, out=2
        mov al, CHIP_AND
        mov ah, 0
        mov bl, 0
        mov bh, 1
        mov cl, 2
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        ; Door at (16,10), node 2
        mov al, 16
        mov ah, 10
        mov bl, 2
        mov bh, 0
        call add_door

        mov esi, msg_l1
        call set_msg
        popad
        ret

;=======================================================================
; LEVEL 2 — OR gate
;  Same layout as level 1 but OR chip.  Door opens when EITHER switch ON.
;=======================================================================
init_level2:
        pushad
        mov dword [num_chips], 0
        mov dword [num_doors], 0
        mov dword [player_x], 2
        mov dword [player_y], 10

        mov esi, map_l2
        call copy_map

        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 0
        mov ch, 5
        mov dl, 8
        mov dh, 0
        call add_chip

        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 1
        mov ch, 5
        mov dl, 12
        mov dh, 0
        call add_chip

        ; OR chip in inventory: in0=0, in1=1, out=2
        mov al, CHIP_OR
        mov ah, 0
        mov bl, 0
        mov bh, 1
        mov cl, 2
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        mov al, 16
        mov ah, 10
        mov bl, 2
        mov bh, 0
        call add_door

        mov esi, msg_l2
        call set_msg
        popad
        ret

;=======================================================================
; LEVEL 3 — NOT chained into AND
;  SW_A (col 4,row 8) starts ON → NOT → node1.
;  SW_B (col 4,row 12) starts OFF → node2.
;  AND(node1,node2) → node3.  Door at (18,10), node3.
;  Player must: turn SW_A OFF (so NOT→HIGH) and SW_B ON.
;=======================================================================
init_level3:
        pushad
        mov dword [num_chips], 0
        mov dword [num_doors], 0
        mov dword [player_x], 2
        mov dword [player_y], 10

        mov esi, map_l3
        call copy_map

        ; SW_A at (4,8), node0, starts ON
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 0
        mov ch, 4
        mov dl, 8
        mov dh, 1               ; ON
        call add_chip

        ; SW_B at (4,12), node2, starts OFF
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 2
        mov ch, 4
        mov dl, 12
        mov dh, 0
        call add_chip

        ; NOT in inventory: in0=node0, out=node1
        mov al, CHIP_NOT
        mov ah, 0
        mov bl, 0
        mov bh, 0xFF
        mov cl, 1
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        ; AND in inventory: in0=node1, in1=node2, out=node3
        mov al, CHIP_AND
        mov ah, 0
        mov bl, 1
        mov bh, 2
        mov cl, 3
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        mov al, 18
        mov ah, 10
        mov bl, 3
        mov bh, 0
        call add_door

        mov esi, msg_l3
        call set_msg
        popad
        ret

;=======================================================================
; LEVEL 4 — Final: two doors, three logic chips
;
;  SW_A (4,6) OFF  → node0         SW_B (4,10) ON  → node1
;  SW_C (4,14) OFF → node2         SW_D (4,17) OFF → node3
;
;  NOT(node1) → node5.
;  AND(node0, node5) → node4  →  Door A at (16,8)
;  OR (node2, node3) → node6  →  Door B at (16,15)
;
;  Solution: SW_A=ON, SW_B=OFF, SW_C or SW_D = ON.
;=======================================================================
init_level4:
        pushad
        mov dword [num_chips], 0
        mov dword [num_doors], 0
        mov dword [player_x], 2
        mov dword [player_y], 10

        mov esi, map_l4
        call copy_map

        ; SW_A (4,6) → node0, OFF
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 0
        mov ch, 4
        mov dl, 6
        mov dh, 0
        call add_chip

        ; SW_B (4,10) → node1, ON
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 1
        mov ch, 4
        mov dl, 10
        mov dh, 1
        call add_chip

        ; SW_C (4,14) → node2, OFF
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 2
        mov ch, 4
        mov dl, 14
        mov dh, 0
        call add_chip

        ; SW_D (4,17) → node3, OFF
        mov al, CHIP_SWITCH
        mov ah, 1
        mov bl, 0xFF
        mov bh, 0xFF
        mov cl, 3
        mov ch, 4
        mov dl, 17
        mov dh, 0
        call add_chip

        ; NOT inventory: in0=node1, out=node5
        mov al, CHIP_NOT
        mov ah, 0
        mov bl, 1
        mov bh, 0xFF
        mov cl, 5
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        ; AND inventory: in0=node0, in1=node5, out=node4
        mov al, CHIP_AND
        mov ah, 0
        mov bl, 0
        mov bh, 5
        mov cl, 4
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        ; OR inventory: in0=node2, in1=node3, out=node6
        mov al, CHIP_OR
        mov ah, 0
        mov bl, 2
        mov bh, 3
        mov cl, 6
        mov ch, 0
        mov dl, 0
        mov dh, 0
        call add_chip

        ; Door A at (16,8), node4
        mov al, 16
        mov ah, 8
        mov bl, 4
        mov bh, 0
        call add_door

        ; Door B at (16,15), node6
        mov al, 16
        mov ah, 15
        mov bl, 6
        mov bh, 0
        call add_door

        mov esi, msg_l4
        call set_msg
        popad
        ret

;=======================================================================
; RENDERING
;=======================================================================
full_redraw:
        pushad
        mov edx, C_BG
        call vbe_clear_screen
        call draw_hud
        call draw_tiles
        call draw_chips_on_board
        call draw_player
        call draw_panel
        VBE_GAME_PRESENT
        popad
        ret

;-----------------------------------------------------------------------
; draw_hud — 48-pixel bar at top
;-----------------------------------------------------------------------
draw_hud:
        pushad

        ; Bar background
        xor ebx, ebx
        xor ecx, ecx
        mov edx, SCR_W
        mov esi, MAP_DRAW_Y
        mov edi, C_HUD_BG
        call vbe_fill_rect

        ; Title
        mov ebx, 8
        mov ecx, 16
        mov esi, str_title
        mov edi, C_PANEL_HL
        call fb_draw_text

        ; Level
        mov ebx, 220
        mov ecx, 16
        mov esi, str_lev
        mov edi, C_HUD_TXT
        call fb_draw_text

        mov eax, [cur_level]
        inc eax
        mov ebx, 272
        mov ecx, 16
        mov edi, C_PANEL_HL
        call fb_draw_num

        ; Score
        mov ebx, 340
        mov ecx, 16
        mov esi, str_score
        mov edi, C_HUD_TXT
        call fb_draw_text

        mov eax, [score]
        mov ebx, 400
        mov ecx, 16
        mov edi, C_PANEL_HL
        call fb_draw_num

        ; Message (right side of HUD)
        mov ebx, 520
        mov ecx, 16
        mov esi, msg_buf
        mov edi, C_MSG_INF
        call fb_draw_text

        popad
        ret

;-----------------------------------------------------------------------
; draw_tiles — render MAP_COLS × MAP_ROWS tile grid
;-----------------------------------------------------------------------
draw_tiles:
        pushad
        xor esi, esi            ; row
.dt_row:
        cmp esi, MAP_ROWS
        jge .dt_done
        xor edi, edi            ; col
.dt_col:
        cmp edi, MAP_COLS
        jge .dt_next_row

        ; Save row/col BEFORE tile_colour clobbers EDI
        mov [esi_bak], esi      ; row
        mov [edi_bak], edi      ; col

        ; tile type
        mov eax, esi
        imul eax, MAP_COLS
        add eax, edi
        movzx ecx, byte [level_map + eax]

        ; pixel origin (computed while edi still = col)
        mov ebx, edi
        imul ebx, T
        add ebx, MAP_DRAW_X
        push ebx                ; px_x
        mov ebx, esi
        imul ebx, T
        add ebx, MAP_DRAW_Y
        push ebx                ; px_y

        ; pick colour → EDI=colour (clobbers col counter)
        call tile_colour

        ; Draw tile background: vbe_fill_rect(EBX=x, ECX=y, EDX=w, ESI=h, EDI=colour)
        pop ecx                 ; px_y
        pop ebx                 ; px_x
        mov edx, T
        mov esi, T
        call vbe_fill_rect

        ; Restore row/col loop vars
        mov esi, [esi_bak]      ; row
        mov edi, [edi_bak]      ; col

        ; Draw tile overlay using correct pixel coordinates
        push eax
        mov ebx, edi
        imul ebx, T
        add ebx, MAP_DRAW_X     ; px_x
        mov ecx, esi
        imul ecx, T
        add ecx, MAP_DRAW_Y     ; px_y
        mov eax, [esi_bak]
        imul eax, MAP_COLS
        add eax, [edi_bak]
        movzx eax, byte [level_map + eax]
        call draw_tile_overlay  ; EAX=type, EBX=px_x, ECX=px_y
        pop eax

        inc edi
        jmp .dt_col
.dt_next_row:
        inc esi
        jmp .dt_row
.dt_done:
        popad
        ret

; tile_colour  ECX=tile_type → EDI=colour
tile_colour:
        cmp ecx, TILE_VOID
        je .tc_void
        cmp ecx, TILE_FLOOR
        je .tc_floor
        cmp ecx, TILE_WALL
        je .tc_wall
        cmp ecx, TILE_DOOR_CL
        je .tc_dcl
        cmp ecx, TILE_DOOR_OP
        je .tc_dop
        cmp ecx, TILE_EXIT
        je .tc_exit
        cmp ecx, TILE_SLOT
        je .tc_slot
        mov edi, C_FLOOR
        ret
.tc_void:  mov edi, C_VOID
           ret
.tc_floor: mov edi, C_FLOOR
           ret
.tc_wall:  mov edi, C_WALL
           ret
.tc_dcl:   mov edi, C_DOOR_CL
           ret
.tc_dop:   mov edi, C_DOOR_OP
           ret
.tc_exit:  mov edi, C_EXIT
           ret
.tc_slot:  mov edi, C_SLOT
           ret

; draw_tile_overlay  EAX=tile, EBX=px_x, ECX=px_y
draw_tile_overlay:
        pushad
        cmp al, TILE_EXIT
        jne .dto_done
        add ebx, T/2 - 5
        add ecx, T/2 - 4
        mov edx, '>'
        mov esi, 0xFFFFFF
        mov eax, 2
        call vbe_draw_char
.dto_done:
        popad
        ret

;-----------------------------------------------------------------------
; draw_chips_on_board — draw placed chips
;-----------------------------------------------------------------------
draw_chips_on_board:
        pushad
        xor esi, esi
.dcb_lp:
        cmp esi, [num_chips]
        jge .dcb_done
        CHIP_PTR edi, esi
        movzx eax, byte [edi + 1]   ; placed?
        test eax, eax
        jz .dcb_next

        movzx ebx, byte [edi + 6]   ; col
        movzx ecx, byte [edi + 7]   ; row
        imul ebx, T
        add ebx, MAP_DRAW_X
        imul ecx, T
        add ecx, MAP_DRAW_Y

        movzx eax, byte [edi]       ; type
        movzx edx, byte [edi + 2]   ; state

        push esi
        push edi
        call draw_chip_icon         ; EAX=type, EBX=px_x, ECX=px_y, EDX=state
        pop edi
        pop esi

.dcb_next:
        inc esi
        jmp .dcb_lp
.dcb_done:
        popad
        ret

; draw_chip_icon  EAX=type, EBX=px_x, ECX=px_y, EDX=state(0/1)
draw_chip_icon:
        pushad

        ; Choose body colour
        cmp al, CHIP_SWITCH
        je .ci_sw_col
        cmp al, CHIP_AND
        je .ci_and_col
        cmp al, CHIP_OR
        je .ci_or_col
        ; NOT / default
        mov edi, C_CHIP_NOT
        jmp .ci_body
.ci_sw_col:
        mov edi, C_CHIP_SW
        jmp .ci_body
.ci_and_col:
        mov edi, C_CHIP_AND
        jmp .ci_body
.ci_or_col:
        mov edi, C_CHIP_OR

.ci_body:
        ; Inset square: T/4 inset each side → T/2 × T/2
        push ebx
        push ecx
        push edx
        add ebx, T/4
        add ecx, T/4
        mov edx, T/2
        mov esi, T/2
        call vbe_fill_rect
        pop edx
        pop ecx
        pop ebx

        ; Letter label in centre
        push ebx
        push ecx
        add ebx, T/4 + 2
        add ecx, T/4 + 2

        ; Build label char from saved EAX (pushad: EAX at [esp+28])
        mov eax, [esp + 28]
        cmp al, CHIP_SWITCH
        je .ci_lbl_sw
        cmp al, CHIP_AND
        je .ci_lbl_and
        cmp al, CHIP_OR
        je .ci_lbl_or
        ; NOT
        mov edx, 'N'
        jmp .ci_lbl_draw
.ci_lbl_sw:
        ; show '0' or '1' based on state
        movzx edx, byte [esp + 16]  ; EDX original (state) after pushad
        add edx, '0'
        jmp .ci_lbl_draw
.ci_lbl_and:
        mov edx, 'A'
        jmp .ci_lbl_draw
.ci_lbl_or:
        mov edx, 'O'
.ci_lbl_draw:
        mov esi, 0xFFFFFF
        mov eax, 2
        call vbe_draw_char
        pop ecx
        pop ebx

        ; Small output signal dot (top-right corner, 5×5)
        push ebx
        push ecx
        add ebx, T - 7
        add ecx, 2
        mov edx, 5
        mov esi, 5
        ; state from original EDX
        mov eax, [esp + 16 + 8]     ; EDX pushed in pushad
        ; Actually re-read from the saved EDX in pushad frame:
        ; PUSHAD pushes EAX ECX EDX EBX ESP EBP ESI EDI  (32 bytes)
        ; After our own 3 push/pop pairs the esp is back to pushad frame.
        ; Original EDX at [esp + 8 + 16] = [esp+24]? Let's use safe approach:
        mov eax, [esp + 28]         ; original EAX (type)
        CHIP_PTR edi, eax
        ; No – use [edi+2] state directly
        ; Actually we need chip index; use indirect approach through pushed EAX
        ; Simplification: use a local temp
        ; For SWITCH, the state is the 3rd byte of the chip record. For others it's the computed output.
        ; We know type from [esp+28], and chip_arr is iterated outside – but we don't have index here.
        ; Safest: just use the colour we already know. Green if state HIGH.
        ; We'll read edi+2 since edi still points to the chip record from draw_chips_on_board caller.
        ; But edi was pushed in pushad. Retrieve original EDI from frame.
        mov edi, [esp + 0]          ; original EDI (chip record pointer)
        movzx eax, byte [edi + 2]   ; state
        test eax, eax
        jz .ci_dot_lo
        mov edi, C_WIRE_HI
        jmp .ci_dot_draw
.ci_dot_lo:
        mov edi, 0x333333
.ci_dot_draw:
        call vbe_fill_rect
        pop ecx
        pop ebx

        popad
        ret

;-----------------------------------------------------------------------
; draw_player
;-----------------------------------------------------------------------
draw_player:
        pushad
        mov ebx, [player_x]
        imul ebx, T
        add ebx, MAP_DRAW_X + T/4
        mov ecx, [player_y]
        imul ecx, T
        add ecx, MAP_DRAW_Y + T/4
        mov edx, T/2
        mov esi, T/2
        mov edi, C_PLAYER
        call vbe_fill_rect

        ; centre dot
        add ebx, T/4 - 3
        add ecx, T/4 - 3
        mov edx, 6
        mov esi, 6
        mov edi, C_PLAYER_C
        call vbe_fill_rect

        popad
        ret

;-----------------------------------------------------------------------
; draw_panel — right-side status panel
;-----------------------------------------------------------------------
draw_panel:
        pushad

        ; Background
        mov ebx, PANEL_X
        xor ecx, ecx
        mov edx, PANEL_W
        mov esi, SCR_H
        mov edi, C_PANEL_BG
        call vbe_fill_rect

        ; Separator line
        mov ebx, PANEL_X
        xor ecx, ecx
        mov edx, 2
        mov esi, SCR_H
        mov edi, C_WALL_HL
        call vbe_fill_rect

        mov dword [dp_y], MAP_DRAW_Y + 8

        ; Title
        mov ebx, PANEL_X + 8
        mov ecx, [dp_y]
        mov esi, str_inventory
        mov edi, C_PANEL_HL
        call fb_draw_text
        add dword [dp_y], 18

        ; List inventory chips
        xor esi, esi
.dp_inv:
        cmp esi, [num_chips]
        jge .dp_doors
        CHIP_PTR edi, esi
        movzx eax, byte [edi + 1]   ; placed?
        test eax, eax
        jnz .dp_inv_next

        ; Show chip name
        movzx eax, byte [edi]       ; type
        push esi
        call chip_name_ptr          ; → EAX = string ptr
        mov esi, eax
        mov ebx, PANEL_X + 8
        mov ecx, [dp_y]
        mov edi, C_PANEL_TXT
        call fb_draw_text
        add dword [dp_y], 14
        pop esi

.dp_inv_next:
        inc esi
        jmp .dp_inv

.dp_doors:
        add dword [dp_y], 6
        mov ebx, PANEL_X + 8
        mov ecx, [dp_y]
        mov esi, str_doors
        mov edi, C_PANEL_HL
        call fb_draw_text
        add dword [dp_y], 18

        xor esi, esi
.dp_dr:
        cmp esi, [num_doors]
        jge .dp_hold
        DOOR_PTR edi, esi
        movzx eax, byte [edi + 3]   ; state
        mov ebx, PANEL_X + 8
        mov ecx, [dp_y]
        test eax, eax
        jz .dp_dr_cl
        push esi
        mov esi, str_open
        mov edi, C_MSG_OK
        call fb_draw_text
        pop esi
        jmp .dp_dr_next
.dp_dr_cl:
        push esi
        mov esi, str_locked_d
        mov edi, C_MSG_ERR
        call fb_draw_text
        pop esi
.dp_dr_next:
        add dword [dp_y], 14
        inc esi
        jmp .dp_dr

.dp_hold:
        add dword [dp_y], 6
        mov ebx, PANEL_X + 8
        mov ecx, [dp_y]
        mov esi, str_holding
        mov edi, C_PANEL_HL
        call fb_draw_text
        add dword [dp_y], 14

        mov ebx, PANEL_X + 8
        mov ecx, [dp_y]
        mov eax, [held_chip]
        cmp eax, -1
        je .dp_hold_none
        CHIP_PTR edi, eax
        movzx eax, byte [edi]
        call chip_name_ptr
        mov esi, eax
        mov edi, C_CHIP_AND
        call fb_draw_text
        jmp .dp_ctrl

.dp_hold_none:
        mov esi, str_none
        mov edi, 0x666666
        call fb_draw_text

.dp_ctrl:
        ; Controls at bottom
        mov ebx, PANEL_X + 4
        mov ecx, SCR_H - 100
        mov esi, str_c1
        mov edi, 0x556677
        call fb_draw_text
        mov ecx, SCR_H - 86
        mov esi, str_c2
        call fb_draw_text
        mov ecx, SCR_H - 72
        mov esi, str_c3
        call fb_draw_text
        mov ecx, SCR_H - 58
        mov esi, str_c4
        call fb_draw_text
        mov ecx, SCR_H - 44
        mov esi, str_c5
        call fb_draw_text

        popad
        ret

; chip_name_ptr  EAX=type → EAX=str ptr
chip_name_ptr:
        cmp al, CHIP_SWITCH
        je .cp_sw
        cmp al, CHIP_AND
        je .cp_and
        cmp al, CHIP_OR
        je .cp_or
        cmp al, CHIP_NOT
        je .cp_not
        mov eax, str_chip_unk
        ret
.cp_sw:  mov eax, str_chip_sw
         ret
.cp_and: mov eax, str_chip_and
         ret
.cp_or:  mov eax, str_chip_or
         ret
.cp_not: mov eax, str_chip_not
         ret

;-----------------------------------------------------------------------
; show_help — draw overlay, wait for keypress
;-----------------------------------------------------------------------
show_help:
        pushad

        mov ebx, 60
        mov ecx, 60
        mov edx, 620
        mov esi, 550
        mov edi, 0x000030
        call vbe_fill_rect

        ; Border top/bot
        mov ebx, 60
        mov ecx, 60
        mov edx, 620
        mov esi, 2
        mov edi, C_WALL_HL
        call vbe_fill_rect

        mov ecx, 608
        call vbe_fill_rect

        ; Title
        mov ebx, 160
        mov ecx, 80
        mov esi, str_help_title
        mov edi, C_PANEL_HL
        call fb_draw_text

        %macro HLINE 3
                mov ebx, 80
                mov ecx, %1
                mov esi, %2
                mov edi, %3
                call fb_draw_text
        %endmacro

        HLINE  116, str_h1, C_HUD_TXT
        HLINE  134, str_h2, C_HUD_TXT
        HLINE  152, str_h3, C_HUD_TXT
        HLINE  170, str_h4, C_HUD_TXT
        HLINE  188, str_h5, C_HUD_TXT
        HLINE  206, str_h6, C_HUD_TXT
        HLINE  224, str_h7, C_HUD_TXT
        HLINE  248, str_h8,  0xFFDD44
        HLINE  266, str_h9,  0xFFDD44
        HLINE  284, str_h10, 0xFFDD44
        HLINE  308, str_h11, C_MSG_OK
        HLINE  332, str_h12, C_MSG_INF

        VBE_GAME_PRESENT

.sh_wait:
        VBE_GAME_POLL_KEY
        cmp eax, -1
        je .sh_wait

        call full_redraw
        popad
        ret

;=======================================================================
; VBE HELPERS  (local copies so we don't depend on galaga/pong patterns)
;=======================================================================

; fb_draw_text  EBX=x, ECX=y, ESI=str, EDI=colour
fb_draw_text:
        pushad
        mov edx, ecx
        mov ecx, ebx
        mov eax, SYS_FRAMEBUF
        mov ebx, 3
        int 0x80
        popad
        ret

; fb_draw_num  EAX=number, EBX=x, ECX=y, EDI=colour
fb_draw_num:
        push esi
        push ebx
        push ecx
        push edi
        call itoa
        pop edi
        pop ecx
        pop ebx
        mov esi, num_buf
        call fb_draw_text
        pop esi
        ret

; itoa  EAX=uint32 → num_buf (NUL-terminated decimal)
itoa:
        pushad
        mov edi, num_buf + 11
        mov byte [edi], 0
        dec edi
        test eax, eax
        jnz .id
        mov byte [edi], '0'
        dec edi
        jmp .ic
.id:
        mov ecx, 10
.il:
        test eax, eax
        jz .ic
        xor edx, edx
        div ecx
        add dl, '0'
        mov [edi], dl
        dec edi
        jmp .il
.ic:
        inc edi
        mov esi, edi
        mov edi, num_buf
.im:
        mov al, [esi]
        mov [edi], al
        inc esi
        inc edi
        test al, al
        jnz .im
        popad
        ret

;=======================================================================
; LEVEL MAPS  (23 × 21 = 483 bytes each, stored row-major)
;
; Tile codes:
;  0=void  1=floor  2=wall  3=door_cl  4=door_op  5=exit  6=slot
;
; Each %define row 23 bytes
;=======================================================================

%define W 2
%define F 1
%define V 0
%define D 3
%define E 5
%define S 6

;------------------------------------------
; L0 — Tutorial  (NOT gate)
;------------------------------------------
map_l0:
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,S,F,F,F,S,F,F,D,F,F,F,F,F,F,F,F,E,W
db W,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W

;------------------------------------------
; L1 — AND gate
;------------------------------------------
map_l1:
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,S,F,F,F,F,S,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,S,F,D,F,F,F,F,F,F,F,F,E,W
db W,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,S,F,F,F,F,S,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W

;------------------------------------------
; L2 — OR gate (same layout as L1)
;------------------------------------------
map_l2:
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,S,F,F,F,F,S,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,S,F,D,F,F,F,F,F,F,F,F,E,W
db W,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,S,F,F,F,F,S,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,F,F,F,F,W
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W

;------------------------------------------
; L3 — NOT then AND
;------------------------------------------
map_l3:
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,S,F,F,F,S,F,F,F,S,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,D,F,F,E,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,W
db W,F,F,F,S,F,F,F,S,F,F,F,S,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,W
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W

;------------------------------------------
; L4 — Final: two doors
;------------------------------------------
map_l4:
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,S,F,F,F,S,F,F,F,S,F,F,F,D,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,S,F,F,F,F,F,F,F,S,F,F,F,W,F,F,F,F,E,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,S,F,F,F,S,F,F,F,S,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,D,F,F,F,F,F,W
db W,F,F,F,S,F,F,F,F,F,F,F,S,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,W,F,F,F,F,F,W
db W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W

%undef W
%undef F
%undef V
%undef D
%undef E
%undef S

;=======================================================================
; STRINGS
;=======================================================================
str_title:    db "ROBOT TOWN", 0
str_lev:      db "Level:", 0
str_score:    db "Score:", 0
str_inventory: db "INVENTORY", 0
str_doors:    db "DOORS", 0
str_open:     db "OPEN  ", 0
str_locked_d: db "LOCKED", 0
str_holding:  db "HOLDING", 0
str_none:     db "(none)", 0
str_chip_sw:  db "SWITCH", 0
str_chip_and: db "AND gate", 0
str_chip_or:  db "OR gate", 0
str_chip_not: db "NOT gate", 0
str_chip_unk: db "chip?", 0
str_c1:       db "Arrows: move", 0
str_c2:       db "E: interact", 0
str_c3:       db "E on SWITCH:toggle", 0
str_c4:       db "R:restart  Q:quit", 0
str_c5:       db "?:help", 0

str_help_title: db "R O B O T  T O W N  -  H E L P", 0
str_h1:  db "Move with arrow keys.", 0
str_h2:  db "YELLOW = you.", 0
str_h3:  db "GREEN door = open.  RED = locked.", 0
str_h4:  db "CYAN tile = exit (go here to advance).", 0
str_h5:  db "DARK tile = chip socket.", 0
str_h6:  db "Stand on SWITCH and press E to toggle.", 0
str_h7:  db "Stand on chip+press E to pick up.", 0
str_h8:  db "AND gate: door opens if BOTH inputs HIGH.", 0
str_h9:  db "OR  gate: door opens if EITHER input HIGH.", 0
str_h10: db "NOT gate: inverts input (HIGH<->LOW).", 0
str_h11: db "All doors must be open to use the exit!", 0
str_h12: db "Press any key to close.", 0

msg_l0:    db "Tutorial: place the NOT chip on a socket!", 0
msg_l1:    db "AND gate: BOTH switches must be ON.", 0
msg_l2:    db "OR gate: EITHER switch opens the door.", 0
msg_l3:    db "Cascade: NOT then AND. Think carefully!", 0
msg_l4:    db "Final: AND+NOT and OR must both unlock.", 0
msg_picked: db "Chip picked up.", 0
msg_placed: db "Chip placed on socket.", 0
msg_locked: db "Some doors still locked!", 0
msg_youwin: db "YOU WIN! All levels complete!", 0

;=======================================================================
; Initialized data (zero-filled to ensure clean startup)
;=======================================================================
player_x    dd 0
player_y    dd 0
cur_level   dd 0
score       dd 0
game_won    dd 0
held_chip   dd 0
num_chips   dd 0
num_doors   dd 0
rand_seed   dd 0
dp_y        dd 0
esi_bak     dd 0
edi_bak     dd 0

level_map   times MAP_COLS * MAP_ROWS db 0
chip_arr    times MAX_CHIPS * CREC db 0
door_arr    times MAX_DOORS * DREC db 0
node_sig    times MAX_NODES db 0

msg_buf     times 96 db 0
num_buf     times 16 db 0
