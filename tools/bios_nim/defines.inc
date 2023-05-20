; --------------------------------------------------------
; Defines
; --------------------------------------------------------

%define dbg xchg bx, bx

%define MB (1<<20)
%define KB (1<<10)
%define ROM_SIZE  (1*MB)
%define BB_SIZE   (8*KB)
%define FILL_BYTE (0x00)
%define FILL(s) times (s)-($-$$) db (FILL_BYTE)

; Logical device selection
%define SIO_LDSEL     0x07
; Multi-function pin selection
%define SIO_MFPS      0x2C
; Register enable
%define SIO_REG_EN    0x30
; Logical Device 2, UART A
%define SIO_LD_UART_A 0x02
; Logical Device Address
%define SIO_REG_ADDR  0x60

; PCI
%define PCI_ADDR 0xCF8
%define PCI_DATA 0xCFC
%define ICH_FLAG_DECODE_LPC 0x30010010

; MTTR constants
%define IA32_MTRR_DEF_TYPE     0x2FF
%define IA32_MTRR_FIX4K_C0000  0x268

;
; UART constants
;
%define UART_CLOCK_SIGNAL 1843200
%define UART_BASE         0x3F8
%define UART_BAUD         9600 ; set to 9600 if things go wrong
%define UART_DIVISOR      UART_CLOCK_SIGNAL / (UART_BAUD << 4)
%define UART_RB           UART_BASE + 0 ; Receiver Buffer (R).
%define UART_IER          UART_BASE + 1 ; Interrupt Enable Register (RW).
%define UART_FCR          UART_BASE + 2 ; FIFO Control Register (W).
%define UART_LCR          UART_BASE + 3 ; Line Control Register (RW).
%define UART_MCR          UART_BASE + 4 ; Modem Control Register (W).
%define UART_LSR          UART_BASE + 5 ; Line Status Register (R).
; Line Control Register values
%define UART_LCR_DLA   0x80 ; Divisor Latch Access.
%define UART_LCR_BPC_8 0x3  ; 8 bits per character.
; Modem Control Register values
%define UART_MCR_OUT2  0x8  ; OUT2 pin
%define UART_MCR_RTS   0x2  ; Request to Send
%define UART_MCR_DTR   0x1  ; Data Terminal Ready
; Divisor register
%define UART_DLB1 UART_BASE + 0 ; Divisor Latch LSB (RW).
%define UART_DLB2 UART_BASE + 1 ; Divisor Latch MSB (RW).
; FIFO Control Register bits.
%define UART_FCR_CLRRECV 0x1  ; Clear receiver FIFO.
%define UART_FCR_CLRTMIT 0x2  ; Clear transmitter FIFO.
; FIFO Controle Register bit 7-6 values
%define UART_FCR_TRIG_1 0x0  ; Trigger level 1-byte.
; Line status register
%define UART_LSR_TFE 0x20 ; Transmitter FIFO Empty.


; --------------------------------------------------------
; Macros
; --------------------------------------------------------
%macro ROM_CALL 1
	mov sp, $+6 ; 3 bytes from mov + 3 bytes from jump
	jmp near %1 ; force jump to be 3 bytes
%endmacro

%macro sio_enter_pnp 0
	nop
	mov dx, 0x2E
	mov al, 0x87
	out dx, al
	out dx, al
%endmacro

%macro sio_exit_pnp 0
	nop
	mov dx, 0x2E
	mov al, 0xAA
	out dx, al
%endmacro

%macro DEBUG 1
	mov bl, %1
	ROM_CALL early_uart_write_byte
%endmacro

%macro DEBUG_CALL 1
	mov al, %1
	call print_char
%endmacro

;
; Params
;   first:  reg
;   second: value
;
%macro sio_write_value_to_reg 2
	nop
	mov dx, 0x2E
	mov al, %1  ; reg
	out dx, al
	mov dx, 0x2F
	mov ax, %2  ; value
	out dx, al
%endmacro

;
;
;
%macro sio_select_logical_device 1
	sio_write_value_to_reg SIO_LDSEL, %1
%endmacro

%macro sio_set_enable 1
	sio_write_value_to_reg SIO_REG_EN, %1
%endmacro

;
; Params:
;  first:  index
;  second: iobase (16-bit)
;
%macro sio_set_iobase 2
	sio_write_value_to_reg %1+0, ((%2 >> 8) & 0xFF)
	sio_write_value_to_reg %1+1, (%2 & 0xFF)
%endmacro

;
; Read from an I/O into al
; Parameters:
;   first: I/O port
;
%macro inputb 1
	mov dx, %1
	in al, dx
%endmacro

;
; Output a byte to an I/O port
; Parameters:
;    first:  I/O port
;    second: byte
;
%macro outbyte 2
	mov ax, %2
	mov dx, %1
	out dx, al
%endmacro

;
; Output a dword value (32-bit) into some PCI
; device specified in the bus,device,function
; and offset
;
; Parameters:
;   1st: bus
;   2nd: device
;   3rd: function
;   4th: offset
;   5th: data
;
%macro pci_out_dword 5
	mov eax, 0x80000000 | (%1 << 24) | (%2 << 11) | (%3 << 8) | %4
	mov dx,  PCI_ADDR
	out dx,  eax
	mov dx,  PCI_DATA
	mov eax, %5
	out dx,  eax
%endmacro
