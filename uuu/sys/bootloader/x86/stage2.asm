; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage2.asm,v 1.6 2003/11/01 00:46:37 bitglue Exp $
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



;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

%include "stage2-config.asm"

; arbitrary number used to detect if we are restarting from a reboot or from
; scratch

%define INIT_MAGIC	0x1fe81f8c




;---------------===============\                /===============---------------
;				external symbols
;---------------===============/                \===============---------------

extern set_pcx_palette
extern set_video_mode
extern builtin_clear
extern start_prompt
extern print_string



;---------------===============\              /===============---------------
;				global symbols
;---------------===============/              \===============---------------

global panic



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------
					;
global _start				; Setup permanent GDT
_start:					;--------------------
  mov edi, 0x30 * 8 + 8			; set address of GDT
  mov esi, _gdt				; set ptr to data
  mov ecx, 4				; number of dwords
  rep movsd				; move 'em
  lgdt [_gdtr]				; reload gdt
					;

%ifidn BOOT_CONSOLE,graphical
  call set_pcx_palette
  call set_video_mode
%endif

  call builtin_clear


get_to_business:			;---------------------------------

  mov bl, VGA_YELLOW
  printstr "Unununium stage 2 bootloader version $Revision: 1.6 $",0x0a
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



;---------------===============\                 /===============---------------
				section multiboot	noalloc align=4
;---------------===============/                 \===============---------------

; the multiboot header -- this is placed at the start of the binary by the
; linker script

dd MBOOT_HDR_MAGIC
dd MBOOT_HDR_FLAGS
dd - MBOOT_HDR_MAGIC - MBOOT_HDR_FLAGS



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
