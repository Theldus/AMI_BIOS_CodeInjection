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
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/mman.h>
#include <netinet/in.h>
#include <sys/socket.h>

/* Progress amount of bars. */
#define AMNT_BARS 32

/* Serial fd. */
static int sfd;
static struct termios savetty;

/* Error and exit */
#define errx(...) \
	do { \
		fprintf(stderr, __VA_ARGS__); \
		exit(1); \
	} while (0)


/* Error */
#define err(...) fprintf(stderr, __VA_ARGS__)

/* Error and goto */
#define errto(lbl, ...) \
	do { \
		fprintf(stderr, __VA_ARGS__); \
		goto lbl; \
	} while (0)

/* Restore the tty/device while exiting. */
static void restore_tty(void) {
	tcsetattr(sfd, TCSANOW, &savetty);
}

/**
 * @brief Configure a TCP server to listen to the
 * specified port @p port.
 *
 * @param port Port to listen.
 *
 * @return Returns the client fd.
 */
int setup_server_and_listen(uint16_t port)
{
	struct sockaddr_in server;
	int cli_fd;
	int srv_fd;
	int reuse;

	reuse = 1;

	printf("Waiting to launch VM...\n");

	srv_fd = socket(AF_INET, SOCK_STREAM, 0);
	if (srv_fd < 0)
		errx("Unable to open socket!\n");

	setsockopt(srv_fd, SOL_SOCKET, SO_REUSEADDR,
		(const char *)&reuse, sizeof(reuse));

	/* Prepare the sockaddr_in structure. */
	memset((void*)&server, 0, sizeof(server));
	server.sin_family = AF_INET;
	server.sin_addr.s_addr = INADDR_ANY;
	server.sin_port = htons(port);

	/* Bind. */
	if (bind(srv_fd, (struct sockaddr *)&server, sizeof(server)) < 0)
		errx("Bind failed");

	/* Listen. */
	listen(srv_fd, 1);

	/* Blocks in accept() until someone connects. */
	cli_fd = accept(srv_fd, NULL, NULL);
	if (cli_fd < 0)
		errx("Failed to accept connection!\n");

	/* Close server. */
	close(srv_fd);
	return (cli_fd);
}

/**
 * @brief Initial setup for the serial device.
 *
 * @param sdev Serial device path, like: /dev/ttyUSB0
 *
 * @return Returns the serial file descriptor.
 */
int setup_serial(const char *sdev)
{
	int sfd;
	struct termios tty;

	/* Open device. */
	if ((sfd = open(sdev, O_RDWR | O_NOCTTY)) < 0)
		errx("Failed to open: %s, (%s)", sdev, strerror(errno));

	/* Attributes. */
	if (tcgetattr(sfd, &tty) < 0)
		errx("Failed to get attr: (%s)", strerror(errno));

	savetty = tty;
	cfsetospeed(&tty, (speed_t)B115200);
	cfsetispeed(&tty, (speed_t)B115200);
	cfmakeraw(&tty);

	/* TTY settings. */
	tty.c_cc[VMIN]  = 1;
	tty.c_cc[VTIME] = 10;
	tty.c_cflag &= ~CSTOPB;
	tty.c_cflag &= ~CRTSCTS; /* no HW flow control? */
	tty.c_cflag |= CLOCAL | CREAD;

	printf("Device %s opened for reading...\n", sdev);

	if (tcsetattr(sfd, TCSANOW, &tty) < 0)
		errx("Failed to set attr: (%s)", strerror(errno));

	/* Restore tty at exit. */
	atexit(restore_tty);
	return (sfd);
}

/**
 * @brief Perform some sanity checks on the output
 * file.
 *
 * Passing these checks does not mean that the file
 * is (with 100% of certainty) fine, but is very
 * likely to.
 *
 * @param ofd        Output file fd.
 * @param amnt_bytes Output file expected size.
 *
 * @return Returns 0 if success, -1 otherwise.
 */
#ifndef BIOS
static int check_output(int ofd, size_t amnt_bytes)
{
	uint8_t *out_found = NULL;
	uint8_t *out_file  = NULL;
	struct stat st = {0};
	off_t out_size =  0;
	int shift      =  0;  /* Amount of bytes to shift. */
	int ret        = -1;

	fstat(ofd, &st);
	out_size = st.st_size;

	if ((size_t)out_size != amnt_bytes)
		err("WARNING: Output size (%zu) differs from expected: "
			"%zu bytes!\n", st.st_size, amnt_bytes);

	/* If not a boot sector code, we cant proceed. */
	if (!stat("mdump.img", &st) && st.st_size != 512)
		errto(out0, "INFO: mdump.img file is not a bootable file!\n"
					"      I'm unable to check for consistency");

	/* Check if there is room to check. */
	if (out_size < 0x7c00 + 512)
		goto out0;

	lseek(ofd, 0, SEEK_SET);

	/* Mmap the output file. */
	out_file = mmap(0, out_size, PROT_READ, MAP_PRIVATE, ofd, 0);
	if (out_file == MAP_FAILED)
		errto(out0, "ERROR: Failed to mmap: %s\n", strerror(errno));

	/* Check for alignment. */
	if (out_file[0x7c00 + 510] == 0x55 &&
		out_file[0x7c00 + 511] == 0xaa)
	{
		goto check_a20; /* is aligned, do not align this file. */
	}

	err("WARNING: Output is not properly aligned!\n");

	/* Try to find our magic number: 0xB16B00B5 (little endian). */
	out_found = memmem(out_file, out_size, "\xb5\x00\x6b\xb1", 4);
	if (!out_found)
		errto(out1, "ERROR: Magic number not found, output file should be "
			"discarded!\n");

	shift = ((out_found - out_file) - 0x7c00) - 506;

	err("WARNING: Found magic number!, output file is %+d bytes "
		"shifted!\n", shift);

check_a20:
	if ((out_size >= 0x7c00 + 512 + (1<<20) + shift) &&
		out_file[0x7c00 + 510 + (1<<20) + shift] == 0x55 &&
		out_file[0x7c00 + 511 + (1<<20) + shift] == 0xaa)
	{
		errto(out1, "WARNING: A20 line looks like its *not* enabled!\n");
	}

	ret = 0;
	printf("Success!\n");
out1:
	munmap(out_file, out_size);
out0:
	return (ret);
}
#endif

/**
 * @brief Write @p len bytes from @p buf to @p conn.
 *
 * Contrary to send(2)/write(2) that might return with
 * less bytes written than specified, this function
 * attempts to write the entire buffer, because...
 * thats the most logical thing to do...
 *
 * @param conn Target file descriptor.
 * @param buf Buffer to be sent.
 * @param len Amount of bytes to be sent.
 *
 * @return Returns 0 if success, -1 otherwise.
 */
ssize_t send_all(
	int conn, const void *buf, size_t len)
{
	const char *p;
	ssize_t ret;

	if (conn < 0)
		return (-1);

	p = buf;
	while (len)
	{
		ret = write(conn, p, len);
		if (ret == -1)
			return (-1);
		p   += ret;
		len -= ret;
	}
	return (0);
}

/**
 *
 */
static int wait_ready(int ifd)
{
	static const uint8_t magic[] = {0x0b,0xb0,0x01,0xc0};
	uint8_t c = 0;
	ssize_t r = 0;
	int idx   = 0;

	while (1)
	{
		r = read(ifd, &c, 1);
		if (r <= 0)
			return (-1);

		if (c == magic[idx])
		{
			idx++;
			if (idx == sizeof magic)
				return (0);
		}
		else
			idx = 0;
	}

	/* Never reaches. */
	return (-1);
}

/**
 *
 */
static void send_amount_and_wait(int ifd, uint32_t length)
{
	union len {
		uint32_t len32;
		uint8_t  len8[4];
	} len;

	len.len32 = length;

	/* Wait serial device to be ready. */
	if (wait_ready(ifd) < 0)
		errx("Unable to receive message from dbg!\n");

	/* Send amount of bytes. */
	if (send_all(ifd, len.len8, 4) < 0)
		errx("Unable to send amount of bytes!\n");
}

/**
 * @brief Usage
 * @param prg_name Program name
 */
static void usage(const char *prg_name)
{
	errx(
		"Usage: %s [-s|/serial/path] output_file output_file_length\n"
		"Arguments:\n"
		"  -s:           Uses a TCP connection, listening to 2345\n"
		"  /serial/path: Uses a serial cable for the given path\n"
		"Example:\n"
		"  # Dumps 4M listening to a socket: \n"
		"  %s -s dump4M.img $((4<<20))\n\n"
		"  # Dumps 4M using a serial cable: \n"
		"  %s /dev/ttyUSB0 dump4M.img $((4<<20))\n",
		prg_name, prg_name, prg_name);
}

/* Main =). */
int main(int argc, char **argv)
{
	uint8_t buf[128];
	ssize_t out_len;
	size_t rdbytes;
	ssize_t rdlen;
	size_t amnt;
	char *out;
	size_t i;
	int ifd;
	int ofd;

	if (argc != 4)
		usage(argv[0]);

	out     = argv[2];
	out_len = atoi(argv[3]);
	amnt    = out_len / AMNT_BARS; /* amnt of bytes per bar. */
	rdbytes = 0;

	printf("Waiting to read %zd bytes...\n", out_len);

	/* Open output file. */
	if ((ofd = open(out, O_CREAT|O_RDWR|O_TRUNC, 0644)) < 0)
		errx("Failed to open: %s, (%s)", out, strerror(errno));

	/* If not socket. */
	if (strcmp(argv[1],"-s") != 0)
		ifd = setup_serial(argv[1]);
	else
		ifd = setup_server_and_listen(2345);

	/* Wait to dump. */
	send_amount_and_wait(ifd, out_len);

	fputs("Dumping memory: [                                 ]\r", stderr);
	fputs("Dumping memory: [", stderr);

	do
	{
		if ((rdlen = read(ifd, buf, sizeof(buf))) <= 0)
			errx("Failed to read %zu bytes! (%s)\n", sizeof(buf),
				strerror(errno));

		if (write(ofd, buf, rdlen) <= 0)
			errx("Unable to write %zu bytes to output file!\n",
				rdlen);

		rdbytes += rdlen;
		out_len -= rdlen;

		/* Update progress bar */
		if (rdbytes >= amnt)
		{
			for (i = 0; i < rdbytes / amnt; i++)
				fputc('#', stderr);
			rdbytes = 0;
		}

	} while (out_len > 0);

	fputs("] done =)\n", stderr);

#ifndef BIOS
	puts("Checking output file...");
	check_output(ofd, atoi(argv[3]));
#endif

	close(ifd);
	close(ofd);
	return (0);
}
