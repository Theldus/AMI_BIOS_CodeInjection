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

#ifndef VGA_H
#define VGA_H

#include "types.h"
#include "io.h"

/* Video registers. */
#define VIDEO_CRTL_REG 0x3d4 /* Video control register. */
#define VIDEO_DATA_REG 0x3d5 /* Video data register.    */
#define VIDEO_CLH      0x0e  /* Cursor location high.   */
#define VIDEO_CLL      0x0f  /* Cursor location low.    */
#define VIDEO_CS       0x0a  /* Cursor start.           */
#define VIDEO_CE       0x0b  /* Cursor end.             */

/* Video colors. */
enum VIDEO_COLOR {
	BLACK, BLUE, GREEN, CYAN, RED, MAGENTA, BROWN, LIGHT_GRAY,
	DARK_GRAY, LIGHT_BLUE, LIGHT_GREEN, LIGHT_CYAN, LIGHT_RED,
	LIGHT_MAGENTA, YELLOW, WHITE
};

static uint8_t current_color;

/**
 * @brief Set the current drawing color.
 *
 * @param bg Background color
 * @param fg Foreground (text) color.
 */
static void vga_set_color(uint8_t bg, uint8_t fg) {
	current_color = (bg << 4) | fg;
}

/**
 * @brief Set the current video mode to 80x25, mode 3
 */
static inline void vga_set_8025(void)
{
	/* Set video mode: 80x25, 16-color text. */
	asm volatile (
		/* Set video mode. */
		"mov $0x0003, %%ax \n"
		"int $0x10         \n"
		::: "ax"
	);
}

/**
 * @brief Moves the cursor to @p col and @p row.
 *
 * @param col Target column to move.
 * @param row Target row to move.
 */
static void vga_cursor_move(uint16_t col, uint16_t row)
{
	uint16_t cpos = row*80 + col;
	outputb(VIDEO_CRTL_REG, VIDEO_CLH);
	outputb(VIDEO_DATA_REG, (uint8_t) ((cpos >> 8) & 0xFF));
	outputb(VIDEO_CRTL_REG, VIDEO_CLL);
	outputb(VIDEO_DATA_REG, (uint8_t) (cpos & 0xFF));
}

/**
 * @brief Disable cursor.
 */
static void vga_cursor_disable(void)
{
	outputb(VIDEO_CRTL_REG, VIDEO_CS);
	outputb(VIDEO_DATA_REG, 0x20);
}

/**
 * @brief Enable cursor.
 */
static void vga_cursor_enable(void)
{
	outputb(VIDEO_CRTL_REG, VIDEO_CS);
	outputb(VIDEO_DATA_REG, (inputb(VIDEO_DATA_REG) & 0xC0) | 0);
	outputb(VIDEO_CRTL_REG, VIDEO_CE);
	outputb(VIDEO_DATA_REG, (inputb(VIDEO_DATA_REG) & 0xE0) | 15);
}

/**
 * @brief Puts a single char into the screen.
 *
 * @param col Target column position.
 * @param row Target row position.
 * @param ch Character to be put.
 *
 * @note This routine is shamely not optimized, but this would
 * not be a huge problem, since this program is not 'video-heavy'
 * in any way (I hope...).
 */
static void vga_put_char(uint16_t col, uint16_t row, uint8_t ch)
{
	uint16_t off = (row * 160) + (col * 2);
	asm volatile (
		"push %%es\n"
		"mov $0xB800,  %%bx\n"
		"mov %%bx,     %%es\n"
		"mov %[off],   %%bx\n"
		"mov %[ch],    %%es:(%%bx)\n"
		"inc %%bx\n"
		"mov %[color], %%es:(%%bx)\n"
		"pop %%es\n"
		: /* out */
		: [off]   "d" (off),
		  [ch]    "a" (ch),
		  [color] "c" (current_color)
		: "bx", "memory"
	);
}

/**
 * @brief Puts a given string into the screen, in the coordinates
 * indicated by @p col and @p row.
 *
 * @param col Target column position.
 * @param row Target row position.
 * @param s   Target string.
 *
 * @note Ideally, this routine should be asm-optimized too,
 * instead of relying on 'vga_put_char()', but I'm too lazy...
 */
static void vga_put_string(uint16_t col, uint16_t row,
	const char *s)
{
	const char *p;
	uint16_t c = col;
	uint16_t r = row;

	for (p = s; *p != '\0'; p++)
	{
		if (*p == '\n')
		{
			r++, c = col;
			continue;
		}
		vga_put_char(c++, r, *p);
	}
}

#endif /* VGA_H */
