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

#ifndef IO_H
#define IO_H

#include "types.h"

/**
 * @brief Read a single byte from the I/O port @p port.
 *
 * @return Returns the read byte.
 */
static inline uint8_t inputb(uint16_t port)
{
	uint8_t value;
	asm volatile (
		"inb %1, %0"
		: "=a" (value)
		: "Nd" (port)
	);
	return (value);
}

/**
 * @brief Writes a single byte @p value to the I/O port
 * @p port.
 *
 * @param port  Target I/O port to be written.
 * @param value Value to be written.
 */
static inline void outputb(uint16_t port, uint8_t value) {
	asm volatile (
		"outb %0, %1"
		:
		: "a" (value), "Nd" (port)
	);
}

#endif /* IO_H */
