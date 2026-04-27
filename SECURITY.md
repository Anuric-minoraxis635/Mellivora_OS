# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 7.5.x   | :white_check_mark: |
| < 7.5   | :x:                |

Only the latest release on the `main` branch receives security fixes.

## Scope

Mellivora OS is a **bare-metal educational operating system** that runs directly on hardware (or QEMU). It includes a full TCP/IP networking stack (RTL8139 NIC driver, ARP, IPv4, ICMP, UDP, TCP, DHCP, DNS) and has no user authentication. Security concerns include:

- **Buffer overflows** in kernel or shell code that could corrupt memory or escalate privilege (Ring 3 → Ring 0)
- **Network stack vulnerabilities** — malformed packets, integer overflows in protocol parsers, or boundary errors in the BSD-style socket API (8 simultaneous sockets)
- **Filesystem integrity** issues in HBFS that could cause data loss or corruption
- **Build chain safety** — ensuring the Makefile, Python scripts, and tooling don't introduce vulnerabilities
- **Syscall boundary validation** — ensuring user-mode programs cannot pass invalid pointers or sizes to kernel syscalls

## Reporting a Vulnerability

If you discover a security issue, please report it responsibly:

1. **Do NOT open a public GitHub issue** for security vulnerabilities.
2. Use GitHub's private vulnerability reporting:
   [Report a vulnerability](https://github.com/James-HoneyBadger/Mellivora_OS/security/advisories/new)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce (assembly snippet, shell command, or disk image)
   - Impact assessment (crash, memory corruption, privilege escalation, data loss)
   - Suggested fix if you have one

## Response Timeline

- **Acknowledgment**: Within 72 hours
- **Assessment**: Within 1 week
- **Fix release**: As soon as practical, typically within 2 weeks for confirmed issues

## Security Hardening History

The project actively hardens its codebase. Recent examples:

- **v7.3**: Fixed black-screen hang in VBE games caused by missing `VBE_GAME_PRESENT` call; removed redundant `KEY_UP`/`KEY_DOWN`/`KEY_LEFT`/`KEY_RIGHT` `%ifndef` guards in `vbe_game.inc` that caused inconsistent redefinition errors
- **v7.0**: Shell prompt placement fix — `vga_cursor_x` is checked before emitting prompt to prevent output corruption at column boundaries
- **v6.5**: `audio.inc` and `highscore.inc` libraries validated for bounds on score path construction; `hs_update` only writes when candidate beats stored value
- **v6.1**: VBE UI library (`vbe_ui.inc`) introduced with input-length guards on modal and text-input widgets
- **Earlier**: Fixed `build_cwd_path` buffer overflow, added bounded `copy_word_n`, ATA retry wrappers with soft reset, HBFS error propagation with carry flag, nested batch execution guard, superblock `free_blocks` consistency tracking
