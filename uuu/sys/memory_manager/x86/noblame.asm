; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/memory_manager/x86/noblame.asm,v 1.3 2003/12/31 04:57:34 bitglue Exp $
;
; minimalistic memory allocater, for tempoary and troubleshooting uses.


extern memory_bottom
extern memory_top

global mem_alloc



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						mem.allocate:		;
;! <proc>
;!   <p type="uinteger32" reg="eax" brief="bytes to allocate"/>
;!
;!   <ret brief="allocation successful">
;!     <r type="pointer" reg="eax" brief="pointer to allocated block"/>
;!   </ret>
;!   <ret fatal="1" brief="insufficent memory"/>
;! </proc>

  add eax, byte 3
  and eax, byte -4
  neg eax
  add eax, [memory_frame]
  mov [memory_frame], eax
  pop ebx
  cmp eax, memory_bottom
  jb .nomem
  return

.nomem:
  return 1



;-----------------------------------------------------------------------.
						mem.free:		;
;! <proc>
;!   <p type="pointer" reg="eax" brief="block to free"/>
;!
;!   <ret brief="deallocation successful"/>
;!   <ret fatal="1" brief="no such block exists">
;!     In the case of a debugging memory manager, this may be used to indicate
;!     that an attempt to free a block of memory that doesn't exist, or
;!     previously was not allocated with mem_alloc, was made. However, this is
;!     for debugging only, and this behaviour should not be used under normal
;!     circumstances.
;!   </ret>
;! </proc>

  return


;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

memory_frame:	dd memory_top
