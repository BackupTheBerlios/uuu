; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage1.asm,v 1.3 2003/10/13 01:14:55 bitglue Exp $
; original version called "u_burn" by Dave Poirier
; adapted to use UDBFS by Phil Frost
;
; Copyright (C) 2002, Dave Poirier
; Distributed under the X11 License
;
; Note: Unless otherwise specified all values in the comments are assumed to
;       be hexadecimal.
;
; originally developped for the Unununium Operating Engine, http://uuu.sf.net/

org 0x7C00
bits 16

%include "../../../include/udbfs.inc"

%assign LOAD_ADDR	0x100000	; address to which to load flat binaries

; Let's define some generic constants...
%assign BIOSVIDEO			0x10
%assign BIOSDISK			0x13
%assign BIOSDISK_RESET			0x00
%assign BIOSDISK_READ_SECTORS		0x02
%assign BIOSDISK_GET_DRIVE_PARAM	0x08
%assign CGA_TEXT_SEGMENT		0xB800
%assign VRAM_SEGMENT			0xA000

; some more definitions for MultiBoot support
%assign MBOOT_SIGNATURE	0x1BADB002
%assign MBOOT_LOADED	0x2BADB002

struc mboot
.magic               resd 1
.flags               resd 1
.checksum            resd 1
.header_addr         resd 1
.load_addr           resd 1
.load_end_addr       resd 1
.bss_end_addr        resd 1
.entry_addr          resd 1
endstruc


;%macro dbg 1
;pusha
;mov dx, %1
;call print_hex
;popa
;%endmacro


;------------------------------------------------------------------------------
_start:
  jmp short _entry		; some bioses requires a jump at the start
  nop				; and they also check the third byte..
;------------------------------------------------------------------------------
;Insert here any file system specific information you might I.e.:
;FAT Header


;------------------------------------------------------------------------------
error:
;  push ax			; backup the error code mov ax,
;  mov ax, 0x0003		; function: set video mode, mode: 80x25 color
;  int BIOSVIDEO			; set text video mode
;  push word CGA_TEXT_SEGMENT	;
;  pop ds			; load ds with text video segment
;  pop ax			; restore the error code
;  aam 0x10			; split the two digits apart
;  cwde				; give us some room in eax
;  cmp al, 0x0A			; convert first digit into ascii
;  sbb al, 0x69			;
;  das				;
;  shl eax, 8			;
;  aad 0x01			;
;  cmp al, 0x0A			; convert second digit into ascii
;  sbb al, 0x69			;
;  das				;
;  or [0], eax			; display them
  				; note: we use 'or' instead of 'mov' so that we
				; dont' have to fill in the color codes for the
				; 2 digits string.
				;
  jmp short $			; lock it up.
				;
_entry:				; setup data and stack segments
				;------------------------------
  xor di, di			; prepare di for get_drive_param (bios bug)
  mov ds, di			; set data segment to	0000
;  mov es, di			; prepare es for get_drive_param (bios bug)
  mov ss, di			; set stack segment to	0000
  mov sp, 0x1000		; set top of stack to	1000
  sti				; enable interrupts
				;
				; set video mode to 320x200
				;--------------------------
  mov ax, 0x13			; 13h = 320x200x4bpp
  int BIOSVIDEO			; request servicing
				;
				; get disk geometry
				;------------------
  mov ah, BIOSDISK_GET_DRIVE_PARAM
  mov [drive], dl		; backup drive id
  int BIOSDISK			; request servicing
  mov al, ah			; store error code in case
  test ah, ah			; check if completed with success
  jnz short error		; if not, display error and lock
				;
  and cl, 0x3F			; extract max sector number
  mov [spt], cl			; store spt
  mov [head], dh		; store head
				;
				; load superblock
				;----------------
  mov al, 2			; set sector id:  00000002
  cwd				; DX = 0          -DX--AX-
  mov si, 0x7e0			; to be placed in ES and later shifted
  push si			; save this number; we use it much
  mov cx, 1			; sector count:   CX = 1
  mov bx, dx			; BX = 0
  mov es, si			; ES:BX = address to load the sectors
  call load_sector		; load them
  shl si, 4			; DS:SI = ptr to superblock
				;
				; check magic number
				;-------------------
  mov eax, [esi+udbfs_superblock.magic_number]
  sub eax, udbfs_magic		; compare, and set EAX = 0 while we are at it
  jnz error			;

  mov cl, -9			; CL = - log2( 512 )
  add cl, [si + udbfs_superblock.block_size]
  mov [..@sect_size1], cl	; CL = log2( block size / 512 )
  inc ax			; AX = 1
  shl al, cl
  mov [..@sect_size2], ax	; do some self modifying code magic...
				;
				; superblock has been verified
				; SI = .boot_loader_inode
  lodsw				; get low word of .boot_loader_inode
  xchg bp, ax			;
  lodsw				; get high word
  xchg bx, ax			; BX:BP = boot loader inode

  lodsd
  ; XXX check that high dword is zero
 
  lodsw				; get low word of .inode_first_block
  xchg dx, ax			;
  lodsw				; AX:DX = first block of inode table
				;
  				; convert the boot loader inode to an offset
				;   within the inode table
				;-------------------------------------------
  mov di, bp			; DI will be the byte offset
  add cl, 3			; CL = log2( block size / udbfs_inode_size )
  shl di, 6			; multiply by udbfs_inode_size
  shrd bp, bx, cl		;
  shr bx, cl			;
				;
  add dx, bp			; add calculated block offset to AX:DX
  adc ax, bx			; AX:DX = block containing bootloader inode

  pop es			; ES:BX = 0x7e0, address to load the sectors

  push cx			; PUSH log2( block size / udbfs_inode_size )
  neg cl
  add cl, 10			; CL = number of bits to discard in DI
  mov bp, -1			; we will use this value later
  shl bp, cl
  shr bp, cl			; BP = block size in bytes - 1
  and di, bp			; zero the CL MSbs of DI

  xor bx, bx
  call load_block

  lea si, [di + 0x7e00 ]	; DS:SI = ptr to bootloader inode
				;
				; calculate how many blocks are in the file
				;-------------------------------------------
  lodsw				; AX = file size in bytes
  add [..@file_size], ax	; some SMC magic for later
  add ax, bp			; AX = file size in bytes rounded to multiple
				;   of the block size (low bits don't matter)
  pop cx			; POP CL = log2( block size / udbfs_inode_size )
  add cl, 6			; CL = log2( block size )
  shr ax, cl			; convert bytes -> blocks
  xchg di, ax			; DI = number of blocks to load

  				; verify that the size wasn't too big
				;------------------------------------
  mov cx, 3			;
  push cx			; we will need a 3 after loading
  xor ax, ax			;
  rep lodsw			; DS:SI = ptr to first block of bootloader
				;
				; XXX this should be a scasw to check that all
  				; other bytes are 0, but it doesn't seem to work
				;
				;
  xchg bp, ax			; set progress bar start BP = 0
  mov [..@file_location], es	; SMC magic
  				;
				; load the stage2 loader block by block
loading_object:			;--------------------------------------
  cmp bp, byte 4		;
  jnz .not_yet			; sometimes thinking of label names is hard...
				; we have read 4 blocks, now move to the
  lodsw				;   indirection block
  xchg ax, dx			;
  lodsw				; AX:DX = indirection block number

  push es
  mov si, 0x7e0
  mov es, si
  call load_block
  shl si, 4			; SI = ptr to next block number
  pop es

.not_yet:
  lodsw				; load low 16-bit of block number
  xchg ax, dx			;
  lodsw				; load high 16-bit of block number
  inc bp			; increase progress mark
  lodsd				; advance SI, eax should be 0, but don't check
  pusha				; backup registers (si,bx,cx,bp,di)
				;
  call load_block		; load 1 block

  ;---------------------------------------------------------------------------
  ; display some cute gfx progress bar on the right side, bottom to top
  ;
  ; bp = number of blocks loaded
  ; di = total number of blocks to load
  ; si = pointer to next sector id to load
  ; ax, dx and cx are free to use
  ; bx = offset to load the sectors, must be 0 when leaving
  ; cx = 0
  ; es = segment to load the sectors, must be kept intact
  ; ds = 0000
  ; cs = 0000
  mov ax, 200			; 320 x 200
  mul bp			; compute progress bar percentage
  div di			;
  push es			; backup load segment address
  push word VRAM_SEGMENT	;
  pop es			; set es = gfx video segment
  mov di, 320*200		; warp to bottom right corner
  xchg ax, dx			; dx = progress / 200
  mov al, 0x09			; al = color
.drawing_bar:			;
  dec di			; get place for 1 pixel
  dec di			; get place for a 2nd pixel
  stosb				; draw both pixels with color of AL
  stosb				;
  sub di, 320			; move up one line
  jz short .done_drawing	; if we reached the top we're done.
  dec dx			; progress bar color swap check
  jnz short .drawing_bar	; haven't reached that point yet
  dec ax			; al = color 09->08
  jmp short .drawing_bar	; continue drawing up to the top
.done_drawing:			;
  pop es			; restore the load segment address
  popa				; restore registers (si,bx,cx,bp,di)
  cmp bp, di			; loaded all sectors?
  jnz loading_object		; if not, continue loading them
				;
;----------------------------------------------------------------------------
				;
  ;mov ax, 0x0003		; all loaded, set video mode back to 80x25
  ;int BIOSVIDEO		;
				;
  cli				; disable interrutps, sensitive stuff coming
				;
				; Enable A20
				;-----------
  mov al, 0x02			; AX=2; enable A20 bit of PS/2 control register
  out 0x92, al                  ; flag the bit, should enable the A20 gate
  call wait_kbd_command         ; wait for 8042 to be ready
  mov al, 0xD1                  ; equivalent for older systems
  out 0x64, al                  ; this time send it to the keyboard controller
  call wait_kbd_command         ; wait for 8042 to be ready
  pop ax			; AX = 3, A20 enabled, reset line high
  out 0x60, al                  ; send to keyboard controller
				;
				; turn off FDC motor
				;-------------------
  mov dx, 0x3F2			; fdc reg
  mov al, 0x0C			; motor bit off
  out dx, al			; done
				;
				; Setup Protected Mode
				;---------------------
  lgdt [__gdt]			; load GDTR
  mov ecx, cr0			; ecx = CR0
  inc ecx			; set pmode bit to 1
  mov cr0, ecx			; update CR0
  jmp 0x0008:pmode		; clear prefetch (activate change)
;-----------------------------------------------------------------------------



;print_hex:
;  mov bh, 4
;  mov ah, 0x07
;  mov di, [cursor]
;  push es
;  push word 0xb800
;  pop es
;.do_char:
;  rol dx, 4
;  mov al, dl
;  and al, 0x0f
;
;  cmp al, 0xa
;  sbb al, 0x69
;  das
;  stosw
;
;  dec bh
;  jnz .do_char
;
;pop es
;  add di, byte 2
;  mov [cursor], di
;  retn
;
;  cursor: dw 0xa0




load_block:
;-----------------------------------------------------------------------------
; AX:DX = block # to load
; *** note *** the above parameter is reversed from what it would usually be
; ES = destination segment
; BX = 0
;
; returns:
; ES = updated to point to end of loaded data
; CX = 0
; DX:AX = sector after the last one read
; everything else unmodified
;-----------------------------------------------------------------------------

  xchg ax, dx			; DX:AX = block number of inode table
  mov cl, 0
..@sect_size1 equ $-1
  shl ax, cl			; [SMC] same again
  shl cx, cl			; [SMC] yet again
  mov cx, 0
..@sect_size2 equ $-2

.read_sectors:
  call load_sector
  inc ax
  adc dx, bx			; (BX is 0)
  loop .read_sectors

  retn

load_sector:
;-----------------------------------------------------------------------------
; DX:AX = LBA sector to load
; ES = destination segment
; BX = 0
;
; returns:
; ES = updated to point to end of loaded data
; everything else unmodified
;-----------------------------------------------------------------------------

  pusha				; save starting values

  mov cl, 0			; <- Self-modifying code, 0 replaced by
spt equ $-1			;    sector-per-track value
  div cx			; extract sector number
  mov si, dx			; si = sector number
  mov cl, 0			; <- Self-modifying code, 0 replaced by
head equ $-1			;    number of heads
  inc cx			; head is 0 based, get it up a notch
  inc si			; sector number should be 1 based, adapt it
  xor dx, dx			; prepare for another division
  div cx			; extract head number
  mov dh, dl			; dh = head number
  mov dl, 0			; <- Self-modifying code, 0 replaced by
drive equ $-1			;    drive ID
  xchg al, ah			; compute cylinder/sector value
  shl al, 6			; move high 2 bits of cylinder number
  or ax, si			; merge in sector value
  xchg ax, cx			; cx = cylinder/sector
  mov ah, BIOSDISK_READ_SECTORS	; set function number
  mov ax, (BIOSDISK_READ_SECTORS << 8) + 1
.retry:				;
  pusha				; save all regs in case of an error
  int BIOSDISK			; read those babies!
  test ah, ah			; error occured?
  jz short .next_sector		; if not, this one is done
				;
  mov ah, 0			; reset drive
  mov dl, [drive]		; load up the drive ID
  int BIOSDISK			; do it!
  popa				; restore the regs and retry
  jmp short .retry		;
				;
.next_sector:			;
  popa				; clear the regs for the bios call
  popa				; restore the original passed values
  push es			;
  add word[esp], byte 0x20	;
  pop es			;
  retn				; done loading
;-----------------------------------------------------------------------------



wait_kbd_command:
;-----------------------------------------------------------------------------
  in AL, 64h			; read 8042 status port
  test al, 0x01			; wait until port 0x60 is ready
  jc wait_kbd_command		;
  retn				;
;-----------------------------------------------------------------------------





pmode:
;-----------------------------------------------------------------------------
[bits 32]
;-----------------------------------------------------------------------------
  cwde				; zero high part of eax
  mov al, 0x10			; set eax = 0x00000010 (data selector)
  mov ds, eax			;
  mov es, eax			;
;  mov fs, eax			;
;  mov gs, eax			;
  mov ss, eax			;

  mov esi, 0			; [SMC] set esi to header of loaded file
..@file_location equ $-4
  shl esi, 4

  mov edi, esi			; prepare to search for multiboot header
  mov eax, MBOOT_SIGNATURE	; value to search for
  mov ecx, esi			; search for about 0x8000 cases (will vary
  repnz scasd			;   on the block size, but it doesn't matter)
  jnz short .flat		; if we don't find it, assume a flat binary
				;
				;
				; MultiBoot file
.mboot:				;---------------
  mov ecx, [edi + mboot.load_end_addr - 4]
  mov ebp, [edi + mboot.bss_end_addr - 4]
  mov edx, [edi + mboot.entry_addr - 4]
  mov edi, [edi + mboot.load_addr - 4]
  sub ecx, edi			; find number of bytes to move
  shr ecx, 2			; make them dwords
  rep movsd			; move them over
  xor eax, eax			; set eax = 0 for zeroize operation
  mov ecx, ebp			;
  sub ecx, edi			; find number of bytes to zeroize
  jz short .none		; in case there are none
  shr ecx, 2			; make those bytes dwords
  rep stosd			; zeroize them
.none:				;
  mov eax, MBOOT_LOADED		; set eax to multiboot loaded
  jmp edx			; jump to entry point
				;
				;
				; flat binary
.flat:				;------------
  mov ecx, 3			; [SMC]
..@file_size equ $-4		;
  shr ecx, 2			; bytes -> dwords
  mov edi, LOAD_ADDR		;
  mov eax, edi			;
  rep movsd			;
  jmp eax			;
;------------------------------------------------------------------------------




__gdt: ; Global Descriptor Table
;------------------------------------------------------------------------------
  dw (.end - .start) + 7                ; part of GDTR, size of the GDT
  dd __gdt.start - 8                    ; part of GDTR, pointer to GDT
.start:
  dd 0x0000FFFF, 0x00CF9B00             ; pmode CS, 4GB r/x, linear=physical
  dd 0x0000FFFF, 0x00CF9300             ; pmode DS, 4GB r/w, linear=physical
.end:
;------------------------------------------------------------------------------




; BIOS signature
;------------------------------------------------------------------------------
_end:
db 'mo'
times 509 - ($-$$) db 'o'	; pad so that signature is the last 2 bytes
db '!'
db 0x55, 0xAA			; of the sector.
;------------------------------------------------------------------------------
