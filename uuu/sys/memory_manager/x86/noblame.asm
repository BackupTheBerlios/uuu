; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/memory_manager/x86/noblame.asm,v 1.6 2004/01/08 22:05:52 bitglue Exp $
;
; minimalistic memory allocater, for tempoary and troubleshooting uses.


extern memory_bottom
extern memory_top

global mem.allocate
global mem.allocate_bare
global mem.deallocate
global mem.reallocate



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						mem.allocate:		;
;! <proc brief="allocates a block of memory">
;!   This differs from traditional allocation in that it assumes by default
;!   the memory block uses some sort of reference counting and has a pointer
;!   to a procedure to destroy the object.. What this means is that the first
;!   dword is set to 1 automatically, and the 2nd is set to mem.deallocate.
;!   The size parameter includes this first dword, so a size under 4 is an
;!   error.
;!
;!   <p type="uinteger32" reg="eax" brief="bytes to allocate"/>
;!
;!   <ret brief="allocation successful">
;!     <r type="pointer" reg="eax" brief="pointer to allocated block"/>
;!   </ret>
;!
;!   <ret fatal="1" brief="insufficent memory"/>
;!
;!   <ret brief="other"/>
;! </proc>

  cmp eax, byte 4
  jbe .other

  ecall mem.allocate_bare, CONT, .other, .no_mem
  mov [eax+ref_counted.ref], dword 1
  mov [eax+ref_counted.destroy], dword mem.deallocate
  return

.other:
  return 2

.no_mem:
  return 1



;-----------------------------------------------------------------------.
						mem.allocate_bare:	;
;! <proc>
;!   This allocates a block of memory with no embelishments. Contrast to
;!   mem.allocate.
;!
;!   <p type="uinteger32" reg="eax" brief="bytes to allocate"/>
;!
;!   <ret brief="allocation successful">
;!     <r type="pointer" reg="eax" brief="pointer to allocated block"/>
;!   </ret>
;!
;!   <ret fatal="1" brief="insufficent memory"/>
;!
;!   <ret brief="other"/>
;! </proc>

  test eax, eax
  jz .other

  add eax, byte 3
  and eax, byte -4
  neg eax
  add eax, [memory_frame]
  mov [memory_frame], eax

  cmp eax, memory_bottom
  jb .nomem
  return

.nomem:
  return 1

.other:
  return 2



;-----------------------------------------------------------------------.
						mem.deallocate:		;
;! <proc>
;!   <p type="pointer" reg="eax" brief="block to free"/>
;!
;!   <ret brief="deallocation successful"/>
;!
;!   <ret brief="other"/>
;! </proc>

  cmp eax, memory_top
  jae .other
  cmp eax, memory_bottom
  jb .other
  return

.other:
  return 1



;-----------------------------------------------------------------------.
						mem.reallocate:		;
;! <proc>
;!   This reallocates a block of memory, the idea being one can change the
;!   size of a previously allocated block. However, it may not be possible to
;!   resize the block, so often the block returned is not the same as the
;!   block requested. In this case, reallocate acts as if the old block were
;!   freed, and a new one allocated, except the data is copied from the old to
;!   the new.
;!
;!   <p type="uinteger32" reg="eax" brief="new size"/>
;!   <p type="pointer" reg="ebx" brief="block to reallocate"/>
;!
;!   <ret brief="block resized">
;!     This is used in the (uncommon) case that the memory manager was able to
;!     resize the block without moving it. Some can do this when the new size
;!     is smaller than the old, and few can do it when making the block
;!     larger.
;!
;!     <r type="pointer" reg="eax" brief="pointer to new block, which is
;!     always the same as the old in this case"/>
;!   </ret>
;!
;!   <ret brief="block moved">
;!     This is used in the (more common) case that the block had to be
;!     reallocated and moved.
;!
;!     <r type="pointer" reg="eax" brief="pointer to new block"/>
;!   </ret>
;!
;!   <ret fatal="1" brief="insufficient memory"/>
;!
;!   <ret brief="other"/>
;! </proc>

  push esi
  push edi

  push eax
  mov esi, ebx
  ecall mem.allocate, CONT, .no_mem, .other

  pop ecx
  mov edi, eax
  rep movsb

  pop edi
  pop esi

  return 1

.no_mem:
  return 2

.other:
  return 3



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

memory_frame:	dd memory_top
