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

#ifndef BAUDRATE
#define BAUDRATE B115200
#endif

/* Progress amount of bars. */
#define AMNT_BARS 32

/* Serial fd. */
static int is_serial;
static int serial_fd;
static struct termios savetty;

/* Mmaped outfile file. */
static uint8_t *out_file;
static off_t out_size;
static int out_fd;

/* CRC-32 table. */
uint32_t crc32_table[256];

/* Receive buffer. */
struct recv_buffer
{
	uint8_t buff[128];
	size_t cur_pos;
	size_t amt_read;
} recv_buffer = {0};

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
static void restore_settings(void)
{
	if (is_serial && serial_fd)
	{
		tcsetattr(serial_fd, TCSANOW, &savetty);
		close(serial_fd);
	}
	if (out_fd)
		close(out_fd);
	if (out_file)
		munmap(out_file, out_size);
}

/**
 * @brief Read a chunk of bytes and return the next byte
 * belonging to the frame.
 *
 * @return Returns the byte read, or -1 if error.
 */
static inline int next_byte(void)
{
	ssize_t n;

	/* If empty or full. */
	if (recv_buffer.cur_pos == 0 ||
		recv_buffer.cur_pos == recv_buffer.amt_read)
	{
		if ((n = read(serial_fd, recv_buffer.buff,
			sizeof(recv_buffer.buff))) <= 0)
		{
			return (-1);
		}
		recv_buffer.amt_read = (size_t)n;
		recv_buffer.cur_pos = 0;
	}
	return (recv_buffer.buff[recv_buffer.cur_pos++]);
}

/**
 * @brief Creates the CRC-32 table
 */
void build_crc32_table(void)
{
	uint32_t i, j;
	uint32_t crc;
	uint32_t ch;
	uint32_t b;

	for (i = 0; i < 256; i++)
	{
		ch  = i;
		crc = 0;
		for (j = 0; j < 8; j++)
		{
			b = (ch ^ crc) & 1;
			crc >>= 1;
			if (b)
				crc = crc ^ 0xEDB88320;
			ch >>= 1;
		}
		crc32_table[i] = crc;
	}
}

/**
 * @brief Calculates the CRC-32 checksum for the
 * given buffer @p buff.
 *
 * @param buff   Input buffer.
 * @param length Buffer length.
 *
 * @return Returns the calculated CRC-32.
 */
uint32_t do_crc32(const uint8_t *buff, size_t length)
{
	uint32_t crc;
	uint32_t t;
	size_t i;

	crc = 0xFFFFFFFF;
	for (i = 0; i < length; i++)
	{
		t = (buff[i] ^ crc) & 0xFF;
		crc = (crc >> 8) ^ crc32_table[t];
	}
	return (~crc);
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
	serial_fd = accept(srv_fd, NULL, NULL);
	if (serial_fd < 0)
		errx("Failed to accept connection!\n");

	/* Close server. */
	close(srv_fd);
	return (serial_fd);
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
	struct termios tty;

	is_serial = 1;

	/* Open device. */
	if ((serial_fd = open(sdev, O_RDWR | O_NOCTTY)) < 0)
		errx("Failed to open: %s, (%s)", sdev, strerror(errno));

	/* Attributes. */
	if (tcgetattr(serial_fd, &tty) < 0)
		errx("Failed to get attr: (%s)", strerror(errno));

	savetty = tty;
	cfsetospeed(&tty, (speed_t)BAUDRATE);
	cfsetispeed(&tty, (speed_t)BAUDRATE);
	cfmakeraw(&tty);

	/* TTY settings. */
	tty.c_cc[VMIN]  = 1;
	tty.c_cc[VTIME] = 10;
	tty.c_cflag &= ~CSTOPB;
	tty.c_cflag &= ~CRTSCTS; /* no HW flow control? */
	tty.c_cflag |= CLOCAL | CREAD;

	printf("Device %s opened for reading...\n", sdev);

	if (tcsetattr(serial_fd, TCSANOW, &tty) < 0)
		errx("Failed to set attr: (%s)", strerror(errno));

	return (serial_fd);
}

/**
 * @brief Perform some sanity checks on the output
 * file.
 *
 * Passing these checks does not mean that the file
 * is (with 100% of certainty) fine, but is very
 * likely to.
 *
 * @param amnt_bytes Output file expected size.
 *
 * @return Returns 0 if success, -1 otherwise.
 */
#ifndef BIOS
static int check_output(size_t amnt_bytes)
{
	uint8_t *out_found = NULL;
	struct stat st = {0};
	int shift      =  0;  /* Amount of bytes to shift. */
	int ret        = -1;

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
		errto(out0, "ERROR: Magic number not found, output file should be "
			"discarded!\n");

	shift = ((out_found - out_file) - 0x7c00) - 506;

	err("WARNING: Found magic number!, output file is %+d bytes "
		"shifted!\n", shift);

check_a20:
	if ((out_size >= 0x7c00 + 512 + (1<<20) + shift) &&
		out_file[0x7c00 + 510 + (1<<20) + shift] == 0x55 &&
		out_file[0x7c00 + 511 + (1<<20) + shift] == 0xaa)
	{
		errto(out0, "WARNING: A20 line looks like its *not* enabled!\n");
	}

	ret = 0;
	printf("Success!\n");
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
 * @brief Receives the CRC-32 sent from the dumper
 * and compares with the output file.
 *
 * A clean transmission should have matching CRCs,
 * otherwise, the output file is not exactly as sent
 * and might be very (or not) wrong.
 */
static void wait_and_check_crc(void)
{
	struct stat st = {0};
	uint32_t crc32;
	size_t i = 0;
	int c    = 0;

	union crc {
		uint32_t crc32;
		uint8_t  crc8[4];
	} crc;

	/* Create our table. */
	build_crc32_table();

	/* Wait to our received crc. */
	for (i = 0; i < sizeof crc.crc8; i++)
	{
		c = next_byte();
		if (c < 0)
			errto(out0, "Unable to receive CRC-32!\n");

		crc.crc8[i] = c;
	}

	/* Mmap the output file. */
	lseek(out_fd, 0, SEEK_SET);
	fstat(out_fd, &st);
	out_size = st.st_size;

	out_file = mmap(0, out_size, PROT_READ, MAP_PRIVATE, out_fd, 0);
	if (out_file == MAP_FAILED)
		errto(out0, "ERROR: Failed to mmap: %s\n", strerror(errno));

	/* Get CRC. */
	crc32 = do_crc32(out_file, out_size);

	printf("Received CRC-32: %08x\n", crc.crc32);
	printf("Calculated CRC-32: %08x, match?: %s\n", crc32,
		(crc32 == crc.crc32 ? "yes" : "no"));

out0:
	return;
}

/**
 * @brief Wait until the dumper is ready to talk
 */
static int wait_ready()
{
	static const uint8_t magic[] = {0x0b,0xb0,0x01,0xc0};
	int c   = 0;
	int idx = 0;

	while (1)
	{
		c = next_byte();
		if (c < 0)
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
 * @brief Wait the dumper to be ready and then
 * send the amountof bytes to be dumped.
 *
 * @param serial_fd Serial file descriptor (or socket).
 * @param length Amount of bytes to dump.
 */
static void wait_and_send_length(uint32_t length)
{
	union len {
		uint32_t len32;
		uint8_t  len8[4];
	} len;

	len.len32 = length;

	/* Wait serial device to be ready. */
	if (wait_ready() < 0)
		errx("Unable to receive message from dbg!\n");

	/* Send amount of bytes. */
	if (send_all(serial_fd, len.len8, 4) < 0)
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
		"  %s /dev/ttyUSB0 dump4M.img $((4<<20))\n\n"
		"Note:\n"
		"<output_file_length> must be divisible by 4!!",
		prg_name, prg_name, prg_name);
}

/**
 * @brief Handle program arguments
 *
 * @param argc Argument count.
 * @param argv Argument list.
 * @param out_len Dump length.
 */
static void handle_arguments(int argc, char **argv,
	ssize_t *out_len)
{
	char *out;

	if (argc != 4)
		usage(argv[0]);

	out = argv[2];

	/* Dump length. */
	*out_len = atoi(argv[3]);
	if (*out_len <= 0 || (*out_len % 4 != 0))
	{
		err("Output length must be multiple of 4!\n");
		usage(argv[0]);
	}

	/* Open output file. */
	if ((out_fd = open(out, O_CREAT|O_RDWR|O_TRUNC, 0644)) < 0)
		errx("Failed to open: %s, (%s)", out, strerror(errno));

	printf("Waiting to read %zd bytes...\n", *out_len);

	/* Setup socket and/or serial. */
	if (strcmp(argv[1],"-s") != 0)
		serial_fd = setup_serial(argv[1]);
	else
		serial_fd = setup_server_and_listen(2345);
}

/* Main =). */
int main(int argc, char **argv)
{
	ssize_t out_len  = 0;
	size_t rdbytes;
	size_t amnt;
	size_t i, j;
	int c;

	handle_arguments(argc, argv, &out_len);
	rdbytes = 0;
	amnt    = out_len / AMNT_BARS;

	/* Wait to dump. */
	wait_and_send_length(out_len);

	/* Restore tty and stuff at exit. */
	atexit(restore_settings);

	/* Dump. */
	fputs("Dumping memory: [                                 ]\r", stderr);
	fputs("Dumping memory: [", stderr);

	for (i = 0; i < (size_t)out_len; i++)
	{
		if ((c = next_byte()) < 0)
			errx("Failed to read from device! (%s)\n", strerror(errno));

		if (write(out_fd, &c, 1) <= 0)
			errx("Unable to write to the output file!\n");

		rdbytes++;

		/* Update progress bar. */
		if (rdbytes >= amnt)
		{
			for (j = 0; j < rdbytes / amnt; j++)
				fputc('#', stderr);
			rdbytes = 0;
		}
	}

	fputs("] done =)\n", stderr);

	/* Check for CRC. */
	wait_and_check_crc();

#ifndef BIOS
	puts("Checking output file...");
	check_output(out_len);
#endif

	return (0);
}
