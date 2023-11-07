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

#define _GNU_SOURCE
#include <err.h>
#include <ctype.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>

struct smi_disp_table {
	char sign[6];    /* $SMIxx. */
	uint16_t flags;
	uint32_t ptr0;
	uint32_t ptr1;
	uint32_t ptr2;
	uint32_t handle_smi_ptr;
} __attribute__((packed));

static struct smi_disp_table *sdt;
static size_t num_entries;

/**
 * @brief For a given input file @p file_buff of size @p file_size,
 * find the SMI Dispatch Table and allocates a new structure with
 * all its data.
 *
 * @param file_buff MMaped file buffer (1B module).
 * @apram file_size File size (1B module).
 *
 * @return Returns 0 if success, -1 otherwise.
 */
static int fill_sdt(const char *file_buff, size_t file_size)
{
	const char *ptr1, *ptr2, *first_smi, *def;
	size_t rem_size;
	ptrdiff_t size;

	ptr1     = file_buff;
	rem_size = file_size;

	ptr2 = memmem(ptr1, rem_size, "$APMEND$", 8);
	if (!ptr2)
		return (-1);
	ptr2     += 8;
	ptr1      = ptr2;
	rem_size -= 8;

	/* Find first $SMI. */
	ptr2 = memmem(ptr1, rem_size, "$SMI", 4);
	if (!ptr2)
		return (-1);

	first_smi = ptr2;
	ptr2     += 4;
	ptr1     = ptr2;
	rem_size -= 4;

	ptr2 = memmem(ptr1, rem_size, "$DEF", 4);
	if (!ptr2)
		return (-1);

	def  = ptr2 + sizeof (struct smi_disp_table);
	size = def  - first_smi;

	if (size % (sizeof (struct smi_disp_table)))
		return (-1);

	num_entries = (size_t)size/(sizeof(struct smi_disp_table));

	printf(
		">> Found SMI dispatch table!\n"
		"Size: %td bytes\n"
		"Entries: %td\n"
		"Start file offset: 0x%tx\n",
		size,
		num_entries,
		first_smi - file_buff
	);

	/* Allocate the table and save it. */
	sdt = calloc(1, (size_t)size);
	if (!sdt)
		return (-1);

	memcpy(sdt, first_smi, (size_t)size);
	return (0);
}

/**
 * @brief Gets a printable char or '?'.
 *
 * @param c Input character
 *
 * @return Returns the same character or a '?' if its not
 * printable.
 */
static inline int get_char(int c) {
	return (isprint(c) ? c : '?');
}

/**
 * @brief Given the already filled SDT and the @p file_buff,
 * dumps all the SMI handlers and its respective addresses
 * and file offset.
 *
 * @param file_buff MMaped file buffer (1B module).
 * @apram file_size File size (1B module).
 */
static void dump_sdt(const char *file_buff, size_t file_size)
{
	size_t i;
	char *handle_smied;
	uint32_t smied_ptr;
	uint32_t smied_handle_foff;

	/* Find '$SMIED' handle ptr addr. */
	for (i = 0; i < num_entries; i++)
		if (!memcmp(sdt[i].sign, "$SMIED", 6))
			break;

	if (i == num_entries) {
		fprintf(stderr, "$SMIED not present, aborting!\n");
		return;
	}

	smied_ptr = sdt[i].handle_smi_ptr;

	/*
	 * We need to find some known handler, and once found,
	 * it's possible to know the offset of all the others.
	 *
	 * From my (brief) research, several AMIBIOS 8 have the
	 * '$SMIED' and the handler of all of them are the same,
	 * so the 'memmem' below searches for its initial
	 * instructions...
	 */
	handle_smied = memmem(file_buff, file_size,
		"\x0e"         /* push cs     */
		"\xe8\xe9\xff" /* call 0xb2fd */
		"\xb8\x01\x00" /* mov ax, 0x1 */
		"\x72\x45"     /* jc 0xb35e   */
		"\x66\x60"     /* pushad      */
		"\x1e"         /* push ds     */
		"\x06"         /* push es     */
		"\x68\x00\x70" /* push 0x7000 */,
		16
	);

	if (!handle_smied) {
		fprintf(stderr, "Unable to find the handle for $SMIED, aborting...\n");
		return;
	}

	smied_handle_foff = (uint32_t)((ptrdiff_t)(handle_smied - file_buff));

	printf("\n>> SMI dispatch table entries:\n");

	for (i = 0; i < num_entries; i++)
	{
		printf("Entry %zu:\n", i);
		printf("  Name: %c%c%c%c%c%c\n",
			get_char(sdt[i].sign[0]),
			get_char(sdt[i].sign[1]),
			get_char(sdt[i].sign[2]),
			get_char(sdt[i].sign[3]),
			get_char(sdt[i].sign[4]),
			get_char(sdt[i].sign[5])
		);
		printf("  Handle SMI ptr:  0x%x\n", sdt[i].handle_smi_ptr);
		printf("  Handle SMI foff: 0x%x\n",
			 (int32_t)smied_handle_foff +
			((int32_t)sdt[i].handle_smi_ptr - (int32_t)smied_ptr)
		);
	}
}

/* Main =). */
int main(int argc, char **argv)
{
	int fd;
	char *file;
	struct stat s;

	if (argc < 2)
		errx(1, "Usage: %s <1b-module>\n", argv[0]);

	fd = open(argv[1], O_RDONLY);
	if (fd < 0)
		errx(1, "Error while opening!\n");

	fstat(fd, &s);

	file = mmap(NULL, s.st_size, PROT_READ, MAP_SHARED, fd, 0);
	if (file == MAP_FAILED)
		errx(1, "Failed to mmap!\n");

	if (fill_sdt(file, s.st_size) < 0)
		errx(1, "Unable to Fill SDT!\n");

	dump_sdt(file, s.st_size);

	free(sdt);
	munmap(file, s.st_size);
	close(fd);
	return (0);
}
