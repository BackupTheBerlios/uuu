; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/boot.asm,v 1.7 2003/12/26 21:32:55 bitglue Exp $
;---------------------------------------------------------------------------==|
; stage2 bootloader for Unununium
; boot routines
;
; these routines perform the work of unpacking and booting the RAM image after
; it has been loaded. All of this code copied by stage2 to 0x500 so that
; everything above 1M will be availible to the booting system.
;
; All code from zlib, used to decompress the RAM image, is loaded below 1M with
; this code.
;
; Also contained here are a few functions required by zlib: calloc, memcpy, and
; free.
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-11-02	Phil Frost	Initial version


%include "stage2-config.asm"

;---------------===============\                /===============---------------
;				external symbols
;---------------===============/                \===============---------------

extern uncompress	; from zlib
extern stack_top
extern boot_top
extern print_string
extern print_hex
extern set_display_start
extern redraw_display



;---------------===============\              /===============---------------
;				global symbols
;---------------===============/              \===============---------------

global calloc
global malloc
global free
global memcpy
global boot



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						free:			;
  ; do nothing; we don't care :)
  retn



;-----------------------------------------------------------------------.
						malloc:			;
  mov eax, [esp+4]
  add eax, byte 3
  and al, -4
  neg eax
  add eax, [memory_frame]
  mov [memory_frame], eax
  retn



;-----------------------------------------------------------------------.
						calloc:			;
  pushad

  mov eax, [esp+32+4]
  xor edx, edx
  mov ebx, [esp+32+8]
  mul ebx

  pushad
  mov bl, VGA_CYAN
  mov edx, eax
  printstr "requested "
  mov edx, eax
  call print_hex
  printstr "; "
  popad

  add eax, byte 3
  and eax, -4
  mov ecx, eax
  shr ecx, 2

  neg eax
  add eax, [memory_frame]
  mov [memory_frame], eax

  cmp eax, boot_top
  jb .out_of_mem

  mov ebx, eax


.zero:
  mov [ebx], edx
  add ebx, byte 4
  dec ecx
  jnz .zero

  mov [esp+28], eax
  popad

  pushad
  mov bl, VGA_CYAN
  printstr "allocated ram at "
  mov edx, eax
  call print_hex
  printstr 0xa
  popad
  
  retn

.out_of_mem:
  popad
  xor eax, eax
  retn



;-----------------------------------------------------------------------.
						memcpy:			;
  pushad
  mov edi, [esp+36]
  mov esi, [esp+40]
  mov ecx, [esp+44]
  rep movsb
  popad
  retn



boot.invalid_format:
  mov bl, VGA_RED
  printstr "invalid format for boot image",0xa
  retn

;-----------------------------------------------------------------------.
						boot:			;
  mov ebp, boot_image
  cmp [ebp], dword "UnBI"
  jnz .invalid_format

  push dword [ebp+8]	; entry address

.process_section:
  add ebp, [ebp+4]
  cmp [ebp], dword "end "
  jz .end
  cmp [ebp], dword "zspn"
  jz .zspan
  cmp [ebp], dword "fspn"
  jz .fillspan

  mov bl, VGA_RED
  mov edx, [ebp]
  call print_hex
  pop eax
  jmp .invalid_format

.end:
  mov bl, VGA_WHITE
  printstr "image looks good",0xa
  call redraw_display
  xor ebx, ebx
  call set_display_start
  pop eax
  jmp eax

.zspan:
  mov bl, VGA_WHITE
  printstr "processing zspan section",0xa
  call redraw_display

  push ebp	; we can be sure C will klobber this...stupid stack frames
  push dword [ebp+16]	; will be our *destLen

  mov eax, [ebp+4]
  sub eax, [ebp+8]
  push eax		; sourceLen

  mov eax, ebp
  add eax, [ebp+8]
  push eax		; source

  lea eax, [esp+8]
  push eax		; destLen

  push dword [ebp+12]	; dest

  call uncompress
  add esp, byte 16

  pop ebx
  pop ebp

  test eax, eax
  jnz .decompress_error

  cmp ebx, [ebp+16]
  jnz .decompress_error

  jmp .process_section


.fillspan:
  mov bl, VGA_WHITE
  printstr "processing fillspan section",0xa
  call redraw_display

  mov edi, [ebp+8]
  mov ecx, [ebp+12]
  mov eax, [ebp+16]

  shr ecx, 2
  jz .fill1
  rep stosd

.fill1:
  mov ecx, [ebp+12]
  and ecx, -4
  jz .process_section

.fill2:
  stosb
  shr eax, 8
  loop .fill2

  jmp .process_section


.decompress_error:
  mov bl, VGA_RED
  printstr "error while decompressing",0xa
  pop eax
  retn



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

memory_frame: dd stack_top - 0x500

boot_image: incbin "../../../boot.bimage"
boot_image_size equ $ - boot_image
