; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/memory_manager/x86/noblame.asm,v 1.1 2003/12/26 21:32:55 bitglue Exp $
;
; minimalistic memory allocater, for tempoary and troubleshooting uses.


extern memory_bottom
extern memory_top


section .text

global mem_alloc

mem_alloc:

;! <proc>
;!   <p type="uinteger32" reg="eax" brief="bytes to allocate"/>
;!
;!   <ret brief="allocation successful>
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
jmp $
  jmp [ebx]

.nomem:
  jmp [ebx+4]

section .data

memory_frame:	dd memory_top
