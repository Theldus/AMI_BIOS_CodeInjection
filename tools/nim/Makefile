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

AS ?= as
OBJ = nim.o boot.o
BIN = nim.bin boot.bin bootable.img
LDFLAGS = -T linker.ld

.PHONY: all bochs qemu clean

all: $(BIN)

# ASM Files
%.o: %.S
	$(AS) $^ -o $@

nim.bin: nim.o
	$(LD) $(LDFLAGS) -Ttext=0x8210 --oformat binary $^ -o $@
boot.bin: boot.o
	$(LD) $(LDFLAGS) -Ttext=0x7c00 --oformat binary $^ -o $@

bootable.img: boot.bin nim.bin
	cat boot.bin nim.bin > bootable.img

# Run on Bochs and QEMU
bochs: bootable.img
	bochs -q -f .bochsrc.txt
qemu: bootable.img
	qemu-system-i386 -boot a -fda bootable.img -soundhw pcspk

clean:
	$(RM) $(OBJ)
	$(RM) $(BIN)
	$(RM) bx_enh_dbg.ini
