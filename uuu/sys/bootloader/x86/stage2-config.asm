; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage2-config.asm,v 1.3 2003/11/01 00:46:37 bitglue Exp $

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

%ifnidn BOOT_CONSOLE,textual
  %define BOOT_CONSOLE graphical
%endif


%ifidn BOOT_CONSOLE,graphical
  %assign FONT_HEIGHT	8
  %assign FONT_WIDTH	5
  %assign FONT_START	' ' ; first letter in the font
  %assign FONT_END	'~' ; last letter in the font
  %assign LETTER_PADDING	1   ; blank pixels between letters
  %assign LINE_PADDING	0   ; blank pixels between lines

  %assign CELL_WIDTH	(FONT_WIDTH + LETTER_PADDING)
  %assign CELL_HEIGHT	(FONT_HEIGHT + LINE_PADDING)
  %assign CHAR_PER_COL	(SCREEN_HEIGHT / CELL_HEIGHT)
  %assign CHAR_PER_ROW	(SCREEN_WIDTH / CELL_WIDTH)

  %assign CURSOR_HEIGHT	2
  %assign CURSOR_HEADROOM	(FONT_HEIGHT-CURSOR_HEIGHT)
  %assign CURSOR_COLOR	0xff

  %assign PLANE_SIZE	(SCREEN_HEIGHT * SCREEN_WIDTH / 4)	; bytes per plane
%elifidn BOOT_CONSOLE,textual
  %assign CHAR_PER_COL	25
  %assign CHAR_PER_ROW	80
%endif

%ifidn BOOT_CONSOLE,graphical
  %assign VIDEO_RAM	0xa0000
%elifidn BOOT_CONSOLE,textual
  %assign VIDEO_RAM	0xb8000
%endif


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
.magic               resd 1
.flags               resd 1
.checksum            resd 1
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
