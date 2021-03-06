;****************************************************************************
;*
;*                  SciTech OS Portability Manager Library
;*
;*  ========================================================================
;*
;*   Copyright (C) 1991-2002 SciTech Software, Inc. All rights reserved.
;*
;*   This file may be distributed and/or modified under the terms of the
;*   GNU Lesser General Public License version 2.1 as published by the Free
;*   Software Foundation and appearing in the file LICENSE.LGPL included
;*   in the packaging of this file.
;*
;*   Licensees holding a valid Commercial License for this product from
;*   SciTech Software, Inc. may use this file in accordance with the
;*   Commercial License Agreement provided with the Software.
;*
;*   This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING
;*   THE WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
;*   PURPOSE.
;*
;*   See http://www.scitechsoft.com/license/ for information about
;*   the licensing options available and how to purchase a Commercial
;*   License Agreement.
;*
;*   Contact license@scitechsoft.com if any conditions of this licensing
;*   are not clear to you, or you have questions about licensing options.
;*
;*  ========================================================================
;*
;* Language:    NASM
;* Environment: Intel 32 bit Protected Mode.
;*
;* Description: Code for 64-bit arhithmetic
;*
;****************************************************************************

include "scitech.mac"

header      _int64

begcodeseg  _int64                  ; Start of code segment

a_low       EQU 04h                 ; Access a_low directly on stack
a_high      EQU 08h                 ; Access a_high directly on stack
b_low       EQU 0Ch                 ; Access b_low directly on stack
shift       EQU 0Ch                 ; Access shift directly on stack
result_2    EQU 0Ch                 ; Access result directly on stack
b_high      EQU 10h                 ; Access b_high directly on stack
result_3    EQU 10h                 ; Access result directly on stack
result_4    EQU 14h                 ; Access result directly on stack

;----------------------------------------------------------------------------
; void _PM_add64(u32 a_low,u32 a_high,u32 b_low,u32 b_high,__u64 *result);
;----------------------------------------------------------------------------
; Adds two 64-bit numbers.
;----------------------------------------------------------------------------
cprocstart  _PM_add64

        mov     eax,[esp+a_low]
        add     eax,[esp+b_low]
        mov     edx,[esp+a_high]
        adc     edx,[esp+b_high]
        mov     ecx,[esp+result_4]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; void _PM_sub64(u32 a_low,u32 a_high,u32 b_low,u32 b_high,__u64 *result);
;----------------------------------------------------------------------------
; Subtracts two 64-bit numbers.
;----------------------------------------------------------------------------
cprocstart  _PM_sub64

        mov     eax,[esp+a_low]
        sub     eax,[esp+b_low]
        mov     edx,[esp+a_high]
        sbb     edx,[esp+b_high]
        mov     ecx,[esp+result_4]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; void _PM_mul64(u32 a_high,u32 a_low,u32 b_high,u32 b_low,__u64 *result);
;----------------------------------------------------------------------------
; Multiples two 64-bit numbers.
;----------------------------------------------------------------------------
cprocstart  _PM_mul64

        mov     eax,[esp+a_high]
        mov     ecx,[esp+b_high]
        or      ecx,eax
        mov     ecx,[esp+b_low]
        jnz     @@FullMultiply
        mov     eax,[esp+a_low]         ; EDX:EAX = b.low * a.low
        mul     ecx
        mov     ecx,[esp+result_4]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

@@FullMultiply:
        push    ebx
        mul     ecx                     ; EDX:EAX = a.high * b.low
        mov     ebx,eax
        mov     eax,[esp+a_low+4]
        mul     [DWORD esp+b_high+4]    ; EDX:EAX = b.high * a.low
        add     ebx,eax
        mov     eax,[esp+a_low+4]
        mul     ecx                     ; EDX:EAX = a.low * b.low
        add     edx,ebx
        pop     ebx
        mov     ecx,[esp+result_4]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; void _PM_div64(u32 a_low,u32 a_high,u32 b_low,u32 b_high,__u64 *result);
;----------------------------------------------------------------------------
; Divides two 64-bit numbers.
;----------------------------------------------------------------------------
cprocstart  _PM_div64

        push    edi
        push    esi
        push    ebx
        xor     edi,edi
        mov     eax,[esp+a_high+0Ch]
        or      eax,eax
        jns     @@ANotNeg

; Dividend is negative, so negate it and save result for later

        inc     edi
        mov     edx,[esp+a_low+0Ch]
        neg     eax
        neg     edx
        sbb     eax,0
        mov     [esp+a_high+0Ch],eax
        mov     [esp+a_low+0Ch],edx

@@ANotNeg:
        mov     eax,[esp+b_high+0Ch]
        or      eax,eax
        jns     @@BNotNeg

; Divisor is negative, so negate it and save result for later

        inc     edi
        mov     edx,[esp+b_low+0Ch]
        neg     eax
        neg     edx
        sbb     eax,0
        mov     [esp+b_high+0Ch],eax
        mov     [esp+b_low+0Ch],edx

@@BNotNeg:
        or      eax,eax
        jnz     @@BHighNotZero

; b.high is zero, so handle this faster

        mov     ecx,[esp+b_low+0Ch]
        mov     eax,[esp+a_high+0Ch]
        xor     edx,edx
        div     ecx
        mov     ebx,eax
        mov     eax,[esp+a_low+0Ch]
        div     ecx
        mov     edx,ebx
        jmp     @@BHighZero

@@BHighNotZero:
        mov     ebx,eax
        mov     ecx,[esp+b_low+0Ch]
        mov     edx,[esp+a_high+0Ch]
        mov     eax,[esp+a_low+0Ch]

; Shift values right until b.high becomes zero

@@ShiftLoop:
        shr     ebx,1
        rcr     ecx,1
        shr     edx,1
        rcr     eax,1
        or      ebx,ebx
        jnz     @@ShiftLoop

; Now complete the divide process

        div     ecx
        mov     esi,eax
        mul     [DWORD esp+b_high+0Ch]
        mov     ecx,eax
        mov     eax,[esp+b_low+0Ch]
        mul     esi
        add     edx,ecx
        jb      @@8
        cmp     edx,[esp+a_high+0Ch]
        ja      @@8
        jb      @@9
        cmp     eax,[esp+a_low+0Ch]
        jbe     @@9
@@8:    dec     esi
@@9:    xor     edx,edx
        mov     eax,esi

@@BHighZero:
        dec     edi
        jnz     @@Done

; The result needs to be negated as either a or b was negative

        neg     edx
        neg     eax
        sbb     edx,0

@@Done: pop     ebx
        pop     esi
        pop     edi
        mov     ecx,[esp+result_4]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; __i64 _PM_shr64(u32 a_low,s32 a_high,s32 shift,__u64 *result);
;----------------------------------------------------------------------------
; Shift a 64-bit number right
;----------------------------------------------------------------------------
cprocstart  _PM_shr64

        mov     eax,[esp+a_low]
        mov     edx,[esp+a_high]
        mov     cl,[esp+shift]
        shrd    edx,eax,cl
        mov     ecx,[esp+result_3]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; __i64 _PM_sar64(u32 a_low,s32 a_high,s32 shift,__u64 *result);
;----------------------------------------------------------------------------
; Shift a 64-bit number right (signed)
;----------------------------------------------------------------------------
cprocstart  _PM_sar64

        mov     eax,[esp+a_low]
        mov     edx,[esp+a_high]
        mov     cl,[esp+shift]
        sar     edx,cl
        rcr     eax,cl
        mov     ecx,[esp+result_3]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; __i64 _PM_shl64(u32 a_low,s32 a_high,s32 shift,__u64 *result);
;----------------------------------------------------------------------------
; Shift a 64-bit number left
;----------------------------------------------------------------------------
cprocstart  _PM_shl64

        mov     eax,[esp+a_low]
        mov     edx,[esp+a_high]
        mov     cl,[esp+shift]
        shld    edx,eax,cl
        mov     ecx,[esp+result_3]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; __i64 _PM_neg64(u32 a_low,s32 a_high,__u64 *result);
;----------------------------------------------------------------------------
; Shift a 64-bit number left
;----------------------------------------------------------------------------
cprocstart  _PM_neg64

        mov     eax,[esp+a_low]
        mov     edx,[esp+a_high]
        neg     eax
        neg     edx
        sbb     eax,0
        mov     ecx,[esp+result_2]
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend


endcodeseg  _int64

        END
