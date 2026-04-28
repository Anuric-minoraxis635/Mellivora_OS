; tip.asm - Quick tip / bill split calculator
;
; Usage:
;   tip <bill> [<percent>] [<people>]
;     bill      dollars (integer or .NN)
;     percent   default 18
;     people    default 1
;
; Output:
;   Bill:     $XX.XX
;   Tip XX%:  $XX.XX
;   Total:    $XX.XX
;   Per person ($XX.XX over N): $XX.XX

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80

        mov esi, argbuf
        call skip_ws
        cmp byte [esi], 0
        je usage_err

        ; bill in cents
        call parse_cents
        test eax, eax
        jle usage_err
        mov [bill_c], eax

        mov dword [pct], 18
        mov dword [people], 1

        call skip_ws
        cmp byte [esi], 0
        je .calc
        call parse_uint_in
        test eax, eax
        jle .ck_people
        mov [pct], eax
.ck_people:
        call skip_ws
        cmp byte [esi], 0
        je .calc
        call parse_uint_in
        test eax, eax
        jle .calc
        mov [people], eax

.calc:
        ; tip_c = bill_c * pct / 100
        mov eax, [bill_c]
        mul dword [pct]
        mov ebx, 100
        xor edx, edx
        div ebx
        mov [tip_c], eax

        mov eax, [bill_c]
        add eax, [tip_c]
        mov [total_c], eax

        ; per person
        mov eax, [total_c]
        xor edx, edx
        div dword [people]
        mov [pp_c], eax

        ; Print
        mov eax, SYS_PRINT
        mov ebx, str_bill
        int 0x80
        mov eax, [bill_c]
        call print_money
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80

        mov eax, SYS_PRINT
        mov ebx, str_tip
        int 0x80
        mov eax, [pct]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_pct
        int 0x80
        mov eax, [tip_c]
        call print_money
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80

        mov eax, SYS_PRINT
        mov ebx, str_total
        int 0x80
        mov eax, [total_c]
        call print_money
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80

        cmp dword [people], 1
        jle .out
        mov eax, SYS_PRINT
        mov ebx, str_per
        int 0x80
        mov eax, [people]
        call print_uint
        mov eax, SYS_PRINT
        mov ebx, str_each
        int 0x80
        mov eax, [pp_c]
        call print_money
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
.out:
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

;-----------------------------------
skip_ws:
.l:
        mov al, [esi]
        cmp al, ' '
        je .a
        cmp al, 9
        je .a
        ret
.a:
        inc esi
        jmp .l

; parse decimal $X.YY into cents from [esi]; advance esi
parse_cents:
        push ebx
        push ecx
        push edx
        xor eax, eax
.di:
        mov bl, [esi]
        cmp bl, '0'
        jb .frac_check
        cmp bl, '9'
        ja .frac_check
        sub bl, '0'
        movzx ecx, bl
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .di
.frac_check:
        imul eax, eax, 100
        cmp byte [esi], '.'
        jne .out
        inc esi
        ; up to 2 fractional digits
        xor ecx, ecx
        ; tens digit
        mov bl, [esi]
        cmp bl, '0'
        jb .out
        cmp bl, '9'
        ja .out
        sub bl, '0'
        movzx ecx, bl
        imul ecx, ecx, 10
        add eax, ecx
        inc esi
        ; ones
        mov bl, [esi]
        cmp bl, '0'
        jb .skipx
        cmp bl, '9'
        ja .skipx
        sub bl, '0'
        movzx ecx, bl
        add eax, ecx
        inc esi
.skipx:
        ; consume any remaining digits
.sx:
        mov bl, [esi]
        cmp bl, '0'
        jb .out
        cmp bl, '9'
        ja .out
        inc esi
        jmp .sx
.out:
        pop edx
        pop ecx
        pop ebx
        ret

; parse plain uint at [esi]; advance esi; EAX = value (0 if none)
parse_uint_in:
        xor eax, eax
        xor ecx, ecx
.l:
        mov cl, [esi]
        cmp cl, '0'
        jb .d
        cmp cl, '9'
        ja .d
        sub cl, '0'
        imul eax, eax, 10
        add eax, ecx
        inc esi
        jmp .l
.d:
        ret

; Print EAX as $X.YY (cents)
print_money:
        push ebx
        push ecx
        push edx
        push edi
        mov ecx, eax
        mov eax, SYS_PUTCHAR
        mov ebx, '$'
        int 0x80
        mov eax, ecx
        xor edx, edx
        mov ebx, 100
        div ebx                 ; eax = dollars, edx = cents
        push edx
        call print_uint
        mov eax, SYS_PUTCHAR
        mov ebx, '.'
        int 0x80
        pop edx
        ; print 2-digit cents
        mov eax, edx
        xor edx, edx
        mov ebx, 10
        div ebx                 ; eax = tens, edx = ones
        add al, '0'
        add dl, '0'
        mov [pad2], al
        mov [pad2+1], dl
        mov byte [pad2+2], 0
        mov eax, SYS_PRINT
        mov ebx, pad2
        int 0x80
        pop edi
        pop edx
        pop ecx
        pop ebx
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

;-----------------------------------
str_bill:  db 'Bill:     ', 0
str_tip:   db 'Tip ', 0
str_pct:   db '%:    ', 0
str_total: db 'Total:    ', 0
str_per:   db 'Per person (over ', 0
str_each:  db '): ', 0
usage:     db 'usage: tip <bill> [percent=18] [people=1]', 10, 0
pad2:      times 4 db 0
argbuf:    times 64 db 0
bill_c:    dd 0
pct:       dd 0
people:    dd 0
tip_c:     dd 0
total_c:   dd 0
pp_c:      dd 0
numbuf:    times 12 db 0
