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

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <inttypes.h>
#include <sys/mman.h>
#include <sys/stat.h>

/* Error and exit */
#define errx(...) \
	do { \
		fprintf(stderr, __VA_ARGS__); \
		exit(1); \
	} while (0)

#define PNP_HDR_OFF  0x1A
#define PNP_HDR_IDX  5 /* Header length index. */
#define PNP_CSUM_IDX 9 /* Checksum index. */

/**
 * @brief Calculates the entire file checksum and
 * saves it into the last byte.
 *
 * @param file File buffer.
 * @param size File size.
 */
static void file_chksum(uint8_t *file, size_t size)
{
	uint8_t csum;

	/* Calculate file checksum. */
	csum = 0;
	for (size_t i = 0; i < size - 1; i++)
		csum += file[i];
	csum = 256 - csum;

	/* Put it to the last byte. */
	file[size - 1] = csum;
	printf("File checksum: 0x%02x\n", csum);
}

/**
 * @brief Calculates the checksum for the PnP header
 * and saves it.
 *
 * @param file Opened file buffer.
 * @param size Total file size.
 */
static void pnp_chksum(uint8_t *file, size_t size)
{
	off_t    pnp_hdr_off;
	uint8_t *pnp_hdr;
	int      hdr_len;
	uint8_t  csum;

	/* No PnP hdr location. */
	if (size < PNP_HDR_OFF + 1)
		return;

	pnp_hdr_off =
		((uint16_t)file[PNP_HDR_OFF + 1] << 8) +
		file[PNP_HDR_OFF];

	/* Check if pointed PnP header exists. */
	if (size < pnp_hdr_off + PNP_CSUM_IDX)
		return;

	/* Check if there _is_ a PnP signature. */
	if (strncmp(file + pnp_hdr_off, "$PnP", 4))
		return;

	/* Get header length and check if it exists entirely. */
	hdr_len = (int)file[pnp_hdr_off + PNP_HDR_IDX] * 16;
	if (size < pnp_hdr_off + hdr_len)
		errx("PnP header is broken!, aborting...\n");

	/* Reset checksum field and calculate new checksum. */
	pnp_hdr = file + pnp_hdr_off;
	pnp_hdr[PNP_CSUM_IDX] = 0;

	csum = 0;
	for (int i = 0; i < hdr_len; i++)
		csum += pnp_hdr[i];
	csum = 256 - csum;

	/* Put the new checksum. */
	pnp_hdr[PNP_CSUM_IDX] = csum;
	printf("PnP header checksum: 0x%02X\n", csum);
}

/**
 * Main
 */
int main(int argc, char **argv)
{
	struct stat st = {0};
	uint8_t *file;
	uint8_t  csum;
	int fd;

	fd = open(argv[1], O_RDWR);
	if (fd < 0)
		errx("Unable to open file (%s)\n", argv[1]);

	fstat(fd, &st);
	file = mmap(0, st.st_size, PROT_READ|PROT_WRITE,
		MAP_SHARED, fd, 0);

	if (file == MAP_FAILED)
		errx("Failed to mmap file!\n");

	/* Calculate PnP header checksum. */
	pnp_chksum(file, st.st_size);

	/* Calculate file checksum. */
	file_chksum(file, st.st_size);

	msync(file, st.st_size, MS_SYNC);
	munmap(file, st.st_size);
	close(fd);
	return (0);
}
