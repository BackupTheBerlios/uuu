; Unununium Operating Engine
; Distributed under the BSD License

%ifndef __MACROS_INC__
%define __MACROS_INC__

%macro ucs4string 1

  %strlen length %1
  %assign i 0

  %rep length
    %assign i i+1
    %substr char %1 i
    dd char
  %endrep

%endmacro


%macro uuustring 1-*
  %rep %0
    %ifstr %1
      ucs4string %1
    %else
      dd %1
    %endif
    %rotate 1
  %endrep
%endmacro

%endif	;__MACROS_INC__

; vim: syn=nasm
