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

/**
 * This is our very first entrypoint, either via bootable code,
 * or where the BIOS must make a far call to.
 *
 * The following code sets up the stack, segments, and everything
 * else so that the C code can run smoothly. It's virtually our
 * 'crt0.c' for all intents and purposes.
 */

#define dbg asm ("xchg %bx, %bx\n");
#define nop asm ("nop\n");

asm (
	".code16gcc\n"
	"xchg %bx, %bx\n"

	/* ================== PROLOGUE ================ */

	/* Backup registers. */
	"pushal\n"
	"pushfl\n"
	"push %ds\n"
	"push %es\n"

	/**
	 * GCC normally requires that DS=ES=SS, and this, for real
	 * mode and within the BIOS, complicates our life quite
	 * a bit.
	 *
	 * To get around this, the code below sets up a secondary
	 * stack in the code segment itself, and when it returns
	 * (in the epilogue), it retrieves the original BIOS stack
	 * and returns as if nothing had happened. Interesting
	 * isn't it?
	 */

	/* Backup old stack. */
	"mov $_stack_addr, %bx\n"
	"movw %sp, %cs:(%bx)\n"
	"movw %ss, %cs:0x2(%bx)\n"

	/* Setup new stack. */
	"sub $4,  %bx\n"
	"mov %bx, %sp\n"
	"mov %cs, %ax\n"
	"mov %ax, %ss\n"

	/* Configure remaining data seg. */
	"mov %ax, %ds\n"
	"mov %ax, %es\n"

	/* ================== CODE ================ */
	"call twofa_main\n"
	"xchg %bx, %bx\n"

	/* ================== EPILOGUE ================ */

	/* Restore BIOS/old stack. */
	"mov $_stack_addr, %bx\n"
	"movw %cs:(%bx),    %sp\n"
	"movw %cs:0x2(%bx), %ax\n"
	"movw %ax, %ss\n"

	/* Restore registers. */
	"pop %es\n"
	"pop %ds\n"
	"popfl\n"
	"popal\n"

#ifdef BIOS
	/*
	 * >> CHANGE_HERE <<
	 * Add your backup instructions here.
	 */
	"mov $0x4F02, %ax\n"
	"int $0x10\n"
#endif

	"retf\n"
);
