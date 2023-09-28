# MIT License
#
# Copyright (c) 2023 Davidson Francis <davidsondfgl@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

CC ?= cc
CFLAGS += -Wall -Wextra -pedantic -O2
OBJ = mdump.o
BIN = mdump mdump.img

ifeq ($(BIOS),yes)
	CFLAGS   += -DBIOS
	ASMFLAGS += -DBIOS
endif

ifneq ($(DUMP_BYTES),)
	CFLAGS   += -DDUMP_BYTES=$(DUMP_BYTES)
	ASMFLAGS += -DDUMP_BYTES=$(DUMP_BYTES)
endif

ifneq ($(BAUDRATE),)
	CFLAGS   += -DBAUDRATE=B$(BAUDRATE)
	ASMFLAGS += -DBAUDRATE=$(BAUDRATE)
endif

ifeq ($(DISABLE_CRC),yes)
	CFLAGS   += -DDISABLE_CRC
	ASMFLAGS += -DDISABLE_CRC
endif

.PHONY: all qemu clean

all: $(BIN)

# C Files
%.o: %.c Makefile
	$(CC) $< $(CFLAGS) -c -o $@

# ASM Files
%.img: %.asm
	nasm -fbin $< -o $@ $(ASMFLAGS)

mdump.img: mdump.asm

# Main
mdump: $(OBJ)
	$(CC) $^ $(LDFLAGS) $(LDLIBS) -o $@

# Run on Bochs and QEMU
bochs: mdump.img
	bochs -q -f .bochsrc.txt
qemu: mdump.img
	qemu-system-i386 -boot a -fda mdump.img \
		-serial tcp:127.0.0.1:2345 -gdb tcp::5678

clean:
	$(RM) $(OBJ)
	$(RM) $(BIN)
