# Spinning Donut - Pure x86-64 Assembly Masterpiece
# Dynamic Terminal Resolution + Mouse Interaction
# No C, No libc, No external dependencies.

.set SYS_READ,        0
.set SYS_WRITE,       1
.set SYS_MMAP,        9
.set SYS_MUNMAP,      11
.set SYS_IOCTL,       16
.set SYS_NANOSLEEP,   35
.set SYS_EXIT,        60

.set STDIN,           0
.set STDOUT,          1
.set STDERR,          2

.set PROT_READ,       0x1
.set PROT_WRITE,      0x2
.set MAP_PRIVATE,     0x02
.set MAP_ANONYMOUS,   0x20

.set TCGETS,          0x5401
.set TCSETS,          0x5402
.set TIOCGWINSZ,      0x5413
.set FIONBIO,         0x5421

.set ICANON,          2
.set ISIG,            1
.set ECHO,            10

# Fixed Max Arena Size (to handle up to 256x256 terminals)
.set MAX_WIDTH,       256
.set MAX_HEIGHT,      256
.set MAX_BUF_SIZE,    ((MAX_WIDTH + 1) * MAX_HEIGHT)
.set MAX_ZBUF_SIZE,   (MAX_WIDTH * MAX_HEIGHT * 4)
.set ARENA_SIZE,      (MAX_BUF_SIZE + MAX_ZBUF_SIZE + 4096)

.intel_syntax noprefix

.section .data
    clear_screen:    .ascii "\x1b[2J\x1b[H"
    .set clear_len, . - clear_screen

    home_cursor:     .ascii "\x1b[H"
    .set home_len, . - home_cursor

    hide_cursor:     .ascii "\x1b[?25l\x1b[?1000h\x1b[?1002h"
    .set hide_len, . - hide_cursor
    
    show_cursor:     .ascii "\x1b[?25h\x1b[?1000l\x1b[?1002l"
    .set show_len, . - show_cursor
    
    luminance_map:   .ascii ".,-~:;=!*#$@"
    .set lum_len, . - luminance_map
    
    sleep_ts:       .quad 0, 10000000 # 10ms for very smooth ~100fps

    # State
    angle_a:         .float 0.0
    angle_b:         .float 0.0
    step_a:          .float 0.018
    step_b:          .float 0.009
    
    # Constants
    const_2pi:       .float 6.28318
    theta_step:      .float 0.07
    phi_step:        .float 0.02
    float_r1:        .float 1.0
    float_r2:        .float 2.0
    float_k2:        .float 5.0
    float_8:         .float 8.0
    float_0:         .float 0.0
    float_aspect:    .float 0.5 # Terminal char aspect ratio correction

    err_msg:         .ascii "[donut] fatal runtime error\n"
    .set err_len, . - err_msg

.section .bss
    .lcomm arena_ptr, 8
    .lcomm char_buffer, 8
    .lcomm z_buffer, 8
    .lcomm orig_termios, 128
    .lcomm raw_termios, 128
    .lcomm mouse_buf, 32
    .lcomm termios_active, 4
    .lcomm input_enabled, 4
    
    # Dynamic Screen Info
    .lcomm screen_w, 4
    .lcomm screen_h, 4
    .lcomm prev_screen_w, 4
    .lcomm prev_screen_h, 4
    .lcomm half_w, 4
    .lcomm half_h, 4
    .lcomm k1_scale, 4

    # FPU Scratchpad
    .lcomm sin_a, 4
    .lcomm cos_a, 4
    .lcomm sin_b, 4
    .lcomm cos_b, 4
    .lcomm circle_x, 4
    .lcomm circle_y, 4
    .lcomm cos_theta, 4
    .lcomm sin_theta, 4
    .lcomm cos_phi, 4
    .lcomm sin_phi, 4
    .lcomm temp_f, 4
    .lcomm winsize_buf, 8 # struct winsize: row, col, xpixel, ypixel (4 shorts)

.section .text
    .global _start

_start:
    # 1. MMAP Arena
    mov rax, SYS_MMAP
    xor rdi, rdi
    mov rsi, ARENA_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall
    test rax, rax
    js .fatal_exit
    mov [arena_ptr], rax
    mov [char_buffer], rax
    add rax, MAX_BUF_SIZE
    mov [z_buffer], rax

    # 2. Terminal Raw Mode (best effort)
    mov dword ptr [termios_active], 0
    mov dword ptr [input_enabled], 0

    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TCGETS
    mov rdx, offset orig_termios
    syscall
    test rax, rax
    js .after_termios_setup

    mov rcx, 16
    mov rsi, offset orig_termios
    mov rdi, offset raw_termios
    rep movsq
    and dword ptr [raw_termios + 12], ~(ICANON | ECHO | ISIG)
    
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TCSETS
    mov rdx, offset raw_termios
    syscall
    test rax, rax
    js .after_termios_setup
    mov dword ptr [termios_active], 1

.after_termios_setup:

    # Set STDIN non-blocking once
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, FIONBIO
    sub rsp, 8
    mov dword ptr [rsp], 1
    mov rdx, rsp
    syscall
    add rsp, 8
    test rax, rax
    js .no_nonblock_input
    mov dword ptr [input_enabled], 1

.no_nonblock_input:
    
    # Hide Cursor & Mouse Track
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, offset hide_cursor
    mov rdx, hide_len
    syscall
    test rax, rax
    js .cleanup_error

    # Safe defaults (used if winsize ioctl fails)
    mov dword ptr [screen_w], 80
    mov dword ptr [screen_h], 24

.main_loop:
    # 3. Dynamic Screen Size Detection
    mov rax, SYS_IOCTL
    mov rdi, STDOUT
    mov rsi, TIOCGWINSZ
    mov rdx, offset winsize_buf
    syscall
    test rax, rax
    js .have_dims
    
    movzx rax, word ptr [winsize_buf + 2] # ws_col
    test eax, eax
    jnz .col_nonzero
    mov eax, 1
.col_nonzero:
    cmp eax, MAX_WIDTH
    jle .col_ok
    mov eax, MAX_WIDTH
.col_ok:
    mov [screen_w], eax

    movzx rbx, word ptr [winsize_buf]     # ws_row
    test ebx, ebx
    jnz .row_nonzero
    mov ebx, 1
.row_nonzero:
    cmp ebx, MAX_HEIGHT
    jle .row_ok
    mov ebx, MAX_HEIGHT
.row_ok:
    mov [screen_h], ebx

.have_dims:
    mov eax, [screen_w]
    mov ebx, [screen_h]
    
    # Compute half_w, half_h, k1
    cvtsi2ss xmm0, eax
    movss xmm1, [float_aspect]
    mulss xmm0, xmm1
    movss [half_w], xmm0
    
    cvtsi2ss xmm2, ebx
    mulss xmm2, xmm1
    movss [half_h], xmm2
    
    # K1 = screen_w * 0.75
    cvtsi2ss xmm3, eax
    mov r8d, 0x3f400000 # 0.75f
    mov [temp_f], r8d
    mulss xmm3, [temp_f]
    movss [k1_scale], xmm3

    # 4. Input handling (Non-blocking)
    cmp dword ptr [input_enabled], 1
    jne .no_input

    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, offset mouse_buf
    mov rdx, 32
    syscall
    
    cmp rax, 6
    jl .no_input
    cmp byte ptr [mouse_buf], 0x03 # Ctrl+C (Though usually caught by TTY, we check anyway)
    je .cleanup
    
    cmp byte ptr [mouse_buf], 0x1b
    jne .no_input
    cmp byte ptr [mouse_buf+2], 'M'
    jne .no_input
    
    movzx rbx, byte ptr [mouse_buf+4]
    sub rbx, 32 # X
    cvtsi2ss xmm0, rbx
    divss xmm0, [half_w]
    mulss xmm0, [const_2pi]
    movss [angle_b], xmm0
    
    movzx rbx, byte ptr [mouse_buf+5]
    sub rbx, 32 # Y
    cvtsi2ss xmm0, rbx
    divss xmm0, [half_h]
    mulss xmm0, [const_2pi]
    movss [angle_a], xmm0

.no_input:
    # 5. Clear Frame
    mov rdi, [char_buffer]
    mov eax, [screen_w]
    mov ebx, [screen_h]
    imul eax, ebx
    add eax, ebx # Include newlines
    mov rcx, rax
    mov al, ' '
    rep stosb
    
    mov rdi, [char_buffer]
    mov edx, [screen_w]
    mov ebx, 0
.nl_loop:
    add rdi, rdx
    mov byte ptr [rdi], 0x0a
    inc rdi
    inc ebx
    cmp ebx, [screen_h]
    jl .nl_loop
    
    mov rdi, [z_buffer]
    mov eax, [screen_w]
    imul eax, [screen_h]
    mov rcx, rax
    xor rax, rax
    rep stosd

    # 6. Math Precalc
    finit
    fld dword ptr [angle_a]
    fadd dword ptr [step_a]
    fst dword ptr [angle_a]
    fsincos
    fstp dword ptr [cos_a]
    fstp dword ptr [sin_a]
    
    fld dword ptr [angle_b]
    fadd dword ptr [step_b]
    fst dword ptr [angle_b]
    fsincos
    fstp dword ptr [cos_b]
    fstp dword ptr [sin_b]

    # 7. Render Torus
    fldz # Phi
.phi_loop:
    fldz # Theta
.theta_loop:
    # Precompute sin/cos theta/phi
    fld st(0)
    fsincos
    fstp dword ptr [cos_theta]
    fstp dword ptr [sin_theta]
    fld st(1)
    fsincos
    fstp dword ptr [cos_phi]
    fstp dword ptr [sin_phi]
    
    fld dword ptr [float_r1]
    fmul dword ptr [cos_theta]
    fadd dword ptr [float_r2]
    fstp dword ptr [circle_x]
    
    fld dword ptr [float_r1]
    fmul dword ptr [sin_theta]
    fstp dword ptr [circle_y]
    
    # z = K2 + cos_A * circle_x * sin_phi + circle_y * sin_A
    fld dword ptr [cos_a]
    fmul dword ptr [circle_x]
    fmul dword ptr [sin_phi]
    fld dword ptr [sin_a]
    fmul dword ptr [circle_y]
    faddp st(1), st(0)
    fadd dword ptr [float_k2]
    
    fld1
    fdiv st(0), st(1) # ST(0)=1/Z, ST(1)=Z
    
    # x_rot
    fld dword ptr [cos_b]
    fmul dword ptr [cos_phi]
    fld dword ptr [sin_a]
    fmul dword ptr [sin_b]
    fmul dword ptr [sin_phi]
    faddp st(1), st(0)
    fmul dword ptr [circle_x]
    fld dword ptr [cos_a]
    fmul dword ptr [sin_b]
    fmul dword ptr [circle_y]
    fsubp st(1), st(0)
    
    fmul st(0), st(1)
    fmul dword ptr [k1_scale]
    fadd dword ptr [half_w]
    fistp dword ptr [temp_f]
    movsxd r8, dword ptr [temp_f]
    
    # y_rot
    fld dword ptr [sin_b]
    fmul dword ptr [cos_phi]
    fld dword ptr [sin_a]
    fmul dword ptr [cos_b]
    fmul dword ptr [sin_phi]
    fsubp st(1), st(0)
    fmul dword ptr [circle_x]
    fld dword ptr [cos_a]
    fmul dword ptr [cos_b]
    fmul dword ptr [circle_y]
    faddp st(1), st(0)
    
    fmul st(0), st(1)
    fmul dword ptr [k1_scale]
    fmul dword ptr [float_aspect]
    fld dword ptr [half_h]
    fsubrp st(1), st(0)
    fistp dword ptr [temp_f]
    movsxd r9, dword ptr [temp_f]

    # Luminance L
    fld dword ptr [cos_phi]
    fmul dword ptr [cos_theta]
    fmul dword ptr [sin_b]
    fld dword ptr [cos_a]
    fmul dword ptr [cos_theta]
    fmul dword ptr [sin_phi]
    fsubp st(1), st(0)
    fld dword ptr [sin_a]
    fmul dword ptr [sin_theta]
    fsubp st(1), st(0)
    fld dword ptr [cos_b]
    fld dword ptr [cos_a]
    fmul dword ptr [sin_theta]
    fld dword ptr [cos_theta]
    fmul dword ptr [sin_a]
    fmul dword ptr [sin_phi]
    fsubp st(1), st(0)
    fmulp st(1), st(0)
    faddp st(1), st(0) # ST(0)=L, ST(1)=1/Z, ST(2)=Z
    
    # Bounds Check
    cmp r8d, 0
    jl .skip_point
    cmp r8d, [screen_w]
    jge .skip_point
    cmp r9d, 0
    jl .skip_point
    cmp r9d, [screen_h]
    jge .skip_point
    
    # Z-Buffer Test
    mov eax, r9d
    imul eax, [screen_w]
    add eax, r8d
    mov rdi, [z_buffer]
    movss xmm0, dword ptr [rdi + rax*4]
    fld st(1)
    fst dword ptr [temp_f]
    movss xmm1, dword ptr [temp_f]
    fstp st(0)
    ucomiss xmm1, xmm0
    jbe .skip_point
    
    movss dword ptr [rdi + rax*4], xmm1
    
    # Shade map
    fld st(0)
    fmul dword ptr [float_8]
    fistp dword ptr [temp_f]
    mov eax, [temp_f]
    cmp eax, 0
    jge .l_min
    xor eax, eax
.l_min:
    cmp eax, 11
    jle .l_max
    mov eax, 11
.l_max:
    movzx rax, byte ptr [luminance_map + rax]
    
    mov rdi, [char_buffer]
    mov rbx, r9
    mov edx, [screen_w]
    inc edx # Account for newline
    imul rbx, rdx
    add rbx, r8
    mov byte ptr [rdi + rbx], al

.skip_point:
    fstp st(0) # pop L
    fstp st(0) # pop 1/Z
    fstp st(0) # pop Z
    
    fld dword ptr [theta_step]
    faddp st(1), st(0)
    fld dword ptr [const_2pi]
    fcomip st(0), st(1)
    ja .theta_loop
    
    fstp st(0)
    fld dword ptr [phi_step]
    faddp st(1), st(0)
    fld dword ptr [const_2pi]
    fcomip st(0), st(1)
    ja .phi_loop
    
    fstp st(0)

    # 8. Flush Buffer
    # Only fully erase the display when the terminal size changed (or on the
    # first frame); otherwise just home the cursor and repaint in place. Every
    # cell is rewritten each frame anyway, so a full erase every frame just
    # causes visible flicker/tearing for no benefit.
    mov eax, [screen_w]
    mov ebx, [screen_h]
    cmp eax, [prev_screen_w]
    jne .need_full_clear
    cmp ebx, [prev_screen_h]
    jne .need_full_clear
    mov rsi, offset home_cursor
    mov rdx, home_len
    jmp .clear_seq_ready
.need_full_clear:
    mov rsi, offset clear_screen
    mov rdx, clear_len
.clear_seq_ready:
    mov [prev_screen_w], eax
    mov [prev_screen_h], ebx

    mov rax, SYS_WRITE
    mov rdi, STDOUT
    syscall
    test rax, rax
    js .cleanup

    mov rdi, STDOUT
    mov rsi, [char_buffer]
    mov eax, [screen_w]
    mov ebx, [screen_h]
    imul eax, ebx
    add eax, ebx
    mov rdx, rax
    mov rax, SYS_WRITE
    syscall
    test rax, rax
    js .cleanup
    
    mov rax, SYS_NANOSLEEP
    mov rdi, offset sleep_ts
    xor rsi, rsi
    syscall
    jmp .main_loop

.cleanup:
    cmp dword ptr [termios_active], 1
    jne .skip_term_restore
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TCSETS
    mov rdx, offset orig_termios
    syscall
.skip_term_restore:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, offset show_cursor
    mov rdx, show_len
    syscall
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall

.cleanup_error:
    cmp dword ptr [termios_active], 1
    jne .fatal_exit
    jmp .cleanup

.fatal_exit:
    mov rax, SYS_WRITE
    mov rdi, STDERR
    mov rsi, offset err_msg
    mov rdx, err_len
    syscall
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall
