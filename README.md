xeboot (Xmodem Encrypted Bootloader)
======

About:
-----

This is tiny (0.5KB) bootloader for AVR Atmega8 microcontroller.

Protocol supported by bootloader: XMODEM

It also support (optional) simple encrypted binaries.

Encryption is based on xor, swap bits and changing bytes order
in packet. There are 2 coefficients used for 'encryption':

- starting point within packet (variable 'poczatek')
- offset for next byte in packet (variable 'mieszacz' - must be
a prime number)

Simple FreePascal converter from ihex to binary, and encrypter
also is attached.


Compiling:
---------

Use [AVRA](http://avra.sourceforge.net/) to compile.

Before compiling adjust some defines:

1. ZEGAR - set to your clock frequency in Hz
2. uncomment .define use_crypt if you need image decryption
and adjust mieszacz and poczatek
3. UART_RATE - set to other speed if 9600 is not what you like

Compile simply by 'avra bootloader.asm'


Burning:
-------

Use your favorite burner. Avrdude works fine.

In order to bootloader work, some fuses have to be changed:
