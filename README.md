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

You clould add seed for xor if you wish :-)

Simple FreePascal converter from ihex to binary, and encrypter
also is attached.

It supports only uploading flash image starting from 0 address.
Programming eeprom, fuses etc. is NOT supported.


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

Use your favorite burner. [Avrdude](http://www.nongnu.org/avrdude/) works fine.

Fuses and lock bits:

Required:
- BOOTRST=0
- BOOTSZ1=1
- BOOTSZ0=0

Recommended:
- BLB12=0
- BLB11=0


Using:
-----

Boot process:

1. Set serial to 9600, 8 bits, parity none, 1 stop bit
2. Print greeting over serial
3. Wait max 2 seconds for 'B' (capital 'b')
4. If received char is other than 'B' -> boot
5. If timeout exceeded -> boot
6. Print second part od greeting
7. Wait max 2 seconds for 'P' (capital 'p')
8. If received char is other than 'P' -> boot
9. If timeout exceeded -> boot
10. Switch to xmodem communication and wait for data

So, simply speaking you need:

1. Connect to Atmega via serial and run some terminal application (for example Minicom)
2. After boot you should get some prompt
3. Hit 'B' and then 'P'
4. Use some application to transfer code (for example lsz if you have binary image)
5. After programming reset controller ot hit enter in console


Credits:
-------

XEBOOTloader was written by Marek Wodzinski (me) in 2007 based on Atmel
Atmega8 datasheet, with small modification in 2011, and finally released to public in 2014.

Public repository: https://github.com/majekw/xeboot


License:
-------

This bootloader is licensed unded GPL v3 license.

Commercial use: you could use it to upload your own proprietary software to chip
as long as you treat this bootloader as separate software.

In short:
- you put/deliver 2 pieces of software (XEBOOT + your software) = OK
- you put one software into chip (treating XEBOOT as part of your software) = BAD

Values of encrypting variables you could keep secret.

