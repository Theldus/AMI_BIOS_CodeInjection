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
- MMTool 3.22 w/ module 1B unlocked: MMTool is an official AMI tool for extracting and
inserting modules into the BIOS. However, the module we will be working on in this article
(1B) is blocked by default. Therefore, we need this modded version to proceed (more details
later).
- FreeDOS: In order to run AFUDOS.EXE and reflash without external tools
- AFUDOS v4.08p: AMI's Tool to Flash BIOS ROM
- Hex editor for disassembling and static analysis: I highly recommend [HT],
[Cutter] and [ImHex].

[HT]: https://hte.sourceforge.net/
[Cutter]: https://github.com/rizinorg/cutter
[ImHex]: https://github.com/WerWolv/ImHex

## BIOS modules
Every (as far as I know) BIOS ROM is made up of modules. These modules can be compressed or
not, (generally) they are extracted to a fixed memory location and have a specific function.
The main idea behind these modules is to make the ROM easily modifiable by making it modular
and allowing for specific points to be altered.

Some of the key modules and their functions:

### Bootblock
The bootblock is the first module to be executed by the computer, it is usually uncompressed
and runs from the memory location `F000:FFF0`.

The function of the bootblock is to perform a very basic initialization of the system, such
as initializing the RAM, decompressing the remaining modules, and performing checksum checks
on these modules as well.

### Single Link Arch BIOS/System BIOS/POST ROM
This module is the main module of the ROM and is responsible  for further initializing the PC,
performing all POST tests and invoking the other modules as well.

This is the module where we are going to make changes.

### OEM Logo
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
00000000  52 55 4e 5f 43 53 45 47  00 01                    |RUN_CSEG..|
```
That is, just strings being interpreted as instructions, be *very* careful with that!

#### A good location (b):
```asm
00011513  6660              pushad
00011515  57                push di
00011516  66B802000080      mov eax,0x80000002
0001151C  0FA2              cpuid
0001151E  E84300            call 0x1564
00011521  66B803000080      mov eax,0x80000003
00011527  0FA2              cpuid
00011529  E83800            call 0x1564
0001152C  66B804000080      mov eax,0x80000004
00011532  0FA2              cpuid
00011534  E82D00            call 0x1564
00011537  5F                pop di
...
```

The above code uses the CPUID instruction multiple times to get the computer's CPU model
string. With each invocation, the same function is called (probably saving the contents of
the registers somewhere).

Looking at this piece of code, you can say with 100% certainty that it is not garbage,
string or random data being interpreted as an instruction, but actual instructions.

Also, this code makes use of the stack (`pushad`, `push` and `call`) and uses the `0x66` prefix
for `pushad` and `mov`, meaning that we are on (un)real-mode. Overall is a very good candidate!

> :information_source: **Note:** Being on real mode is a *must*, for some reasons: a) it's the way
the PC starts by default, b) you can use BIOS interrupts, and c) there are fewer restrictions on what
you can do. The BIOS can (and will) jump in and out of protected-mode one or more times during
its entire run. So please, make sure your code has been injected into some area that runs as
16-bit code.

#### How to find, then?
There is no magic formula for this, just "educated guesses".

First of all, extract the "Single Link Arch BIOS" module (module ID 0x1B) with MMTool and...
