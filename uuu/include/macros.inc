; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/include/macros.inc,v 1.3 2003/10/23 03:11:01 bitglue Exp $
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



%endif ;__MACROS_INC__

; vim: syn=nasm
