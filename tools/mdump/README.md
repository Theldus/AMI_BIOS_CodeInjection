# mdump
`mdump` is a lightweight memory dump tool that can be used to dump the entire memory of a
system over a serial cable. It is designed to be minimally invasive and can be booted or
injected into a system to perform memory dumps.

## Features
`mdump` is quite simple, and this brings several advantages:
- Lightweight: only 512-byte. Fits inside a single disk sector
- Bootable: No OS required, just burn the bootable image file and perform the
memory dump.
- Minimal memory footprint: Even if there are similar solutions for Linux or
even FreeDOS, the memory usage of `mdump` is minimal, which means that it interferes
minimally with the contents of the PC's memory.
- Injectable: Its source code is made to be modular and easily injected into other
environments, such as within the BIOS itself or even as a DOS program.

## Usage
To use it is quite simple, something like:

```bash
# Build
$ git clone https://github.com/Theldus/AMI_BIOS_CodeInjection.git
$ cd AMI_BIOS_CodeInjection/tools/mdump
$ make

# Copy the bootable image to your USB flash drive
$ sudo dd if=mdump.img of=/dev/sdX

# << PLUG THE SERIAL CABLE >>

# Run the `mdump` tool, specifying the path of the serial device and
# amount of memory. To dump 4MB, reading from /dev/ttyUSB0:
$ ./mdump /dev/ttyUSB0 output_file.bin $((4<<20))
Waiting to read 4194304 bytes...
Device /dev/ttyUSB0 opened for reading...
Dumping memory: [################################] done =)
Received CRC-32: ce18133e
Calculated CRC-32: ce18133e, match?: yes
Checking output file...
Success!

# << BOOT THE PC YOU WANT TO DUMP >>
```
A progress bar will indicate the status of the transfer. After the dump is complete, some
sanity checks will be performed on the output file, and if everything is ok, chances are
the dump is in good shape.

## Limitations
`mdump` has a few limitations:
- Speed: Serial cable is naturally slow, so don't expect too much speed. A 4M dump (usually
more than enough for BIOS analysis) takes about 6 minutes. A dump of 128M is expected to
take ~3h12m.
- No switch back: `mdump` jumps to protected mode but does not jump back to real mode... So
you will have to restart your PC to use it again (if using a bootable media or DOS) or
reflash the BIOS again, if you have put it inside the BIOS ROM.
