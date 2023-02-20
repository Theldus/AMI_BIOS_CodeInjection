# AMI BIOS Code Injection
A simple article on how to reverse engineer and do code injection on AMI BIOSes (Legacy)

## Intro
This article aims to document what I've learned about BIOS reverse engineering and
code injection, something I've always wanted to do. So don't expect something big
that cover every corner about BIOS, for that please refer to Pinczakko's tutorials.

Particularly, I will talk about AMI (legacy) BIOS and how to inject arbitrary code
into it for execution. I'm not going to delve deeply into how the BIOS works
(because it's a very complex subject that I don't master), but I intend to talk
about some topics that I consider important.

The method described here, although focused on the AMI, can be replicated in other
BIOSes as well, with the necessary changes.

## Requirements
A few requirements are necessary in order to be able to follow this text:

### 1. Needed knowledge:
Knowledge about x86, real-mode, protected-mode, OSDev and related. I assume you
know how to program in assembly, write bootable code, and etc.

### 2. Needed hardware:
- Motherboard with AMI Legacy BIOS. Here I will use an ECS G31T-M, with 1MB ROM,
using the Macronix MX25L4005 flash chip.
- Flash programmer (can be a [Raspberry Pi]). Unless you want to do the [hot swapping]
technique (removing the chip and putting another one with the PC turned on),
I strongly recommend that you have a working programmer.
Bricking the BIOS with an invalid or partially working ROM is not a matter of _if_,
but _when_. During my journey I had to easily reflash more than __50 times!__.

[Raspberry Pi]: https://www.rototron.info/recover-bricked-bios-using-flashrom-on-a-raspberry-pi/
[hot swapping]: https://www.overclockers.com/bios-hot-swapping/

### 3. Needed software:
- Windows (for MMTool, unfortunately)
- Linux (preferrably, for the remaining)
- [MMTool 3.22] w/ module 1B unlocked: MMTool is an official AMI tool for extracting and
inserting modules into the BIOS. However, the module we will be working on in this article
(1B) is blocked by default. Therefore, we need this modded version to proceed (more details
later).
- [AFUDOS v4.08p]: AMI's Tool to Flash BIOS ROM
- [amideco]: (Optional) To extract AMI ROM modules on Linux
- [FreeDOS]: In order to run AFUDOS.EXE and reflash without external tools
- Hex editor for disassembling and static analysis: I highly recommend [HT],
[Cutter] and [ImHex].
- `NASM`, `ndisasm`, `objdump` and relateds are useful too

[HT]: https://hte.sourceforge.net/
[Cutter]: https://github.com/rizinorg/cutter
[ImHex]: https://github.com/WerWolv/ImHex
[FreeDOS]: https://www.freedos.org/
[amideco]: https://manpages.ubuntu.com/manpages/trusty/man1/amideco.1.html
[AFUDOS v4.08p]: https://archive.org/details/afudos_4-08p
[MMTool 3.22]: https://archive.org/details/mmtool_bkmod

## BIOS modules
Every (as far as I know) BIOS ROM is made up of modules. These modules can be compressed or
not, (generally) they are extracted to a fixed memory location and have a specific function.
The main idea behind these modules is to make the ROM easily modifiable by making it modular
and allowing for specific points to be altered.

Some of the key modules and their functions:

### Bootblock (ID 0x08)
The bootblock is the first module to be executed by the computer, it is usually uncompressed
and runs from the memory location `F000:FFF0`.

The function of the bootblock is to perform a very basic initialization of the system, such
as initializing the RAM, decompressing the remaining modules, and performing checksum checks
on these modules as well.

### Single Link Arch BIOS/System BIOS/POST ROM (ID 0x1B)
This module is the main module of the ROM and is responsible  for further initializing the PC,
performing all POST tests and invoking the other modules as well.

This is the module where we are going to make changes.

### OEM Logo (ID 0x0E)
This module contains the motherboard logo. For this specific motherboard, the file is in PCX format.

Although it seems useless, this module is extremely useful for us: the BIOS doesn't *need* it,
it is extracted in fixed memory position, it's 'big'. It's the perfect place to put arbitrary code
that will be executed.

## Code Injection
Code injection can be done in multiple ways, here I will talk about two ways: a) via POST ROM and
b) POST ROM + logo.

But before we get started, we first need to locate a good injection spot.

### Finding good candidates to injection
Finding a good place to inject code means that **the location must make sense**:

- You **want** to replace instructions with others, you don't want to add on places that have
data!
- The location must have a minimum of system startup. Having instructions that manipulate the
stack nearby (`push`,`pop`,`ret`...) _might_ be a good sign!
- The instructions _together_ should make sense too: is there a loop? function? what are they doing?

#### A bad location (a):
```asm
00000158  52                push dx
00000159  55                push bp
0000015A  4E                dec si
0000015B  5F                pop di
0000015C  43                inc bx
0000015D  53                push bx
0000015E  45                inc bp
0000015F  47                inc di
00000160  0001              add [bx+di],al
```
The 'code' above is literally:
```asm
00000000  52 55 4e 5f 43 53 45 47  00 01    |RUN_CSEG..|
```
That is, just strings being interpreted as instructions, be *very* careful with that!

#### A good location (b):
```asm
get_cpuid():
00011513  6660              pushad
00011515  57                push di
00011516  66B802000080      mov eax,0x80000002
0001151C  0FA2              cpuid
0001151E  E84300            call 0x1564 <save_cpuid>
00011521  66B803000080      mov eax,0x80000003
00011527  0FA2              cpuid
00011529  E83800            call 0x1564 <save_cpuid>
0001152C  66B804000080      mov eax,0x80000004
00011532  0FA2              cpuid
00011534  E82D00            call 0x1564 <save_cpuid>
00011537  5F                pop di
...
```

The above code uses the `CPUID` instruction multiple times to get the computer's CPU model
string. With each invocation, the same function is called, saving the contents of
the registers somewhere.

Looking at this piece of code, you can say with 100% certainty that it is not garbage,
string or random data being interpreted as an instruction, but actual instructions.

Also, this code makes use of the stack (`pushad`, `push` and `call`) and uses the `0x66` prefix
for `pushad` and `mov`, meaning that we are on (un)real-mode. Overall is a very good candidate!

> :information_source: **Note:** Being on real mode is a *must*, for some reasons: a) it's the way
the PC starts by default, b) you can use BIOS interrupts, and c) there are fewer restrictions on what
you can do. The BIOS can (and will) jump in and out of protected-mode one or more times during
its entire run. So please, make sure your code has been injected into some area that runs as
16-bit code.

> :warning: **Spoiler Alert:** While it is indeed a good location for injection, the BIOS at this
stage has not yet initialized video, keyboard or anything interesting... so it could be a bad
location if you want some user interaction. We'll look at a better location later.

### How to find, then?
We can divide in two steps:

___a) Extract the POST.ROM file:___

First of all, extract the "Single Link Arch BIOS/SLAB" module (module ID 0x1B) with MMTool (or amideco).
I'll call the extracted file as `post.rom`.

___b) Search:___

This is by far the hardest step of all, but once you've found a good spot, everything gets easier =).
Unfortunately, there's no magical formula here, just 'educated guesses':

<details><summary><b><code>ndisasm</code>-only approach</b></summary>

My suggestion is to initially use `ndisasm` and try to "`grep`" for something useful, something like:
```bash
$ ndisasm -b16 post.rom | grep "cpuid"
```
or maybe:
```bash
$ ndisasm -b16 post.rom  | grep "cpuid" -C 10 | grep "80000002" -C 10
```
The line above returns the code block (b) shown earlier, magical isn't it?

However, there are a few quirks with this approach: `ndisasm` actually interprets the input file as
a raw binary file, so strings and etc will also be seen as instructions, remember what I said in
the beginning? You can never blindly trust the output of ndisasm... the ROM file is a mess inside,
and we can't 100% separate what is code and what is data... since it's just a raw binary file..

</details>

<details><summary><b><code>tools/skip_strings.sh</code> approach</b></summary>

This script generates a 'skip list' for `ndisasm` using the strings command. This list contains
the strings offsets that are then ignored by `ndisasm`.

To put it simply:
```bash
# Generates a dump skipping strings
$ ./tools/skip_strings.sh post.rom 
Output file: post.rom.dump

# Search again
$ grep "cpuid" -C 10 post.rom.dump | grep "80000002" -C 10
```
Optionally, the `-t` parameter can be used to define the strings minimum length  (default = 8). 
See `-h` for more details.

(This method isn't foolproof either, but it can help find previously unrecognized instructions.)

</details>

<details><summary><b><code>tools/find_asm.sh</code> approach</b></summary>

If all fails, you can search for a particular instruction directly by its encoding, i.e. its
'raw bytes'. For instance, the instruction `mov eax, 0x80000002` consists of the following
bytes: `0x66, 0xB8, 0x02, 0x00, 0x00, 0x80` on 16-bit mode.

The `find_asm.sh` script was written to aid in this process. You can type as many instructions
on stdin as you want, and they will be compiled to assembly and their corresponding bytes will
be searched in ROM. The chances of not finding an instruction (which exists!) are greatly
reduced in this manner:

```bash
$ ./tools/find_asm.sh post.rom
mov eax,0x80000002
^D # Press Ctrl+D to finish

Offset 70934:
00000000  66B802000080      mov eax,0x80000002   ┐ valid instructions
00000006  0FA2              cpuid                |
00000008  E84300            call 0x4e            |
0000000B  66B803000080      mov eax,0x80000003   |
00000011  0FA2              cpuid                |
00000013  E83800            call 0x4e            |
00000016  66B804000080      mov eax,0x80000004   |
0000001C  0FA2              cpuid                ┘            
0000001E  E8                db 0xe8 ┐ invalid insns due to the lack of
0000001F  2D                db 0x2d ┘ remaining bytes
```
If the instructions below the found instruction make sense, congratulations, you found a valid
code snippet.

It is worth noting, however, that the instruction dump is based on byte quantity, rather than
instruction quantity, so the last instructions in the dump may be invalid. To work around this,
increase the dump size with the `-d` option. See `-h` for more details.

</details>

### Injecting Code
Now that you have a place to inject the code, there are basically 2 ways to inject it:

1. Completely replacing instructions
2. Adding a `call`,`jmp` (or equivalent) to elsewhere

#### 1. Replacing instructions
I want to emphasize here that replacing means literally replacing the original instructions to others,
_without_ backup, because the BIOS does not need them. Remove instructions that are not needed? Yes,
and I've already shown an example: the '[good location (b)](#a-good-location-b)'
is unnecessary and can be completely replaced by any of your code.

This function (`get_cpuid()`) returns the CPUID and begins at `0x11513` (physical file offset).
The function (`save_cpuid()`) that this function calls, located at `0x11564`, simply saves the
string to memory and can be replaced without issue, giving us an additional 25 bytes.

Furthermore, the function that calls '`get_cpuid()`' can be removed, giving us an extra 92 bytes.
In short, we have 198 bytes that can be completely erased/replaced from `0x114b7` to `0x1157c`!
Isn't it amazing?

Okay, let's say you want to inject some code that changes the CPU name, which is saved at the
physical address `0xfd301 (F000:3D01)`.

You could do something like:
```asm
; File: mycode.asm

[BITS 16]
[ORG 0x1138] ; 4000:1138

pusha ; Always backup registers
pushf ; and flags that you touch

mov  ax, cs
mov  ds, ax
mov  ax, 0xF000
mov  es, ax
mov  di, 0x3D01
mov  si, cpu_model_str

mov  cx, cpu_model_str_len
write:
    lodsb
    stosb
    loop write

popf
popa
ret

cpu_model_str: db 'MyCPU', 0
cpu_model_str_len equ $-cpu_model_str

times 198-($-$$) db 0x90 ; Padding
```
You can now build with:
```bash
$ nasm -fbin mycode.asm -o mycode.bin
```
and replace the appropriate portion with:
```bash
$ dd if=mycode.bin of=post.rom bs=1 seek=$((0x114b7)) conv=notrunc
```
Now with the `post.rom` file modified, just replace the original module (Single Link Arch
BIOS/SLAB, ID 0x1B) for this one in `MMTool`, and save your new ROM, which will be ready
to be flashed.

> :information_source: **Note:** Note that I used the value `0x1138` as the ORG directive.
This is the offset from the EIP at which the function resides in real memory (`4000:1138`).
This value was obtained via memory dump with the `mdump` tool. _Whenever_ you make memory
references within your own code, change the ORG directive to the appropriate value.

#### 2. Call to elsewhere
The replacement method is quite limited: it's hard to find locations that can be
replaced/deleted completely. The most common approach is:
- Find an empty place in your `post.rom` (like some place filled with 0s)
- Add a call to there from somewhere
- Add to the end of your new code the instructions you replaced when adding your call

this way, it is possible to get larger portions of code available, without having to delete
important instructions, because now your code will backup them.

Unfortunately, there is very little space available within the 512kB ROM, so I will need to
take a different approach. Instead of looking for free space inside the `post.rom` module,
I will use the logo module to add instructions. This way, we can increase the available
space from a mere 198 bytes to a whopping 20kB, or ~103 times more.

To do this, we need to do it in two steps:
1. Edit the `post.rom` module to invoke the code inside the logo module
2. Edit the logo module (I'll call it `logo.rom`) with your code.

For the first step, we must first decide where to inject the code... and since we're working
with the logo, a good place to do so is right before the video is set up.

How can we find it? Since the logo is a colored image with pixels (rather than text), the
video mode should be appropriate for that. What about
`int 0x10, AX = 0x4F02 - Set VBE Video Mode`?

```bash
$ ndisasm post.rom -b16 | grep "4f02" -C 4
00017EF2  06                push es
00017EF3  1E                push ds
00017EF4  07                pop es
00017EF5  8BD8              mov bx,ax
00017EF7  B8024F            mov ax,0x4f02 ┐ our target! 0x17ef7
00017EFA  CD10              int 0x10      ┘
00017EFC  07                pop es
00017EFD  C3                ret
00017EFE  6650              push eax
```
bingo! thats exactly what we are looking for!

With our target in hands, we can now create a file called `mycall.asm` with the
following content:
```asm
[BITS 16]
call 0xFFFF:0x8A10 ; far call occupies 5 bytes
```
build and inject with:
```bash
$ nasm -fbin mycall.asm -o mycall.bin
$ dd if=mycall.bin of=post.rom bs=1 seek=$((0x17ef7)) conv=notrunc
```

Now, you might be wondering: what address is this `FFFF:8A10`? This is the address that the
logo module is loaded into the memory (obtained via `mdump`).

Okay, now let's move on to the logo:

Make the following modifications to `mycode.asm`:
```patch
--- mycode.asm	2023-02-16 17:30:08.449703077 -0300
+++ mycode_new.asm	2023-02-16 18:25:05.342841097 -0300
@@ -1,7 +1,10 @@
 ; File: mycode.asm
 
 [BITS 16]
-[ORG 0x1138] ; 4000:1138
+[ORG 0x8210] ; FFFF:8210
+
+; Dummy 2kB logo
+times 2048 db 0x0a
 
 pusha ; Always backup registers
 pushf ; and flags that you touch
@@ -21,9 +24,11 @@
 
 popf
 popa
-ret
+
+mov ax, 0x4f02 ; Restore overwritten
+int 0x10       ; instructions
+
+retf
 
 cpu_model_str: db 'MyCPU', 0
 cpu_model_str_len equ $-cpu_model_str
-
-times 198-($-$$) db 0x90 ; Padding
```
There are 5 changes that need to be commented:
1. The `ORG` directive has changed. Since the logo is loaded at `FFFF:8210` (or `0x108200`), you
need to change the ORG to generate the labels at the correct offsets.

2. There is a 2kB 'dummy logo'. This turned out to be necessary as the BIOS image decompressor
tries to decode the code as an image and displays 'glitch art' on the screen (quite scary at
first). Filling in '0xa' causes nothing to be displayed on the screen, but the code continues
to run as before. This also explains why the previous far call is made to `FFFF:8A10` instead
of `FFFF:8210`, since: `8210+2kB = 8A10`.

3. Since the code is invoked from a far call, you need to use a far ret.

4. The previously overwritten instructions (in `mycall.bin`) are restored in the logo module,
just before the code returns.

5. There is no need to padding anymore.

After that, just compile with:
```bash
$ nasm -fbin mycode.asm -o mycode.bin
```
and `mycode.bin` will be your new logo module.

To create your new ROM, just replace the POST ROM and logo modules with their respective versions
modified: `post.rom`, and `mycode.bin` on `MMTool`. Save the new ROM, and it will be ready to be
flashed.

> :warning: **Warning:** Be careful with the locations you choose to inject the code. This example
> only works because the address, although above 1MB, is still accessible within the range that A20
> reaches (`1MB+64kB-16 bytes`) and the A20 line is already enabled at this point in the code. When
> in doubt, only use memory below 1MB.

## Flashing the ROM
Flashing the ROM can be done in multiple ways. For AMI BIOS, there are the official AMI tools:
`AFUDOS` and `AFUWIN`, for MS-DOS and Windows, respectively.

In addition, there is the possibility of external flash, either with a flash programmer, or even
with a Raspberry Pi (using SPI).

### AFUDOS + USB Flash Drive
Download and/or create a bootable FreeDOS image with `AFUDOS.EXE` and the new ROM inside. 

You can optionally download a [bootable FreeDOS image] already prepared with AFUDOS inside,
and then:

[bootable FreeDOS image]: https://archive.org/details/afudos_4-08p

```bash
# Mount the image and copy the BIOS ROM to it:
$ sudo mount -o loop BOOT_AFUDOS_4-08p.IMG /path/to/mount

# Copy the new rom to the bootable image
$ sudo cp NEWROM.ROM /path/to/mount

# Umount
sudo umount /path/to/mount

# Copy to the USB Flash Drive
$ sudo dd if=BOOT_AFUDOS_4-08p.IMG of=/dev/sdX
$ sync
```
Once the USB Flash Drive has been properly prepared, boot into FreeDOS and from there:

```bash
C:\> AFUDOS.EXE NEWROM.ROM
```
invoke AFUDOS passing your new ROM as a parameter and wait a few seconds, the PC will
restart automatically.

> :warning: **Warning:** ___Never___ flash a modified ROM unless you have a way to reprogram
it externally, such as a rom programmer, a Raspberry Pi, or another microcontroller that
performs a similar function.

## Acknowledgements
This project was created in collaboration with [@rlaneth], so I'd like to express my sincere
thanks to him for his valuable contributions to this project. Together, we reverse engineered
AMI and Award BIOSes, gaining invaluable insights and making significant progress in our
understanding of this complex subject matter.

I'd also like to thank [Pinczakko's BIOS articles] for his invaluable amount of information,
which inspired us to continue our research and exploration.

[Pinczakko's BIOS articles]: https://sites.google.com/site/pinczakko/bios-articles
[@rlaneth]: https://github.com/rlaneth

## References
Some good references that helped a lot in the BIOS reverse engineering:
- [Pinczakko's BIOS articles]
- [IBM PC Technical Reference](https://www.pcjs.org/documents/manuals/ibm/)
- [IBM PC BIOS source code](https://github.com/philspil66/IBM-PC-BIOS)
- [System BIOS for IBM PC XT/XT/AT Computers and Compatibles](https://archive.org/details/System_BIOS_for_IBM_PC-XT-AT_Computersand_Compatibles_Phoenix)
- [Intel Software Developer](https://software.intel.com/en-us/articles/intel-sdm)
