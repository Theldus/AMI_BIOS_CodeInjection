;
; MIT License
;
; Copyright (c) 2021-23 Davidson Francis <davidsondfgl@gmail.com>
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
;

[BITS 16]
section BOOTSECTOR start=0

%include "defines.inc"

boot_init:
    cli

    ; Read 10 sectors
    mov   ax, 0x1000 ; segment
    mov   es, ax
    mov   bx, 0x0000 ; offset addr
    mov   al, 10     ; num sectors to read
    mov   cl, 2      ; from sector 2 (1-based)
    call  read_sectors

    ; Far call to our module
    call 0x1000:0x0000

    ; Hang
    jmp $

read_sectors:
    mov ah, 2
    mov ch, 0
    mov dh, 0
    int 0x13
    jc .again
    ret
.again:
    xor ax, ax
    int 0x13
    jmp read_sectors
    ret

times 510-($-$$) db 0
dw 0xAA55

;
; Section game text
;

section GAME_TEXT follows=BOOTSECTOR vstart=0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;             System Helpers & Boot stuff                                     #
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Backup registers and flags
_start:
	; Define proper segment registers
	mov   ax, cs
	mov   ds, ax
	mov   es, ax
	mov   fs, ax

	; Stack
	mov   ax, 0x2000
	mov   ss, ax
	mov   sp, 0xFFF

	;
	; Configure serial
	;
	; Calculate and set divisor
	outbyte UART_LCR,  UART_LCR_DLA
	outbyte UART_DLB1, UART_DIVISOR & 0xFF
	outbyte UART_DLB2, UART_DIVISOR >> 8
	; Set line control register:
	outbyte UART_LCR, UART_LCR_BPC_8
	; Reset FIFOs and set trigger level to 1 byte.
	outbyte UART_FCR, UART_FCR_CLRRECV|UART_FCR_CLRTMIT|UART_FCR_TRIG_1
	; IRQs enabled, RTS/DSR set
	outbyte UART_MCR, UART_MCR_OUT2|UART_MCR_RTS|UART_MCR_DTR

	; Hide cursor
	mov   si, str_hide_cursor
	call  print

	; Reset data
	call  reset_data

	; Jump to game
	jmp main_screen

; ----------------------------------------------------
; reset_data: Reset all game data at the beginning
; ----------------------------------------------------
reset_data:
	mov byte ss:[curr_turn],    0xF
	mov byte ss:[sticks_count], 16
	mov si, sticks
	mov word ss:[si+0], 1
	mov word ss:[si+2], 3
	mov word ss:[si+4], 5
	mov word ss:[si+6], 7
	ret

; ----------------------------------------------------
; read_number: Read a number with the arrow keys (up
; and down) from 0 to 7, Enter selects the number.
;
; Returns:
;   cx: Number read.
; ----------------------------------------------------
read_number:
	call  read_kbd
	cmp   al, KBD_UP
	jne   .l1
	add   cx, 1
	and   cx, 7
	jmp   .l3
.l1:
	cmp   al, KBD_DOWN
	jne   .l2
	sub   cx, 1
	and   cx, 7
	jmp   .l3
.l2:
	cmp   al, KBD_ENTER
	jne   read_number
	jmp   .l4
.l3:
	; Move cursor to left
	mov   si, str_cursor_back
	call  print

	; Draw again (overwriting the previous)
	mov   al, cl
	add   al, '0'
	call  print_char

	jmp read_number
.l4:
	ret

; ---------------------------------------------
; read_kbd: Reads a keypress from the keyboard
;
; This routine uses a polling approach because
; the BIOS at this stage does not have keyboard
; ints yet! (and I'm too lazy to setup one)
;
; Returns:
;   ah: Scan code
;   al: ASCII Character code
; ---------------------------------------------
read_kbd:
	push  dx
.loop:
	inputb UART_LSR
	bt    ax, 0
	jnc   .loop
	inputb UART_RB ; WARN: Do not handle ANSI escape sequences
	pop   dx
	ret

; ---------------------------------------
; print: Print a string to screen
;
; Parameters:
;   si: pointer to string
; ---------------------------------------
print:
.loop:
	lodsb
	cmp   al, 0
	je    .done
	call  print_char
	jmp   .loop
.done:
	ret

; ---------------------------------------------
; print_char: Print a character to the screen
;
; Parameters:
;   al: character
; ---------------------------------------------
print_char:
	push bx
	push dx

	mov   bl, al
	mov   dx, UART_LSR
    .loop:
	in    al, dx
	and   al, UART_LSR_TFE
	cmp   al, 0
	je .loop
	mov   dx, UART_BASE
	mov   al, bl
	out   dx, al

	pop dx
	pop bx
	ret

; ---------------------------------------------
; clear_screen: Clear the screen
; ---------------------------------------------
clear_screen:
	mov   si, str_clear_screen
	call  print
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Game helpers                                                                #
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; --------------------------------------------
; draw_title: Draw game title
; --------------------------------------------
draw_title:
	call  clear_screen
	mov   si, str_game_title
	call  print
	ret

; --------------------------------------------
; draw_sticks: Draw the sticks remaining
; --------------------------------------------
draw_sticks:
	xor   cx, cx
.l1:
	mov   al, cl
	add   al, 49
	call  print_char
	mov   si, str_stick_ddots
	call  print
	mov   si, cx
	shl   si, 1
	add   si, sticks
	mov   si, ss:[si]
	cmp   si, 0
	je    .l2
	sub   si, 1
	shl   si, 1
	add   si, str_sticks_vec
	mov   si, [si] ; sticks vec is a constant in code seg!
	mov   dx, si
	call  print
	mov   si, dx
	call  print
	mov   si, dx
	call  print
.l2:
	add   cl, 1
	cmp   cl, 4
	jl    .l1
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Game entry point                                                            #
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Redraw the options
;
draw_options:
	mov   si, str_cursor_up_2x
	call  print

	; Check pos
	cmp   dx, 0
	jne   .arrow_me

	; Arrow YOU
	.arrow_you:
		mov   si, str_arrow
		call  print
		mov   si, str_you
		call  print
		mov   si, str_empty_space
		call  print
		mov   si, str_me
		call  print
		jmp   .out_drawing
	.arrow_me:
		mov   si, str_empty_space
		call  print
		mov   si, str_you
		call  print
		mov   si, str_arrow
		call  print
		mov   si, str_me
		call  print
.out_drawing:
	ret

;
; Main screen, decides who starts to play
;
main_screen:
	xor   dx, dx

	call  draw_title
	mov   si, str_game_explanation
	call  print

	mov   si, str_who_starts
	call  print

	call  draw_options

	; Reads who starts
.who_starts:
	call  read_kbd
	cmp   al, KBD_UP
	jne   .l1
	sub   dx, 1
	and   dx, 1
	jmp   .l3
.l1:
	cmp   al, KBD_DOWN
	jne   .l2
	add   dx, 1
	and   dx, 1
	jmp   .l3
.l2:
	cmp   al, KBD_ENTER
	jne   .who_starts
	jmp   .out_who_starts
.l3:
	; Update options on screen
	call  draw_options
	jmp   .who_starts

.out_who_starts:
	; Save current turn
	mov   ss:[curr_turn], dl

game_loop:
	mov   dl, ss:[sticks_count]
	cmp   dl, 0
	jle   game_loop_end
	call  think
	jmp   game_loop
game_loop_end:

	; Elects who win
	call  draw_title
	mov   dl, ss:[curr_turn]
lose:
	cmp   dl, COMPUTER_TURN
	jne   win
	mov   si, str_lose
	call  print
	jmp   wait_key
win:
	mov   si, str_win
	call  print
wait_key:
	mov   si, str_play_again
	call  print
	call  read_kbd

	; Reset everything
	call  reset_data

	; Start again
	call  clear_screen
	jmp   main_screen

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PC and Player movements                                                     #
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; --------------------------------------------
; think: PC and Player movements
; --------------------------------------------
think:
	call  draw_title
	call  draw_sticks

.computer_turn:
	mov   dl, ss:[curr_turn]
	cmp   dl, COMPUTER_TURN
	jne   .player_turn

	mov   si, str_think_pc
	call  print
	call  read_kbd

	; Count amnt of heaps > 1
	xor   cx, cx
	xor   dx, dx
	mov   si, sticks
.count_sticks:
	cmp   word ss:[si+0], 1
	jg    .sticks_gt_1
	jmp   .sticks_lte_1
.sticks_gt_1:
	add   dx, 1
.sticks_lte_1:
	add   cx, 1
	add   si, 2
	cmp   cx, 4
	jl   .count_sticks
	push  dx
	mov   bp, sp

.nim_sum:
	; Calculate NIM sum
	mov   si, sticks
	mov   dx, ss:[si+0]
	xor   dx, ss:[si+2]
	xor   dx, ss:[si+4]
	xor   dx, ss:[si+6]

	; Check if there is a good movement or not
	cmp   dx, 0
	jne   .recalculate_nim_sum

.only_one:
	;
	; Too bad, if the player keeps playing like this the
	; computer will lose.
	;
	xor   cx, cx
.l1:
	mov   ax, ss:[si]
	cmp   ax, 0
	jne   .l2
	add   cx, 1
	add   si, 2
	cmp   cx, 4
	jl   .l1
.l2:
	sub   word ss:[si], 1
	sub   byte ss:[sticks_count], 1
	jmp   .finish

	;
	; If NIM sum differs from 0, great, we *will* win. We just
	; need to recalculate the amount of pieces.
	;
.recalculate_nim_sum:
	xor   cx, cx
	mov   si, sticks
.recalc_loop:
	mov   ax, ss:[si]
	mov   bx, ax
	xor   bx, dx     ; bx = p ^ nimsum, ax = p, dx = nimsum
	cmp   bx, ax
	jl   .recalc_end
	add   cx, 1
	add   si, 2
	cmp   cx, 4
	jl  .recalc_loop
.recalc_end:
	;
	; We have 2 options here:
	; a) More than one heap with more than one stick
	; b) Exactly one heap with more than one stick
	;
	; The option b) do not conforms with the maths as
	; expected and we fall in a case were we remove
	; n or n-1 sticks from that column. So is necessary
	; to bifurcate these two scenarios here.
	;
	cmp word [bp], 1
	jne   .scenario_a

.scenario_b:
	mov    bl, ss:[sticks_count]
	sub    bl, al
	mov    ax, bx

	;
	; We need to leave a odd numbers of stickers to the player
	; If odd: remove all the sticks from the line
	; If even: remove all but one sticks from the line
	;
	and   al, 1
	cmp   al, 0
	je   .even
.odd:
	mov word ss:[si], 0
	mov   ss:[sticks_count], bl
	jmp   .finish
.even:
	mov word ss:[si], 1
	add   bl, 1
	mov   ss:[sticks_count], bl
	jmp   .finish

.scenario_a:
	; Now we proceed as usual
	mov   ss:[si], bx
	sub   ax, bx
	sub   ss:[sticks_count], ax

	; Set turn to player
.finish:
	mov byte ss:[curr_turn], PLAYER_TURN
	add    sp, 2
	ret

;
; Player turn
;
.player_turn:
	mov   si, str_think_askrow
	call  print

	; Read rows
.read_rows:
	mov   cx, 1
	mov   al, '1'
	call  print_char
.invalid_row:
	call  read_number
	; Check if selected row is valid
	cmp   cx, 0
	je    .invalid_row
	cmp   cx, 4
	jg    .invalid_row
	; Check if selected row is not empty
	mov   si, cx
	sub   si, 1
	shl   si, 1
	add   si, sticks
	mov   si, ss:[si]
	cmp   si, 0
	je   .invalid_row
	sub   cx, 1 ; make row 0 based
	push  cx
	mov   bp, sp

	; Read sticks amount
.read_amnt:
	mov   si, str_newline
	call  print
	mov   si, str_think_askstick
	call  print
	mov   cx, 1
	mov   al, '1'
	call  print_char
.invalid_amnt:
	call  read_number
	; Check if selected amount is valid
	cmp   cx, 0
	je    .invalid_amnt
	; Check if selected amount not exceeds the sticks amnt
	mov   dx, [bp]
	mov   si, dx
	shl   si, 1
	add   si, sticks
	mov   si, ss:[si]
	cmp   cx, si
	jg    .invalid_amnt

	; Decrement the row sticks
	mov   dx, [bp]
	mov   si, dx
	shl   si, 1
	add   si, sticks
	sub   ss:[si], cx

	; Decrement sticks count
	sub   ss:[sticks_count], cx

	; Set turn to computer
	mov byte ss:[curr_turn], COMPUTER_TURN

	; 'Pop' cx and return
	add   sp, 2
	ret

;
; Strings
;
str_hide_cursor:   db 0x1B, '[?25l', 0
str_clear_screen:  db 0x1B, '[2J', 0x1B, '[H', 0 ; Clear & jump to top (0,0)
str_cursor_back:   db 0x1B, '[D', 0  ; Cursor backwards
str_cursor_up_2x:  db 0x1B, '[2A', 0 ; Cursor upwards two times

str_game_title:
	db     ' _______  _______  _______ ', 10,13
	db     '|    |  ||_     _||   |   |', 10,13
	db     '|       | _|   |_ |       |', 10,13
	db     '|__|____||_______||__|_|__| by Theldus', 10,13, 10,13, 0

str_game_explanation:
	db     'The NIM game consists of removing the sticks from the table the amount you', 10,13
	db     'want, a single row at a time. The last to remove the sticks LOSES!!', 10,13
	db     'Good luck!!!', 10,13, 10,13, 0

str_who_starts:
	db     'Who starts? (UP - k/DOWN - j, Enter select):', 10,13, 10,13, 10,13, 0
str_you:
	db     'You', 10,13, 0
str_me:
	db     'Me', 10,13, 0
str_arrow:
	db     '-> ', 0
str_empty_space:
	db     '   ', 0

str_stick_ddots:
	db     ': ', 10,13, 0
str_stick_1: db     '      ##', 10,13, 0
str_stick_2: db     '      ## ##', 10,13, 0
str_stick_3: db     '      ## ## ##', 10,13, 0
str_stick_4: db     '      ## ## ## ##', 10,13, 0
str_stick_5: db     '      ## ## ## ## ##', 10,13, 0
str_stick_6: db     '      ## ## ## ## ## ##', 10,13, 0
str_stick_7: db     '      ## ## ## ## ## ## ##', 10,13, 0
str_sticks_vec:
	dw str_stick_1, str_stick_2, str_stick_3, str_stick_4
	dw str_stick_5, str_stick_6, str_stick_7

str_think_pc:
	db     10,13, 'Thats my turn, can I play? (press ENTER) ', 0
str_think_askrow:
	db     10,13, 'Choose the row you want (Up - k/Down - j, Enter to select): ', 0
str_think_askstick:
	db     'How many sticks you want to remove? (Up - k/Down - j, Enter to select): ', 0

str_newline:
	db     10,13, 0

str_lose:
    db     '         @@@ @@@  @@@@@@  @@@  @@@      @@@       @@@@@@   @@@@@@ @@@@@@@@', 10,13
    db     '         @@! !@@ @@!  @@@ @@!  @@@      @@!      @@!  @@@ !@@     @@!', 10,13
    db     '          !@!@!  @!@  !@! @!@  !@!      @!!      @!@  !@!  !@@!!  @!!!:!', 10,13
    db     '           !!:   !!:  !!! !!:  !!!      !!:      !!:  !!!     !:! !!:', 10,13
    db     '           .:     : :. :   :.:: :       : ::.: :  : :. :  ::.: :  : :: :::', 10,13, 10,13, 0
str_win:
    db     '                   __ __  ___  __ __      __    __ ____ ____  ', 10,13
    db     `                  |  |  |/   \\|  |  |    |  |__|  |    |    \\ `, 10,13
    db     `                  |  |  |     |  |  |    |  |  |  ||  ||  _  |`, 10,13
    db     `                  |  ~  |  O  |  |  |    |  |  |  ||  ||  |  |`, 10,13
    db     `                  |___, |     |  :  |    |  \`     ||  ||  |  |`, 10,13
    db     `                  |     |     |     |     \\      / |  ||  |  |`, 10,13
    db     `                  |____/ \\___/ \\__,_|      \\_/\\_/ |____|__|__|`, 10,13,10,13, 0
str_play_again:
    db     '                     =-=- Press ENTER to play again -=-=', 0

;
; Section game data
; (Our data should be located in the same place as our stack
; because the code section is not writtable!)
;

section GAME_DATA follows=GAME_TEXT vstart=0

curr_turn:    db  0       ; default = 0xF
sticks_count: db  0       ; default = 16
sticks:       dw  0,0,0,0 ; default = 1,3,5,7

;
; Constants
;

; Game
PLAYER_TURN   equ 0
COMPUTER_TURN equ 1

; Keyboard scan codes
KBD_UP    equ 'k'
KBD_DOWN  equ 'j'
KBD_ENTER equ 13 ; Carriage Return
