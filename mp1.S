
# mp1.S - missile-command version
# Good luck, and have fun!

#define CALLER_SAVE                  \
        pushl   %eax;                \
        pushl   %ecx;                \
        pushl   %edx

#define CALLER_POP                   \
        popl    %edx;                \
        popl    %ecx

.data

    # Constants for accessing the fields of a struct missile,
    # struct missile is defined in rtc.h and mp1.h

    NEXT      = 0
    X         = 4
    Y         = 8
    VX        = 12
    VY        = 16
    DEST_X    = 20
    DEST_Y    = 24
    EXPLODED  = 28
    C         = 32
    SIZE      = 36

    # Character to draw for an explosion - '@'

    EXPLOSION = 64
    CROSSHAIR = 42
    SPACE     = 32


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list: .long 0x0   # Head of list pointer
base_alive:       .long 0x0   # Array of 3 bytes, plus a padding byte
mp1_score:        .long 0x0   # Player's current score
mp1_status:       .long 0x0


# Data private to this  file

dead_base_pic: .string "xxxxx" # Picture of a dead base
base_pic:      .string "/^^^\\"    # Picture of a live base
crosshairs_x:  .long 0x0   # X-position of the crosshairs
crosshairs_y:  .long 0x0   # Y-position of the crosshairs

jump_table:
.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, \
      mp1_ioctl_getstatus, mp1_ioctl_endgame

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
        movl    vmem_base_addr(,1),%edx
        movb    %cl,(%edx,%eax,1)
        ret

# void mp1_draw(int x, int y, char value);
mp1_draw:
        pushl   %ebp
        movl    %esp, %ebp
        movl    8(%esp), %eax       #x
        movl    12(%esp), %edx      #y
        imull   $80, %edx, %edx
        addl    %edx, %eax
        imull   $2, %eax            # since video memory is weird
        movl    16(%esp), %ecx
        andl    $0xFF, %ecx
        call    mp1_poke
        leave
        ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#   (1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#   (2) Redraw the bases - they may have been overwritten with missiles
#   (3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
        pushl   %ebp
        movl    %esp, %ebp
        call    update_missiles
        call    draw_bases
        call    draw_xhair
        leave
        ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
        movl    8(%esp), %eax
        cmpl    $5, %eax
        jae     on_error
        jmp     *jump_table(, %eax, 4)
        ret


# ----------------- Functions private to this file -------------------

# void update_missiles(void);
update_missiles:
        pushl   %ebp
        movl    %esp, %ebp
        movl    $mp1_missile_list, %eax     # struct missile**
update_missiles_loop1:
        cmpl    $0, %eax
        jz      update_missiles_done1
        cmpl    $0, (%eax)
        jz      update_missiles_done1
        movl    (%eax), %ecx
        CALLER_SAVE
        xorl    %edx, %edx
        movb    $SPACE, %dl
        pushl   %edx
        xorl    %edx, %edx
        movw    Y + 2(%ecx), %dx
        pushl   %edx
        movw    X + 2(%ecx), %dx
        pushl   %edx
        call    mp1_draw
        addl    $12, %esp
        CALLER_POP
        popl    %eax
        movl    EXPLODED(%ecx), %edx
        cmpl    $0, %edx
        jnz     update_missiles_exploded
        movl    X(%ecx), %edx
        addl    VX(%ecx), %edx
        movl    %edx, X(%ecx)
        movl    Y(%ecx), %edx
        addl    VY(%ecx), %edx
        movl    %edx, Y(%ecx)
        # check out of screen. y first
        shrl    $16, %edx
        cmpw    $25, %dx
        jae     update_missiles_delete
        movl    X(%ecx), %edx
        shrl    $16, %edx
        cmpw    $80, %dx
        jae     update_missiles_delete
        # check on destination. x first
        andl    $0xffff, %edx
        cmpl    DEST_X(%ecx), %edx
        jnz     update_missiles_redraw
        movl    Y(%ecx), %edx
        shrl    $16, %edx
        andl    $0xffff, %edx
        cmpl    DEST_Y(%ecx), %edx
        jnz     update_missiles_redraw
        CALLER_SAVE
        pushl   (%eax)
        call    missile_explode
        addl    $4, %esp
        cmpl    $0, %eax
        jz      update_missiles_nochange
        call    mp1_notify_user
update_missiles_nochange:
        CALLER_POP
        popl    %eax
update_missiles_exploded:
        movb    $EXPLOSION, C(%ecx)
        decl    %edx
        cmpl    $0, %edx
        jz      update_missiles_delete
        movl    %edx, EXPLODED(%ecx)
update_missiles_redraw:
        CALLER_SAVE
        xorl    %edx, %edx
        movb    C(%ecx), %dl
        pushl   %edx
        xorl    %edx, %edx
        movw    Y + 2(%ecx), %dx
        pushl   %edx
        movw    X + 2(%ecx), %dx
        pushl   %edx
        call    mp1_draw
        addl    $12, %esp
        CALLER_POP
        popl    %eax
        jmp     update_missiles_continue
update_missiles_delete:
        pushl   %eax
        pushl   %eax
        call    remove_missile
        addl    $4, %esp
        popl    %eax
update_missiles_continue:
        movl    (%eax), %eax
        jmp     update_missiles_loop1
update_missiles_done1:
        leave
        ret

# void remove_missile(struct missile** missle)
remove_missile:
        pushl   %ebp
        movl    %esp, %ebp
        movl    8(%ebp), %eax
        movl    (%eax), %ecx
        movl    (%ecx), %edx
        movl    %edx, (%eax)
        pushl   %ecx
        call    mp1_free
        leave
        ret

# void draw_bases(void);
draw_bases:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        xorl    %eax, %eax       # outer loop counter
draw_bases_loop1:
        cmpl    $2, %eax
        ja      draw_bases_done1 # greater than 2, done
        xorl    %ecx, %ecx       # loop counter
        xorl    %ebx, %ebx
        movb    base_alive(%eax), %bl
        imull   $6, %ebx
        addl    $dead_base_pic, %ebx
draw_bases_loop2:
        cmpl    $5, %ecx
        jae     draw_bases_done2
        CALLER_SAVE
        xorl    %edx, %edx
        movb    (%ebx, %ecx), %dl
        pushl   %edx
        pushl   $24
        movl    %eax, %edx
        imull   $20, %edx
        addl    $18, %edx
        addl    %ecx, %edx
        pushl   %edx
        call    mp1_draw
        addl    $12, %esp
        CALLER_POP
        popl    %eax
        incl    %ecx
        jmp     draw_bases_loop2
draw_bases_done2:
        incl    %eax
        jmp     draw_bases_loop1
draw_bases_done1:
        popl    %ebx
        leave
        ret

# void draw_xhair(void);
draw_xhair:
        pushl   %ebp
        movl    %esp, %ebp
        movl    $CROSSHAIR, %eax
        pushl   %eax
        movl    crosshairs_y, %eax
        pushl   %eax
        movl    crosshairs_x, %eax
        pushl   %eax
        call    mp1_draw
        leave
        ret

# int mp1_ioctl_startgame (unsigned long);
mp1_ioctl_startgame:
        pushl   %ebp
        movl    %esp, %ebp
        movl    $40, %eax
        movl    %eax, crosshairs_x
        movl    $12, %eax
        movl    %eax, crosshairs_y
        movl    $0x01010101, %eax
        movl    %eax, base_alive
        leave
        ret

# int mp1_ioctl_addmissile (struct missile* user_missle);
mp1_ioctl_addmissile:
        pushl   %ebp
        movl    %esp, %ebp
        # copy from user
        pushl   $SIZE
        call    mp1_malloc
        addl    $4, %esp
        cmpl    $0, %eax        # return of malloc
        jz      on_error_leave
        pushl   %eax
        pushl   $SIZE
        movl    8(%ebp), %ecx
        pushl   %ecx
        pushl   %eax
        call    mp1_copy_from_user
        addl    $12, %esp
        cmpl    $0, %eax
        popl    %eax
        jnz     on_error_free
        # insert the struct
        movl    mp1_missile_list, %ecx
        movl    %ecx, NEXT(%eax)
        movl    %eax, mp1_missile_list
        xorl    %eax, %eax
        leave
        ret

# int mp1_ioctl_movexhairs (unsigned long xhair_delta_packed);
mp1_ioctl_movexhairs:
        pushl   %ebp
        movl    %esp, %ebp
        movl    crosshairs_x, %ecx
        movl    crosshairs_y, %edx
        pushl   $SPACE
        pushl   %edx
        pushl   %ecx
        call    mp1_draw
        addl    $12, %esp
        movl    8(%esp), %eax
        movl    crosshairs_x, %ecx
        movl    crosshairs_y, %edx
        addw    %ax, %cx
        shrl    $16, %eax
        addw    %ax, %dx

        # boundry checkings
        cmpw    $0, %cx
        jg      mp1_ioctl_movexhairs_check_x_up
        movl    $0, %ecx
        jmp     mp1_ioctl_movexhairs_check_y_low
mp1_ioctl_movexhairs_check_x_up:
        cmpl    $80, %ecx
        jl      mp1_ioctl_movexhairs_check_y_low
        movl    $79, %ecx
mp1_ioctl_movexhairs_check_y_low:
        cmpw    $0, %dx
        jg      mp1_ioctl_movexhairs_check_y_up
        movl    $0, %edx
        jmp     mp1_ioctl_movexhairs_check_done
mp1_ioctl_movexhairs_check_y_up:
        cmpl    $24, %edx
        jl      mp1_ioctl_movexhairs_check_done
        movl    $23, %edx
mp1_ioctl_movexhairs_check_done:
        movl    %ecx, crosshairs_x
        movl    %edx, crosshairs_y
        call    draw_xhair
        xorl    %eax, %eax
        leave
        ret

# int mp1_ioctl_getstatus (unsigned long* user_status);
mp1_ioctl_getstatus:
        pushl   %ebp
        movl    %esp, %ebp
        movl    mp1_score, %eax
        andl    $0xffff, %eax
        movb    base_alive, %cl
        cmpb    $0, %cl
        jz      mp1_ioctl_getstatus_1
        xorl    %edx, %edx
        movl    $1, %edx
        shll    $16, %edx
        orl     %edx, %eax
mp1_ioctl_getstatus_1:
        movb    base_alive + 1, %cl
        cmpb    $0, %cl
        jz      mp1_ioctl_getstatus_2
        xorl    %edx, %edx
        movl    $1, %edx
        shll    $17, %edx
        orl     %edx, %eax
mp1_ioctl_getstatus_2:
        movb    base_alive + 2, %cl
        cmpb    $0, %cl
        jz      mp1_ioctl_getstatus_3
        xorl    %edx, %edx
        movl    $1, %edx
        shll    $18, %edx
        orl     %edx, %eax
mp1_ioctl_getstatus_3:
        movl    %eax, mp1_status
        pushl   $4
        pushl   $mp1_status
        pushl   8(%ebp)
        call    mp1_copy_to_user
        cmpl    $0, %eax
        jnz     on_error_leave
        leave
        ret

# int mp1_ioctl_endgame (unsigned long);
mp1_ioctl_endgame:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   $mp1_missile_list
mp1_ioctl_endgame_loop:
        cmpl    $0, mp1_missile_list
        jz      mp1_ioctl_endgame_end
        call    remove_missile
        jmp     mp1_ioctl_endgame_loop
mp1_ioctl_endgame_end:
        leave
        ret

# ----------------- Helpers ---------------
on_error_free:
        pushl   %eax
        call    mp1_free
on_error_leave:
        leave
on_error:
        movl    $-1, %eax
        ret
