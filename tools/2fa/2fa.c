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

#include "crt0.h"
#include "tiny2fa.h"

#include "vga.h"
#include "ui.h"
#include "kbd.h"

/*
 * SECRET_KEY must be a 32-char key encoded in BASE32:
 * - All characters must be in upper case and
 * - should be in the following alphabet: A-Z, 2-7
 */
#ifndef SECRET_KEY
#warning "Using default secret key, please change it!"
#define SECRET_KEY "AAAAAAAABBBBBBBBCCCCCCCCDDDDDDDD"
#endif

/*
 * Backup password: this password must be sent for when
 * the date & hour are reset... choose at most 20 chars.
 */
#ifndef BACK_PASSWD
#warning "Using default password, please change it!"
#define BACK_PASSWD "foo"
#endif

static uint8_t secret_key[] = SECRET_KEY;
static char back_passwd[] = BACK_PASSWD;

/**
 * @brief Displays an error message on screen
 * and waits the user to press any key.
 */
static void ui_error_window(void)
{
	vga_cursor_disable();
	vga_set_color(RED, WHITE);

	ui_draw_box(34,3,
		CENTER_X(80,34), CENTER_Y(25,3),
		1, "Wrong Code!"
	);
	vga_put_string(
		CENTER_X(80,32), CENTER_Y(25,3) + 1,
		"~~ Press any key to try again ~~"
	);

	kbd_read_char();
}

/**
 * @brief Main window: reads the 2FA code (or password)
 * and check for its validity: if wrong, tell the user
 * and read again, if right, return to the previous
 * code.
 */
static void ui_main_window(void)
{
	const char *input;

again:
	vga_cursor_enable();
	vga_set_color(BLUE, WHITE);

	ui_draw_box(
		40, 10,
		CENTER_X(80,40), CENTER_Y(25,10),
		1,
		" Two-Factor Authentication Required "
	);

	vga_put_string(
		CENTER_X(80,40) + 1, CENTER_Y(25,10) + 2,
		"You must type a 2FA code below to\n"
		"grant access to this PC:"
	);

	input = ui_input_box(20, 1,
		CENTER_X(80,20), CENTER_Y(25,10) + 5
	);

	/*
	 * Check if input matches the expected 2FA
	 * key, or the default password.
	 */
	if (strcmp(input, back_passwd)
		&& t2_verify_key(secret_key, str2int(input), 0) <= 0)
	{
		ui_error_window();
		goto again;
	}
}

/* Main. */
int twofa_main(void)
{
	vga_set_8025();
	ui_main_window();
	return (0);
}
