; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/display.asm,v 1.8 2003/11/08 14:51:15 bitglue Exp $
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

%assign DEFAULT_SCROLL_SPEED	1

%assign MISC_OUTPUT         0x03c2    ; VGA misc. output register
%assign SC_INDEX            0x03c4    ; VGA sequence controller
%assign SC_DATA             0x03c5
%assign PALETTE_INDEX       0x03c8    ; VGA digital-to-analog converter
%assign PALETTE_DATA        0x03c9

%assign CRTC_INDEX		0x03d4	; VGA CRT controller
%define CRTC_START_ADDR_LOW	0x0d	;
%define CRTC_START_ADDR_HIGH	0x0c	;
%define CRTC_PRESET_ROW_SCAN	0x08

%assign MAP_MASK            0x02      ; Sequence controller registers
%assign MEMORY_MODE         0x04

%assign H_TOTAL			0x00      ; CRT controller registers
%assign H_DISPLAY_END		0x01
%assign H_BLANK_START		0x02
%assign H_BLANK_END		0x03
%assign H_RETRACE_START		0x04
%assign H_RETRACE_END		0x05
%assign V_TOTAL			0x06
%assign OVERFLOW		0x07
%assign MAX_SCAN_LINE		0x09
%assign HIGH_ADDRESS		0x0C
%assign LOW_ADDRESS		0x0D
%assign V_RETRACE_START		0x10
%assign V_RETRACE_END		0x11
%assign V_DISPLAY_END		0x12
%assign OFFSET			0x13
%assign UNDERLINE_LOCATION	0x14
%assign V_BLANK_START		0x15
%assign V_BLANK_END		0x16
%assign MODE_CONTROL		0x17


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



;---------------===============\              /===============---------------
;				global symbols
;---------------===============/              \===============---------------

global screen_pos
global print_string
global print_string_len
global print_hex
global print_hex_len
global print_char
global set_video_mode
global set_pcx_palette
global smooth_scroll_off
global smooth_scroll_on
global pcx_refresh
global display_buffer
global redraw_display
global wait_vtrace



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
;  cmp edi, CHAR_PER_COL * CHAR_PER_ROW * 2 + 0xa0 * 2
;  jae .scroll
.retn:
  mov [screen_pos], edi

  popad
  retn




;-----------------------------------------------------------------------.
						draw_cursor:		;

    mov ecx, [screen_pos]
    cmp ecx, CHAR_PER_ROW * CHAR_PER_COL * 2
    jae .retn
    shr ecx, 1
    mov dx, 0x03D4
    mov ax, 0x0000E
    mov ah, ch
    out dx, ax
    mov dx, 0x03D4
    mov ax, 0x0000F
    mov ah, cl
    out dx, ax

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
						pcx_refresh:		;
; returns all unmodified

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
  cmp eax, CHAR_PER_ROW * CHAR_PER_COL * 2
  xor edx, edx
  mov ebx, CHAR_PER_ROW * 2
  div ebx

  xor esi, esi
  add edx, byte -1	; set cf if edx is not 0
  adc esi, eax		; ESI = eax, or eax + 1 if there was a remainder

  sub esi, CHAR_PER_COL		; ESI = number of whole lines to scroll
  jbe short .done

%if FONT_HEIGHT != 16
  %error "FONT_HEIGHT assumed to be 16 here"
%endif
  lea ebp, [esi * 8]
  shl ebp, 1			; EBP = target scanline
  xor ebx, ebx			; EBX = current scanline

.jump_half:
  mov ecx, ebp
  sub ecx, ebx			; ECX = scanlines remaining
  shr ecx, 1
  adc ebx, ecx			; add the bigger half of the distance to ebx

  call .set_location

  cmp ebx, ebp
  jb .jump_half

%if CHAR_PER_ROW != 80
  %error "CHAR_PER_ROW assumed to be 80 here"
%endif
  shl esi, 5
  lea esi, [esi*5]

  sub [screen_pos], esi
  add esi, VIDEO_RAM
  mov edi, VIDEO_RAM

  xor ebx, ebx
  call .set_location
  mov ecx, CHAR_PER_ROW * CHAR_PER_COL / 2
  rep movsd

  mov eax, 0x07200720
  mov ecx, CHAR_PER_ROW * CHAR_PER_COL / 2
  rep stosd

.done:
  call draw_cursor
  popad
  retn


.set_location:
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

;.last_line:
;  mov ecx, FONT_HEIGHT / 4
;  mov edx, CRTC_INDEX
;  mov al, CRTC_PRESET_ROW_SCAN
;  xor ah, ah
;.by_2s:
;  add ah, 2
;  call wait_vtrace
;  out dx, ax
;  loop .by_2s
;
;  mov cl, FONT_HEIGHT / 2
;.by_1s:
;  inc ah
;  call wait_vtrace
;  out dx, ax
;  loop .by_1s
;
;  lea esi, [ebx*4+VIDEO_RAM+CHAR_PER_ROW*2]
;  mov edi, VIDEO_RAM
;  mov ecx, CHAR_PER_ROW * CHAR_PER_COL / 2
;
;  mov ebx, esi
;  sub ebx, edi
;  sub [screen_pos], ebx
;
;  call wait_vtrace
;  xor ah, ah
;  out dx, ax	; start again at 0
;  xor ebx, ebx
;  call .set_start_addr_no_wait
;  rep movsd
;
;.done:
;  call draw_cursor
;  retn
;
;
;
;.set_start_addr:
;  call wait_vtrace
;.set_start_addr_no_wait:
;xor ebx, ebx
;  mov edx, 0x3d4
;
;  mov al, 0xc ;CRTC_START_ADDR_HIGH
;  mov ah, bh
;  out dx, ax
;
;  mov al, 0xd ;CRTC_START_ADDR_LOW
;  mov ah, bl
;  out dx, ax
;
;  retn


;.scroll:					;-----------------------------
;  mov dx, 03D4h	;The VGA sequencer port
;  mov ax, 0x08	;Index 8 - set starting scan line
;.inc_scanline:
;  add ah, 2
;  call wait_vtrace
;  out dx, ax
;  cmp ah, 16 * 2
;  jb .inc_scanline
;
;  mov esi, VIDEO_RAM + CHAR_PER_ROW * 2
;  mov edi, VIDEO_RAM
;  mov ecx, CHAR_PER_ROW * (CHAR_PER_COL - 1) / 2
;
;  call wait_vtrace
;  xor ah, ah
;  out dx, ax	; start again at 0
;  rep movsd
;
;  push edi
;
;  mov eax, 0x07200720
;  mov ecx, CHAR_PER_ROW / 2
;  rep stosd
;
;  pop edi
;  mov edi, CHAR_PER_ROW * (CHAR_PER_COL - 1) * 2
;  jmp .retn
;
;
;-----------------------------------------------------------------------.
						smooth_scroll_on:	;

  retn

 

;-----------------------------------------------------------------------.
						smooth_scroll_off:	;

  retn



;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

align 4

screen_pos: resd 1
