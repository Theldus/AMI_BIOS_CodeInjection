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

#ifndef UTIL_H
#define UTIL_H

#include "types.h"

/**
 * @brief Copies @p n bytes from @p src to @p dest.
 *
 * @param dest Destination memory.
 * @param src  Source memory.
 * @param n    Amount of bytes.
 *
 * @return Returns a pointer to @p dest.
 */
static void *memcpy(void *dest, const void *src, size_t n)
{
	char *d;       /* Write pointer. */
	const char* s; /* Read pointer.  */

	s = src;
	d = dest;

	while (n-- > 0)
		*d++ = *s++;

	return (dest);
}

/**
 * @brief Sets @p n bytes of memory in the address @p ptr
 * with the char @p c.
 *
 * @param ptr Destination memory.
 * @param c   Fill char.
 * @param n   Amount of bytes.
 */
static void *memset(void *ptr, int c, size_t n)
{
	unsigned char *p;

	p = ptr;

	/* Set bytes. */
	while (n-- > 0)
		*p++ = (unsigned char) c;

	return (ptr);
}

/**
 * @brief Gets the length of a given string pointed by
 * @p s.
 *
 * @param s Input string.
 *
 * @return Returns the string length.
 */
static size_t strlen(const char *s)
{
	const char *p;

	/* Count the number of characters. */
	for (p = s; *p != '\0'; p++);

	return (p - s);
}

/**
 * @brief Compares two strings, pointed by @p str1 and
 * @p str2.
 *
 * @param str1 First string.
 * @param str2 Second string.
 *
 * @return Zero if the strings are equal, and non-zero
 * otherwise.
 */
static int strcmp(const char *str1, const char *str2)
{
	/* Compare strings. */
	while (*str1 == *str2)
	{
		/* End of string. */
		if (*str1 == '\0')
			return (0);

		str1++;
		str2++;
	}

	return (*str1 - *str2);
}

/**
 * @brief Converts the input integer to string.
 *
 * @param n Integer to be converted.
 *
 * @return Returned the integer converted.
 */
static char *int2str(int n)
{
	static char buff[16];
	char *s = buff, *t, tmp;
	int sign = 1;

	if (n < 0)
	{
		sign = -1;
		n = -n;
	}

	do
	{
		*s++ = (n % 10) + '0';
		n /= 10;
	} while (n > 0);

	if (sign < 0)
		*s++ = '-';

	*s-- = '\0';
	t = buff;

	while (t < s)
	{
		tmp  = *t;
		*t++ = *s;
		*s-- = tmp;
	}

	return buff;
}

/**
 * @brief Converts the input string to integer.
 *
 * @param str Input string to be converted.
 *
 * @return Returns the string converted.
 */
static int str2int(const char *str)
{
	int n    = 0;
	int sign = 1;

	if (*str == '-')
	{
		sign = -1;
		str++;
	}

	while (*str != '\0')
	{
		if (*str >= '0' && *str <= '9')
		{
			n = n * 10 + (*str - '0');
			str++;
		}
		else
			break;
	}
	return sign * n;
}

#endif /* UI_H */
