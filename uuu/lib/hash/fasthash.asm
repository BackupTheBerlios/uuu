;; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/lib/hash/fasthash.asm,v 1.2 2004/01/01 02:16:48 bitglue Exp $
;;
;; Fasthash - a lib cell providing a fast hash function for hash table lookups
;; Copyright (C) 2001 by Phil Frost.
;; This software may be distributed under the terms of the BSD license.
;; See file 'licence' for details.
;;
;; The hashing function provided in this cell kicks ass :) It was created by
;; Bob Jenkins in 1996. [http://burtleburtle.net/bob/hash/doobs.html] You rock
;; Bob!
;;
;; This is a fast, very good hash function, but it is no good for cryptographic
;; purposes because the hash is easily reversed. Use it in your hash lookup
;; tables and such and be happy :P
;;
;; status:
;; -------
;; i'm 75% sure it is a propper implementation of the hash function. In any
;; case you will get a value, I just don't know if it's the "propper" one yet
;; :P



global lib.string.fasthash



;---------------===============\      /===============---------------
;				macros
;---------------===============/      \===============---------------

%macro mix 0
; mixes eax, ebx, and edx
; todo: optimize?

  sub eax, ebx
  mov ebp, edx
  sub eax, edx
  shr ebp, 13

  sub ebx, edx
  xor eax, ebp
  mov edi, eax
  sub edx, eax
  shl edi, 8
  
  sub edx, eax
  xor ebx, edi
  mov ebp, ebx
  sub edx, ebx
  shr ebp, 13
  
  sub eax, ebx
  xor edx, ebp
  mov edi, edx
  sub eax, edx
  shr edi, 12

  sub ebx, edx
  xor eax, edi
  mov ebp, eax
  sub edx, eax
  shl ebp, 16
  
  sub edx, eax
  xor ebx, ebp
  mov edi, ebx
  sub edx, ebx
  shr edi, 5
  
  sub eax, ebx
  xor edx, edi
  mov ebp, edx
  sub eax, edx
  shr ebp, 3

  sub ebx, edx
  xor eax, ebp
  mov edi, eax
  sub edx, eax
  shl edi, 10
  
  sub edx, eax
  xor ebx, edi
  mov ebp, ebx
  sub edx, ebx
  shr ebp, 15
  xor edx, ebp
%endmacro



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------


;-----------------------------------------------------------------------.
						lib.hash.fasthash:	;
;! <proc>
;!   Computes a fast, very nice hash sutiable for non cryptographic purposes.
;!   See http://burtleburtle.net/bob/hash/doobs.html for credits.
;!
;!   <p reg="eax" type="pointer" brief="the key, a string of arbitrary
;!   bytes"/>
;!   <p reg="ebx" type="uinteger32" brief="seed"/>
;!   <p reg="ecx" type="uinteger32" brief="length of the key">
;!     This can be used to hash a key in multiple steps by using the result of
;!     a previous run as the seed for the next. For the initial call, it may
;!     be any value, provided it is always the same, for otherwise the same
;!     result won't be provided.
;!   </p>
;!
;!   <ret brief="success">
;!     <r reg="eax" type="uinteger32" brief="hash of given key"/>
;!   </ret>
;! </proc>
  
  pushad

  mov esi, eax
  mov edx, ebx
  
  mov eax, 0x9e3779b9	; init to an arbitrary value

  ; first hack away at the string 12 bytes at a time
  cmp ecx, 12
  mov ebx, eax		; init to an arbitrary value
  jb near .last_bytes

.do_12_bytes:
  movzx ebp, byte[esi+1]
  shl ebp, 8
  movzx edi, byte[esi+2]
  shl edi, 16
  add ebp, edi
  movzx edi, byte[esi+3]
  shl edi, 24
  add ebp, edi
  movzx edi, byte[esi]
  add ebp, edi
  add eax, ebp
  
  movzx ebp, byte[esi+5]
  shl ebp, 8
  movzx edi, byte[esi+6]
  shl edi, 16
  add ebp, edi
  movzx edi, byte[esi+7]
  shl edi, 24
  add ebp, edi
  movzx edi, byte[esi+4]
  add ebp, edi
  add ebx, ebp
  
  movzx ebp, byte[esi+9]
  shl ebp, 8
  movzx edi, byte[esi+10]
  shl edi, 16
  add ebp, edi
  movzx edi, byte[esi+11]
  shl edi, 24
  add ebp, edi
  movzx edi, byte[esi+8]
  add ebp, edi
  add edx, ebp

  mix

  add esi, byte 12
  sub ecx, byte 12
  cmp ecx, byte 12
  jae .do_12_bytes

  ; now finish up the last bytes, up to 11 of them
.last_bytes:
  add edx, [esp+24]	; add legnth from call

  jmp [jmp_table+ecx*4]
  
.11:
  movzx ebp, byte[esi+10]
  shl ebp, 24
  add edx, ebp
.10:
  movzx ebp, byte[esi+9]
  shl ebp, 16
  add edx, ebp
.9:
  movzx ebp, byte[esi+8]
  shl ebp, 8
  add edx, ebp
.8:
  movzx ebp, byte[esi+7]
  shl ebp, 24
  add ebx, ebp
.7:
  movzx ebp, byte[esi+6]
  shl ebp, 16
  add ebx, ebp
.6:
  movzx ebp, byte[esi+5]
  shl ebp, 8
  add ebx, ebp
.5:
  movzx ebp, byte[esi+4]
  add ebx, ebp
.4:
  movzx ebp, byte[esi+3]
  shl ebp, 24
  add eax, ebp
.3:
  movzx ebp, byte[esi+2]
  shl ebp, 16
  add eax, ebp
.2:
  movzx ebp, byte[esi+1]
  shl ebp, 8
  add eax, ebp
.1:
  movzx ebp, byte[esi]
  add eax, ebp
.0:

  mix

  mov [esp+28], edx
  popad
  
  retn

;                                           -----------------------------------
;                                                                          data
;==============================================================================

section .data
jmp_table:
dd lib.hash.fasthash.0, lib.hash.fasthash.1, lib.hash.fasthash.2
dd lib.hash.fasthash.3, lib.hash.fasthash.4, lib.hash.fasthash.5
dd lib.hash.fasthash.6, lib.hash.fasthash.7, lib.hash.fasthash.8
dd lib.hash.fasthash.9, lib.hash.fasthash.10, lib.hash.fasthash.11
