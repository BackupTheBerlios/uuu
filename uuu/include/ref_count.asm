; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/include/ref_count.asm,v 1.2 2003/12/31 20:16:55 bitglue Exp $

%ifndef __REF_COUNT_INCLUDE__
%define __REF_COUNT_INCLUDE__


struc ref_counted
  .ref:		resd 1
  .destroy:	resd 1
endstruc


;! <proc name="ref_counted.destroy">
;!   All procedures used in ref_counted.destroy conform to this interface.
;!
;!   <p type="pointer" reg="eax" brief="object to destroy"/>
;!
;!   <ret brief="success"/>
;!   <ret brief="other"/>
;! </proc>


;-----------------------------------------------------------------------.
;						dec_ref			;

; decrement the reference count of something, and if it reaches 0, call the
; destructor. Because it may call a procedures, the normal rules concerning
; register preservation across procedure calls apply.
;
; usage: dec_ref OBJECT, SUCCESS, OTHER
;
; OBJECT is a pointer to the object of which to decrement the reference count.
; It must be either an immediate label or a register.
;
; SUCCESS is the return point in the case that the destructor was called and
; succeeded. In the style of ecall, it may be "CONT".
;
; OTHER is the return point in the case that the destructor was called and
; returned other, or if something bad happened, such as an attempt to
; decrement the count past zero was made. In the style of ecall, it may be
; "CONT".
;
; If the count is decremented and does not reach zero, the destructor is not
; called and execution continues to the instruction following the macro.

%macro dec_ref 3
  dec dword[%1+ref_counted.ref]
  jz %%nonzero
%ifdef SANITY_CHECKS
  jc %3
%endif

  %define CONT %%nonzero

  mov eax, %1
  call [eax+ref_counted.destroy]
  dd %2
  dd %3

  %%nonzero:
%endmacro

%endif
