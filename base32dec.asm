;  Executable name : base32dec
;  Version         : 1.0
;  Created date    : 24.10.2018
;  Last update     : 19.12.2018
;  Author          : Simon Barben
;  Description     : This program decodes a base32 input to a binary output
;
;  Build using these commands:
;    nasm -f elf64 -g base32dec.asm
;    ld -o base32dec base32dec.o
;

section .bss
	bufferLen 				equ 	1					; Reading the file one byte at a time
	buffer: 					resb 	bufferLen

	outputLen 				equ 	5
	outputStr:				resb 	outputLen

section .data												; Section containing initialised data
	stdin							equ 	0
	stdout						equ 	1
	sys_read					equ 	3
	sys_write					equ 	4

	outputDigits			db 		00h,01h,02h,03h,04h,05h,06h,07h,08h,09h,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h,18h,19h,1Ah,1Bh,1Ch,1Dh,1Eh,1Fh,00h
	inputDigits				db 		41h,42h,43h,44h,45h,46h,47h,48h,49h,4Ah,4Bh,4Ch,4Dh,4Eh,4Fh,50h,51h,52h,53h,54h,55h,56h,57h,58h,59h,5Ah,32h,33h,34h,35h,36h,37h,3Dh

	errorStr:					db 		"invalid input"
	errorLen 					EQU 	$-errorStr

section .text
  global _start	   									; Linker needs this to find the entry point!

_start:
	nop			       										; This no-op keeps gdb happy...
	call 	initRegisters
	call 	convertInput

; Init the registers before converting input.
initRegisters:
	xor		r12,		r12
	xor		r13,		r13
	xor		r14,		r14
	ret

convertInput:
	call 	read
	xor 	r14, 		r14
	jmp 	convertDigit

read:
; Back up registers
	push 	r14
	push 	r13
	push 	r12

	mov 	eax, 		sys_read						; Specify sys_read call
	mov 	ebx, 		stdin								; Standard input
	mov 	ecx, 		buffer							; Pass offset of the buffer to read to
	mov 	edx,		bufferLen						; Pass number of bytes to read at one pass
	int 	80h													;	syscall

; recover registers
	pop 	r12
	pop 	r13
	pop 	r14
	mov 	bl,			byte [buffer]

	cmp 	eax,		0										; If end of input is reached, go to done
	je		done
	cmp 	bl, 		0Ah
	je 		read

	ret

write:
	push 	r14

	xor 	r14,		r14
	xor 	r15,		r15
	mov  	r13,		0
	call 	swapOutput

	mov 	qword [outputStr],r14

	mov 	eax,		sys_write						; Specify sys_write call
	mov 	ebx,		stdout							; Standard output
	mov 	ecx,		outputStr						; Pass offset of line string
	mov 	edx,		outputLen						; Pass size of the line string
	int 	80h													; Make kernel call to display line string

	pop 	r14
	xor 	r13,		r13
	xor 	r12,		r12
	jmp  	convertInput

; Swap output into the right order
swapOutput:
	shl 	r14, 		8
	mov 	r15, 		r12

	and 	r15, 		0FFh
	or 		r14, 		r15
	shr 	r12, 		8

	inc 	r13
	cmp 	r13, 		5
	jne 	swapOutput
	ret

; Add digit to output
addToOutput:
	shl 	r12,		5
	mov 	bl,			byte [outputDigits + r14]
	and 	rbx, 		1Fh
	or		r12, 		rbx
	inc 	r13
	cmp 	r13, 		8
	je 		write
	jmp 	convertInput

; Find the equivalent of the input digit in the output digits
convertDigit:
	cmp 	bl, 		byte [inputDigits + r14]
	je 		addToOutput
	inc 	r14
	cmp 	r14, 		21h
	je 		printError
	jmp 	convertDigit

; If there is invalid input, write error message to console
printError:
	mov 	eax,		sys_write							; Specify sys_write call
	mov 	ebx,		stdout								; Standard output
	mov 	ecx,		errorStr							; Pass offset of error string
	mov 	edx,		errorLen							; Pass size of the error string
	int 	80h														; Make kernel call

	mov 	eax,		1											; Code for Exit Syscall
	mov 	ebx,		1											; Return a code of one
	int 	80h														; Make kernel call

done:
	cmp 	r13, 		0
	jne   printError
	mov 	eax,		1											; Code for Exit Syscall
	mov 	ebx,		0											; Return a code of zero
	int 	80h														; Make kernel call
