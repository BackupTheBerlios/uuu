; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/command.asm,v 1.3 2003/10/23 03:11:01 bitglue Exp $
;---------------------------------------------------------------------------==|
; command parsing and builtin commands for the stage2 bootloader
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	Initial version

;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

; thod dumps THOD_GROUPS * THOD_GROUP_SIZE bytes at a time, with an extra space
; every THOD_GROUP_SIZE bytes
%if SCREEN_WIDTH = 360
  %assign THOD_GROUPS	4
%else
  %assign THOD_GROUPS	3
%endif
%assign THOD_GROUP_SIZE	4




;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

parse_command:
  mov esi, command_buffer
  mov ecx, ebp			; ECX = length
  lea ebp, [esi+ebp*4]		; EBP = end of buffer, exclusive

  xor ecx, ecx
  call find_token
  ; ECX = length of token in characters
  ; ESI = ptr to start of token
  test ecx, ecx
  jz start_prompt

  mov edi, builtin_list
  jmp .scan_list

.next_element:
  lea edi, [edi+edx*4+8]	; EDI = ptr to list node
.scan_list:
  mov edx, [edi]		; EDX = length of target string
  test edx, edx
  jz .not_found
  cmp ecx, edx
  jnz .next_element

  pushad
  add edi, byte 4
  repz cmpsd
  popad
  jnz .next_element

  call smooth_scroll_off
  call [edi+edx*4+4]
  jmp start_prompt

.not_found:
  mov bl, VGA_RED
  printstr "command not found",0xa
  ; spill to start_prompt



start_prompt:
  call smooth_scroll_on
  mov bl, VGA_BLUE
  printstr "stage2"
  mov bl, VGA_WHITE
  printstr " > "

.get_key_zero_ebp:
  xor ebp, ebp
.get_key:
  call get_key

  cmp eax, byte 0x20
  jae .add_to_buffer

  cmp eax, byte 0x0a	; ^J, line feed
  jz .nl
  cmp eax, byte 0x0d	; ^M, carriage return
  jz .nl
  cmp eax, byte 0x08	; ^H, backspace
  jz .bs

  jmp .get_key		; unknown control char; ignore

.add_to_buffer:
  mov bl, VGA_WHITE
  call print_char

  mov [command_buffer + ebp*4], eax
  inc ebp

  jmp .get_key

.nl:
  call print_char
  test ebp, ebp
  jz parse_command
  cmp dword[command_buffer + ebp*4 - 4], '\'
  jnz parse_command

  ; just got a \NL; remove the \ and ignore the NL

  mov bl, VGA_WHITE
  printstr "> "
  dec ebp
  jmp .get_key

.bs:
  dec ebp
  js .get_key_zero_ebp
  call print_char
  jmp .get_key



;=============================================================================
								find_token:
;						------------------------------
; isolates a token in a string
;
; ECX = length of previous token in characters
; ESI = ptr to string
; EBP = ptr to end of string, exclusive
;
; returns
;
; ECX = length of token in characters
; ESI = ptr to start of token
; EBP = unmodified
; EAX = destroyed
; everything else unmodified

  lea esi, [esi+ecx*4-4]	; advance ESI past previous token - 4
  xor ecx, ecx			; ECX = 0
				;
				; move ESI past any leading whitespace
.scan_leading_whitespace:	;---------------------------
  add esi, byte 4		; move to next char

  cmp esi, ebp			;
  jz .end			;
				;
  cmp dword[esi], byte ' '	; is it a space?
  jz .scan_leading_whitespace	; if so, eat it
				;
				; find the length of the token
  mov eax, esi
.find_end:			;---------------------------
  inc ecx			;
  add eax, byte 4

  cmp eax, ebp			; 
  jz .end			;
  cmp dword[eax], byte ' '	;
  jnz .find_end			;
				;
.end				;
  retn				;



;=============================================================================
								builtin_echo:
;						------------------------------

  mov bl, VGA_WHITE
.print_token
  call find_token
  test ecx, ecx
  jz .done

  call print_string_len

  mov eax, ' '
  call print_char
  jmp .print_token

.done:
  mov eax, 0xa
  call print_char
  retn



builtin_thod.error:
  mov bl, VGA_WHITE
  printstr "USAGE: thod ADDRESS COUNT",0xa,0xa,"Dumps COUNT bytes of memory at ADDRESS. All numbers",0xa,"are in hex with no leading 0x or trailing ",0x27,"h",0x27,".",0xa
  retn
;=============================================================================
								builtin_thod:
;						------------------------------

  mov bl, VGA_WHITE
.print_token
  call find_token
  test ecx, ecx
  jz .error
  call scan_hex
  jc .error
  mov edi, edx			; EDI = starting address

  call find_token
  test ecx, ecx
  jz .error
  call scan_hex
  jc .error

  call find_token		; should be no more tokens
  test ecx, ecx
  jnz .error

  mov ebp, edx			; EBP = count

  mov bl, VGA_CYAN
  printstr "dumping "
  mov edx, ebp
  call print_hex
  printstr " bytes of ram at "
  mov edx, edi
  call print_hex
  mov eax, 0xa
  call print_char

; this can be used by other commands that want to dump memory
; set EDI = start address; EBP = count
; jmp to this label
..@go_thod:

  push byte CHAR_PER_COL - 1

  test ebp, ebp
  jz .done

  mov bl, VGA_WHITE
.dump_row:
  mov ch, THOD_GROUPS

  mov edx, edi
  call print_hex
  ;mov eax, ' '
  ;call print_char
  ;call print_char
  printstr "  "

.dump_group:
  mov cl, THOD_GROUP_SIZE
.dump_byte:
  mov dl, [edi]
  mov bh, 2
  call print_hex_len

  inc edi
  dec ebp
  jz .done

  dec cl
  jz .next_group

  mov eax, ' '
  call print_char

  jmp .dump_byte

.next_group:
  dec ch
  jz .next_line

  mov eax, ' '
  call print_char
  call print_char
  jmp .dump_group

.next_line:
%if SCREEN_WIDTH != 360
  ; we don't do this when width is 360, because at that width, our output wraps
  ; the display. If we print the newline, we get a blank line between each row.
  mov eax, 0xa
  call print_char
%endif

  dec dword[esp]
  jnz .dump_row

  pushad
  printstr "-MORE-"
  call pcx_refresh

  call get_key
  cmp eax, byte 'q'
  popad
  jz .done

%if SCREEN_WIDTH = 360
  ; however, since we don't print the newline above, we still need to print it
  ; here.
  mov eax, 0xa
  call print_char
%endif

  mov dword[esp], CHAR_PER_COL
  jmp .next_line
  

.done:
  pop eax			; free stack space
  mov eax, 0xa
  call print_char
  retn




;=============================================================================
							builtin_reboot:
;						------------------------------

  mov al, 0xFE
  out 0x64, al
  mov al, 0x01
  out 0x92, al
  ; should have rebooted, but lock to be sure
  cli
  jmp short $



;=============================================================================
								builtin_help:
;						------------------------------
  
[section .data]
.helpstr:
  dd (.end - $ - 4) / 4
  ucs4string "available commands:"
  dd 0xa
  ucs4string "echo - have the computer mock you"
  dd 0xa
  ucs4string "lba2chs - test LBA->CHS conversion for the floppy"
  dd 0xa
  ucs4string "read-ata - read from the primary master ATA device"
  dd 0xa
  ucs4string "read-floppy - read sectors from the floppy"
  dd 0xa
  ucs4string "reboot - for compatibilty with windows machines"
  dd 0xa
  ucs4string "thod - dump memory contents"
  dd 0xa
  dd 0xa
  ucs4string "Note: these commands are here for testing only. If"
  dd 0xa
  ucs4string "you give them invalid inputs and they crash, it is a"
  dd 0xa
  ucs4string "feature, not a bug :)"
  dd 0xa
.end:
__SECT__

  mov bl, VGA_WHITE
  mov esi, .helpstr
  call print_string
  retn



;=============================================================================
								scan_hex:
;						------------------------------
; ESI = ptr to string
; ECX = length of string -- must be nonzero
;
; return
;
; EDX = number
; CF set if the number was improperly formated
; EAX = destroyed
; everything else unmodified

  xor edx, edx
  push ecx

  cmp ecx, byte 8
  ja .error

.read_char
  mov eax, [esi+ecx*4-4]
  cmp eax, byte '0'
  jb .error
  cmp eax, byte '9'
  ja .letter

  lea edx, [edx+eax-'0']
  jmp .next

.letter:
  cmp eax, byte 'A'
  jb .error
  cmp eax, byte 'F'
  ja .lower_letter

  lea edx, [edx+eax-'A'+0xa]
  jmp .next

.lower_letter:
  cmp eax, byte 'a'
  jb .error
  cmp eax, byte 'f'
  ja .error

  lea edx, [edx+eax-'a'+0xa]

.next:
  ror edx, 4
  dec ecx
  jnz .read_char

  pop ecx
  shl ecx, 2
  rol edx, cl
  shr ecx, 2

  clc
  retn

.error:
  stc
  pop ecx
  retn


;-----------------------------------------------------------------------.
						builtin_read_ata:	;
  call find_token
  test ecx, ecx
  jz .usage
  call scan_hex			; EDX = sector to read
  jc .usage

  call find_token
  test ecx, ecx
  jnz .usage

  mov edi, 0x200000
  mov eax, edx			; EAX = sector to read
  xor edx, edx

  call ata_read_sector
  jc .read_error

  mov edi, 0x200000
  mov ebp, 0x200
  jmp ..@go_thod

.read_error:
  push eax
  mov bl, VGA_RED
  printstr "Error reading from ATA, error code "
  pop edx
  mov bh, 2
  call print_hex_len
  mov al, 0xa
  call print_char
  retn

.usage:
  mov bl, VGA_WHITE
  printstr "USAGE: read-ata SECTOR",0xa
  retn



;-----------------------------------------------------------------------.
						builtin_read_floppy:	;
  call find_token
  test ecx, ecx
  jz .error
  call scan_hex
  jc .error			; EDX = LBA

  call find_token
  test ecx, ecx
  jnz .error

  mov eax, edx
  cdq
  mov edi, 0x200000
  lea ecx, [edx+1]

  call floppy_motor_on
  call floppy_read_sectors
  call floppy_motor_off

  mov ebp, 0x200
  mov edi, 0x200000
  jmp ..@go_thod

.error:
  mov bl, VGA_WHITE
  printstr "USAGE: read-floppy SECTOR",0xa,0xa,"Reads and displays SECTOR (LBA) from the floppy.",0xa
  retn



;-----------------------------------------------------------------------.
						builtin_lba2chs:	;

  call find_token
  test ecx, ecx
  jz .error
  call scan_hex
  jc .error

  call find_token
  test ecx, ecx
  jnz .error

  mov eax, edx
  call lba_to_chs
  push eax

  mov edx, ebx		; DL = head; DH = cyl
  xchg dl, dh
  mov bh, 2
  mov bl, VGA_WHITE
  call print_hex_len

  mov eax, '/'
  call print_char

  xchg dl, dh
  mov bh, 2
  call print_hex_len

  mov eax, '/'
  call print_char

  pop edx		; DH = sector
  shr edx, 8
  mov bh, 2
  call print_hex_len

  mov eax, 0xa
  call print_char

  retn

.error:
  mov bl, VGA_WHITE
  printstr "USAGE: lba2chs SECTOR",0xa,0xa,"convert SECTOR (LBA) to cylinder/head/sector for the floppy",0xa
  retn
  


;-----------------------------------------------------------------------.
						builtin_clear:		;

%ifidn BOOT_CONSOLE,graphical
  mov edi, display_buffer
  mov ecx, PLANE_SIZE
  xor eax, eax
  rep stosd
%endif

%ifidn BOOT_CONSOLE,textual
  mov eax, 0x07200720
  mov edi, VIDEO_RAM
  mov ecx, CHAR_PER_COL * CHAR_PER_ROW / 2
  rep stosd
%endif

  xor eax, eax
  mov dword [screen_pos], eax

  retn



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------



align 4

builtin_list:	; a list of all builtin commands, in no particular order

uuustring	"help"
dd		builtin_help

uuustring	"thod"
dd		builtin_thod

uuustring	"reboot"
dd		builtin_reboot

uuustring	"echo"
dd		builtin_echo

uuustring	"read-floppy"
dd		builtin_read_floppy

uuustring	"read-ata"
dd		builtin_read_ata

uuustring	"lba2chs"
dd		builtin_lba2chs

uuustring	"clear"
dd		builtin_clear

dd		0
