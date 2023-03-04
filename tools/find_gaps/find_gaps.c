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

#include <stdio.h>
#include <stdlib.h>

/* Error and exit */
#define errx(...) \
	do { \
		fprintf(stderr, __VA_ARGS__); \
		exit(1); \
	} while (0)

/* Main. */
int main(int argc, char **argv)
{
	FILE *fp;
	int pos;
	long offset;
	int curr_byte;
	int prev_byte;
	long seq_start;
	long min_length;
	long seq_length;

	if (argc < 4)
		errx("Usage: %s <offset> <min_length> <filename>\n", argv[0]);

	offset     = strtol(argv[1], NULL, 10);
	min_length = strtol(argv[2], NULL, 10);

	fp = fopen(argv[3], "rb");
	if (fp == NULL)
		errx("Error: Could not open file %s\n", argv[3]);

	if (fseek(fp, offset, SEEK_SET) != 0)
		errx("Error: Could not seek to offset %ld in file %s\n", offset,
			argv[3]);

	pos        = offset;
	seq_length =  0;
	seq_start  = -1;
	curr_byte  =  0;
	prev_byte  = fgetc(fp);

	if (prev_byte == EOF)
		errx("Error: Could not read first byte from file %s\n", argv[3]);

	while ((curr_byte = fgetc(fp)) != EOF)
	{
		pos++;
		if (curr_byte == prev_byte && (curr_byte == 0 || curr_byte == 0xff))
		{
			if (seq_start == -1)
				seq_start = pos - 1;
			seq_length++;
		}
		else
		{
			if (seq_length >= min_length)
				printf("Found sequence at offset %ld, length %ld bytes\n",
					seq_start, seq_length);

			seq_start  = -1;
			seq_length = 0;
		}

		prev_byte = curr_byte;
	}

	if (seq_length >= min_length)
		printf("Found sequence at offset %ld, length %ld bytes\n",
			seq_start, seq_length);

	return (0);
}
