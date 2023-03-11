OUTPUT_FORMAT(binary)
SECTIONS
{
	.boot :
	{
		boot.o *(.boot)
	}

	/*
	 * ## Warning ##
	 * The final image needs to be 'adjusted', because
	 * the linker adds physical padding to the file when
	 * adjusting the section start offset (and I couldn't
	 * get around that).
	 *
	 * If anyone knows of a cleaner way to do this, I'd
	 * really appreciate.
	 *
	 * Note: Please checkout the Makefile to get a better
	 * idea on how I achieve this.
	 */

	. = 0x8a10;
	.text :
	{
		*(.text)
	}
	.data :
	{
		*(.bss)
		*(.data)
		*(.rodata)
	}

	_stack_addr = . + 2048;

	/DISCARD/ :
	{
		*(.comment)
		*(.note)
		*(.eh_frame)
	}
}
