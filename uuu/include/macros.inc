; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/include/macros.inc,v 1.4 2003/10/31 22:29:18 bitglue Exp $
;
; Unununium Operating Engine
; Distributed under the BSD License
;
; Standard macros; included by nearly everything

%ifndef __MACROS_INC__
%define __MACROS_INC__



;-----------------------------------------------------------------------.
;							ucs4string	;

%macro ucs4string 1

  %strlen length %1
  %assign i 0

  %rep length
    %assign i i+1
    %substr char %1 i
    dd char
  %endrep

%endmacro



;-----------------------------------------------------------------------.
;							uuustring	;

%macro uuustring 1-*
  dd (%%end - %%begin) / 4
  %%begin:
  %rep %0
    %ifstr %1
      ucs4string %1
    %else
      dd %1
    %endif
    %rotate 1
  %endrep
  %%end:
%endmacro



;-----------------------------------------------------------------------.
;							return		;

; by default, return to the first entry using ebx

%macro return 0
  pop ebx
  jmp [ebx]
%endmacro


; to return to any entry, but still use ebx

%macro return 1
  pop ebx
  jmp [ebx+%1*4]
%endmacro


; to return to any entry using any register. Note that general Uuu calling
; conventions say that EBP, ESI, and EDI must be unchanged across function
; calls.

%macro return 2
  pop %2
  jmp [%2+%1*4]
%endmacro
 


%endif ;__MACROS_INC__

; vim: syn=nasm
