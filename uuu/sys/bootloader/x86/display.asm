; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/display.asm,v 1.14 2003/12/25 01:38:26 bitglue Exp $
;---------------------------------------------------------------------------==|
; graphical console for the stage2 bootloader
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	Initial version



;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

%include "stage2-config.asm"

%define CRTC_INDEX		0x03d4	; VGA CRT controller
%define CRTC_PRESET_ROW_SCAN	0x08	;
%define CRTC_START_ADDR_HIGH	0x0c	;
%define CRTC_START_ADDR_LOW	0x0d	;
%define CRTC_CURSOR_LOCATION_HIGH	0x0e
%define CRTC_CURSOR_LOCATION_LOW	0x0f



;---------------===============\              /===============---------------
;				global symbols
;---------------===============/              \===============---------------

global screen_pos
global cur_scanline
global print_string
global print_string_len
global print_hex
global print_hex_len
global print_char
global redraw_display
global wait_vtrace
global set_display_start
global print_nul_string



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;=============================================================================
								print_hex:
;						------------------------------
; prints a nuber in hex
; edx = number to print
; bl = vga color
;
; destroys bh, eax

  mov bh, 8
.do_char:
  rol edx, 4
  mov al, dl
  and al, 0x0f

  cmp al, 0xa
  sbb al, 0x69
  das
  call print_char

  dec bh
  jnz .do_char

  retn



;=============================================================================
								print_hex_len:
;						------------------------------
; prints a given number of digits in hex
; bh = number of digits to print
; edx = number to print
; bl = vga color
;
; destroys bh, eax

  push ecx
  mov cl, 8
  sub cl, bh
  shl cl, 2
  rol edx, cl
  pop ecx
  jmp print_hex.do_char



;-----------------------------------------------------------------------.
						print_char:		;
; prints a single character
;
; eax = char to print
; bl = color

  pushad
  mov edi, [screen_pos]				;
.write:

  cmp eax, byte 0x0a			; test for NL
  jz .nl				;
  cmp eax, byte 0x0d			; test for CR too
  jz .nl				;
  cmp eax, byte 0x08			; test for BS
  jz .bs

  mov ah, bl
  mov [VIDEO_RAM + edi], ax
  add edi, byte 2
  jmp .done



.nl:			;------------------------------------------------------
  mov eax, edi
  mov ebx, CHAR_PER_ROW * 2
  cdq
  div ebx		;
  sub edi, edx		; move cursor to left edge
  add edi, CHAR_PER_ROW * 2

  push edi
  add edi, VIDEO_RAM
  mov ecx, CHAR_PER_ROW / 2
  mov eax, 0x07200720
  rep stosd
  pop edi

  jmp .done

.bs:			;------------------------------------------------------
  test edi, edi
  jz .done		; backspace only works on the monitor!

  sub edi, byte 2
  mov al, ' '
  mov ah, bl
  mov [VIDEO_RAM + edi], ax
  ; spill to .done

.done:
  mov [screen_pos], edi

  popad
  retn




;-----------------------------------------------------------------------.
						draw_cursor:		;

  mov ecx, [screen_pos]
  shr ecx, 1
  mov dx, CRTC_INDEX
  mov al, CRTC_CURSOR_LOCATION_HIGH
  mov ah, ch
  out dx, ax
  mov al, CRTC_CURSOR_LOCATION_LOW
  mov ah, cl
  out dx, ax

.retn:
  retn



;-----------------------------------------------------------------------.
						print_nul_string:	;
; prints a boring ascii nul terminated string
;
; ESI = ptr to string
; BL = VGA color
;
; destroys EAX, ESI

  movzx eax, byte[esi]
  test eax, eax
  jz .retn
.do_byte:
  call print_char
  inc esi
  movzx eax, byte[esi]
  test eax, eax
  jnz .do_byte
.retn:
  retn

  

;-----------------------------------------------------------------------.
						print_string_len:	;
; prints a string with a given length
;
; ECX = length
; ESI = ptr to string
; BL = VGA color

  pushad
  jmp print_string.char



;-----------------------------------------------------------------------.
						print_string:		;
; prints a string
;
; esi = ptr to single nul terminated string
; bl = vga textmode text attributes
						;
  pushad					;
						;
  mov ecx, [esi]
  add esi, byte 4
  inc ecx
  jmp .begin

.char:
  lodsd
  call print_char

.begin:
  dec ecx
  jnz .char

  popad
  retn



;-----------------------------------------------------------------------.
						wait_vtrace:		;
  pushad

  mov dx, 0x3da		;
.wait:			;
  in al, dx		;
  and al, 0x8		;
  jnz .wait		;
.waitmore:		;
  in al, dx		;
  and al, 0x8		;
  jz .waitmore		;

  popad
  retn



;-----------------------------------------------------------------------.
						redraw_display:		;
  pushad

  call draw_cursor

  mov eax, [screen_pos]
;  cmp eax, CHAR_PER_ROW * CHAR_PER_COL * 2
  xor edx, edx
  mov ebx, CHAR_PER_ROW * 2
  div ebx

  xor esi, esi
  add edx, byte -1	; set cf if edx is not 0
  adc esi, eax		; ESI = eax, or eax + 1 if there was a remainder
;  mov esi, eax
;  test edx, edx
;  jz .no_remainder
;  inc esi
;.no_remainder:

  mov ebx, [cur_scanline]	; EBX = current scanline

  mov eax, ebx
%if FONT_HEIGHT != 16
  %error "FONT_HEIGHT assumed to be 16 here"
%endif
  shr eax, 4
  sub esi, eax
  sub esi, CHAR_PER_COL		; ESI = number of whole lines to scroll
  jbe short .done

  push edi
  mov edi, [screen_pos]
  add edi, VIDEO_RAM
  mov ecx, CHAR_PER_ROW / 2
  mov eax, 0x07200720
  rep stosd
  pop edi

%if FONT_HEIGHT != 16
  %error "FONT_HEIGHT assumed to be 16 here"
%endif
  lea ebp, [esi * 8]
  shl ebp, 1			; EBP = target scanline
  add ebp, ebx

.jump_half:
  mov ecx, ebp
  sub ecx, ebx			; ECX = scanlines remaining
  shr ecx, 1
  adc ebx, ecx			; add the bigger half of the distance to ebx

  call set_display_start

  cmp ebx, ebp
  jb short .jump_half

  cmp esi, CHAR_PER_COL
  jb short .no_shift

%if CHAR_PER_ROW != 80
  %error "CHAR_PER_ROW assumed to be 80 here"
%endif
  shl esi, 5
  lea esi, [esi*5]

  sub [screen_pos], esi
  add esi, VIDEO_RAM
  mov edi, VIDEO_RAM

  mov ecx, CHAR_PER_ROW * CHAR_PER_COL / 2
  rep movsd

  xor ebx, ebx
  call set_display_start

.no_shift:
  mov [cur_scanline], ebx

.done:
  call draw_cursor
  popad
  retn



;-----------------------------------------------------------------------.
						set_display_start:	;
  ; ebx = scanline offset
  mov dx, CRTC_INDEX

%if CHAR_PER_ROW != 80
  %error "CHAR_PER_ROW assumed to be 80 here"
%endif
  mov ecx, ebx
  shr ecx, 4		; ECX = number of whole lines
  shl ecx, 4
  lea ecx, [ecx*5]

  mov al, CRTC_START_ADDR_LOW
  mov ah, cl
  call wait_vtrace
  out dx, ax

  mov al, CRTC_START_ADDR_HIGH
  mov ah, ch
  out dx, ax

  mov al, CRTC_PRESET_ROW_SCAN
  mov ah, bl
  and ah, 0x0f
  out dx, ax
  retn



;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

align 4

screen_pos: resd 1
cur_scanline: resd 1
