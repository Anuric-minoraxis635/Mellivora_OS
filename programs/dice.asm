; dice.asm - Roll dice (NdM notation)
;
; Usage:
;   dice              roll 1d6
;   dice 3d6          roll 3 six-sided dice
;   dice 2d20         roll 2 d20s

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        mov dword [n], 1
        mov dword [m], 6

        mov esi, argbuf
.sw:
        mov al, [esi]
        cmp al, ' '
        je .swa
        cmp al, 9
        je .swa
        jmp .check
.swa:
        inc esi
        jmp .sw
.check:
        cmp byte [esi], 0
        je .seedit

        ; parse N
        xor eax, eax
.dl:
        mov bl, [esi]
        cmp bl, '0'
        jb .ed
        cmp bl, '9'
        ja .ed
        sub bl, '0'
        movzx ecx, bl
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .dl
.ed:
        test eax, eax
        jz .badusage
        mov [n], eax

        ; expect 'd' or 'D'
        mov al, [esi]
        cmp al, 'd'
        je .pm
        cmp al, 'D'
        jne .seedit
.pm:
        inc esi
        xor eax, eax
.dl2:
        mov bl, [esi]
        cmp bl, '0'
        jb .ed2
        cmp bl, '9'
        ja .ed2
        sub bl, '0'
        movzx ecx, bl
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .dl2
.ed2:
        test eax, eax
        jz .badusage
        mov [m], eax

.seedit:
        ; Validate
        mov eax, [n]
        cmp eax, 1
        jl .badusage
        cmp eax, 100
        jg .badusage
        mov eax, [m]
        cmp eax, 2
        jl .badusage
        cmp eax, 1000
        jg .badusage

        ; Seed
        mov eax, SYS_GETTIME
        int 0x80
        mov [seed], eax
        mov eax, SYS_GETPID
        int 0x80
        xor [seed], eax
        cmp dword [seed], 0
        jne .ok
        mov dword [seed], 0xBADC0DE1
.ok:

        ; Roll
        mov ecx, [n]
        xor edi, edi          ; total
.roll:
        test ecx, ecx
        jz .doneroll
        push ecx
        call rand
        xor edx, edx
        div dword [m]
        ; edx = 0..m-1
        inc edx
        ; Print
        push edx
        push edi
        mov eax, edx
        call print_uint
        pop edi
        pop edx
        add edi, edx
        pop ecx
        dec ecx
        test ecx, ecx
        jz .done_roll_no_sp
        push ecx
        push edi
        mov eax, SYS_PUTCHAR
        mov ebx, ' '
        int 0x80
        pop edi
        pop ecx
        jmp .roll
.done_roll_no_sp:
.doneroll:
        ; Show total if N>1
        cmp dword [n], 1
        jle .nosum
        mov eax, SYS_PRINT
        mov ebx, str_eq
        int 0x80
        mov eax, edi
        call print_uint
.nosum:
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        xor ebx, ebx
        jmp .exit
.badusage:
        mov eax, SYS_PRINT
        mov ebx, usage
        int 0x80
        mov ebx, 1
.exit:
        mov eax, SYS_EXIT
        int 0x80

rand:
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

print_uint:
        push ebx
        push ecx
        push edx
        push edi
        mov edi, numbuf + 11
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

usage:  db 'usage: dice [NdM]   e.g. dice 3d6, dice d20', 10, 0
str_eq: db ' = ', 0

argbuf: times 64 db 0
n:      dd 0
m:      dd 0
seed:   dd 0
numbuf: times 12 db 0
