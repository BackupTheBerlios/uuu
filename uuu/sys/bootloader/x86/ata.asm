; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/ata.asm,v 1.2 2003/10/31 22:32:06 bitglue Exp $
;---------------------------------------------------------------------------==|
; Primary IDE driver			   Copyright (c) 2000-2001 Dave Poirer
; for the stage2 bootloader		     Distributed under the BSD License
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	adapted to work in stage2 bootloader
; 2002-01-17	Dave Poirer	initial version

;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

%include "stage2-config.asm"

%define ATA_SECTOR_BUFFER	0x7c00		; use the boot record's memory

__IODE_ADD_DEVICE_ERR__   equ 1
%define _DEBUG_


struc ata_geometry
	.sectors_per_track:	resd 1
	.heads_per_cylinder:	resd 1
endstruc



;---------------===============\                /===============---------------
;				external symbols
;---------------===============/                \===============---------------

extern print_string



;---------------===============\              /===============---------------
;				global symbols
;---------------===============/              \===============---------------

global ata_read_sector



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						ata_init:		;

; detect drives and allocate mem for structures
; scans only the primary bus atm
;---------------------------------------;
  pushad				;

  mov ebp, drives.pm			; first drive
  mov edi, ATA_SECTOR_BUFFER

  call ata_wait_not_busy
  mov edx, dword 0x01F6			;
  in al, dx				; get device/head register
  and al, 11101111b			; select first drive (bit 4=0)
;---------------------------------------;  
.probe:					; test for drives
  push eax				; wait_not_busy destroys eax, edx
  push edx				;
  call ata_wait_not_busy		; wait
  pop edx				;
  pop eax				;
  out dx, al				; write dev/hd register
  call ata_wait_not_busy		; wait until drive is ready
  mov dl, 0xF7				; write to the command register
  mov al, 0xEC				; the IDENTIFY command
  out dx, al				; 
  call ata_wait_not_busy		; wait
  mov dl, 0xF0				; from data port
  mov ecx, 256				; read 256 words
  repz insw				; into buffer
  sub edi, 512				; set edi to start of buffer
  mov ax, word [edi+2*49]		; read capabilities field
  test ax, 0000001000000000b		; lba bit set?
  jz .no_lba_drive_found		; either no drv or no lba
;---------------------------------------;
  movzx eax, word [edi+56*2]		; get current lg. sectors/track
  mov dword [ebp+ata_geometry.sectors_per_track], eax
  movzx eax, word [edi+55*2]		; get logical heads/cylinder
  mov dword [ebp+ata_geometry.heads_per_cylinder],eax
;---------------------------------------;
.no_lba_drive_found:			;
  cmp ebp, drives.pm			; check if finished
  jnz .finished				;
  add ebp, ata_geometry_size		; ebp now points to drive.ps
  call ata_wait_not_busy		;
  mov dl, 0xF6				;
  in al, dx				;
  or ax, 0000000000010000b		; select second drive (slave)  
  jmp .probe				; probe slave
;---------------------------------------;
					;
.finished:				;
					;
.end:					;
  popad					; end of init section.
  retn					;
;---------------------------------------;




;;-----------------------------------------------------------------------.
;						ata_read_sectors:	;
;;>
;;; parameters:
;;; -----------
;;; EDX:EAX = 64 bit LBA
;;; ECX = number of sectors to read
;;; EDI = pointer to buffer to put data in
;;; EBX = pointer to file handle
;;;
;;; returned values:
;;; ----------------
;;; errors as usual
;;<
;;-----------------------------------------------;
;						;
;  push edi					;
;  clc						; clear carry
;  add eax, dword [ebx+local_file_descriptor.lba_start]
;  adc edx, dword [ebx+local_file_descriptor.lba_start+4]
;  mov ebx, [ebx+local_file_descriptor.device]	;
;  test edx, edx					; lba addreess out of range?
;  jnz short .sector_above_supported_address	;
;;-----------------------------------------------;
;.continue:					;
;  test eax, 0xF0000000				;
;  jnz short .sector_above_supported_address	;
;  cmp bl, 1					; drive one or zero?
;  ja short .invalid_drive			;	
;.reading_next_sector:				;
;  push ecx					;
;  push eax					;
;  push ebx					;
;  mov dl, bl					;
;  call ata_read_sector				;
;  pop ebx					;
;  pop eax					;
;  pop ecx					;
;  jc short .error_while_reading			;
;  inc eax					;
;  dec ecx					;
;  jnz short .reading_next_sector		;
;  pop edi					;
;  clc						;
;  retn						;
;;-----------------------------------------------;  
;.error_while_reading:				;
;  dbg lprint "IODE: error while reading", LOADINFO
;  mov edi, eax					;
;  xor eax, eax					;
;  dec eax					; TODO: define an error code
;  xor edx, edx					;		
;  pop edi					;
;  stc						;
;  retn						;
;;-----------------------------------------------;
;.invalid_drive:					;
;  dbg lprint "IODE: invalid drive", LOADINFO	;
;  xor eax, eax	; TODO: define specific error code for invalid drive
;  dec eax					;
;  pop edi					;
;  stc						;
;  retn						;
;;-----------------------------------------------;
;.sector_above_supported_address:		;
;  dbg lprint "IODE: sector above supported address", LOADINFO
;  xor eax, eax					;
;  dec eax					; TODO: define an error code
;  pop edi					;
;  stc						;
;  retn						;
;;-----------------------------------------------;
;

		
;-----------------------------------------------------------------------.
						ata_read_sector:	;
; parameters:
;------------
; eax = lba
; edi = location where to put the data (512 bytes)
; dl  = drive, 0 = master, 1 = slave

  test eax, 0xF0000000	; test for bits 28-31
  jnz short .return_error
  test dl, 0xFE		; test for invalid device ids
  jnz short .return_error
  push edx
  push eax
  call ata_wait_not_busy

  mov dl, 0xF2		; port 0x1F2 (sector count register)
  mov al, 0x01		; read one sector at any given time
  out dx, al		;

  inc edx		; port 0x1F3 (sector number register)
  pop ecx		; set ecx = lba
  mov al, cl		; al = lba bits 0-7
  out dx, al		;

  inc edx		; port 0x1F4 (cylinder low register)
  mov al, ch		; al = lba bits 8-15
  out dx, al		;

  inc edx		; port 0x1F5 (cylinder high register)
  ror ecx, 16		;
  mov al, cl		; set al = lba bits 16-23
  out dx, al		;

  pop eax		; restore drive id
  inc edx		; port 0x1F6 (device/head register)
  and ch, 0x0F		; set ch = lba bits 24-27
  shl al, 4		; switch device id selection to bit 4
  or al, 0xE0		; set bit 7 and 5 to 1, with lba = 1
  or al, ch		; add in lba bits 24-27
  out dx, al		;

  call _wait_drdy	; wait for DRDY = 1 (Device ReaDY)
  test al, 0x10		; check DSC bit (Drive Seek Complete)
  jz short .return_error

  mov al, 0x20		; set al = read sector(s) (with retries)
  out dx, al		; edx = 0x1F7 == command/status register

  ; TODO: ask for thread yield, giving time for hdd to read data
  jmp short $+2
  jmp short $+2

  call ata_wait_not_busy.waiting	; bypass the "mov edx, 0x1F7"
  test al, 0x01     ; check for errors
  jnz short .return_error

  mov dl, 0xF0		; set dx = 0x1F0 (data register)
  mov ecx, 256		; 256 words (512 bytes)
  repz insw		; read the sector to memory
  clc			; set completion flag to successful
  retn			;

.return_error:
  pushad
  mov bl, VGA_RED
  printstr "ATA: error in read_sector",0xa
  popad
  mov dl, 0xF1		; error status register 0x1F1
  in al, dx		; read error code
  stc			; set completion flag to failed
  retn			;



_wait_drdy:
; Parameters: none
; returns:
;   al = status register value
;   edx = 0x1F7
;
; TODO: add check in case DRDY is 0 too long
;
  mov edx, 0x00001F7		; set edx = status register
.waiting:
  in al, dx			; read status
  test al, 0x40			; check DRDY bit state
  jz .waiting			; if DRDY = 0, wait
  retn



;                                           -----------------------------------
;                                                                ata_wait_not_busy
;==============================================================================

ata_wait_not_busy:
; parameters: none
; destroys: edx = 0x1F7
; returns: al = status
; TODO: add error check if drive is busy too long
  mov edx, 0x000001F7
.waiting:
  in al, dx
  test al, 0x80
  jnz .waiting
  retn



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

primary_dev:		db "hd/0",0
secondary_dev:		db "hd/1",0



;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

; This shows to the drive's geometry structure
drives:
	.pm:		resb ata_geometry_size
	.ps:		resb ata_geometry_size
