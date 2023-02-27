# mdump
`mdump` is a lightweight memory dump tool that can be used to dump the entire memory of a
system over a serial cable. It is designed to be minimally invasive and can be booted or
injected into a system to perform memory dumps.

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
# amount of memory. To dump 4MB, reading from /dev/ttyYSB0:
$ ./mdump /dev/ttyUSB0 output_file.bin $((4<<20))

# << BOOT THE PC YOU WANT TO DUMP >>
```

