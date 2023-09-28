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
[ORG 0x7C00] ; No need to change anything here

; --------------------------------
; Macros
; --------------------------------
%macro dbg 0
	xchg bx, bx
%endmacro

%macro inputb 1
	mov dx, %1
	in al, dx
%endmacro

%macro outbyte 2
	mov ax, %2
	mov dx, %1
	out dx, al
%endmacro

%ifndef BAUDRATE
%define BAUDRATE 115200
%endif

%ifndef BIOS
%define SETUP_STACK
%endif

; --------------------------------
; Code
; --------------------------------

; Disable ints
cli

%ifdef SETUP_STACK
mov ax, 0x7C0
add ax, 544
mov ss, ax
mov sp, 4096
%endif

;
; Create our GDB on stack
;
; Code and data with 4G, base=0, 4k pages
;

; Entry 2, Data
push dword 0x00CF9200
push dword 0x0000FFFF
; Entry 1, Code
push dword 0x00CF9A00
push dword 0x0000FFFF
; Entry 0
push dword 0
push dword 0

; Phys addr
xor eax, eax
mov bp, sp
mov ax, ss
shl ax, 4
add ax, bp ; Make AX point to the first element on stack

; GDT desc
push eax
push word 23 ; gdt_end-gdt-1

; Jump to protected mode
mov bp, sp
lgdt [ss:bp]

mov eax, cr0
or  eax, 1     ; protecc mode
mov cr0, eax

; Do your 'far jump' without absolute address =)
push 0x08
call protecc
return:
retf

;
; Adjust return address:
; Skip protecc itself and the retf byte too
;
protecc:
	mov bp, sp
	add word [bp], protecc_len + 1
	jmp return
	protecc_len equ $ - protecc

[BITS 32]
protected_mode:
	mov ax, 10h       ; data seg
	mov ds, ax        ; data seg
	mov es, ax        ; data seg
	mov ss, ax        ; stack seg as data seg
	mov esp, 090000h  ; set stack pointer

	%define STCK_CRC_TBL_ADDR 12
	%define STCK_DUMP_VG_OFF  8
	%define STCK_CRC_VALUE    4
	%define STCK_DUMP_AMOUNT  0

	; Reserve space to our CRC table (1024 bytes)
	sub esp, 1024

	; Prepare our aux data
	push dword 0x0B8000 ; DUMP_VG_OFF
	push dword 0xFFFFFFFF ; CRC_VALUE
	push dword 0 ; DUMP_AMOUNT
	mov ebp, esp

	; UART
	call setup_uart

	; Create our CRC-32 table
	call build_crc32_table

	; Signal that we're ready
	mov ebx, 0xc001b00b
	call write_dword_serial

%ifndef BIOS
	; Clear entire screen
	mov edi, 0xB8000
	xor eax, eax
	mov ecx, 2*80*25
	repe stosb

	; Initial text
	push dword 0x202e2e2e ; '... '
	push dword 0x74696157 ; 'Wait'
	mov esi, esp
	call print_text
	add esp, 8
%endif

	; Wait for the length
	mov edi, ebp+STCK_DUMP_AMOUNT
	mov ecx, 4

	wait_len:
		inputb UART_LSR
		bt   ax, 0
		jnc  wait_len
		inputb UART_RB
		stosb
		loop wait_len

	; 'Fix' our DUMP_AMOUNT by /4
	shr dword [ss:ebp+STCK_DUMP_AMOUNT], 2

%ifndef BIOS
	; Dump text
	push dword 0x2e2e2e70 ; 'p...'
	push dword 0x6d754420 ; ' Dum'
	mov esi, esp
	call print_text
	add esp, 8
%endif

	; ------- Memory dump -------------
	cld
	mov esi, 0
	mov ecx, dword [ss:ebp+STCK_DUMP_AMOUNT]
dump:
	; Load 4-bytes and dump
	lodsd

	; Update CRC-32 value
	call update_crc

	; Send over serial
	mov ebx, eax
	call write_dword_serial
	loop dump

	;
	; Done, now we send our calculated CRC-32 value
	;
	mov ebx, dword [ss:ebp+STCK_CRC_VALUE]
	not ebx
	call write_dword_serial

%ifndef BIOS
	; Done
	push dword 0x20202065 ; 'e   '
	push dword 0x6e6f4420 ; ' Don'
	mov esi, esp
	call print_text
	add esp, 8
%endif

	hang: jmp hang

%ifndef BIOS
;
; Write a NULL-terminated text into the screen
; Parameters:
;   esi = text buffer
;
print_text:
	mov edi, [ss:ebp+STCK_DUMP_VG_OFF]
	mov ecx, 8
	.loop:
		lodsb
		stosb
		mov al, 0x1B
		stosb
		loop .loop
	.out:
		; Update curr vid memory
		mov [ss:ebp+STCK_DUMP_VG_OFF], edi
		ret
%endif

;
; Configure our UART with the following parameters:
;   8 bits, no parity, one stop bit
;
setup_uart:
	; Calculate and set divisor
	outbyte UART_LCR,  UART_LCR_DLA
	outbyte UART_DLB1, UART_DIVISOR & 0xFF
	outbyte UART_DLB2, UART_DIVISOR >> 8

	; Set line control register:
	outbyte UART_LCR, UART_LCR_BPC_8

	; Reset FIFOs and set trigger level to 14 bytes.
	outbyte UART_FCR, UART_FCR_CLRRECV | UART_FCR_CLRTMIT | UART_FCR_TRIG_14
	ret

;
; Write a single byte to UART
; Parameters:
;   bl = byte to be sent
;
write_byte_serial:
	mov dx, UART_LSR
	.loop:
		in  al, dx
		and al, UART_LSR_TFE
		cmp al, 0
		je .loop
	mov dx, UART_BASE
	mov al, bl
	out dx, al
	ret

;
; Write a dword to UART
;
; Parameters:
;   ebx = dword to be written
;
write_dword_serial:
	call write_byte_serial
	shr ebx, 8
	call write_byte_serial
	shr ebx, 8
	call write_byte_serial
	shr ebx, 8
	call write_byte_serial
	ret

;
; Generate a CRC-32 table
;
; Based on:
;   https://lxp32.github.io/docs/a-simple-example-crc32-calculation/
;
build_crc32_table:
	mov edi, ebp
	add edi, STCK_CRC_TBL_ADDR
	xor ecx, ecx
	; ecx = counter/i/j
	; eax = crc
	; ebx = ch
	; edx = b
	.outer: ; 256
		mov  ebx, ecx ; ch  = i
		xor  eax, eax ; crc = 0
		push ecx      ; backup outer counter
		mov  ecx, 8   ; ecx = j = 0
		.inner: ; 8
			mov edx, ebx ; b = ch
			xor edx, eax ; b = b^crc
			and edx, 1   ; b = b & 1
			shr eax, 1   ; crc >>= 1
			cmp edx, 0   ; if (b)
			je  .skip
			xor eax, 0xEDB88320 ; crc = crc^0xEDB88320
		.skip:
			shr  ebx, 1   ; ch >>= 1
			loop .inner
		pop ecx ; restore outer counter
		stosd   ; crc32_table[i] = crc/eax
		inc ecx
		cmp ecx, 256
		jl .outer
	ret

;
; Update the CRC-32 value for a given dword
;
; Parameters:
;   eax = dword to be crc'ed
; Register usage:
;   ebx = t
;   edx = crc
;   eax = dword crc'ed
;
update_crc:
	push eax
	push ecx
	mov  ecx, 4
	mov  edx, dword [ss:ebp+STCK_CRC_VALUE]
	.crc_calc_loop:
		movzx ebx, al   ; t = s[0]
		xor   ebx, edx  ; ch ^ crc
		and   ebx, 0xFF ; & 0xFF
		shr   edx, 8    ; crc>>8
		xor   edx, dword [ss:ebp+STCK_CRC_TBL_ADDR+(ebx*4)]
		shr   eax, 8
		loop  .crc_calc_loop
	; Save our new CRC
	mov dword [ss:ebp+STCK_CRC_VALUE], edx
	pop ecx
	pop eax
	ret

; General
; -------
DUMP_BARS_SHIFT equ 5 ; (32 bars)

; UART Constants
; --------------
UART_CLOCK_SIGNAL equ 1843200
UART_BASE         equ 0x3F8
UART_BAUD         equ BAUDRATE ; 9600 if things go wrong
UART_DIVISOR      equ UART_CLOCK_SIGNAL / (UART_BAUD << 4)
UART_RB           equ UART_BASE + 0 ; Receiver Buffer (R).
UART_FCR          equ UART_BASE + 2 ; FIFO Control Register (W).
UART_LCR          equ UART_BASE + 3 ; Line Control Register (RW).
UART_LSR          equ UART_BASE + 5 ; Line Status Register (R).

; Line Control Register values
UART_LCR_DLA   equ 0x80 ; Divisor Latch Access.
UART_LCR_BPC_8 equ 0x3  ; 8 bits per character.

; Divisor register
UART_DLB1 equ UART_BASE + 0 ; Divisor Latch LSB (RW).
UART_DLB2 equ UART_BASE + 1 ; Divisor Latch MSB (RW).

; FIFO Control Register bits.
UART_FCR_CLRRECV equ 0x1  ; Clear receiver FIFO.
UART_FCR_CLRTMIT equ 0x2  ; Clear transmitter FIFO.

; FIFO Controle Register bit 7-6 values
UART_FCR_TRIG_14 equ 0x0  ; Trigger level 14-byte.

; Line status register
UART_LSR_TFE equ 0x20 ; Transmitter FIFO Empty.

%ifndef BIOS
; Some magic number
times 506-($-$$) db 0
dd 0xB16B00B5

; Signature
dw 0xAA55
%endif
