/*
 * MIT License
 *
 * Copyright (c) 2023 Davidson Francis <davidsondfgl@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef KBD_H
#define KBD_H

#include "types.h"
#include "io.h"
#include "util.h"

/* PS/2 registers. */
#define PS2_DATA_PORT  0x60
#define PS2_STATUS_REG 0x64

/* ASCII characters. */
#define ESC         27
#define BACKSPACE  '\b'
#define TAB        '\t'
#define ENTER      '\n'
#define RETURN     '\r'
#define NEWLINE   ENTER

/* Non-ASCII special scan-codes. */
#define KESC          1
#define KF1        0x80
#define KF2   (KF1 + 1)
#define KF3   (KF2 + 1)
#define KF4   (KF3 + 1)
#define KF5   (KF4 + 1)
#define KF6   (KF5 + 1)
#define KF7   (KF6 + 1)
#define KF8   (KF7 + 1)
#define KF9   (KF8 + 1)
#define KF10  (KF9 + 1)
#define KF11 (KF10 + 1)
#define KF12 (KF11 + 1)

/* Cursor keys. */
#define KINS           0x90
#define KDEL     (KINS + 1)
#define KHOME    (KDEL + 1)
#define KEND    (KHOME + 1)
#define KPGUP    (KEND + 1)
#define KPGDN   (KPGUP + 1)
#define KLEFT   (KPGDN + 1)
#define KUP     (KLEFT + 1)
#define KDOWN     (KUP + 1)
#define KRIGHT  (KDOWN + 1)
#define KCTRL  (KRIGHT + 1)

/* Non-shift PS/2 scan codes table. */
static uint8_t ascii_non_shift[] = {
	'\0', ESC, '1', '2', '3', '4', '5', '6', '7', '8', '9',
	'0', '-', '=', BACKSPACE, TAB, 'q', 'w', 'e', 'r', 't',
	'y', 'u', 'i', 'o', 'p',  '[', ']', ENTER, 0, 'a', 's',
	'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0, '\\',
	'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0,
	' ', 0, KF1, KF2, KF3, KF4, KF5, KF6, KF7, KF8, KF9, KF10,
	0, 0, KHOME, KUP, KPGUP,'-', KLEFT, '5', KRIGHT, '+', KEND,
	KDOWN, KPGDN, KINS, KDEL, 0, 0, 0, KF11, KF12
};

/**
 * @brief Read a single char from the keyboard PS/2
 * (via polling) and returns it.
 */
static char kbd_read_char(void)
{
	uint8_t ch, rd_ch;
	ch = rd_ch = 0;

again:
	/* Wait to buffer have something. */
	while (!(inputb(PS2_STATUS_REG) & 1));

	ch = inputb(PS2_DATA_PORT);
	if (ch == 0xE0) /* Ignore if 0xE0. */
		goto again;

	/* Check if key release. */
	if (ch & 0x80)
		return (ascii_non_shift[rd_ch]);

	/* If key pressed. */
	rd_ch = ch;
	goto again;
	return (0);
}

#endif /* KBD_H. */
