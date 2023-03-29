OUTPUT_FORMAT(binary)
SECTIONS
{
	.text :
	{
		*(.text)
	}

	/DISCARD/ :
	{
		*(*)
		KEEP(*(.text))
	}
}
