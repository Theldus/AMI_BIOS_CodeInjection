# Tools
Below is a list of tools that I developed throughout the BIOS reverse engineering process:

## [bread](https://github.com/Theldus/bread)
BREAD (BIOS Reverse Engineering & Advanced Debugging) is an 'injectable' real-mode x86
debugger that can debug arbitrary real-mode code (on real HW) from another PC via serial
cable.

## [mdump](https://github.com/Theldus/AMI_BIOS_CodeInjection/tree/main/tools/mdump)
`mdump` is a lightweight memory dump tool that can be used to dump the entire memory of
a system over a serial cable. It is designed to be minimally invasive and can be booted
or injected into a system to perform memory dumps.

Example output:
```bash
$ ./mdump /dev/ttyUSB0 output_file.bin $((4<<20))
Waiting to read 4194304 bytes...
Device /dev/ttyUSB0 opened for reading...
Dumping memory: [################################] done =)
Received CRC-32: ce18133e
Calculated CRC-32: ce18133e, match?: yes
Checking output file...
Success!
```

## [find_gaps](https://github.com/Theldus/AMI_BIOS_CodeInjection/tree/main/tools/find_gaps)
`find_gaps` is a small C utility that looks for gaps (sequences of 0xFF or 0x00) in a given
file of at least the specified size. This is useful for finding potential spots in the ROM
that can be used to inject code.

Example output:
```bash
$ ./find_gaps
Usage: ./find_gaps <offset> <min_length> <filename>

$ ./find_gaps 0 5000 post.rom
Found sequence at offset 180980, length 9479 bytes
Found sequence at offset 307343, length 29557 bytes
Found sequence at offset 336933, length 5779 bytes
Found sequence at offset 345607, length 8691 bytes
```

## [find_asm.sh](https://github.com/Theldus/AMI_BIOS_CodeInjection/blob/main/tools/find_asm.sh)
`find_asm.sh` is a small shell script that searches for one (or more) assembly (16-bit) instructions
for a given file.

Example output:
```bash
$ ./tools/find_asm.sh post.rom
mov eax,0x80000002
^D # Press Ctrl+D to finish

Offset 70934:
00000000  66B802000080      mov eax,0x80000002
00000006  0FA2              cpuid
00000008  E84300            call 0x4e
0000000B  66B803000080      mov eax,0x80000003
00000011  0FA2              cpuid
00000013  E83800            call 0x4e
00000016  66B804000080      mov eax,0x80000004
0000001C  0FA2              cpuid
0000001E  E8                db 0xe8
0000001F  2D                db 0x2d
```

## [skip_string.sh](https://github.com/Theldus/AMI_BIOS_CodeInjection/blob/main/tools/skip_strings.sh)
