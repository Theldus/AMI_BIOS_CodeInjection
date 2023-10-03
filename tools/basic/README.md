# IBM BASIC OptionROM
This project is an attempt to bring IBM (Cassette) BASIC 1.0 back to
modern PCs as an OptionROM.

Once injected into the computer, a new interrupt (`int 0xC8`) will be
available, and when invoked, the original IBM BASIC will be executed.

Demo video: https://youtu.be/ugK_S9CgUto

In the video above, the BASIC is running on the PCWare IPM41-D3 motherboard
only if there are no bootable devices available, just like in the old
IBM PCs =).

## How it works?
Running IBM BASIC itself is not complicated; it simply waits to be invoked
from `SEGMENT:0` (just like in the original IBM PC, which was at `F600:0000`).
The segment number doesn't matter as long as the code is in real mode.

The interesting part that this project brings involves the implementation
of interrupts
[15h AH=0, 1, 2, and 3](http://mirror.cs.msu.ru/oldlinux.org/Linux.old/docs/interrupts/int-html/int-15.htm),
which are related to Cassette I/O.
This means that it's possible to read/save BASIC programs just as it was
done in the past, but this time using your hard drive, USB flash drive,
floppy disk, and etc.

From an implementation perspective, this was achieved using
[int 13h AH=2 and 3](http://mirror.cs.msu.ru/oldlinux.org/Linux.old/docs/interrupts/int-html/int-13.htm).
The challenge here was that int 15h (AH=2 and 3 as well) reads in terms
of bytes, whereas int 13h reads in terms of 512-byte blocks. Therefore,
aligning everything between the two interrupts was relatively laborious,
but I believe it's now functional.

## Building
To build, simply invoke 'make,' and the pnp.rom file will be generated, as in:

```bash
$ make
```

However, please note that this ROM is for testing purposes. To generate something
compatible with real hardware, edit `pnp.asm` and comment out the line `%define TEST`.
