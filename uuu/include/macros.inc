; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/include/macros.inc,v 1.5 2003/12/31 03:22:44 bitglue Exp $
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
 


;-----------------------------------------------------------------------.
;						external procedures	;


%macro ecall 1-*
  %define CONT %%continue

  %if %0 - 1 <> %{1}__ret_count
    %error "incorrect number of return points"
  %endif
  call %1
  %rep %0-1
    %rotate 1
    dd %1
  %endrep
  %%continue:
%endmacro



;-----------------------------------------------------------------------.
;						debugging macros	;

%macro dme 1.nolist	; prints a number to the upper-left corner of screen
  pushfd
  pushad
  mov edx, %{1}
  mov edi, 0xB8000
  extern diable_word_out
  call diable_dword_out
  popad
  popfd
%endmacro

%macro dmeh 1.nolist	; prints a number and waits for <enter>
  pushfd
  pushad
  mov edx, %{1}
  mov edi, 0xB80A0
  extern diable_dword_out_wait
  call diable_dword_out_wait
  popad
  popfd
%endmacro

%macro dmej 1.nolist	; prints a number to the upper-left and locks
  pushfd
  pushad
  mov edx, %{1}
  mov edi, 0xB80A0
  extern diable_dword_out
  call diable_dword_out
  popad
  popfd
  cli
  jmp short $
%endmacro

%macro dbg 1+.nolist    ; a single line %ifdef _DEBUG_ thing
%ifdef _DEBUG_
  %1
%endif
%endmacro



%endif ;__MACROS_INC__

; vim: syn=nasm
