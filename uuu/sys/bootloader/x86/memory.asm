; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/memory.asm,v 1.1 2003/09/23 03:46:22 bitglue Exp $
;---------------------------------------------------------------------------==|
; tempoary memory manager for the stage2 bootloader
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-09-22	Phil Frost	Initial version


%assign RAM_MEGS	4

; ammount of ram to leave at the begining of ram allocations, to be used by the
; memory manager when it's loaded

%assign MEMORY_HEADER_SPACE	0


; the maximum number of allocations the tempoary memory manager can do before
; puking. This needs to be enough to load the IRQ, thread, and memory
; components. If this number is exceeded, the system panics.

%assign MAX_MEMORY_ALLOCATIONS	0x10


; allocate memory in sizes that are multiples of this. MEMORY_HEADER_SPACE is
; added to the total size _after_ aligning to this size.

%assign MEMORY_ALIGN	4


;=============================================================================
								section .text
;						------------------------------



;=============================================================================
								temp_malloc:
;						------------------------------
; this is used to allocate memory before the memory manager has been loaded. It
; works by simply allocating from the top of memory downward. It records the
; allocations made so they can be later transfered to the memory manager.
;
; ecx = size of memory block required
; returns:
; edi = pointer to memory block allocated

  push ecx

  add ecx, MEMORY_ALIGN - 1
  mov edi, [memory_top]
  and ecx, -MEMORY_ALIGN
  sub edi, ecx

  mov eax, [memory_alloc_count]
  cmp eax, MAX_MEMORY_ALLOCATIONS
  jae .too_many_allocs

  mov [memory_allocs + eax * 8], edi
  mov [memory_allocs + eax * 8 + 4], ecx
  inc eax
  mov [memory_alloc_count], eax

  sub edi, byte MEMORY_HEADER_SPACE
  mov [memory_top], edi
  add edi, byte MEMORY_HEADER_SPACE

  pop ecx
  retn

.too_many_allocs:
  go_panic "too many memory allocations made",0xa



;=============================================================================
							print_mem_stats:
;						------------------------------

  mov edx, [memory_alloc_count]
  mov bl, VGA_CYAN
  call print_hex
  printstr " memory allocations made:",0xa

  test edx, edx
  jz start_prompt
  xor ecx, ecx
  mov ebp, edx
  mov bl, VGA_WHITE
.dump_memory_alloc:
  mov edx, [memory_allocs + ecx * 8 + 4]
  call print_hex
  printstr " bytes at "
  mov edx, [memory_allocs + ecx * 8]
  call print_hex
  mov al, 0xa
  call print_char

  inc ecx
  cmp ecx, ebp
  jnz .dump_memory_alloc

  retn



;=============================================================================
								section .data
;						------------------------------

align 4

; pointer to the top of free memory; this is moved down after each allocation
memory_top: dd (RAM_MEGS * 0x100000) - MEMORY_HEADER_SPACE

; the number of memory allocations that have been done
memory_alloc_count:	dd 0


;=============================================================================
								section .bss
;						------------------------------

alignb 4
; a list of tuples, (location, size) of each memory allocation done
memory_allocs:		resd MAX_MEMORY_ALLOCATIONS * 2
