; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage2.asm,v 1.3 2003/10/14 22:21:49 bitglue Exp $
;---------------------------------------------------------------------------==|
; stage2 bootloader for Unununium
; central file
;
; most functionality is included in the other *.asm files included in this
; directory.
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	Initial version

bits 32
org 0x100000



;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

; arbitrary number used to detect if we are restarting from a reboot or from
; scratch

%define INIT_MAGIC	0x1fe81f8c

; 				colors
;------------------------------------------------------

%assign VGA_BLACK	0x00
%assign VGA_BLUE	0x01
%assign VGA_GREEN	0x02
%assign VGA_CYAN	0x03
%assign VGA_RED		0x04
%assign VGA_PURPLE	0x05
%assign VGA_ORANGE	0x06
%assign VGA_WHITE	0x07
%assign VGA_YELLOW	0x0E


; 				screen
;------------------------------------------------------

; width can be 320 or 360. 320 is the default width of mode 13h, and thus
; is supported by almost everything. 360 looks better and should still be
; supported by everything.
%assign SCREEN_WIDTH	360

; height for now must be 240. 200 is possible if new background images are
; added. 400 and 480 are possible with new background images and tweaking
; to the page flipping. However, they yield squished pixels that look bad
; with the current font and make things considerably slower.
%assign SCREEN_HEIGHT	240


; 				eyecandy
;------------------------------------------------------

struc pcx_header
  .manufacturer:	resb 1
  .version:		resb 1
  .encoding:		resb 1
  .bpp:			resb 1
  .xmin:		resw 1
  .ymin:		resw 1
  .xmax:		resw 1
  .ymax:		resw 1
  .otherstuff:		resb 116	; bleh bleh
endstruc



;---------------===============\      /===============---------------
;				macros
;---------------===============/      \===============---------------

%macro printstr 1+
  [section .data]
  align 4, db 0
  %%a: uuustring %1
  __SECT__
  mov esi, %%a
  call print_string
%endmacro


%macro go_panic 1+
  [section .data]
  align 4, db 0
  %%a: uuustring %1
  __SECT__
  mov ecx, %%a
  jmp panic
%endmacro



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------
					;
					; Setup permanent GDT
start:					;--------------------
  mov edi, 0x30 * 8 + 8			; set address of GDT
  mov esi, _gdt				; set ptr to data
  mov ecx, 4				; number of dwords
  rep movsd				; move 'em
  lgdt [_gdtr]				; reload gdt
					;

  call set_pcx_palette
  call set_video_mode

  cmp [init_magic], dword INIT_MAGIC
  jz get_to_business

  call builtin_clear
  mov [init_magic], dword INIT_MAGIC


					; enough play; let's start to boot
get_to_business:			;---------------------------------

  mov bl, VGA_YELLOW
  printstr "Unununium stage 2 bootloader version $Revision: 1.3 $",0x0a
  mov bl, VGA_WHITE
  printstr "run ",0x27,"help",0x27," for a list of available commands.",0xa
  jmp start_prompt			;



;-----------------------------------------------------------------------.
								panic:	;
			; this is never used... ;-)
  mov bl, VGA_RED	;
  printstr "PANIC: "	;
  mov esi, ecx		;
  call print_string	;
  cli			;
  jmp $			;



;---------------===============\             /===============---------------
;				subcomponents
;---------------===============/             \===============---------------

%include "display.asm"
%include "command.asm"
%include "keyboard.asm"
%include "floppy.asm"
%include "ata.asm"



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

_gdtr:
  dd 0x00000000 + 0x30 * 8
  dw 3 * 8 - 1

align 4

_gdt:
  dd 0x009BCF00
  dd 0xFFFF0000
  dd 0x0093CF00
  dd 0xFFFF0000



;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

; WARNING: the .bss section is not set to zero

alignb 4

; set to INIT_MAGIC so we can tell if we are restarting from scratch or from
; a reboot

init_magic: resd 1

; buffer for the command line
command_buffer:		; as long as this is last, it can be as big as we like
