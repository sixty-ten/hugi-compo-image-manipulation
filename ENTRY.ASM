;
; Hugi Size Coding Compo 15 - BMP viewer/modifier
; October 2001
;
; See H15RULES.TXT for a description of the competition rules
; and how the program functions.
;
; Written in i586 assembly language
;
;--------------------------------------
;
; 170 bytes
;


BMP_FILESIZE	equ 17462
HEADER_SIZE	equ 1078
IMAGE_SIZE	equ 16384

bmpbuffer	equ 03C8h
imgbuffer	equ bmpbuffer+BMP_FILESIZE


org 256


	push	word 0082h		; ptr -> command params

	mov	ax, 3D20h		; ah = open / al = space
	mov	bx, 3F13h		; bh = read / bl = mode 13h

	jmp	short @@starting

introOutro:				; when exiting...

	mov	ax, 3C0Dh		; ah = create / al = carriage return
	mov	bx, 4003h		; bh = write / bl = mode 03h

@@starting:
	pop	di			; di -> first/second filename

	dec	cx			; cx = 00FEh/FFFFh
	mov	dx, di			; start of filename
	
	repnz	scasb			; scan for space/0Dh
	mov	byte [di-1], 00h	; mark the end

	repz	scasb			; skip whitespace
	dec	di

	mov	cl, 20h			; set file access flags
	int 	21h			; open/create file
	xchg	ax, bx			; bx = filehandle, ax = read/write

	push	ax			; grr read/write trashes ax

	mov	cx, BMP_FILESIZE
	mov	dx, 03C8h		; bmpbuffer = palette port
	int	21h			; read/write file

	pop	ax

	cbw				; set video mode
	int	10h	

	sub	al, 13h			; also sets al to 0
	jz	short @@dontQuit
	ret				; end prog
@@dontQuit:

	push 	di			; save parameter pointer

	out 	dx, al
	inc	dx

setPal:
	mov	cx, 12			; write 12 values
@@set12:	
	out	dx, al
	loop	@@set12

	inc	ax			; overflows dont seem to matter
	jnz	short setPal

mainLoop:

	mov	si, bmpbuffer+HEADER_SIZE
	mov	di, (320*(36+127))+96	; img/screen offsets

	push 	es			; store program seg

	push	word 0A000h		; set correct seg
	pop	es

	mov	dx, 128			; copy img -> screen
copyLoop:
	mov	cl, 128
	rep	movsb
	sub	di, 320+128
	dec	dx
	jnz	short copyLoop

	pop	es			; restore program seg

        mov     ah, 08h
	int     21h			; get stdin

        sub	al, '0'	
	js 	short introOutro

	mov	bx, transforms		; load transform data
	xlatb

	mov	di, imgbuffer		; write to tmp buffer
	push	di

drawLoop:
	or	dx, 08080h		; to make sure the loop works properly	

	mov	bx, dx

	push	ax			; preserve transform data

@@1:
	cbw
	xor	bl, ah
	shl	al, 2
	jnc	@@noXchg
	xchg	bl, bh
@@noXchg:
	cbw
	shl	ax, 2
	add	bl, ah

	test	al, al
	jnz	@@1

	shl	bx, 1			; same as (but 1 byte smaller):
	shr	bh, 1			; and bh, 127
	shr	bx, 1			; shl bl, 1 / shr bx, 1

	lea	si, [bx+bmpbuffer+HEADER_SIZE]
	movsb				; move image -> temp buf

	pop	ax

	inc	dx			; loop 128*128 times
	jnz	short drawLoop

	pop	si
	mov	di, bmpbuffer+HEADER_SIZE
	mov	cx, IMAGE_SIZE
	rep	movsb			; move tmp buffer -> img

	jmp	short mainLoop

;--------------------------------------

; data
;
;  7    6    5    4    3    2    1    0
;  ^    ^    ^^^^^^    ^    ^    ^^^^^^
;  !x !xchg    v       !y   1      h   
;

transforms	db	01001100b	; y flip
		db	11001100b	; rotate 180
		db	01010100b	; move down
		db	01001000b	; rotate 90
		db	01000101b	; move left
		db	11000100b	; x flip
		db	01000111b	; move right
		db	11001100b	; rotate -180
		db	01110100b	; move up
		db	00001100b	; rotate -90	

			; 10 bytes


; eof
