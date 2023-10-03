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
`skip_string.sh` is a small shell script that generates a 'skip list' for ndisasm using the strings
command. This list contains the strings offsets that are then ignored by ndisasm.

# Games
Below is a list of games I made to run in the BIOS:

## [NIM](https://github.com/Theldus/AMI_BIOS_CodeInjection/tree/main/tools/nim)
Nim is a BIOS game where each player takes turns removing sticks from a row. The game
starts with a pre-determined number of sticks, and players can remove as many sticks as they like
on their turn, but they must remove at least one. The player who removes the last stick loses
the game.

The computer will only fully boot if the player wins the game, which can be a difficult and
time-consuming task. As a result, this game was made solely for entertainment purposes.

Video: https://youtu.be/4SEeUinVLCQ

# Security
Below is a list of tools focused on 'security':

## [2FA](https://github.com/Theldus/AMI_BIOS_CodeInjection/tree/main/tools/2fa)
2FA is a tool for two-factor authentication in BIOS via TOTP, so authentication is required when
turning on the computer.

Although for some it may seem useless, I really liked this idea and decided to go ahead: requiring
a physical device (e.g., smartphone) to turn on the computer seemed like a good idea, and that's why
I did it. It amazes me that this doesn't already exist on modern PCs.

Video: https://youtu.be/ycLIlmRGP6M

# Miscellaneous
Below is a diverse list of random code that might be interesting/useful:

## [basic](https://github.com/Theldus/AMI_BIOS_CodeInjection/tree/main/tools/basic)
BASIC is an attempt to bring the IBM (Cassette) BASIC 1.0 back to modern PCs as an OptionROM.
Once injected into the computer, a new interrupt (`int 0xC8`) will be available, and when invoked,
the original IBM BASIC will be executed.

Video: https://youtu.be/ugK_S9CgUto
