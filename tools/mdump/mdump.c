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

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <sys/socket.h>

/* Progress amount of bars. */
#define AMNT_BARS 32

/* Serial fd. */
static int sfd;
static struct termios savetty;

/**/
#define errx(...) \
	do { \
		fprintf(stderr, __VA_ARGS__); \
		exit(1); \
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
		errx("Usage: %s [-s|/serial/device/path] output_file "
			"output_file_length\n", argv[0]);

	out     = argv[2];
	out_len = atoi(argv[3]);
	amnt    = out_len / AMNT_BARS; /* amnt of bytes per bar. */
	rdbytes = 0;

	printf("Waiting to read %zd bytes...\n", out_len);

	/* Open output file. */
	if ((ofd = creat(out, 0644)) < 0)
		errx("Failed to open: %s, (%s)", out, strerror(errno));

	/* If not socket. */
	if (strcmp(argv[1],"-s") != 0)
		ifd = setup_serial(argv[1]);
	else
		ifd = setup_server_and_listen(2345);

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

	close(ifd);
	close(ofd);
	return (0);
}
