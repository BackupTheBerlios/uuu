; Ring Queue Library
; Copyright (C) 2003-2004, Dave Poirier
; Distributed under the BSD license
;
;
; this library offer functionalities to add, remove and browse nodes in a
; ring queue.  A ring queue is a method of organizing data which allow it
; to be browsed or searched in two directions (left or right).
;
; Some advantages of ring queues is that adding a node or removing one does
; not have to make a special case of the "End of List" or "Start of List"
; conditions common in standard queues.
;
; A ring node always have a right and left neighboor.  When that node is
; alone, or when the ring is empty, its left and right neighboors are
; itself.
;







global ringqueue_prepend
ringqueue_prepend:
;--------------------------------------------------------[ prepend to queue ]--
;!<proc brief="Prepend a thread to a ring queue">
;! <p reg="eax" type="pointer" brief="pointer to node to prepend"/>
;! <p reg="ebx" type="pointer" brief="pointer to ring queue"/>
;! <ret fatal="0" brief="prepending successful"/>
;!</proc>
;------------------------------------------------------------------------------
%ifdef RT_SANITY_CHECKS				;-o
 cmp [eax + _ring_queue_t.next], eax		; thread points back to itself?
 jnz short .failed_sanity			; no? failed
 cmp [eax + _ring_queue_t.previous], eax	; thread points back to itself?
 jnz short .failed_sanity			; no? failed
%endif						;--o
						;
  mov ecx, [ebx + _ring_queue_t.next]		; Load first ring member
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp [ecx + _ring_queue_t.previous], ebx	; Make sure member points back
 jnz short .failed_sanity			; ZF=0? guess it doesn't, fail
%endif						;--o
						;
  mov [eax + _ring_queue_t.next], ecx		; set thrd next to 1st member
  mov [eax + _ring_queue_t.previous], ebx	; set thrd previous to head
  mov [ebx + _ring_queue_t.next], eax		; head point to thread
  mov [ecx + _ring_queue_t.previous], eax	; 1st member point to thread
  return					; return to caller
						;
%ifdef RT_SANITY_CHECKS				;-o
 %ifdef RT_SANITY_DEVBENCH
[section .data]					; declare some data
.str:						;
 db .str_end - $ - 1				;
 db "sanity check failed in __prepend_to_queue", 0x0A
 .str_end:					;
__SECT__					; return to code section
.failed_sanity:					;
 mov eax, dword .str	; error message to display
 %else
.failed_sanity:
 %endif
 return
%endif						;--o
;------------------------------------------------------------------------------








global ringqueue_link_ordered
ringqueue_link_ordered:
;---------------------------------------------------[ link to ordered queue ]--
;!<proc>
;! Link a thread into a ordered ring list.  The ordering value for both the
;! ring list members and the thread is a 64bit value located prior to the 
;! ring links.
;! <p reg="eax" type="pointer" brief="pointer to node to link"/>
;! <p reg="ebx" type="pointer" brief="pointer to ring queue"/>
;! <ret fatal="0" brief="linking succeeded"/>
;!</proc>
;------------------------------------------------------------------------------
%ifdef RT_SANITY_CHECKS				;-o
 cmp [eax + _ring_queue_t.next], eax		; thread points back to itself?
 jnz short .failed_sanity			; no? failed
 cmp [eax + _ring_queue_t.previous], eax	; thread points back to itself?
 jnz short .failed_sanity			; no? failed
%endif						;--o
						;
  push edi					; back up current edi
  push esi					; back up current esi
  mov edi, [byte eax - 4]			; load high 32bits
  mov esi, [byte eax - 8]			; complete edi:esi 64bit value
  						;
						; edi:esi is the value by which
						; ordering is decided.  Search
						; for insertion point.
						;
  mov ecx, [ebx + _ring_queue_t.next]		; load first ring member
  mov edx, ebx					; set ref to previous member
.check_complete_round:				;
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp [ecx + _ring_queue_t.previous], edx	; next member points back?
 jnz short .failed_sanity			; if not, invalid next member
%endif						;--o
						;
  cmp ecx, ebx					; did we do a complete round?
  jz short .insert_point_localized		; yes, insert as last member
						;
  cmp edi, [byte ecx - 4]			; compare high 32bits
  jb short .insert_point_localized		; value is lower, insert prior
  cmp esi, [byte ecx - 8]			; compare low 32bits
  jbe short .insert_point_localized		; value is lower or equal
						;
						; greater than current member
						;
  mov edx, ecx					; update ref to previous member
  mov ecx, [ecx + _ring_queue_t.next]		; move to next member
  jmp short .check_complete_round		; attempt another cycle
						;
.insert_point_localized:			; insert between ecx and edx
  pop esi					; restore original esi
  mov [eax + _ring_queue_t.next], ecx		; set thread ring next link
  mov [eax + _ring_queue_t.previous], edx	; set thread ring previous link
  pop edi					; restore original edi
  mov [edx + _ring_queue_t.next], eax		; set ring next to thread
  mov [ecx + _ring_queue_t.previous], eax	; set ring previous to thread
  retn						; return to caller TODO
						;
%ifdef RT_SANITY_CHECKS				;-o
 %ifdef RT_SANITY_DEVBENCH
[section .data]					; declare some data
.str:						;
 db .str_end - $ - 1				;
 db "failed sanity check in __link_to_ordered_queue", 0x0A
 .str_end:					;
__SECT__					; select back the code section
.failed_sanity:					;
 mov [sanity_check_failed.string], dword .str	; error message to display
 jmp sanity_check_failed			; display it
 %else
.failed_sanity:
  %error "return macro not yet included!"	; TODO
 %endif
%endif						;--o
;------------------------------------------------------------------------------




global ringqueue_unlink
ringqueue_unlink:
;-------------------------------------------------------[ unlink from queue ]--
;>
;; Unlink a thread from a ring list.
;;
;;
;; parameters:
;;   eax = pointer to thread ring links
;;
;; returns:
;;   -nothing-
;<
;------------------------------------------------------------------------------
  mov ebx, [eax + _ring_queue_t.next]		; load member after thread
  mov ecx, [eax + _ring_queue_t.previous]	; load member previos to thread
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp [ebx + _ring_queue_t.previous], eax	; next member points to thread?
 jnz short .failed_sanity			; no? well, invalid pointer
 cmp [ecx + _ring_queue_t.next], eax		; prev member points to thread?
 jnz short .failed_sanity			; no? well, invalid pointer
 cmp ebx, eax					; next member = thread?
 jz short .already_unlinked			; yes? oops, did it twice!
%endif						;--o
						;
  mov [ebx + _ring_queue_t.previous], ecx	; close previous ring member
  mov [ecx + _ring_queue_t.next], ebx		; close next ring member
						;
%ifdef RT_SANITY_CHECKS				;-o
 mov [eax + _ring_queue_t.next], eax		; loop back thread next link
 mov [eax + _ring_queue_t.previous], eax	; loop back thread previous lnk
%endif						;--o
						;
  return					; return to the caller
						;
%ifdef RT_SANITY_CHECKS				;-o
 %ifdef RT_SANITY_DEVBENCH			;
[section .data]					; declare some data
.str_failed:					;
 db .end_failed - $ - 1				;
 db "failed sanity check in __unlink_from_queue", 0x0A
 .end_failed:					;
.str_unlinked:					;
 db .end_unlinked - $ - 1			;
 db "thread already unlinked in __unlink_from_queue", 0x0A
 .end_unlinked:					;
__SECT__					; select back the code section
						;
.failed_sanity:					;
 mov [sanity_check_failed.string], dword .str_failed	; error message to display
 jmp sanity_check_failed			; display it
						;
.already_unlinked:				;
 mov [sanity_check_failed.string], dword .str_unlinked	; error message to display
 jmp sanity_check_failed			; display it
 %else						;
.failed_sanity:					;
.already_unlinked:				;
 %endif						;
 return 2					;
%endif						;--o
;------------------------------------------------------------------------------





