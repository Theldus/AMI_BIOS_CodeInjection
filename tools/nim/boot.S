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

.code16

boot_init:
	cli
	mov $0x7C0, %ax
	add $544,   %ax
	mov %ax,    %ss
	mov $4096,  %sp

	# Read 10 sectors
	mov $0xFFFF, %ax # segment
	mov %ax, %es
	mov $0x8210, %bx # offset addr
	mov $10, %al     # num sectors to read
	mov $2, %cl      # from sector 2 (1-based)
	call read_sectors

	# Far call to our module
	lcall $0xFFFF, $0x8A10

	# Hang
1:  jmp 1b

read_sectors:
	mov $2, %ah
	mov $0, %ch
	mov $0, %dh
	int $0x13
	jc .again
	ret
.again:
	xor %ax, %ax
	int $0x13
	jmp read_sectors
	ret

.fill 510-(.-boot_init), 1, 0
.word 0xAA55
