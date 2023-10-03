; MIT License
;
; Copyright (c) 2023 Davidson Francis <davidsondfgl@gmail.com>
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

[BITS 16]
[ORG 0]

%define ROUND_SIZE(s) (((s) + (512)-1) & -(512))
%define dbg xchg bx, bx

%macro delay_ms 1
	mov cx, (%1*1000)>>16
	mov dx, (%1*1000)&0xFFFF
	call delay
%endmacro

;
; ROM header
;
db 0x55, 0xAA       ; ROM signature
db ROM_SIZE_BLOCKS  ; ROM size in blocks of 512-bytes
jmp _init

; Comment/uncomment to enable/disable tests
%define TEST

%define BASIC_SEGMENT 0x7000
%define WORK_SEGMENT  BASIC_SEGMENT

;
; Drive number
; 0 = floppy a
; 1 = floppy b
; 80h=drive 0, 81h=drive 1....
;
; USB Flash Drives also identify as 80h in my
; motherboard, so thats why I'm using it...
;
%ifdef TEST
%define DRIVE_NUMBER 0x0
%define NEW_INT 0x18
%else
%define DRIVE_NUMBER 0x80
%define NEW_INT 0xC8
%endif

%ifdef TEST
%warning "Test build is enabled!"
%else
%warning "Test build is disabled!, this should work on real HW!"
%endif

; 512 bytes of gap between ROM basic
; and anything else
%define WORK_GAP 512

; Where it should store the CS:IP for the int15
%define WORK_OFF_INT15_IP   basicrom_size+WORK_GAP+0 ; 2 bytes (78200h)
%define WORK_OFF_INT15_CS   WORK_OFF_INT15_IP+2      ; 2 bytes (78202h)

; Where it should store the 512-bytes floppy sector
%define WORK_OFF_FLOPPY_SEC WORK_OFF_INT15_CS+2      ; 512 bytes (78204h)

; Cassette read bytes pointer
%define WORK_OFF_CASSETTE_POS WORK_OFF_FLOPPY_SEC+512 ; 2 bytes (78404h)

; Magic number
%define WORK_MAGIC WORK_OFF_CASSETTE_POS+2 ; 4 bytes (78408h)

;
; Init routine
;
; Warning:
; As per PCI Local Bus specs, the memory *inside* the ROM
; is already copied to the RAM and *is* writable, but,
; if changed, the checksums must be recalculated.
;
; This strictly true if one wants to register a 'BEV'
; (as the headers will be parsed again). Otherwise,
; should be ok to change.
;
; As I want to register this as a 'bootable device', I have
; to follow the specs and *do not* change the memory here.
;
_init:
	pusha ; Assuming we have stack
	pushf
	push ds

	;
	; Install our interrupt handler;
	;
	; This handler is the one responsible to copy
	; the basic into elsewhere and then start from
	; there. It also installs the int15 handler.
	;
	; This is necessary since the specs requires
	; the OptionROM to be read-only after the _init
	; call.
	;
	xor ax, ax
	mov ds, ax
	mov ax, cs
	mov word [NEW_INT * 4 + 0], pre_basic_init
	mov word [NEW_INT * 4 + 2], ax

	pop ds
	popf
	popa
	retf

;
; Copy the BASIC ROM to the right place, configure
; some initial values and then jump to the BASIC code
;
pre_basic_init:
	pusha ; Assuming we have stack
	pushf
	push ds
	push es

	; Copy our BASIC to BASIC_SEGMENT:0000
	mov ax, cs
	mov ds, ax
	mov ax, BASIC_SEGMENT
	mov es, ax
	mov si, basicrom_bin
	mov di, 0

	mov cx, basicrom_size
	.copy_basic:
		lodsb
		stosb
		loop .copy_basic

	; Backup original int15 handler
	xor ax, ax
	mov ds, ax
	mov word bx, [0x15 * 4 + 0] ; ip
	mov word cx, [0x15 * 4 + 2] ; cs
	mov word [es:WORK_OFF_INT15_IP], bx
	mov word [es:WORK_OFF_INT15_CS], cx

	; Install our new int15 handler
	mov ax, cs
	mov word [0x15 * 4 + 0], int15_handler
	mov word [0x15 * 4 + 2], ax

	; Set our sector initial pos to '0'
	mov word [es:WORK_OFF_CASSETTE_POS], 0

	; Populate magic number
	mov dword [es:WORK_MAGIC], 0xdeadbeef

	; Exit
	pop es
	pop ds
	popf
	popa

	; Jump to BASIC
	jmp BASIC_SEGMENT:0

;
; Our hooked int15 handler
;
int15_handler:
	;
	; Check if AH is between 0 and 3 (inclusive), if not,
	; call the original int15 handler
	;
	cmp ah, 0x0
	je .handle_cassette_ah0
	cmp ah, 0x1
	je .handle_cassette_ah1
	cmp ah, 0x2
	je .handle_cassette_ah2
	cmp ah, 0x3
	je .handle_cassette_ah3

	;
	; Not cassette, we should call the default handler
	;

	; Prepare to jump to original int15h
	push es

	push WORK_SEGMENT
	pop  es
	push word [es:WORK_OFF_INT15_CS]
	push word [es:WORK_OFF_INT15_IP]

	push bp
	push ax

	;
	; Stack right now:
	; 0 - AX     0-> AX -> IP -> IP
	; 2 - BP     2-> BP -> IP -> CS
	; 4 - IP     4-> IP -> CS
	; 6 - CS ->  6-> IP -> __
	; 8 - ES ->  8-> CS -> __
	;

	; Retrieve ES
	mov bp, sp
	mov word ax, [bp+8]
	mov es, ax
	; Move CS into ES
	mov word ax, [bp+6]
	mov word [bp+8], ax
	; Mov IP into CS
	mov word ax, [bp+4]
	mov word [bp+6], ax

	; Retrieve Backup
	pop ax
	pop bp
	add sp, 2

	; Jump to original int15h
	retf

; Turn on tape drive's motor (stub)
.handle_cassette_ah0:
	clc  ; CF = 0 == success
	iret

; Turn off tape drive's motor (stub)
.handle_cassette_ah1:
	clc
	iret

;
; CASSETTE - READ DATA (PC and PCjr only)
; AH = 02h
; CX = number of bytes to read
; ES:BX -> buffer
;
; Return:
; CF = clear if successful
; DX = number of bytes read
; ES:BX -> byte following last byte read
; CF = set on error
; AH = status (see #00409)
;
; (Table 00409)
; Values for Cassette status:
; 00h    successful
; 01h    CRC error
; 02h    bad tape signals
; 04h    no data
; 80h    invalid command
; 86h    no cassette present
;
.handle_cassette_ah2:
	%define OFF_CX_BCK         16
	%define OFF_DEST_BUFF_SEG  8
	%define OFF_DEST_BUFF_OFF  6
	%define OFF_AMNT_BYTES_REM 4
	%define OFF_START_SECTOR   2
	%define OFF_FIRST_SECTOR   0

	; Backup
	push bp
	push cx
	push si
	push di
	push ds

	; Working values
	push es ; original ES buffer
	push bx ; original BX buffer
	push cx ; amount of bytes remaining

	; Calculate starting sector
	mov  ax, WORK_SEGMENT
	mov  es, ax
	mov  ax, [es:WORK_OFF_CASSETTE_POS]
	mov  bx, ax
	shr  ax, 9 ; /512
	inc  ax    ; sector is 1-based
	push ax    ; starting sector

	; Calculate first-sector offset
	and  bx, 511
	push bx

	; Stack:
	; bp[0] = first-sector offset
	; bp[2] = sector number
	; bp[4] = amout of bytes remaining
	; bp[6] = BX buffer
	; bp[8] = ES backup
	; Backup:
	; bp[10] = DS backup
	; bp[12] = DI backup
	; bp[14] = SI backup
	; bp[16] = CX backup
	; bp[18] = BP backup
	;
	mov  bp, sp

	.read_sector_loop:
		; Dest segment
		mov ax, WORK_SEGMENT
		mov es, ax
		mov ds, ax ; Just in case an early return
		; Dest offset
		mov bx, WORK_OFF_FLOPPY_SEC

		; INT 13
		; cylinder (ch) + sector number (cl)
		mov word cx, [ss:bp+OFF_START_SECTOR]
		mov dh, 0              ; head number
		mov dl, DRIVE_NUMBER
		mov ah, 2
		mov al, 1              ; read single sector
		int 0x13
		jc .done_error

		;
		; Check if we should start at beginning (or not)
		; from the sector
		;
		; Obs: This is kind of dumb because...
		;
		cmp word [ss:bp+OFF_FIRST_SECTOR], 0
		je .do_copy
		add word bx, [ss:bp+OFF_FIRST_SECTOR]
		mov word [ss:bp+OFF_FIRST_SECTOR], 0

	.do_copy:
		;
		; Copy up to 512 bytes into the true destination buffer
		;

		; Origin
		mov ax, WORK_SEGMENT
		mov ds, ax
		mov si, bx ; BX holds our current offset

		; Dest buffer
		mov ax, [ss:bp+OFF_DEST_BUFF_SEG]  ;  ES
		mov es, ax
		mov ax, [ss:bp+OFF_DEST_BUFF_OFF]  ; 'BX'
		mov di, ax

		;
		; Bytes remaining (BX) and sector size counter
		;
		mov bx, word [ss:bp+OFF_AMNT_BYTES_REM]

		.copy_to_buf:
			; If bytes remaining == 0
			cmp bx, 0
			je .done_success
			; If already copied 512 bytes
			cmp si, 512+WORK_OFF_FLOPPY_SEC
			je .copy_to_buf_end

			lodsb ; source (tmp buffer, DS:SI)
			stosb ; dest (ES:DI, originally ES:BX)

			; Update indexes
			dec bx  ; Decrease bytes remaining
			jmp .copy_to_buf

		.copy_to_buf_end:
			; Update dest buffer offset
			mov [ss:bp+OFF_DEST_BUFF_OFF],  di
			; Update bytes remaining
			mov [ss:bp+OFF_AMNT_BYTES_REM], bx
			; Increase start sector
			inc word [ss:bp+OFF_START_SECTOR]
			jmp .read_sector_loop

.done_error:
	stc
	mov ah, 0x4 ; no data
.done_success:
	clc
	mov ah, 0 ; successful

.done:
	;
	; Return values
	;

	; ES:BX with updated value
	; (ES needs to be updated just in case its called
	; right after int13)
	mov cx, [ss:bp+OFF_DEST_BUFF_SEG]
	mov es, cx
	mov bx, di

	; Update our 'tape' position
	mov cx, [ss:bp+OFF_CX_BCK] ; original count value
	add [ds:WORK_OFF_CASSETTE_POS], cx

	; Remove the 6 working values
 	pushf   ; Keep CF untouched (from CLC/STC)
 	pop  cx ; backup in CX
 	add sp, 5*2
 	push cx
 	popf    ; restore EFLAGS via CX =)

	; Restore other values
	pop ds
	pop di
	pop si
	; Amount of bytes read (just the same in the beginning)
	pop cx
	; this is required to be returned in dx...
	mov dx, cx
	pop bp

	iret

;
; CASSETTE - WRITE DATA (PC and PCjr only)
; AH = 03h
; CX = number of bytes to write
; ES:BX -> data buffer

; Return:
; CF clear if successful
; ES:BX -> byte following last byte written
; CF set on error
; AH = status (see #00409)
; CX = 0000h
;
.handle_cassette_ah3:
	; Backup
	push bp
	push dx
	push si
	push di
	push ds

	; Working values
	push bx ; original BX buffer
	push es ; original ES buffer
	push 0  ; dest BX
	push 0  ; dest ES
	push cx ; amount of bytes remaining

	; Calculate current sector
	mov ax, WORK_SEGMENT
	mov es, ax
	mov ax, [es:WORK_OFF_CASSETTE_POS]
	mov bx, ax
	shr ax, 9 ; Current sector (/512, incremented by 1 later)
	push ax

	; Calculate current offset (address)
	and  bx, 511
	add  bx, WORK_OFF_FLOPPY_SEC
	push bx

	%define STCK_ORIG_BX    12
	%define STCK_ORIG_ES    10
	%define STCK_DEST_BX     8
	%define STCK_DEST_ES     6
	%define STCK_BYTES_REM   4
	%define STCK_CURR_SECTOR 2
	%define STCK_CURR_OFF    0

	mov bp, sp
	.do_write_loop:
		cmp word [ss:bp+STCK_BYTES_REM], 0
		je .write_success

		inc word [ss:bp+STCK_CURR_SECTOR]

		; Check if we can safely write an entire sector
		; or we should to fill our tmp buffer first
		cmp word [ss:bp+STCK_BYTES_REM], 512
		jl  .do_fill_read
		cmp word [ss:bp+STCK_CURR_OFF], 0
		jne .do_fill_read

		;
		; We can, prepare our values and jump
		;
		mov ax, [ss:bp+STCK_ORIG_ES]
		mov [ss:bp+STCK_DEST_ES], ax
		mov ax, [ss:bp+STCK_ORIG_BX]
		mov [ss:bp+STCK_DEST_BX], ax

		; Adjust counters and jump
		sub word [ss:bp+STCK_BYTES_REM], 512
		add word [ss:bp+STCK_ORIG_BX],   512
		add word [es:WORK_OFF_CASSETTE_POS], 512
		jmp .do_write_sector

		;
		; We cannot copy our current sector before reading
		; it first and then filling it with our values
		;
	.do_fill_read:
		; Dest segment
		mov ax, WORK_SEGMENT
		mov es, ax
		; Dest offset
		mov bx, WORK_OFF_FLOPPY_SEC

		; INT 13
		; cylinder (ch) + sector number (cl)
		mov word cx, [ss:bp+STCK_CURR_SECTOR]
		mov dh, 0              ; head number
		mov dl, DRIVE_NUMBER
		mov ah, 2
		mov al, 1              ; read single sector
		int 0x13
		jc .write_error

		; source
		mov ax, [ss:bp+STCK_ORIG_ES]
		mov ds, ax
		mov si, [ss:bp+STCK_ORIG_BX]
		;
		; dest
		;
		mov ax, WORK_SEGMENT
		mov es, ax
		mov di, [ss:bp+STCK_CURR_OFF] ; index, i / < 512

		; indexes
		mov cx, [ss:bp+STCK_BYTES_REM]     ; CX
		mov dx, [es:WORK_OFF_CASSETTE_POS] ; curr_amnt/tmp

		.do_fill:
			; i < 512 / i.e., buff < buff_start+512
			cmp di, WORK_OFF_FLOPPY_SEC+512
			jge .do_fill_out
			; cx <= 0
			cmp cx, 0
			jle .do_fill_out
			lodsb  ; ES:BX orig, (DS:SI)
			stosb  ; (ES:DI, tmp_buffer)
			dec cx ; bytes_rem--
			inc dx ; curr_amnt++
			jmp .do_fill
		.do_fill_out:
			; Update values
			mov [ss:bp+STCK_BYTES_REM], cx
			mov [ss:bp+STCK_ORIG_BX], si
			mov [es:WORK_OFF_CASSETTE_POS], dx


		; Reset current offset because the padding is
		; already done
		mov word [ss:bp+STCK_CURR_OFF], WORK_OFF_FLOPPY_SEC

		; Prepare 'ES:BX' to write the sector
		mov ax, WORK_SEGMENT
		mov [ss:bp+STCK_DEST_ES], ax
		mov word [ss:bp+STCK_DEST_BX], WORK_OFF_FLOPPY_SEC

	.do_write_sector:
		; Buffer
		mov ax, [ss:bp+STCK_DEST_ES]
		mov es, ax
		mov bx, [ss:bp+STCK_DEST_BX]

		; Write
		mov word cx, [ss:bp+STCK_CURR_SECTOR]
		mov dh, 0              ; head number
		mov dl, DRIVE_NUMBER
		mov ah, 3 ; Write disk sector
		mov al, 1              ; read single sector
		int 0x13
		jc .write_error

		jmp .do_write_loop

.write_error:
	stc
	mov ax, 0x0400 ; no data
.write_success:
	clc
	mov ax, 0x0000 ; success

.write_done:
	;
	; Return values
	;

	; ES:BX with updated value
	mov cx, [ss:bp+STCK_ORIG_ES]
	mov es, cx
	mov bx, [ss:bp+STCK_ORIG_BX]

 	; Tape already updated

 	; Remove working values
 	pushf   ; Keep CF untouched
 	pop  cx ; backup in CX
 	add  sp, 7*2
 	push cx
 	popf    ; restore EFLAGS via CX =)

 	; Restore remaining
 	pop ds
 	pop di
 	pop si
 	pop dx
 	xor cx, cx ; CX must be 0
 	pop bp

	iret

; ===================
; BASIC ROM here!!!!
; ===================
basicrom_bin:
incbin 'IBM_BASIC_C10.bin'
basicrom_size: equ $-basicrom_bin

; Sizes
ROM_SIZE        equ $-$$
ROM_SIZE_ROUND  equ ROUND_SIZE(ROM_SIZE)
ROM_SIZE_BLOCKS equ ROM_SIZE_ROUND/512

; Padding
times ROM_SIZE_ROUND-ROM_SIZE db 0
