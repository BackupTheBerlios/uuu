; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/floppy.asm,v 1.1 2003/09/23 03:46:22 bitglue Exp $
;---------------------------------------------------------------------------==|
; floppy driver for the stage2 bootloader
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	adapted to work for stage2 bootloader
; 2002-01-17	Phil Frost	initial version



;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

%assign FDC_DOR		0x3f2
%assign FDC_MSR		0x3f4
%assign FDC_DATA	0x3f5

; bits 0 and 1 indicate selected drive
%assign FDC_DOR_NOT_REST	1 << 2
%assign FDC_DOR_DMA	1 << 3
%assign FDC_DOR_MOTA	1 << 4
%assign FDC_DOR_MOTB	1 << 5
%assign FDC_DOR_MOTC	1 << 6
%assign FDC_DOR_MOTD	1 << 7

%assign FDC_MSR_ACTA	1 << 0
%assign FDC_MSR_ACTB	1 << 1
%assign FDC_MSR_ACTC	1 << 2
%assign FDC_MSR_ACTD	1 << 3
%assign FDC_MSR_BUSY	1 << 4
%assign FDC_MSR_NDMA	1 << 5
%assign FDC_MSR_DIO	1 << 6
%assign FDC_MSR_MRQ	1 << 7

%assign SECTORS_PER_TRACK	18
%assign FLOPPY_GAP_3		27	; this is a standard value
%assign FLOPPY_SECTOR_SIZE	2	; 128 * 2^N (2 is the standard)

%assign FDC_CMD_SEEK		0x0f
%assign FDC_CMD_READ_SECTORS	0xe6	; read, high desnity, multitrack, skip deleted data
%assign FDC_CMD_INT_STATUS	0x08

%assign FLOPPY_BUFFER_ADDR	0x7c00	; let's use the bootloader's memory :)



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						floppy_read_sectors:	;
;>
;; parameters:
;; -----------
;; EDX:EAX = 64 bit LBA
;; ECX = number of sectors to read
;; EDI = pointer to buffer to put data in
;; EBX = pointer to file handle
;;
;; returned values:
;; ----------------
;; EDI = unmodified
;; errors as usual
;<

  pushad

  test edx, edx
  jnz .too_big
  cmp eax, 2880
  jnb .too_big

.read:
  call lba_to_chs		; BH = cyl
				; AH = sector
				; BL = head
  push eax			; save sector
  push ebx			; save cyl and head
  mov ah, bh			; AH = head
  mov bh, 0			; BH = 0 (drive number)
  call floppy_seek_heads	;
				;
  mov dl, 0x46			; DL = DMA mode
  mov cx, (128<<FLOPPY_SECTOR_SIZE) - 1
  mov ebx, FLOPPY_BUFFER_ADDR
  call floppy_program_dma
  pop ebx

  mov ah, FDC_CMD_READ_SECTORS
  call floppy_write_data
  pop eax

  call floppy_write_sector_id

  call floppy_read_result
  test al, 0xC0

  mov esi, FLOPPY_BUFFER_ADDR
  mov ecx, 512*2/4
  rep movsd
  
  popad
  clc
  retn
  
.too_big:
  go_panic "Floppy: requested sector is out of range"



;-----------------------------------------------------------------------.
						floppy_read_result:	;
;;
;; reads the result from commands (read track, read sector, write sector...)
;;
;; parameters:
;; -----------
;; none
;;
;; returned values:
;; ----------------
;; EDX = 0|ST2|ST1|ST0
;; BH = cyl
;; AH = sector
;; BL = head
;; 

  xor edx, edx
  call floppy_read_data	; st0
  mov dl, al
  rol edx, 8
  call floppy_read_data	; st1
  mov dl, al
  rol edx, 8
  call floppy_read_data	; st2
  mov dl, al
  ror edx, 16

.got_error:
  call floppy_read_data	; cyl
  mov bh, al
  call floppy_read_data	; head
  mov bl, al
  call floppy_read_data	; sector
  mov ah, al
  call floppy_read_data	; sector size

  retn



;-----------------------------------------------------------------------.
						floppy_write_sector_id:	;
;;
;; sends the sector, cyl, head, and all that good stuff to the FDC. Call this
;; after a read/write sector/track command
;; 
;; parameters:
;; -----------
;; AH = sector
;; BL = head
;; BH = cyl
;;
;; returned values:
;; ----------------
;; all registers except AL = unchanged
;; 


  cmp bh, 79
  ja .cyl_out_of_range

  push eax

  mov ah, bl
  shl ah, 2			; drive # and head
  call floppy_write_data

  mov ah, bh			; cylinder
  call floppy_write_data

  mov ah, bl			; head
  call floppy_write_data

  pop eax			; sector number
  call floppy_write_data

  mov ah, FLOPPY_SECTOR_SIZE	; sector size
  call floppy_write_data

  mov ah, SECTORS_PER_TRACK	; track length / max sector number
  call floppy_write_data

  mov ah, FLOPPY_GAP_3		; gap 3
  call floppy_write_data

  mov ah, -1			; data length
  call floppy_write_data

  retn

.cyl_out_of_range:
  go_panic "floppy_write_sector_id: cylinder out of range"



;-----------------------------------------------------------------------.
						lba_to_chs:		;
;; converts 16 bit LBA to CHS
;;
;; parameters:
;; -----------
;; AX = LBA
;; [sct_per_trk] = sectors per track
;;
;; returned values:
;; ----------------
;; BH = cyl
;; AH = sector
;; BL = head
;; everything else = unchanged
;;
;; This function is really stupid, it will work for standard floppies only

  div byte[sct_per_trk]	; divides AX; answer is in al, remainder in ah
  ;; AL = cyl
  ;; AH = will be sector

  inc ah		; because LBA starts at 0 but we don't
  xor bl, bl		; bl will be the head
  cmp ah, 18		; ah will be the sector
  jna .head0

  ; it's on head 1, subtract 18 and make head 1
  sub ah, 18
  inc bl

.head0:
  mov bh, al
  retn



;-----------------------------------------------------------------------.
						floppy_seek_heads:	;
;; seeks the heads...gee
;;
;; parameters:
;; -----------
;; AH = cyl to seek to
;; BH = drive
;;
;; returned values:
;; ----------------
;; DX = 0x3f5
;; everything else = unchanged

  push eax
  mov ah, FDC_CMD_SEEK
  call floppy_write_data
  mov ah, bh
  call floppy_write_data
  pop eax
  call floppy_write_data

  call floppy_wait_not_busy

  call wait_vtrace	; just stall a bit...
  call wait_vtrace	; it would seem that waiting until it says it's not busy
  call wait_vtrace	; is not sufficient.

  retn



;-----------------------------------------------------------------------.
						floppy_program_dma:	;

;; programs the DMA controller for a transfer. Assumes channel 2.
;;
;; parameters:
;; -----------
;; DL = mode ( add the channel too so: 0x46 for io -> mem; 0x4a for mem -> io )
;; CX = legnth - 1
;; EBX = src or dest ( must be below 16M and not cross page )
;; 
;; returned values:
;; ----------------
;; EAX = destroyed
;; everything else = unchanged


  mov al, 6
  out 0xa, al		; set mask on channel 2

  xor al, al
  out 0xc, al		; clear DMA pointers

  mov al, dl
  out 0xb, al

  mov al, cl
  out 5, al
  mov al, ch
  out 5, al		; set legnth to cx

  mov eax, ebx
  rol eax, 16
  out 0x81, al		; set page
  rol eax, 16
  out 4, al		; send low byte of offset
  mov al, ah
  out 4, al		; high byte

  mov al, 2
  out 0xa, al		; clear mask bit, ready to rock

  retn



;-----------------------------------------------------------------------.
						floppy_write_data:	;
;;
;; waits for the FDC to become ready, then writes a byte to the data register
;;
;; parameters:
;; -----------
;; AH = byte to write
;;
;; returned values:
;; ----------------
;; DX = 0x3f5
;;

  push ecx
.try_again:
  mov ecx, 0x30000
  mov dx, 0x3f4
.wait:
  in al, dx
  dec ecx
  jz .read_extra
  and al, 0xC0
  cmp al, 0x80
  jne .wait

  inc edx
  mov al, ah
  out dx, al

  pop ecx
  retn

.read_extra:
  pushad
  mov bl, VGA_RED
  printstr "Floppy: trying to write but FDC expected a read",0xa
  popad
  call floppy_read_data
  jmp .try_again
  


;-----------------------------------------------------------------------.
						floppy_read_data:	;
;;
;; waits for the FDC to be ready, then reads a byte from the data register
;; 
;; parameters:
;; -----------
;; none
;;
;; returned values:
;; ----------------
;; EDX = 0x3F5
;; AL = byte read
;; 

  mov edx, 0x3F4	; main status register
.wait:
  in al, dx
  and al, 0xC0
  cmp al, 0xC0
  jne .wait

  inc edx
  in al, dx

  retn



;-----------------------------------------------------------------------.
						floppy_motor_on:	;
; returns
;
; all unmodified

  pushad
  mov dx, FDC_DOR
  mov al, FDC_DOR_NOT_REST | FDC_DOR_DMA | FDC_DOR_MOTA
  out dx, al
  popad
  retn
  


;-----------------------------------------------------------------------.
						floppy_motor_off:	;
; returns
;
; all unmodified

  pushad
  mov dx, FDC_DOR
  mov al, FDC_DOR_NOT_REST
  out dx, al
  popad
  retn



;-----------------------------------------------------------------------.
						floppy_wait_not_busy:	;
;
; waits until the FDC says it's not executing a command or positioning

  pushad

  mov dx, FDC_MSR
.wait:
  in al, dx
  test al, FDC_MSR_BUSY
  jnz .wait

  popad



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

sct_per_trk:	db SECTORS_PER_TRACK * 2
