; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/display.asm,v 1.2 2003/10/03 19:41:45 bitglue Exp $
;---------------------------------------------------------------------------==|
; graphical console for the stage2 bootloader
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	Initial version

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

%define SCREEN_POS(x,y)	(SCREEN_WIDTH * SCREEN_HEIGHT - ( SCREEN_WIDTH * CELL_HEIGHT * (CHAR_PER_COL-y) ) + CELL_WIDTH * x )

%assign VIDEO_RAM	0xa0000

%assign DEFAULT_SCROLL_SPEED	1

%assign MISC_OUTPUT         0x03c2    ; VGA misc. output register
%assign SC_INDEX            0x03c4    ; VGA sequence controller
%assign SC_DATA             0x03c5
%assign PALETTE_INDEX       0x03c8    ; VGA digital-to-analog converter
%assign PALETTE_DATA        0x03c9
%assign CRTC_INDEX          0x03d4    ; VGA CRT controller

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



;=============================================================================
								print_char:
;						------------------------------
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

  sub al, FONT_START
  jb near .done				; if the font has not that letter, skip

  lea esi, [edi + FONT_WIDTH + LETTER_PADDING]
  mov [screen_pos], esi				;

%if FONT_HEIGHT != 8
  %error "print_char must be rewritten for font heights other than 8"
%endif
%if FONT_WIDTH != 5
  %error "print_char must be rewritten for font widths other than 5"
%endif

  movzx esi, al
  lea esi, [esi*FONT_WIDTH+font]		; ESI = ptr to char bitmap

  lodsd
  mov ch, 6
  call .do_magic

  ; at this point, we have done 30 bits. 2 remain in EAX, and 8
  ; are not yet loaded.

  movzx ecx, byte[esi]
  and eax, 0xc0000000
  shl ecx, 22
  or eax, ecx

  mov ch, 2
  call .do_magic

  sub edi, SCREEN_WIDTH * FONT_HEIGHT - CELL_WIDTH
  jmp .done

.nl:			;------------------------------------------------------
  mov eax, edi
  mov ebx, SCREEN_WIDTH
  cdq
  div ebx		;
  sub edi, edx		; move cursor to left edge
  add edi, (SCREEN_WIDTH * CELL_HEIGHT)

  jmp .done

.bs:			;------------------------------------------------------
  test edi, edi
  jz .done		; don't backspace past the top of the screen :P
  mov eax, edi
  mov ebx, SCREEN_WIDTH
  cdq
  div ebx		; determine if we are at the left edge
  test edx, edx		; if edx = 0, we are
  jnz .bs_no_boundry

  sub edi, SCREEN_WIDTH * ( FONT_HEIGHT + LINE_PADDING ) - (CELL_WIDTH * (CHAR_PER_ROW-1))
  jmp .bs_update_screen_pos

.bs_no_boundry:
  sub edi, byte FONT_WIDTH + LETTER_PADDING
.bs_update_screen_pos:
  push edi

  mov ch, FONT_HEIGHT
  xor eax, eax

.bs_zero_line:
  mov cl, FONT_WIDTH
.bs_zero_pixel:
  call calc_planar_offset
  mov [edx+display_buffer], al
  inc edi

  dec cl
  jnz .bs_zero_pixel

  add edi, SCREEN_WIDTH - FONT_WIDTH
  dec ch
  jnz .bs_zero_line

  pop edi
  ; spill to .done


.done:
  mov eax, edi
  mov ebx, SCREEN_WIDTH * CELL_HEIGHT
  cdq
  div ebx		; determine if we are at the left edge
  cmp edx, SCREEN_WIDTH - CELL_WIDTH
  jbe .not_at_edge

  sub edi, edx
  add edi, CELL_HEIGHT * SCREEN_WIDTH

.not_at_edge:
  cmp edi, SCREEN_WIDTH * SCREEN_HEIGHT
  jae .scroll
.retn:
  mov [screen_pos], edi

  popad
  retn



						; scroll everything one line
.scroll:					;-----------------------------

  mov ebx, SCREEN_WIDTH * CELL_HEIGHT / 4
  mov edx, SCREEN_WIDTH / 4
  xor eax, eax
  xor ebp, ebp
  db 0xc1, 0xe2, DEFAULT_SCROLL_SPEED	; shl edx, DEFAULT_SCROLL_SPEED
..@scroll_speed equ $-1
.refresh_line:
  mov edi, display_buffer
  lea esi, [edi+edx]
  mov ecx, PLANE_SIZE
  sub ecx, edx
  shr ecx, 2
  rep movsd
  mov ecx, edx
  shr ecx, 2
  rep stosd

  add esi, edx
  mov ecx, PLANE_SIZE
  sub ecx, edx
  shr ecx, 2
  rep movsd
  mov ecx, edx
  shr ecx, 2
  rep stosd

  add esi, edx
  mov ecx, PLANE_SIZE
  sub ecx, edx
  shr ecx, 2
  rep movsd
  mov ecx, edx
  shr ecx, 2
  rep stosd

  add esi, edx
  mov ecx, PLANE_SIZE
  sub ecx, edx
  shr ecx, 2
  rep movsd
  mov ecx, edx
  shr ecx, 2
  rep stosd

  jmp short ..@pre_smooth_scroll
..@pre_smooth_scroll:
..@smooth_scroll_jmp equ $-1
  call redraw_display
..@post_smooth_scroll:

  add ebp, edx
  cmp ebp, ebx
  jnz .refresh_line

  mov edi, SCREEN_WIDTH * (SCREEN_HEIGHT - CELL_HEIGHT)
  jmp .retn




.do_magic:
  ; ch = number of rows to do
  mov cl, FONT_WIDTH
.magic_draw_row
  rcl eax, 1
  jnc .next_col1
  call calc_planar_offset
  mov [edx+display_buffer], bl
.next_col1:
  inc edi
  dec cl
  jnz .magic_draw_row

  add edi, SCREEN_WIDTH - FONT_WIDTH
  dec ch
  jnz .do_magic
  retn




;-----------------------------------------------------------------------.
						draw_cursor:		;
  mov edi, [screen_pos]
  cmp edi, SCREEN_WIDTH * SCREEN_HEIGHT - (SCREEN_WIDTH * (CELL_HEIGHT-1) + CELL_WIDTH)
  jae .retn
%if CURSOR_HEIGHT != 0
%if CURSOR_HEADROOM != 0
  add edi, CURSOR_HEADROOM * SCREEN_WIDTH
%endif

  mov ch, CURSOR_HEIGHT
.draw_cursor:
  mov cl, CELL_WIDTH
.draw_cursor_line:
  call calc_planar_offset
  mov al, [edx+display_buffer]
  cmp al, 0x10
  jz .invert
  cmp al, CURSOR_COLOR
  jnz .skip
.invert:
  xor al, CURSOR_COLOR ^ 0x10
  mov [edx+display_buffer], al
.skip:
  inc edi

  dec cl
  jnz .draw_cursor_line

  add edi, SCREEN_WIDTH - CELL_WIDTH
  dec ch
  jnz .draw_cursor

%endif
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
						set_pcx_palette:	;
.set_up:
  lea esi, [pcx_end - 768]
  mov al, 16
  mov dx, 0x3c8
  mov ecx, (256 - 16) * 3
  out dx, al
  inc dx
.set_palette:
  lodsb
  shr al, 2
  out dx, al
  loop .set_palette
  retn



;-----------------------------------------------------------------------.
						pcx_refresh:		;
; returns all unmodified

  pushad

  mov edi, display_buffer
  mov ebp, display_buffer.end - 1
  mov esi, pcx + pcx_header_size
  xor ecx, ecx
.decode_pcx:
  inc ecx
  lodsb
  cmp al, 0xc0		; if top two bits are set, begin a run
  jb .single

  and al, 0x3f		; unset top two bits
  mov cl, al		; CL = count
  lodsb

.single:
  lea ebx, [eax+0x10]	; BL = color
.draw_pixel:
  mov al, bl
  mov ah, [edi]
  cmp ah, 0xf
  ja .no_change
  test ah, ah
  jz .no_change
  mov al, ah
.no_change:
  mov [edi], al

  cmp edi, ebp
  jz .done

  add edi, display_buffer.plane1 - display_buffer.plane0
  cmp edi, display_buffer.end
  jb .no_wrap

  sub edi, display_buffer.end - display_buffer.plane0 - 1

.no_wrap:

  loop .draw_pixel

.next_run:
  jmp .decode_pcx

.done:

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
						set_video_mode:		;
;
; sets whatever video mode is defined in the SCREEN_WIDTH/HEIGHT macros
;
; width can be 320 or 360
; height can be 200, 400, 240, or 480.
;
; returns: all destroyed

%macro word_out 2
  mov ax, (%2 << 8) + %1
  out dx, ax
%endmacro

  mov dx, SC_INDEX

  ; turn off chain-4 mode
  word_out MEMORY_MODE, 0x06

  ; set map mask to all 4 planes for screen clearing
  word_out MAP_MASK, 0xff

  ; clear all 256K of memory
  xor eax, eax
  mov edi, VIDEO_RAM
  mov ecx, 0x4000
  rep stosd

  mov dx, CRTC_INDEX

  ; turn off long mode
  word_out UNDERLINE_LOCATION, 0x00

  ; turn on byte mode
  word_out MODE_CONTROL, 0xe3


%if SCREEN_WIDTH = 360
    ; turn off write protect
    word_out V_RETRACE_END, 0x2c

    mov dx, MISC_OUTPUT
    mov al, 0xe7
    out dx, al
    mov dx, CRTC_INDEX

    word_out H_TOTAL, 0x6b
    word_out H_DISPLAY_END, 0x59
    word_out H_BLANK_START, 0x5a
    word_out H_BLANK_END, 0x8e
    word_out H_RETRACE_START, 0x5e
    word_out H_RETRACE_END, 0x8a
    word_out OFFSET, 0x2d

    ; set vertical retrace back to normal
    word_out V_RETRACE_END, 0x8e
%else
    mov dx, MISC_OUTPUT
    mov al, 0xe3
    out dx, al
    mov dx, CRTC_INDEX
%endif

%if SCREEN_HEIGHT=240 || SCREEN_HEIGHT=480
    ; turn off write protect
    word_out V_RETRACE_END, 0x2c

    word_out V_TOTAL, 0x0d
    word_out OVERFLOW, 0x3e
    word_out V_RETRACE_START, 0xea
    word_out V_RETRACE_END, 0xac
    word_out V_DISPLAY_END, 0xdf
    word_out V_BLANK_START, 0xe7
    word_out V_BLANK_END, 0x06
%endif

%if SCREEN_HEIGHT=400 || SCREEN_HEIGHT=480
    word_out MAX_SCAN_LINE, 0x40
%endif

  retn
  


;-----------------------------------------------------------------------.
						redraw_display:		;

  pushad

  call pcx_refresh
  call draw_cursor

  mov eax, VIDEO_RAM
  cmp eax, [last_page]
  jnz .use_page_0

  add eax, 0x8000

.use_page_0:
  mov [last_page], eax

  mov esi, display_buffer
  mov ax, 0x0100 + MAP_MASK		; AH = plane mask, AL = MAP_MASK
  mov edx, SC_INDEX
  mov bl, 4
.draw_plane:
  out dx, ax				; set plane mask
  mov edi, [last_page]
  mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT / 4 / 4

  rep movsd

  add ah, ah
  dec bl
  jnz .draw_plane

  mov dx, 0x3da		;
.wait:			;
  in al, dx		;
  test al, 0x8		;
  jnz .wait		;

  mov ebx, [last_page]
  mov dx, CRTC_INDEX
  mov al, HIGH_ADDRESS
  mov ah, bh
  out dx, ax
  ; low address remains the same always

  popad
  retn



;-----------------------------------------------------------------------.
						calc_planar_offset:	;
; EDI = linear offset
; returns:
; EDX = planar offset

  push eax

  mov edx, edi
  and edx, 0x3		; EDX = plane number
  mov eax, PLANE_SIZE
  mul edx		; EAX = offset to plane
  mov edx, edi
  shr edx, 2		; EDX = offset within plane
  add edx, eax

  pop eax
  retn



;-----------------------------------------------------------------------.
						smooth_scroll_on:	;

  pushad


  mov [..@scroll_speed], byte DEFAULT_SCROLL_SPEED
  mov [..@smooth_scroll_jmp], byte 0

  popad
  retn

 

;-----------------------------------------------------------------------.
						smooth_scroll_off:	;

  pushad

  mov [..@scroll_speed], byte 3
  mov [..@smooth_scroll_jmp], byte ..@post_smooth_scroll - ..@pre_smooth_scroll
  mov eax, ..@post_smooth_scroll - ..@pre_smooth_scroll

  popad
  retn


 
;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

align 4
screen_pos: dd SCREEN_POS(0,CHAR_PER_COL-1)
last_page: dd VIDEO_RAM		; last page used; used for page switching

font:
%include "font.inc"

pcx:

%if SCREEN_HEIGHT != 240
  %error "no background image available for SCREEN_HEIGHT"
%endif

%if SCREEN_WIDTH = 360
incbin "logo-360x240.pcx"
%elif SCREEN_WIDTH = 320
incbin "logo-320x240.pcx"
%else
  %error "no background image available for SCREEN_WIDTH"
%endif

pcx_end:



;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

align 4
display_buffer:
  .plane0: resb SCREEN_WIDTH * SCREEN_HEIGHT / 4
  .plane1: resb SCREEN_WIDTH * SCREEN_HEIGHT / 4
  .plane2: resb SCREEN_WIDTH * SCREEN_HEIGHT / 4
  .plane3: resb SCREEN_WIDTH * SCREEN_HEIGHT / 4
  .end:
