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
CFLAGS += -Wall -Wextra -Wno-unused-function
CFLAGS += -I$(CURDIR)/tiny2fa -I$(CURDIR)/tiny2fa/google_pam -I$(CURDIR)
CFLAGS += -std=gnu99 -Os -nostdlib -m32 -march=i386 -ffreestanding
LDFLAGS = --oformat binary -m elf_i386 -T linker.ld -S
OBJ = boot.o 2fa.o
BIN = 2fa.img

# Boot size + dummy logo size
FIRST_STAGE=$$((512+2048))
# Code start address offset
CODE_ADDR=$$((0x8a10))

# BIOS builds?
ifeq ($(BIOS),yes)
	CFLAGS   += -DBIOS
	ASMFLAGS += --defsym BIOS=1
	FIRST_STAGE = 2048
endif

# Set secret key and default passwd
ifneq ($(SECRET_KEY),)
	CFLAGS += -DSECRET_KEY=\"$(SECRET_KEY)\"
endif
ifneq ($(BACK_PASSWD),)
	CFLAGS += -DBACK_PASSWD=\"$(BACK_PASSWD)\"
endif

.PHONY: all clean

all: $(BIN)

boot.o: boot.S
	$(AS) $^ $(ASMFLAGS) -o $@ --32
2fa.o: 2fa.c
	$(CC) $^ $(CFLAGS) -c

#
# Main
#
# The final image needs to be 'adjusted', because the
# linker adds physical padding to the file when adjusting
# the section start offset (and I couldn't get around that).
#
# The data:
# - FIRST_STAGE: 512 (boot size) + 2048 (logo size)
# - CODE_ADDR:   0x8a10: start of code
#
2fa.img: .2fa_big.img
	dd if=.2fa_big.img of=2fa.img bs=1 count=$(FIRST_STAGE)
	dd if=.2fa_big.img of=2fa.img bs=1 skip=$(CODE_ADDR) \
		seek=$(FIRST_STAGE) conv=notrunc

.2fa_big.img: $(OBJ)
	$(LD) $^ $(LDFLAGS) -o $@

# Run on Bochs and QEMU
bochs: 2fa.img
	bochs -q -f .bochsrc.txt
qemu: 2fa.img
	qemu-system-i386 -boot a -fda 2fa.img -rtc base=localtime

clean:
	$(RM) $(OBJ)
	$(RM) $(BIN)
	$(RM) .2fa_big.img
#	$(RM) bx_enh_dbg.ini
