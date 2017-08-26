
# mp1.S - missile-command version
# Good luck, and have fun!

#define CALLER_SAVE                  \
        pushl   %eax;                \
        pushl   %ecx;                \
        pushl   %edx

#define CALLER_POP                   \
        popl    %ecx;                \
        popl    %edx

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

    # Character to draw for an explosion - '@'

    EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list: .long 0x0   # Head of list pointer
base_alive:       .long 0x0   # Array of 3 bytes, plus a padding byte
mp1_score:        .long 0x0   # Player's current score


# Data private to this  file

base_pic:      .string "/^^^\\"    # Picture of a live base
dead_base_pic: .string "xxxxx" # Picture of a dead base
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
        call    *jump_table(, %eax, 4)
        ret


# ----------------- Functions private to this file -------------------

# void update_missiles(void);
update_missiles:
        pushl   %ebp
        movl    %esp, %ebp

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
        addl    $base_pic, %ebx
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
        popl    %eax
        CALLER_POP
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

        leave
        ret

# int mp1_ioctl_startgame (unsigned long);
mp1_ioctl_startgame:
        pushl   %ebp
        movl    %esp, %ebp

        leave
        ret

# int mp1_ioctl_addmissile (struct missile* user_missle);
mp1_ioctl_addmissile:
        pushl   %ebp
        movl    %esp, %ebp

        leave
        ret

# int mp1_ioctl_movexhairs (unsigned long xhair_delta_packed);
mp1_ioctl_movexhairs:
        pushl   %ebp
        movl    %esp, %ebp

        leave
        ret

# int mp1_ioctl_getstatus (unsigned long* user_status);
mp1_ioctl_getstatus:
        pushl   %ebp
        movl    %esp, %ebp

        leave
        ret

# int mp1_ioctl_endgame (unsigned long);
mp1_ioctl_endgame:
        pushl   %ebp
        movl    %esp, %ebp

        leave
        ret

# ----------------- Helpers ---------------
on_error:
        movl    $-1, %eax
        ret
