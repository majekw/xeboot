; Bootloader
; (C) 2007-2011 Marek Wodzinski
;
; Changelog:
; 2007.11.16	- first code
; 2007.11.17	- xmodem and flash programming done
; 2007.11.18	- decrypting
; 2007.11.23	- fixed hang when there is a constant stream of data coming from rs
;		- removed other options, corrected banners
;		- changed a little decrypting algoryth
; 2007.11.24	- final changes in decryption algo
; 2011.07.01	- compute uart divider instead of hardcoding values
;		- make crypt optional

.include "m8def.inc"

;.define use_crypt	;comment it out if no encryption is needed

.ifndef temp
.def	temp=r16
.def	temp2=r17
.endif
.def	rblock=r2
.def	rblocki=r3
.def	rcksum=r4
.def	cksum=r18
.def	block=r19
.def	spmcrval=r20
.def	response=r21
.def	looplo=r24
.def	loophi=r25


;.equ	ZEGAR=8000000			;CLK
.equ	ZEGAR=7372800
.equ    UART_RATE=9600
.equ	RAM_START=0x100			;ram start
.equ	REC_BUF=RAM_START		;receive buffer
.equ	WRITE_BUF=REC_BUF+256		;write buffer
.equ	boot_rx_timeout=ZEGAR/641	;wait about 2s for char from UART

.equ	xmodem_SOH=0x01			;xmodem definitions
.equ	xmodem_EOT=0x04
.equ	xmodem_ACK=0x06
.equ	xmodem_NAK=0x15
.equ	xmodem_CAN=0x18
.equ	xmodem_C=0x45

.equ	mieszacz=79
.equ	poczatek=0x39


.cseg
.org	0
reset:

.org	SECONDBOOTSTART
boot_start:
		;disable interrupts
		cli
		
		;initialize stack
		ldi	temp,low(RAMEND)
		out	SPL,temp
		ldi	temp,high(RAMEND)
		out	SPH,temp
		
		;initialize UART
		cbi	DDRD,PD0	;rx: input
		sbi	DDRD,PD1	;tx: output
		
		ldi	temp,0		;no x2 speed, no multiprocessor comm.
		out	UCSRA,temp
		
		ldi	temp,(1<<RXEN)+(1<<TXEN)	;enable rx and tx
		out	UCSRB,temp
		
		ldi	temp,(1<<URSEL)+(1<<UCSZ1)+(1<<UCSZ0)	;8 bit
		out	UCSRC,temp
		
		ldi	temp,0
		out	UBRRH,temp
		ldi	temp,ZEGAR/16/UART_RATE-1	;speed: 9600 (47 for 7.3728, 51 for 8M)
		out	UBRRL,temp
		
		in	temp,UDR		;flush receiver
		in	temp,UDR
		in	temp,UDR
		
		;print banner
		ldi	ZL,low(boot_banner1<<1)
		ldi	ZH,high(boot_banner1<<1)
		rcall	boot_print
		
		;wait for keypress
boot_wait:
		rcall	boot_rx_char	;get char from uart
		brcs	boot_end	;go to end if timeout

		cpi	temp,'B'	;B?
		brne	boot_end	;no second chance
		
boot_menu:	;menu
		ldi	ZL,low(boot_banner3<<1)
		ldi	ZH,high(boot_banner3<<1)
		rcall	boot_print
boot_menu1:
		sbis	UCSRA,RXC	;wait for char
		rjmp	boot_menu1
		in	temp,UDR	;read char
		
		cpi	temp,'P'
		brne	boot_end
;
; ########## upload new firmware  #########
; #
boot_firmware:
		;upload new firmware
		clr	ZL		;set FLASH address to 0
		clr	ZH
		ldi	block,1		;set block counter
xmodem_start:
		;start xmodem transmission
		ldi	response,xmodem_NAK	;send initial NAK
xmodem_start1:
		mov	temp,response
		rcall	boot_tx_char
		rcall	boot_rx_char	;wait for char
		brcs	xmodem_start1	;time out - wait again

		cpi	temp,xmodem_SOH	;check for start of header
		breq	xmodem_receive
		
		cpi	temp,xmodem_EOT	;check for end of transmission
		breq	xmodem_end
		
		rjmp	xmodem_start1
		
xmodem_receive:
		;get packet
		rcall	boot_rx_char	;get block number
		mov	rblock,temp
		rcall	boot_rx_char	;get inverse block number
		mov	rblocki,temp
		
		ldi	YL,low(REC_BUF)	;prepare buffer address
		ldi	YH,high(REC_BUF)
		clr	cksum		;clear checksum counter
		ldi	temp2,128	;prepare to receive 128 chars
xmodem_receive1:
		rcall	boot_rx_char	;receive byte
		st	Y+,temp		;store in ram
		add	cksum,temp	;checksum
		dec	temp2
		brne	xmodem_receive1
		
		rcall	boot_rx_char	;get checksum
		
		;checks
		cp	temp,cksum	;check checksum
		brne	xmodem_start
		cp	block,rblock	;check for block number
		brne	xmodem_start
		com	rblocki		;check for block and 255-block fields
		cp	rblocki,rblock
		brne	xmodem_start
		
		;block received ok
		rcall	boot_block_process	;do something
		
		inc	block		;get next block
		ldi	response,xmodem_ACK	;send ACK
		rjmp	xmodem_start1
xmodem_end:
		ldi	temp,xmodem_ACK
		rcall	boot_tx_char		
		rjmp	boot_menu
; ### end of new firmware
;

boot_end:
		;time out - boot original application
		ldi	ZL,low(boot_banner2<<1)
		ldi	ZH,high(boot_banner2<<1)
		rcall	boot_print
		
		rjmp	reset		;end of bootloader


;
; ########## subroutines ###########
; #

;
; send chars stored in flash to UART
boot_print:
		lpm	temp,Z+
		tst	temp
		breq	boot_print1
		rcall	boot_tx_char
		rjmp	boot_print
boot_print1:
		ret
;


;
; transmit char from temp to UART
boot_tx_char:
		sbis	UCSRA,UDRE	;wait for empty buffer
		rjmp	boot_tx_char
		out	UDR,temp
		ret
;


;
; # wait for char (about 1s timeout)
boot_rx_char:
		push	temp2
		ldi	looplo,low(boot_rx_timeout)	;maximum time to wait
		ldi	loophi,high(boot_rx_timeout)
		clr	temp2			;second wait loop
boot_rx_char1:
		sbic	UCSRA,RXC		;skip if nothing to read	;2
		rjmp	boot_rx_char2
		
		dec	temp2			;end of small loop		;1
		brne	boot_rx_char1						;2/1 (5*256)
		
		sbiw	looplo,1		;end of main loop		;2
		brne	boot_rx_char1						;2
		
		sec				;set carry=1 : time out
		rjmp	boot_rx_char3
boot_rx_char2:
		in	temp,UDR
		clc				;clear carry, temp<-char received
boot_rx_char3:
		pop	temp2
		ret
;


;
; Make something with 128B of data in RAM
boot_block_process:
.ifdef use_crypt
		rcall	boot_decrypt
		
		ldi	YL,low(WRITE_BUF)	;prepare buffer address
		ldi	YH,high(WRITE_BUF)
.else
		ldi	YL,low(REC_BUF)
		ldi	YH,high(REC_BUF)
.endif
		ldi	temp,128		;how many bytes are to write
		
		rcall	boot_block_write

		ret
;


;
; # write blocks to flash
; - Z : flash address
; - Y : ram address
; - temp : number of bytes to write
boot_block_write:
		;page erase
		ldi	spmcrval,(1<<PGERS)+(1<<SPMEN)
		rcall	boot_spm
		
		;reenable RWW section
		ldi	spmcrval,(1<<RWWSRE)+(1<<SPMEN)
		rcall	boot_spm
		
		;transfer data from RAM to FLASH buffer
		ldi	looplo,PAGESIZE	;number of WORDS in page to write
boot_block_write1:
		ld	r0,Y+
		ld	r1,Y+
		ldi	spmcrval,(1<<SPMEN)
		rcall	boot_spm
		adiw	ZL,2
		subi	temp,2
		dec	looplo
		brne	boot_block_write1
		
		;write page from buffer to FLASH
		subi	ZL,(PAGESIZE<<1)		;step back
		sbci	ZH,0
		ldi	spmcrval,(1<<PGWRT)+(1<<SPMEN)	;write page
		rcall	boot_spm
		ldi	spmcrval,(PAGESIZE<<1)
		add	ZL,spmcrval	;restore Z
		ldi	spmcrval,0	;temporary
		adc	ZH,spmcrval	;for adding only carry
		
		;reenable RWW section
		ldi	spmcrval,(1<<RWWSRE)+(1<<SPMEN)
		rcall	boot_spm
		
		tst	temp		;all bytes saved?
		brne	boot_block_write
		ret
;
		

;
; # make real spm
boot_spm:
		in	temp2,SPMCR	;wait for previous spm complete
		sbrc	temp2,SPMEN
		rjmp	boot_spm
		
		out	SPMCR,spmcrval
		spm
		ret
;

;
; # decrypt
boot_decrypt:
		ldi	YL,low(WRITE_BUF)	;destination buffer
		ldi	YH,high(WRITE_BUF)
		ldi	XL,low(REC_BUF)		;source buffer
		ldi	XH,high(REC_BUF)	;it's 0...
		ldi	temp2,128		;bytes count
		ldi	spmcrval,poczatek	;seed for xor
boot_decrypt1:
		;calculate new address
		subi	XL,-mieszacz		;add XL,mieszacz!
		andi	XL,0x7F			;modulo 128
		ld	temp,X			;get byte
		eor	spmcrval,temp		;decrypt xor
		st	Y+,spmcrval		;store decrypted information
		
		mov	spmcrval,temp		;new seed (last value)
		swap	spmcrval
		
		dec	temp2
		brne	boot_decrypt1
		
		ret
;


	
;
; ########## static data ###########
; #		
boot_banner1:
		.db	"Bootloader v.1.3 (C) Marek Wodzinski",13,10
		.db	"Press B for options or wait 2s for normal boot.",13,10,0
boot_banner2:
		.db	"timed out... booting...",13,10,0
boot_banner3:
		.db	"Press P for firmware update (XMODEM) or any other key to continue booting",13,10,0
