# 2FA
2FA is a tool for two-factor authentication in BIOS via TOTP, so authentication is
required when turning on the computer.

Although for some it may seem useless, I really liked this idea and decided to go ahead:
requiring a physical device (e.g., smartphone) to turn on the computer seemed like a
good idea, and that's why I did it. It amazes me that this doesn't already exist on
modern PCs.

<p align="center">
	<img align="center" src="https://user-images.githubusercontent.com/8294550/224564310-8c9ad58c-c408-4501-9cc3-c30d1a8909f4.png"
  alt="2FA screen">
	<br>
	<i>2FA screen</i>
</p>

## Building
The 2FA algorithm requires some boring bits of code that would otherwise be quite
complicated to write in full assembly, such as HMAC, base32, and SHA1.

Because of that, I chose to use GCC and write all (or almost all) the code in C, but
still in real mode.

So to build 2FA just:
```bash
$ git clone https://github.com/Theldus/AMI_BIOS_CodeInjection
$ cd tools/2fa
$ make

# Or for AMI BIOS builds:
make BIOS=yes
```

By default the following 2FA key will be used: `AAAAAAAABBBBBBBBCCCCCCCCDDDDDDDD`,
and the following password as well: `foo`.

They can be changed with:
```bash
make BIOS=yes SECRET_KEY="key" BACK_PASSWD="passwd"
```
The `SECRET_KEY` must be a base32-encoded string with exactly 32 characters. This
should also be added to the phone or other device to generate the 2FA codes.

The `BACK_PASSWD` is a backup password: if the BIOS date and time is too different
from the current date, the PC would become inaccessible. since there would be no way
to access the BIOS setup to adjust the time again. Thinking about it, a 'backup password'
was introduced: when inserted, access to the PC is granted, without the need for
a 2FA code.

## Acknowledgements
None of this would have been possible without Skeeto's amazing blog post on
['How to build DOS COM files with GCC'](https://nullprogram.com/blog/2014/12/09/).
There he explains how it is possible to use traditional GCC to emit 32-bit code in
real mode, without the need for any kind of extra toolchain.

Thanks to that, I was able to build '2FA' in a simple way and without having to write
everything in assembly. However, it's important to make it clear that there are several
'quirks' that need to be considered with this kind of thing, like GCC issuing the
'0x66' prefix for everything (even when you don't want to! (like in far call/retf),
assuming that DS=ES=SS and so on.

If you intend to build something to run on real-mode with C, read this code carefully,
it should give you some insights =).
