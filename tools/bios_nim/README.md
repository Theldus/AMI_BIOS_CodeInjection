# BIOS Nim
BIOS Nim is a tiny-BIOS/bootblock (with emphasis on tiny) made to work
on PCWare IPM41-D3/Intel DG41WV motherboards where its only purpose is:
to run the NIM game via serial port, without RAM.

Demo video: https://youtu.be/oCrixs5SdVk

## How it works?
This game just initializes the very basics to work:
- Talk to Southbridge (Intel® ICH7) to initialize LPC/Super I/O
- Then talk to Super I/O (Winbond W83627DHG) to enable UART ports
- Configure CAR (Cache-as-RAM) for data/stack

### About CAR
Every x86 PC boots up without using any RAM: it is the responsibility
of the BIOS to talk to the chipset and initialize it.

At this _very_ early stage, all the code is loaded directly from the
BIOS flash memory without using any RAM, and consequently, the code
being limited to just using registers.

Turns out, there is a feature in x86 processors that allows memory
ranges to be mapped directly to the processor's cache memory
(search for MTRRs and CAR, or Cache-as-RAM), be it L1, L2 or L3. 
With this memory mapped, you can then configure a stack, a data
section, etc... it's even possible to jump to protected mode and
run 32-bit C code, in your own BIOS, amazing isn't it?

## Building
The code is divided into 2 files: `bbnim.asm` and `nim.asm`. The first
is BIOS/bootblock and generates a 1M ROM ready to be flashed. The second
is a bootable version, designed to be tested on a real machine/VM in an
easy way.

To compile, simply:
```bash
$ nasm -fbin bbnim.asm -o nim.rom    # ROM file
# or
$ nasm -fbin nim.asm -o bootable.bin # Bootable game
```

## Good references
- Must-read reference: [Intel SDM, Vol 3A: Ch 11, Memory Cache Control: MEMORY TYPE RANGE REGISTERS (MTRRS)](https://www.intel.com.br/content/www/br/pt/architecture-and-technology/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.html)
- A *very* awesome project that I wish more people knew about, I learned a lot from reading his src: [Universal BIOS Recovery console for x86 PCs](https://github.com/pbatard/ubrx/)
- Cache-as-RAM very good insights: [What use is the INVD instruction?](https://stackoverflow.com/questions/41775371/what-use-is-the-invd-instruction),
[Cache-as-Ram (no fill mode) Executable Code](https://stackoverflow.com/questions/27699197/cache-as-ram-no-fill-mode-executable-code), and [UBRX - L2 cache as instruction RAM (CAiR)](https://pete.akeo.ie/2011/08/ubrx-l2-cache-as-instruction-ram.html)
- Excellent introductory material on BIOS crafting: [Crafting a BIOS from scratch](https://pete.akeo.ie/2011/06/crafting-bios-from-scratch.html)
- Huge source of content: if Coreboot supports the motherboard you want to support, then it has the code you need to read: [Coreboot src](https://github.com/coreboot/coreboot)

Also check out the [docs/](/docs) folder for some interesting PDFs on the subject.
