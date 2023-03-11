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

#ifndef UI_H
#define UI_H

#include "vga.h"
#include "kbd.h"

#define CENTER_X(sW,rW) (((sW)/2) - ((rW)/2))
#define CENTER_Y(sH,rH) (((sH)/2) - ((rH)/2))

/* Box Drawing Light characters. */
#define BDL_VERTICAL   '\xb3'
#define BDL_HORIZONTAL '\xc4'
#define BDL_DOWNR      '\xda'
#define BDL_DOWNL      '\xbf'
#define BDL_UPR        '\xc0'
#define BDL_UPL        '\xd9'

/* Input buffer. */
static char input_buff[20 + 1];
static uint8_t input_counter;

/**
 * @brief Draw a colored box of given @p width and @p height
 * containing @p draw_margin and @p title.
 *
 * @param width  Box width  (amount of columns).
 * @param height Box height (amount of rows).
 * @param sc     Starting column (x).
 * @param sr     Starting row (y).
 * @param draw_margin Whether to draw a margin or not.
 * @param title       Optional title.
 */
static void ui_draw_box(int width, int height, int sc, int sr,
	uint8_t draw_margin, const char *title)
{
	int r, c;

	/* Draw box. */
	for (r = sr; r < height+sr; r++)
		for (c = sc; c < width+sc; c++)
			vga_put_char(c, r, ' ');

	if (!draw_margin)
		return;

	/*
	 * Draw lines
	 * - Vertical left
	 * - Horizontal top
	 * - Vertical right
	 * - Horizontal bottom
	 */
	for (r = sr, c = sc; r < height + sr; r++)
		vga_put_char(c, r, BDL_VERTICAL);
	for (r = sr, c = sc; c < width + sc;  c++)
		vga_put_char(c, r, BDL_HORIZONTAL);
	for (r = sr, c = sc + width - 1; r < height + sr; r++)
		vga_put_char(c, r, BDL_VERTICAL);
	for (r = sr + height - 1, c = sc; c < sc+width; c++)
		vga_put_char(c, r, BDL_HORIZONTAL);

	/*
	 * Draw margin decorators:
	 * - Upper  left
	 * - Bottom left
	 * - Upper right
	 * - Down  right
	 */
	vga_put_char(sc +  0,        sr + 0,          BDL_DOWNR);
	vga_put_char(sc + width - 1, sr + height - 1, BDL_UPL);
	vga_put_char(sc + width - 1, sr + 0,          BDL_DOWNL);
	vga_put_char(sc +  0,        sr + height - 1, BDL_UPR);

	/* Draw title. */
	if (title)
		vga_put_string(CENTER_X(80,strlen(title)),
			CENTER_Y(25,height), title);
}

/**
 * @brief Creates an input box and waits the user to type
 * something and hit ENTER.
 *
 * @param width  Input box width  (columns).
 * @param height Input box height (rows).
 * @param sc     Starting column (x).
 * @param sr     Starting row (y).
 *
 * @returns Returns the entered input when the user press
 *          ENTER.
 */
static const char* ui_input_box(int width, int height, int sc, int sr)
{
	uint8_t ch;

	vga_set_color(LIGHT_GRAY, BLACK);

	/* Draw box. */
	ui_draw_box(
		width, height,
		sc, sr,
		0, NULL
	);

	/* Move cursor. */
	vga_cursor_move(sc, sr);

	/* Empty buffer. */
	memset(input_buff, 0, sizeof(input_buff));
	input_counter = 0;

	while (1)
	{
		ch = kbd_read_char();

		/* Skip if not letter or number. */
		if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9'))
		{
			/*
			 * Buffer full, read again in the hope to empty
			 * the buffer (via backspace).
			 */
			if (input_counter >= sizeof input_buff - 1)
				continue;

			vga_put_char(sc++, sr, ch);
			input_buff[input_counter++] = ch;
		}

		/* If some control key, check if ENTER or BACKSPACE. */
		else if (ch == BACKSPACE)
		{
			/* Nothing to erase. */
			if (!input_counter)
				continue;

			input_buff[--input_counter] = '\0';
			vga_put_char(--sc, sr, ' ');
		}

		else if (ch == ENTER)
		{
			/* Nothing read. */
			if (!input_counter)
				continue;

			return (input_buff);
		}

		vga_cursor_move(sc, sr);
	}
}

#endif /* UI_H. */
