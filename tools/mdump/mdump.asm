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
[ORG 0x7C00] ; >> CHANGE_HERE <<

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

; --------------------------------
; Code
; --------------------------------

; Disable ints
cli

xor ax, ax
mov ds, ax

; Jump to protected mode
lgdt [gdt_desc]

mov eax, cr0
or  eax, 1     ; protecc mode
mov cr0, eax

jmp 08h:protected_mode

[BITS 32]
protected_mode:
	mov ax, 10h       ; data seg
	mov ds, ax        ; data seg
	mov es, ax        ; data seg
	mov ss, ax        ; stack seg as data seg
	mov esp, 090000h  ; set stack pointer

	; UART
	call setup_uart

	; Signal that we're ready
	mov ebx, 0xc001b00b
	call write_dword_serial

	; Wait for the length
	mov edi, DUMP_AMOUNT
	mov ecx, 4

	wait_len:
		inputb UART_LSR
		bt   ax, 0
		jnc  wait_len
		inputb UART_RB
		stosb
		loop wait_len

	; 'Fix' our DUMP_AMOUNT by /4
	shr dword [es:DUMP_AMOUNT], 2

%ifndef BIOS
	; Clear first line
	mov edi, 0xB8000
	xor eax, eax
	mov ecx, 160
	repe stosb

	; Initial text
	mov esi, dump_str
	call print_text

	; Closing brace
	mov byte [0xB8000 + (49 * 2) + 0], ']'
	mov byte [0xB8000 + (49 * 2) + 1], 0x1B

	; Calculate dump_bpb
	mov eax, dword [ds:DUMP_AMOUNT]
	shr eax, DUMP_BARS_SHIFT
	mov dword [ds:dump_bpb], eax
%endif

	; ------- Memory dump -------------
	cld
	mov esi, 0
	mov ecx, dword [es:DUMP_AMOUNT]
dump:
	; Load 4-bytes and dump
	lodsd
	mov ebx, eax
	call write_dword_serial

%ifndef BIOS
	; Check the percentage
	inc dword [dump_block_bytes] ; Update counter
	mov eax,  [dump_block_bytes] ; read it again
	cmp eax,  [dump_bpb]  ; compare with bytes per bar
	jne .not_bar
	mov dword [dump_block_bytes], 0 ; Zero again

	; Add a new bar
	mov eax, [dump_vg_off]
	mov byte [eax+0], '#'
	mov byte [eax+1], 0x1B
	add dword [dump_vg_off], 2

	.not_bar:
%endif
		loop dump

%ifndef BIOS
	; Done
	mov esi, dump_done
	call print_text
%endif

	hang: jmp hang

%ifndef BIOS
;
; Write a NULL-terminated text into the screen
; Parameters:
;   esi = text buffer
;
print_text:
	mov edi, [dump_vg_off]
	.loop:
		lodsb
		cmp al, 0
		je .out
		stosb
		mov al, 0x1B
		stosb
		jmp .loop
	.out:
		mov [dump_vg_off], edi ; Update curr vid memory
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

; --------------------------------
; Data
; --------------------------------

; GDT
gdt:        ; Address for the GDT
gdt_null:   ; Null Segment
	dd 0
	dd 0
gdt_code:        ; Code segment, read/execute, nonconforming
	dw 0FFFFh    ; limit = 4G
	dw 0         ; base = 0
	db 0         ; base = 0
	db 10011010b ; access = RO/Exec/Code/Priv 0/Present
	db 11001111b ; limit = 1111 / flags = 4KiB page blocks, 32-bit seg
	db 0
gdt_data:        ; Data segment, read/write, expand down
	dw 0FFFFh    ; limit = 4G
	dw 0         ; base = 0
	db 0         ; base = 0
	db 10010010b ; access = RW/Data/Priv 0/Present
	db 11001111b ; limit = 1111 / flags = 4KiB page blocks, 32-bit seg
	db 0
gdt_end:
gdt_desc:
	dw gdt_end - gdt - 1  ; Limit (size)
	dd gdt ; >> CHANGE_HERE <<  Physical GDT address

%ifndef BIOS
; Dump aux data
dump_str:         db 'Dumping memory: [', 0
dump_done:        db '] done =)', 0
dump_block_bytes: dd 0                     ; Block bytes until now
dump_bpb:         dd 0 ; DUMP_AMOUNT/DUMP_BARS
                       ; Bytes per bar (32 = 100%)
dump_vg_off:      dd 0x0B8000
%endif

; --------------------------------
; Constants
; --------------------------------

; General
; -------
DUMP_AMOUNT:    dd  0
DUMP_BARS_SHIFT equ 5 ; (32 bars)

; UART Constants
; --------------
UART_CLOCK_SIGNAL equ 1843200
UART_BASE         equ 0x3F8
UART_BAUD         equ 115200 ; 9600 if things go wrong
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
