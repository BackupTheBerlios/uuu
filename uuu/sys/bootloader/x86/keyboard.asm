; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/keyboard.asm,v 1.2 2003/10/23 03:11:01 bitglue Exp $
;---------------------------------------------------------------------------==|
; keyboard driver for the stage2 bootloader
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	adapted to work for the stage2 bootloader
; 2002-01-17	Dave Poirer	initial revision

;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

; to change the keymap, see the %include directive at the bottom of this file.

struc KEYB_HEADER
.next_header			resd 1
.translation_table		resd 1
.translation_exceptions		resd 1
.modifier_combinations		resb 0
.mod1				resw 1
.mod2				resw 1
.mod3				resw 1
.mod4				resw 1
.mod5				resw 1
.mod6				resw 1
.mod7				resw 1
.mod8				resw 1
endstruc


%assign _KEYB_IRQ_		0x01
%assign _PIC_SLAVE_IRQ_		0x02
%assign _KEYB_AUXILIARY_IRQ_	0x0C
%assign _KEYB_OUTPUT_BUFFER_	0x01
%assign _KEYB_INPUT_BUFFER_	0x02
%assign _KEYB_AUXILIARY_BUFFER_	0x20
%assign _KEYB_STATUS_PORT_	0x64
%assign _KEYB_COMMAND_PORT_	0x64
%assign _KEYB_DATA_PORT_	0x60


%define mod1 1		; ctrl
%define mod2 2
%define mod3 4		; left shift
%define mod4 8		; right shift
%define mod5 16		; alt
%define mod6 32
%define mod7 64
%define mod8 128
%define mod9 256
%define mod10 512
%define mod11 1024
%define mod12 2048
%define mod13 4096
%define mod14 8192
%define mod15 16384
%define mod16 32768



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						get_key:		;
  call redraw_display
  push edi
.wait:

%ifidn BOOT_CONSOLE,graphical
  call wait_vtrace

  xor eax, eax
  mov dx, 0x3c6
  dec eax
  out dx, al
  add edx, byte 2
  mov al, CURSOR_COLOR
  out dx, al
  inc edx
  xor eax, eax
  out dx, al
  out dx, al
  mov al, [cursor_intensity]
  out dx, al
  inc al
  mov [cursor_intensity], al
%endif ; %ifidn BOOT_CONSOLE,graphical

  in al, _KEYB_STATUS_PORT_
  test al, _KEYB_OUTPUT_BUFFER_
  jz .wait

  in al, _KEYB_DATA_PORT_

  mov edi, [scancode_pointer]
  mov [edi], al			;<-- store scancode for analyze
  inc dword [scancode_pointer]

  call _scancode_analyzer
  jc .wait

  pop edi
  retn



;-----------------------------------------------------------------------.
						_scancode_analyzer:	;
;
; read the scancode_sequence and try to convert it to a matching unicode char.
; if a match is found, CF=0 and the following registers contain data:
;
;  EAX = unicode character
;  ECX = index in keyboard map
;
; This function will destroy the following registers: ESI

  mov esi, scancode_sequence
  movzx eax, byte [esi]
  cmp al, scancode_2_index_max
  ja short .check_release_or_extended

  mov al, [eax + scancode_2_index]
  mov esi, [current_translation_table]
  mov ecx, eax
  mov eax, [eax*4 + esi]

  or eax, eax
  js short .function_or_modifier

  mov [scancode_pointer], dword scancode_sequence
  clc
  retn
  

.function_or_modifier:
 ; TODO: well, the whole kit here too, let's just join the group
 ; and kill the scancode buffer
 cmp eax, 0xF8000000
 jb short .exit_no_unicode

.modifier_detected:
  cmp eax, 0xF8020000
  jae short .special_modifier_detected

  and eax, 0x0000FFFF
  or [current_modifiers], eax
  call _select_translation_table
  jmp short .exit_no_unicode

.special_modifier_detected:
  and eax, 0x0000FFFF
  xor [current_modifiers], eax
  call _select_translation_table
  jmp short .exit_no_unicode

.check_release_or_extended:
 ; TODO: well, the whole kit
 ; right now let's just clear this whole damned buffer
 cmp al, byte 0xE0
 jnz short .check_modifier_release

.exit_no_unicode:
  mov [scancode_pointer], dword scancode_sequence
  stc
  retn

.check_modifier_release:
  test al, 0x80
  jz short .exit_no_unicode

  xor al, byte 0x80
  cmp al, scancode_2_index_max
  ja short .exit_no_unicode

  mov al, [eax + scancode_2_index]
  mov esi, [current_translation_table]
  mov ecx, eax
  mov eax, [eax*4 + esi]
  
  cmp eax, 0xF8000000
  jb short .exit_no_unicode

  cmp eax, 0xF8020000
  jae short .exit_no_unicode

  and eax, 0x0000FFFF
  not eax
  and [current_modifiers], eax
  call _select_translation_table
  jmp short .exit_no_unicode



;-----------------------------------------------------------------------.
						_select_translation_table:
  mov esi, [first_translation_header]
  mov eax, [current_modifiers]
  and eax, [current_modifier_mask]
  inc eax

  .check_modifiers:
  cmp [esi + KEYB_HEADER.mod1], ax
  jz short .map_found
  cmp [esi + KEYB_HEADER.mod2], ax
  jz short .map_found
  cmp [esi + KEYB_HEADER.mod3], ax
  jz short .map_found
  cmp [esi + KEYB_HEADER.mod4], ax
  jz short .map_found
  cmp [esi + KEYB_HEADER.mod5], ax
  jz short .map_found
  cmp [esi + KEYB_HEADER.mod6], ax
  jz short .map_found
  cmp [esi + KEYB_HEADER.mod7], ax
  jz short .map_found
  cmp [esi + KEYB_HEADER.mod8], ax
  jz short .map_found
  ; combination not found, trying to identify 
  mov esi, [esi + KEYB_HEADER.next_header]
  or esi, esi
  jnz short .check_modifiers
  retn
.map_found:
  mov eax, [esi + KEYB_HEADER.translation_exceptions]
  mov esi, [esi + KEYB_HEADER.translation_table]
  mov [current_translation_exceptions], eax
  mov [current_translation_table], esi
  retn



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

align 4

scancode_pointer:		dd scancode_sequence
scancode_sequence:		dd 0,0
current_translation_table:	dd us_keyboard_map.unshifted
current_translation_exceptions:	dd 0
current_modifiers:		dd 0
current_modifier_mask:		dd mod3 | mod4
first_translation_header:	dd us_keyboard_map.header01


scancode_2_index:
db  -1,  57,  59,  60,  61,  62,  63,  64	; 00-07
db  65,  66,  67,  68,  69,  70,  71,  72	; 08-0F
db  73,  74,  75,  76,  77,  78,  79,  80	; 10-17
db  81,  82,  83,  84,  85, 109,  86,  87	; 18-1F
db  88,  89,  90,  91,  92,  93,  94,  95	; 20-27
db  96,  58, 111,  97,  98,  99, 100, 101	; 28-2F
db 102, 103, 104, 105, 106, 107, 112, 122	; 30-37
db 113, 108, 118,   0,   1,   2,   3,  4	; 38-3F
db   5,   6,   7,   8,   9, 120,  27, 134	; 40-47
db 135, 136, 123, 131, 132, 133, 124, 128	; 48-4F
db 129, 130, 127, 126,  26,  -1, 118,  10	; 50-57
db  11
scancode_2_index_max equ $-scancode_2_index

scancode_2_index_extended:
db  -1,  -1,  -1,  -1,  -1,  -1,  28,  31	; 40-47
db  35,  33,  -1,  36,  -1,  38,  -1,  32	; 48-4F
db  37,  34,  29,  30,  -1,  -1,  -1,  -1	; 50-57
db  -1,  -1,  -1, 114, 115, 116
scancode_2_index_extended_max equ $-scancode_2_index_extended


cursor_intensity:	db 0


%include "us.keymap"
