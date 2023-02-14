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
- Windows (unfortunately)
- MMTool 3.22 w/ module 1B unlocked: MMTool is an official AMI tool for extracting and
inserting modules into the BIOS. However, the module we will be working on in this article
(1B) is blocked by default. Therefore, we need this modded version to proceed (more details
later).
- FreeDOS: In order to run AFUDOS.EXE and reflash without external tools
- AFUDOS v4.08p: AMI's Tool to Flash BIOS ROM
- Preferred hex editor for disassembling and static analysis: I highly recommend [HT], [Cutter] and [ImHex].

[HT]: https://hte.sourceforge.net/
[Cutter]: https://github.com/rizinorg/cutter
[ImHex]: https://github.com/WerWolv/ImHex
