; tldr.asm - One-line summaries for commands
; Companion to `man`. Prints just the summary for a topic, or every
; summary if no argument is given. Reads /docs/tldr.db (key:summary lines)
; if present; otherwise falls back to a baked-in table.

%include "syscalls.inc"

start:
        mov eax, SYS_GETARGS
        mov ebx, argbuf
        int 0x80
        mov [arglen], eax

        ; Trim trailing whitespace
        mov esi, argbuf
.tr:
        mov al, [esi]
        test al, al
        jz .ready
        cmp al, ' '
        je .cut
        cmp al, 9
        je .cut
        cmp al, 10
        je .cut
        cmp al, 13
        je .cut
        inc esi
        jmp .tr
.cut:
        mov byte [esi], 0
.ready:
        cmp byte [argbuf], 0
        jne .one
        ; List all
        mov ebx, table
.la:
        mov esi, [ebx]
        test esi, esi
        jz .done
        push ebx
        mov eax, SYS_PRINT
        mov ebx, esi
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, sep
        int 0x80
        pop ebx
        mov esi, [ebx + 4]
        push ebx
        mov eax, SYS_PRINT
        mov ebx, esi
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        pop ebx
        add ebx, 8
        jmp .la

.one:
        mov ebx, table
.lo:
        mov esi, [ebx]
        test esi, esi
        jz .miss
        mov edi, argbuf
        call streq_ci
        je .hit
        add ebx, 8
        jmp .lo
.hit:
        mov esi, [ebx + 4]
        mov eax, SYS_PRINT
        mov ebx, argbuf
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, sep
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, esi
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        jmp .done
.miss:
        mov eax, SYS_PRINT
        mov ebx, miss_msg
        int 0x80
        mov eax, SYS_PRINT
        mov ebx, argbuf
        int 0x80
        mov eax, SYS_PUTCHAR
        mov ebx, 10
        int 0x80
        mov ebx, 1
        jmp .exit
.done:
        xor ebx, ebx
.exit:
        mov eax, SYS_EXIT
        int 0x80

streq_ci:
        push esi
        push edi
.l:
        mov al, [esi]
        mov ah, [edi]
        cmp al, 'A'
        jb .a1
        cmp al, 'Z'
        ja .a1
        add al, 32
.a1:
        cmp ah, 'A'
        jb .a2
        cmp ah, 'Z'
        ja .a2
        add ah, 32
.a2:
        cmp al, ah
        jne .ne
        test al, al
        jz .eq
        inc esi
        inc edi
        jmp .l
.eq:
        pop edi
        pop esi
        xor al, al
        ret
.ne:
        pop edi
        pop esi
        or al, 1
        cmp al, 0
        ret

;-----------------------------------
sep:      db ' - ', 0
miss_msg: db 'tldr: no entry for ', 0

%macro E 2
        dd %1, %2
%endmacro

table:
        E n_ls,       d_ls
        E n_cd,       d_cd
        E n_cp,       d_cp
        E n_mv,       d_mv
        E n_rm,       d_rm
        E n_cat,      d_cat
        E n_grep,     d_grep
        E n_find,     d_find
        E n_edit,     d_edit
        E n_man,      d_man
        E n_tutorial, d_tutorial
        E n_journal,  d_journal
        E n_bcal,     d_bcal
        E n_theme,    d_theme
        E n_play,     d_play
        E n_dnslook,  d_dnslook
        E n_meminfo,  d_meminfo
        E n_pkginfo,  d_pkginfo
        E n_tag,      d_tag
        E n_histgrep, d_histgrep
        E n_mkprog,   d_mkprog
        E n_bnotify,  d_bnotify
        E n_plasma,   d_plasma
        E n_nim,      d_nim
        E n_morse,    d_morse
        E n_pomodoro, d_pomodoro
        E n_todo,     d_todo
        E n_wiki,     d_wiki
        E n_color,    d_color
        E n_tldr,     d_tldr
        dd 0, 0

n_ls:       db 'ls', 0
n_cd:       db 'cd', 0
n_cp:       db 'cp', 0
n_mv:       db 'mv', 0
n_rm:       db 'rm', 0
n_cat:      db 'cat', 0
n_grep:     db 'grep', 0
n_find:     db 'find', 0
n_edit:     db 'edit', 0
n_man:      db 'man', 0
n_tutorial: db 'tutorial', 0
n_journal:  db 'journal', 0
n_bcal:     db 'bcal', 0
n_theme:    db 'theme', 0
n_play:     db 'play', 0
n_dnslook:  db 'dnslook', 0
n_meminfo:  db 'meminfo', 0
n_pkginfo:  db 'pkginfo', 0
n_tag:      db 'tag', 0
n_histgrep: db 'histgrep', 0
n_mkprog:   db 'mkprog', 0
n_bnotify:  db 'bnotify', 0
n_plasma:   db 'plasma', 0
n_nim:      db 'nim', 0
n_morse:    db 'morse', 0
n_pomodoro: db 'pomodoro', 0
n_todo:     db 'todo', 0
n_wiki:     db 'wiki', 0
n_color:    db 'color', 0
n_tldr:     db 'tldr', 0

d_ls:       db 'List directory contents (e.g. ls /bin)', 0
d_cd:       db 'Change current directory (cd /home)', 0
d_cp:       db 'Copy file (cp src dst)', 0
d_mv:       db 'Move or rename file (mv old new)', 0
d_rm:       db 'Remove file (rm name)', 0
d_cat:      db 'Print file contents (cat file)', 0
d_grep:     db 'Search files for a pattern (grep pat file)', 0
d_find:     db 'Locate files by name (find /bin name)', 0
d_edit:     db 'Modal text editor (edit file.txt)', 0
d_man:      db 'Read manual page (man topic)', 0
d_tutorial: db 'Interactive welcome tour for new users', 0
d_journal:  db 'Append a timestamped log entry (journal text)', 0
d_bcal:     db 'Calendar with personal events (bcal add YYYY-MM-DD txt)', 0
d_theme:    db 'Switch system color theme (theme amber)', 0
d_play:     db 'Play notes on PC speaker (play c e g C)', 0
d_dnslook:  db 'Resolve hostname to IPv4 (dnslook host)', 0
d_meminfo:  db 'Show memory + uptime + PID', 0
d_pkginfo:  db 'OS / version / RAM banner; paste in bug reports', 0
d_tag:      db 'Tag files & search by tag (tag add file kw)', 0
d_histgrep: db 'Search command history (histgrep pat)', 0
d_mkprog:   db 'Create a new asm program skeleton (mkprog name)', 0
d_bnotify:  db 'Send Burrows desktop notification (bnotify msg)', 0
d_plasma:   db 'Animated text-mode plasma demo (any key quits)', 0
d_nim:      db 'Single-pile Nim with optimal AI', 0
d_morse:    db 'Convert text to Morse code & beep it (morse SOS)', 0
d_pomodoro: db '25-minute work timer with beep on completion', 0
d_todo:     db 'Persistent todo list (todo add/list/done N)', 0
d_wiki:     db 'Personal knowledge base (wiki list/show/add topic)', 0
d_color:    db 'Show all 256 VGA text-mode color attributes', 0
d_tldr:     db 'One-line summaries (this command)', 0

argbuf: times 64 db 0
arglen: dd 0
