; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage2-config.asm,v 1.5 2003/11/18 18:35:18 bitglue Exp $

%ifndef __STAGE2_CONFIG__
%define __STAGE2_CONFIG__



;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

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

%assign FONT_HEIGHT	16
%assign CHAR_PER_COL	25
%assign CHAR_PER_ROW	80

%assign VIDEO_RAM	0xb8000


;-----------------------------------------------------------------------.
;							multiboot stuffs;

; in EAX if loaded from multiboot loader
%define MULTIBOOTED	0x2BADB002


; magic number that goes in the header
%define MBOOT_HDR_MAGIC	0x1BADB002

; possible flags...
%define MBOOT_HDR_MODULE_ALIGN	1	; align modules on page boundries
%define MBOOT_HDR_MEMINFO	2	; ask for memory information
%define MBOOT_HDR_NOT_ELF	0x1000	; don't use this; we use ELF ;)

; ...and the flags we actually want
%define MBOOT_HDR_FLAGS		MBOOT_HDR_MEMINFO

struc mboot_hdr
  .magic:	resd 1
  .flags:	resd 1
  .checksum:	resd 1
endstruc


struc mboot_info
  .flags:	resd 1
  .mem_lower:	resd 1
  .mem_upper:	resd 1
  .boot_device:	resd 1
  .cmdline:	resd 1
  .mods_count:	resd 1
  .mods_addr:	resd 1
  .syms:	resd 4
  .mmap_length:	resd 1
  .mmap_addr:	resd 1
endstruc


%define MBOOT_INFO_MEM		(1 << 0)
%define MBOOT_INFO_BOOT_DEVICE	(1 << 1)
%define MBOOT_INFO_CMDLINE	(1 << 2)
%define MBOOT_INFO_MODULES	(1 << 3)
%define MBOOT_INFO_AOUT_SYMS	(1 << 4)
%define MBOOT_INFO_ELF_SYMS	(1 << 5)
%define MBOOT_INFO_MMAP		(1 << 6)


struc mboot_module
  .mod_start:	resd 1
  .mod_end:	resd 1
  .string:	resd 1
  .reserved:	resd 1
endstruc

struc mboot_mmap
  .base_low:	resd 1
  .base_high:	resd 1
  .length_low:	resd 1
  .length_high:	resd 1
  .type:	resd 1
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



%endif ; %ifdef __STAGE2_CONFIG__
