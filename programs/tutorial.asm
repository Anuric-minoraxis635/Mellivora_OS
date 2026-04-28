; tutorial.asm - Interactive welcome tutorial for Mellivora OS
; Suggestion #13: Documentation as a product. Walks new users through the
; basics one screen at a time. Press Enter for the next page, q to quit.

%include "syscalls.inc"

start:
        mov eax, SYS_CLEAR
        int 0x80

        mov dword [page], 0
.next:
        mov eax, [page]
        cmp eax, NUM_PAGES
        jge .done

        mov ebx, eax
        shl ebx, 2
        mov esi, [pages + ebx]

        mov eax, SYS_CLEAR
        int 0x80
        mov eax, SYS_SETCOLOR
        mov ebx, 0x0E
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, banner
        int 0x80
        mov eax, SYS_SETCOLOR
        mov ebx, 0x07
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, esi
        int 0x80

        ; Footer
        mov eax, SYS_SETCOLOR
        mov ebx, 0x70
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, footer
        int 0x80
        mov eax, SYS_SETCOLOR
        mov ebx, 0x07
        int 0x80
.read:
        mov eax, SYS_GETCHAR
        int 0x80
        cmp al, 'q'
        je .done
        cmp al, 'Q'
        je .done
        cmp al, 27
        je .done
        cmp al, 'b'
        je .back
        cmp al, 'B'
        je .back
        ; anything else advances
        inc dword [page]
        jmp .next
.back:
        mov eax, [page]
        test eax, eax
        jz .next
        dec dword [page]
        jmp .next

.done:
        mov eax, SYS_CLEAR
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, bye
        int 0x80
        xor ebx, ebx
        mov eax, SYS_EXIT
        int 0x80

;-----------------------------------
banner:
        db '=== Mellivora OS Tutorial ===', 10, 10, 0
footer:
        db 10, ' [Enter] next   [b] back   [q] quit ', 0

NUM_PAGES equ 8
pages:  dd p1, p2, p3, p4, p5, p6, p7, p8

p1:
        db 'Welcome!', 10, 10
        db 'Mellivora is a tiny but complete operating system written entirely', 10
        db 'in x86 assembly. It boots in under a second and gives you a UNIX-y', 10
        db 'shell, a graphical desktop (Burrows), networking, and a small but', 10
        db 'growing app suite.', 10, 10
        db 'This tour takes about three minutes. Press Enter to continue.', 10, 0

p2:
        db 'The Shell', 10, 10
        db 'Type commands at the prompt:', 10, 10
        db '    ls /bin              list installed programs', 10
        db '    cd /docs             change directory', 10
        db '    cat readme.txt       print a file', 10
        db '    echo hi > note.txt   redirect output to a file', 10, 10
        db 'Use Up/Down to recall history, Tab to complete names.', 10, 0

p3:
        db 'Reading the Manual', 10, 10
        db 'Every command has a manual page. Try:', 10, 10
        db '    man                  list all topics', 10
        db '    man shell            read about the shell', 10
        db '    man -k clipboard     find topics about the clipboard', 10, 10
        db 'Inside a page: Space pages, Enter scrolls one line, q quits.', 10, 0

p4:
        db 'Files & Directories', 10, 10
        db '    /bin       system commands', 10
        db '    /Burrows   graphical apps', 10
        db '    /games     games and demos', 10
        db '    /home      your personal files', 10
        db '    /docs      documentation', 10, 10
        db 'Use cp, mv, rm, mkdir, find, grep just like a UNIX shell.', 10, 0

p5:
        db 'Pipelines and Scripting', 10, 10
        db 'Compose tools with pipes and redirection:', 10, 10
        db '    ls /bin | grep b            programs starting with b', 10
        db '    ls | clip                   copy file list to clipboard', 10
        db '    bdialog yesno "Format?"     scriptable confirm prompt', 10
        db '    histgrep ssh                search past commands', 10, 10
        db 'See "man shell" for full details.', 10, 0

p6:
        db 'The Burrows Desktop', 10, 10
        db 'Type "burrows" to launch the graphical desktop. Apps live in', 10
        db '/Burrows and are named with a leading b: bedit, bsheet, bnotes,', 10
        db 'bpaint, bplayer, bsysmon, bsettings ...', 10, 10
        db 'Press F1 inside any app for context help, F2 for the launcher.', 10, 0

p7:
        db 'Programming on Mellivora', 10, 10
        db 'Three first-class languages ship with the system:', 10, 10
        db '    asm <file>.asm       NASM-compatible assembler', 10
        db '    basic                interactive BASIC interpreter', 10
        db '    basicc <file>.bas    BASIC ahead-of-time compiler', 10, 10
        db 'New project? Try:  mkprog hello   then  asm hello.asm', 10, 0

p8:
        db 'You are ready.', 10, 10
        db 'A few useful next stops:', 10, 10
        db '    man intro            high-level system overview', 10
        db '    bcal                 today + your scheduled events', 10
        db '    journal "..."        write a dated log entry', 10
        db '    play c e g C         test the PC speaker', 10
        db '    plasma               admire the framebuffer for a moment', 10, 10
        db 'Have fun, and welcome aboard.', 10, 0

bye:    db 'tutorial: done. Type "tutorial" any time to see it again.', 10, 0

page: dd 0
