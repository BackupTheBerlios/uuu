; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/include/ref_count.asm,v 1.1 2003/12/31 19:50:20 bitglue Exp $

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

%endif
