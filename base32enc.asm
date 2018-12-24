;  Executable name : base32enc
;  Version         : 1.0
;  Created date    : 24.10.2018
;  Last update     : 19.12.2018
;  Author          : Simon Barben
;  Description     : This program converts a binary input to a base32 output
;
;  Build using these commands:
;    nasm -f elf64 -g base32enc.asm
;    ld -o base32enc base32enc.o

section .bss												; Section containing uninitialized data
	bufferLen 				equ 	1					; Reading the file one byte at a time
	buffer: 					resb 	bufferLen

section .data												; Section containing initialised data
	stdin							equ 	0
	stdout						equ 	1
	sys_read					equ 	3
	sys_write					equ 	4

	digits: 					db 		"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

	outputTemplate:		db 		"========"
 	outputLen 				equ 	$-outputTemplate


section .text
  global _start	   									; Linker needs this to find the entry point!

_start:
	nop			       									  ; This no-op keeps gdb happy...
	call 	initRegisters
	call 	convertInput

; Init the registers before converting input.
initRegisters:
	xor 	r8,			r8									; Number of remaining bits
	xor 	r9,			r9									; Iterator für die Anzahl verarbeiteten Bytes
	xor 	r12,		r12									; Position at which to write in outputTemplate
	xor		r14,		r14									; Remaining bits from previous conversion
	ret

convertInput:
	call 	read												; Read one byte at a time
	call 	handleInput									; Depending on number of rest bits, let a different handler do the converting
	cmp		r12,		8										; If the outputTemplate is filled with characters (8 iterations)...
	je		intermediateWrite						; ...write the outputTemplate
	jmp 	convertInput								; Continue converting

; Reads one byte from standard input
read:
; Back up registers
	push 	r8
	push 	r9
	push 	r12
	push 	r14

	mov 	eax, 		sys_read						; Specify sys_read call
	mov 	ebx, 		stdin								; Standard input
	mov 	ecx, 		buffer							; Pass offset of the buffer to read to
	mov 	edx,		bufferLen						; Pass number of bytes to read at one pass
	int 	80h													;	syscall

; recover registers
	pop r14
	pop r12
	pop r9
	pop r8

	cmp 	eax,		0										; If end of input is reached, go to done
	je		done

	mov 	rbx,		qword [buffer]
	ret

; Depending on the number of bits left, jump to a different handler
handleInput:
	cmp 	r8,			0
	je		handleRestZero
	cmp 	r8,			1
	je 		handleRestOne
	cmp 	r8,			2
	je 		handleRestTwo
	cmp 	r8,			3
	je		handleRestThree
	cmp 	r8,			4
	je 		handleRestFour

; Handle case: 0 rest bits
handleRestZero:
	mov 	r14,		rbx
	mov 	r15,		r14
	shr		r15,		3
	and		r14,		07h

	mov 	al, 		byte[digits+r15]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	mov 	r8,		3
	inc 	r9
	ret

; Handle case: 1 rest bit
handleRestOne:
	shl		r14,		8
	or	 	r14,		rbx
	mov 	r15,		r14
	shr		r15,		4
	and		r14,		0Fh

	mov 	al, 		byte[digits+r15]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	mov 	r8,			4
	inc 	r9
	ret

; Handle case: 2 rest bits
handleRestTwo:
	shl		r14,		8
	or	 	r14,		rbx
	mov 	r15,		r14
	shr		r15,		5
	and		r14,		1Fh

	mov 	al, 		byte[digits+r15]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	mov 	al, 		byte[digits+r14]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	xor		r14,		r14
	mov 	r8,			0
	inc 	r9
	ret

; Handle case: 3 rest bits
handleRestThree:
	shl		r14,		8
	or	 	r14,		rbx
	mov 	r15,		r14
	shr		r15,		6
	and		r14,		3Fh

	mov 	al, 		byte[digits+r15]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	mov 	r15,		r14
	shr		r15,		1
	and		r14,		01h

	mov 	al, 		byte[digits+r15]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	mov 	r8,			1
	inc 	r9
	ret

; Handle case: 4 rest bits
handleRestFour:
	shl		r14,		8
	or	 	r14,		rbx
	mov 	r15,		r14
	shr		r15,		7
	and		r14,		7Fh

	mov 	al, 		byte[digits+r15]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	mov 	r15,		r14
	shr		r15,		2
	and		r14,		03h

	mov 	al, 		byte[digits+r15]
	mov 	byte[outputTemplate+r12], al; Save digit in outputTemplate
	add 	r12,		1										; Set write position for outputTemplate to next digit

	mov 	r8,		2
	inc 	r9
	ret

; Writes outputTemplate to console
write:
	push 	r8
	push 	r9
	push 	r14

	mov 	eax,		sys_write						; Specify sys_write call
	mov 	ebx,		stdout							; Standard output
	mov 	ecx,		outputTemplate			; Pass offset of outputTemplate string
	mov 	edx,		outputLen						; Pass size of the outputTemplate string
	int 	80h													; Make kernel call to display outputTemplate string

	pop r14
	pop r9
	pop r8
	xor		r12,		r12									; Reset position counter

	mov 	rax,		8
	jmp 	resetOutputTemplate

; Resets the outputTemplate to "========" in order to prepare it for next output part
resetOutputTemplate:
	dec 	rax
	mov 	byte[outputTemplate+rax], 3Dh
	cmp 	rax, 		0
	jne 	resetOutputTemplate
	mov 	byte[outputTemplate+rax], 3Dh
	ret

; Call this to write but continue with converting
intermediateWrite:
	call 	write
	jmp 	convertInput

; Depending on the bits left, shift a different amount
finalHandleInput:
	cmp 	r8,			0
	je 		shiftZero
	cmp 	r8,			1
	je 		shiftFour
	cmp 	r8,			2
	je 		shiftThree
	cmp 	r8,			3
	je		shiftTwo
	cmp 	r8,			4
	je 		shiftOne

shiftZero:
	mov 	eax,		1										; Code for Exit Syscall
	mov 	ebx,		0										; Return a code of zero
	int 	80h													; Make kernel call
shiftOne:
	shl		r14,		1
	ret
shiftTwo:
	shl		r14,		2
	ret
shiftThree:
	shl		r14,		3
	ret
shiftFour:
	shl		r14,		4
	ret

done:
	call 	finalHandleInput

	mov 	al, 		byte[digits+r14]
	mov 	byte[outputTemplate+r12], al	;Save digit in outputTemplate

	call	write
	mov 	eax,		1											; Code for Exit Syscall
	mov 	ebx,		0											; Return a code of zero
	int 	80h														; Make kernel call
