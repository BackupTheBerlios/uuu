#include "dietfeatures.h"
#include "PIC.h"

.text
.global _start
_start:
	pushl	argv
	pushl	$0
	call	main

	pushl	%eax
	call	exit
	hlt	/* die now ! will ya ... */
.Lstart:
	.size	 _start,.Lstart-_start

.section .data
argv:
	.long name
	.long 0

name:
	.string "uuu"
