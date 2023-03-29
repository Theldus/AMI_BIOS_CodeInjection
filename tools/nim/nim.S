#
# MIT License
#
# Copyright (c) 2021-23 Davidson Francis <davidsondfgl@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

.code16

.macro dbg
	xchgw %bx, %bx
.endm

.macro delay_ms ms
	mov $(\ms*1000)>>16,    %cx
	mov $(\ms*1000)&0xFFFF, %dx
	call delay2
.endm

# Our 'logo'
.fill 2048, 1, 0x0A # >> CHANGE_HERE <<

###############################################################################
#                     System Helpers & Boot stuff                             #
###############################################################################

# Backup registers and flags
_start:
pushfl
pushal
push %ds
push %es
push %fs

# Define proper segment registers
mov %cs, %ax
mov %ax, %ds
mov %ax, %es
mov %ax, %fs

# Set video mode: 80x25, 16-color text
mov $0x0003, %ax
int $0x10

# Play siren
mov $3, %cx
ambulance:
	push %cx
	mov  $4000, %bx
	call sound
	call delay
	mov  $5000, %bx
	call sound
	call delay
	pop  %cx
	loop ambulance

# Mute
call mute

# Jump to game
jmp main_screen

# Let the player use their PC
player_win_exit:
	call well_done_sound

	# Restore register
	pop %fs
	pop %es
	pop %ds
	popal
	popfl

	# Restore old instructions
	mov $0x4F02, %ax # >> CHANGE_HERE <<
	int $0x10
	retf

# ----------------------------------------------------
# sound: Make a sound with buzzer for a given pitch
#
# Parameters:
#   bx: Pitch
# ----------------------------------------------------
sound:
	mov $182, %al
	out %al,  $0x43
	mov %bx,  %ax    # Pitch
	out %al,  $0x42  # Lower value
	mov %ah,  %al
	out %al,  $0x42  # Higher value
	in $0x61, %al
	or $0x3,  %al
	out %al,  $0x61
	ret

# ----------------------------------------------------
# well_done_sound: Plays a well done/you win sound
# ----------------------------------------------------
well_done_sound:
	mov  $2111, %bx
	call sound
	delay_ms 80
	call mute

	delay_ms 200

	mov  $2811, %bx
	call sound
	delay_ms 20
	call mute

	delay_ms 150

	mov  $2111, %bx
	call sound
	delay_ms 300
	call mute

	delay_ms 1000
	ret

# ----------------------------------------------------
# delay: Sleeps/delay for 500ms
# ----------------------------------------------------
delay:
	mov $0x8600, %ax
	mov $0x3,    %cx
	mov $0xD090, %dx
	int $0x15
	ret

# ----------------------------------------------------
# delay: Sleeps/delay for a given time in CX:DS us
# ----------------------------------------------------
delay2:
	mov $0x8600, %ax
	int $0x15
	ret

# ----------------------------------------------------
# mute: Mute current sound
# ----------------------------------------------------
mute:
	in  $0x61, %al
	and $0xFC, %al # Turn off the speaker
	out %al,   $0x61
	ret

# ----------------------------------------------------
# read_number: Read a number with the arrow keys (up
# and down) from 0 to 7, Enter selects the number.
#
# Returns:
#   cx: Number read.
# ----------------------------------------------------
read_number:
	call 	read_kbd
	cmp		$KBD_UP, %ah
	jne		1f
	add 	$1, %cx
	and 	$7, %cx
	jmp		3f
1:
	cmp		$KBD_DOWN, %ah
	jne		2f
	sub 	$1, %cx
	and 	$7, %cx
	jmp 	3f
2:
	cmp 	$KBD_ENTER, %ah
	jne 	read_number
	jmp 	4f
3:
	# Get cursor position
	push 	%cx
	xor		%bx, %bx
	mov 	$3, %ah
	int 	$0x10
	# Adjust column
	sub 	$1, %dl
	mov 	$2, %ah
	int 	$0x10
	# Draw again
	pop 	%cx
	mov 	%cl,  %al
	add 	$'0', %al
	call 	print_char

	jmp 	read_number
4:
	ret

# ---------------------------------------------
# read_kbd: Reads a keypress from the keyboard
#
# This routine uses a polling approach because
# the BIOS at this stage does not have keyboard
# ints yet! (and I'm too lazy to setup one)
#
# Returns:
#   ah: Scan code
#   al: ASCII Character code
# ---------------------------------------------
read_kbd:
	.wait_ready_and_read_again:
		in   $0x64, %al
		andb $1, %al
		cmp  $0, %al
		je   .wait_ready_and_read_again

	# Got something let us check
	in  $0x60, %al
	cmp $0xE0, %al
	je .wait_ready_and_read_again

	# Nice, let us check if its key pressed (not released!)
	test $0x80, %al
	jz  .wait_read_release
	jmp .out

	# We need to ignore the release event as well!
	.wait_read_release:
		mov %ax, %bx # Got our key, backup it
		jmp .wait_ready_and_read_again

.out:
	# If release, we already have our key
	mov %bl, %ah
	ret

# ---------------------------------------
# print: Print a string to screen
#
# Parameters:
#   si: pointer to string
# ---------------------------------------
print:
	mov 	$0xE, %ah
	mov 	$0x0007, %bx
.print_char:
	lodsb
	cmp 	$0, %al
	je 		.done
	int 	$0x10
	jmp		.print_char
.done:
	ret

# ---------------------------------------------
# print_char: Print a character to the screen
#
# Parameters:
#   al: character
# ---------------------------------------------
print_char:
	mov 	$0xE, %ah
	mov 	0x0007, %bx
	int 	$0x10
	ret

# ---------------------------------------------
# clear_screen: Clear the screen
# ---------------------------------------------
clear_screen:
	# Clear screen
	push 	%ax
	push 	%bx
	push 	%cx
	push	%dx
	mov 	$0x0700, %ax # Scroll down, whole window
	mov 	$0x07,   %bh # White on black
	mov 	$0x0000, %cx # Row 0,  Col 0
	mov 	$0x184f, %dx # Row 24, Col 79
	int 	$0x10
	# Set cursor to top
	mov 	$0x2,    %ah
	mov 	$0x0,    %bh
	mov 	$0x0000, %dx
	int 	$0x10
	pop 	%ax
	pop 	%bx
	pop 	%cx
	pop 	%dx
	ret

###############################################################################
# Game helpers                                                                #
###############################################################################
# --------------------------------------------
# draw_title: Draw game title
# --------------------------------------------
draw_error:
	push %bp
	mov $0x1301, %ax # ah=13 (write string), al = 01, advance cursor
	mov $0x00CF, %bx # C = red back, F = white text
	mov $str_error_len, %cx
	mov $0, %dx # dh row, dl col
	mov $str_error, %bp
	int $0x10
	pop %bp
	ret

# --------------------------------------------
# draw_title: Draw game title
# --------------------------------------------
draw_title:
	call    clear_screen
	call    draw_error
	mov 	$str_game_title, %si
	call	print
	ret

# --------------------------------------------
# draw_sticks: Draw the sticks remaining
# --------------------------------------------
draw_sticks:
	xor		%cx, %cx
1:
	mov 	%cl, %al
	add 	$49, %al
	call 	print_char
	mov 	$str_stick_ddots, %si
	call 	print
	mov 	%cx, %si
	shl 	$1,  %si
	add 	$sticks, %si
	mov 	(%si), %si
	cmp 	$0, %si
	je 		2f
	sub 	$1, %si
	shl 	$1, %si
	add 	$str_sticks_vec, %si
	mov 	(%si), %si
	mov 	%si,   %dx
	call 	print
	mov 	%dx, %si
	call 	print
	mov 	%dx, %si
	call 	print
2:
	add 	$1, %cl
	cmp 	$4, %cl
	jl 		1b
	ret

###############################################################################
# Game entry point                                                            #
###############################################################################
main_screen:
	call    draw_title
	mov 	$str_game_explanation, %si
	call	print

	mov 	$str_who_starts, %si
	call 	print
	mov 	$str_arrow, %si
	call	print
	mov 	$str_you, %si
	call	print
	mov 	$str_empty_space, %si
	call	print
	mov 	$str_me, %si
	call 	print

# Reads who starts
	xor		%dx, %dx
who_starts:
	call 	read_kbd
	cmp		$KBD_UP, %ah
	jne		1f
	sub 	$1, %dx
	and 	$1, %dx
	jmp		3f
1:
	cmp		$KBD_DOWN, %ah
	jne		2f
	add 	$1, %dx
	and 	$1, %dx
	jmp 	3f
2:
	cmp 	$KBD_ENTER, %ah
	jne 	who_starts
	jmp 	.out_who_starts
3:
	# Get cursor position
	push 	%dx
	xor		%bx, %bx
	mov 	$3, %ah
	int 	$0x10
	# Adjust row
	sub 	$2, %dh
	mov 	$2, %ah
	int 	$0x10
	# Draw again
	pop 	%dx
	mov 	%dx, %si
	shl 	$2, %si
	add 	$str_arrow, %si
	call 	print
	mov 	$str_you, %si
	call 	print
	mov 	%dx, %si
	add 	$1, %si
	and 	$1, %si
	shl 	$2, %si
	add 	$str_arrow, %si
	call 	print
	mov 	$str_me, %si
	call 	print
	jmp 	who_starts
.out_who_starts:

	# Save current turn
	movb 	%dl, curr_turn

game_loop:
	movb 	sticks_count, %dl
	cmp 	$0, %dl
	jle 	game_loop_end
	call 	think
	jmp 	game_loop
game_loop_end:

	# Elects who win
	call 	draw_title
	movb 	curr_turn, %dl
lose:
	cmp 	$COMPUTER_TURN, %dl
	jne 	win
	mov 	$str_lose, %si
	call 	print
	jmp 	wait_key
win:
	mov 	$str_win, %si
	call    print
	jmp     player_win_exit
wait_key:
	mov 	$str_play_again, %si
	call 	print
	call 	read_kbd

	# Reset everything
	movb 	$16, sticks_count
	mov 	$sticks, %si
	movw 	$1, 0(%si)
	movw 	$3, 2(%si)
	movw 	$5, 4(%si)
	movw 	$7, 6(%si)

	# Start again
	call 	clear_screen
	jmp 	main_screen

###############################################################################
# PC and Player movements                                                     #
###############################################################################
# --------------------------------------------
# think: PC and Player movements
# --------------------------------------------
think:
	call 	draw_title
	call 	draw_sticks

.computer_turn:
	mov 	curr_turn, %dl
	cmp 	$COMPUTER_TURN, %dl
	jne 	.player_turn

	mov 	$str_think_pc, %si
	call 	print

	call 	read_kbd

	# Count amnt of heaps > 1
	xor 	%cx, %cx
	xor 	%dx, %dx
	mov 	$sticks, %si
.count_sticks:
	cmpw 	$1, 0(%si)
	jg 		1f
	jmp 	2f
1:
	add 	$1, %dx
2:
	add 	$1, %cx
	add 	$2, %si
	cmp 	$4, %cx
	jl 		.count_sticks
	push 	%dx
	mov 	%sp, %bp

.nim_sum:
	# Calculate NIM sum
	mov 	$sticks, %si
	mov 	0(%si),  %dx
	xor		2(%si),  %dx
	xor		4(%si),  %dx
	xor		6(%si),  %dx

	# Check if there is a good movement or not
	cmp 	$0, %dx
	jne 	.recalculate_nim_sum

.only_one:
	#
	# Too bad, if the player keeps playing like this the
	# computer will lose.
	#
	xor 	%cx, %cx
1:
	mov 	(%si), %ax
	cmp 	$0,    %ax
	jne 	2f
	add 	$1,    %cx
	add 	$2,    %si
	cmp 	$4,    %cx
	jl      1b
2:
	subw 	$1,    (%si)
	subb 	$1,    sticks_count
	jmp 	.finish

	#
	# If NIM sum differs from 0, great, we *will* win. We just
	# need to recalculate the amount of pieces.
	#
.recalculate_nim_sum:
	xor 	%cx, %cx
	mov 	$sticks, %si
1:
	mov 	(%si), %ax
	mov 	%ax, %bx
	xor 	%dx, %bx    # bx = p ^ nimsum, ax = p, dx = nimsum
	cmp 	%ax, %bx
	jl 		2f
	add 	$1,  %cx
	add 	$2,  %si
	cmp 	$4,  %cx
	jl      1b
2:
	#
	# We have 2 options here:
	# a) More than one heap with more than one stick
	# b) Exactly one heap with more than one stick
	#
	# The option b) do not conforms with the maths as
	# expected and we fall in a case were we remove
	# n or n-1 sticks from that column. So is necessary
	# to bifurcate these two scenarios here.
	#
	cmpw 	$1, (%bp)
	jne 	.scenario_a

.scenario_b:
	movb 	sticks_count, %bl
	subb 	%al, %bl
	mov 	%bx, %ax

	#
	# We need to leave a odd numbers of stickers to the player
	# If odd: remove all the sticks from the line
	# If even: remove all but one sticks from the line
	#
	andb 	$1, %al
	cmpb 	$0, %al
	je 		.even
.odd:
	movw 	$0,  (%si)
	movb 	%bl, sticks_count
	jmp 	.finish
.even:
	movw 	$1, (%si)
	addb 	$1, %bl
	movb 	%bl, sticks_count
	jmp 	.finish

.scenario_a:
	# Now we proceed as usual
	mov 	%bx, (%si)
	sub 	%bx, %ax
	sub 	%ax, sticks_count

	# Set turn to player
.finish:
	movb 	$PLAYER_TURN, curr_turn
	add 	$2, %sp
	ret

.player_turn:
	mov 	$str_think_askrow, %si
	call 	print

	# Read rows
.read_rows:
	mov 	$1,   %cx
	mov 	$'1', %al
	call 	print_char
1:
	call 	read_number
	# Check if selected row is valid
	cmp 	$0, %cx
	je 		1b
	cmp 	$4, %cx
	jg		1b
	# Check if selected row is not empty
	mov 	%cx, %si
	sub 	$1,  %si
	shl 	$1,  %si
	add 	$sticks, %si
	mov 	(%si), %si
	cmp 	$0, %si
	je 		1b
	sub 	$1, %cx # make row 0 based
	push 	%cx
	mov 	%sp, %bp

	# Read sticks amount
.read_amnt:
	mov 	$str_newline, %si
	call 	print
	mov 	$str_think_askstick, %si
	call 	print
	mov 	$1,   %cx
	mov 	$'1', %al
	call 	print_char
2:
	call 	read_number
	# Check if selected amount is valid
	cmp 	$0, %cx
	je 		2b
	# Check if selected amount not exceeds the sticks amnt
	mov 	(%bp), %dx
	mov 	%dx, %si
	shl 	$1,  %si
	add 	$sticks, %si
	mov 	(%si), %si
	cmp 	%si, %cx
	jg 		2b

	# Decrement the row sticks
	mov 	(%bp), %dx
	mov 	%dx, %si
	shl 	$1,  %si
	add 	$sticks, %si
	sub 	%cx, (%si)

	# Decrement sticks count
	sub 	%cx, sticks_count

	# Set turn to computer
	movb 	$COMPUTER_TURN, curr_turn

	# 'Pop' cx and return
	add 	$2, %sp
	ret

#
# Strings
#
str_error:
	.ascii "                                      ERROR                                     "
	.ascii "  This computer is only allowed to run for people who win the following game:   \r\n"
.equ str_error_len, .-str_error

str_game_title:
	.ascii " _______  _______  _______ \r\n"
	.ascii "|    |  ||_     _||   |   |\r\n"
	.ascii "|       | _|   |_ |       |\r\n"
	.asciz "|__|____||_______||__|_|__| by Theldus\r\n\r\n"

str_game_explanation:
	.ascii "The NIM game consists of removing the sticks from the table, \r\n"
	.ascii "the amount you want, a single row at a time. The last to \r\n"
	.asciz "remove the sticks LOSES!! Good luck!!!\r\n\r\n"

str_who_starts:
	.asciz "Who starts? (UP/DOWN, Enter select): \r\n"
str_you:
	.asciz "You\r\n"
str_me:
	.asciz "Me\r\n"
str_arrow:
	.asciz "-> "
str_empty_space:
	.asciz "   "

str_stick_ddots:
	.asciz ": \r\n"
str_stick_1: .asciz "      \xdb\xdb\r\n"
str_stick_2: .asciz "      \xdb\xdb \xdb\xdb\r\n"
str_stick_3: .asciz "      \xdb\xdb \xdb\xdb \xdb\xdb\r\n"
str_stick_4: .asciz "      \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb\r\n"
str_stick_5: .asciz "      \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb\r\n"
str_stick_6: .asciz "      \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb\r\n"
str_stick_7: .asciz "      \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb \xdb\xdb\r\n"
str_sticks_vec:
	.word str_stick_1, str_stick_2, str_stick_3, str_stick_4
	.word str_stick_5, str_stick_6, str_stick_7

str_think_pc:
	.asciz "\r\nThats my turn, can I play? (press any key) "
str_think_askrow:
	.asciz "\r\nChoose the row you want (Up/Down arrows, Enter to select): "
str_think_askstick:
	.asciz "How many sticks you want to remove? (Up/Down arrows, Enter to select): "

str_newline:
	.asciz "\r\n"

str_lose:
	.ascii "         @@@ @@@  @@@@@@  @@@  @@@      @@@       @@@@@@   @@@@@@ @@@@@@@@\r\n"
	.ascii "         @@! !@@ @@!  @@@ @@!  @@@      @@!      @@!  @@@ !@@     @@!\r\n"
	.ascii "          !@!@!  @!@  !@! @!@  !@!      @!!      @!@  !@!  !@@!!  @!!!:!\r\n"
	.ascii "           !!:   !!:  !!! !!:  !!!      !!:      !!:  !!!     !:! !!:\r\n"
	.asciz "           .:     : :. :   :.:: :       : ::.: :  : :. :  ::.: :  : :: :::\r\n\r\n"
str_win:
	.ascii "                   __ __  ___  __ __      __    __ ____ ____  \r\n"
	.ascii "                  |  |  |/   \\|  |  |    |  |__|  |    |    \\ \r\n"
	.ascii "                  |  |  |     |  |  |    |  |  |  ||  ||  _  |\r\n"
	.ascii "                  |  ~  |  O  |  |  |    |  |  |  ||  ||  |  |\r\n"
	.ascii "                  |___, |     |  :  |    |  `  '  ||  ||  |  |\r\n"
	.ascii "                  |     |     |     |     \\      / |  ||  |  |\r\n"
	.asciz "                  |____/ \\___/ \\__,_|      \\_/\\_/ |____|__|__|\r\n\r\n"
str_play_again:
	.asciz "                     =-=- Press any key to play again -=-="

#
# Game data
#
curr_turn:    .byte 0xF
sticks_count: .byte 16
sticks:       .word 1,3,5,7

# Keyboard
got_released: .byte 0x0

#
# Constants
#

# Game
.equ PLAYER_TURN,   0
.equ COMPUTER_TURN, 1

# Keyboard scan codes
.equ KBD_UP,    0x48
.equ KBD_DOWN,  0x50
.equ KBD_ENTER, 0x1C
