;****************************************************************************
;*
;*                  SciTech SNAP Device Driver Architecture
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
;* Environment: IBM PC 32 bit Protected Mode.
;*
;* Description: Assembly support functions for the SNAP library for
;*              the high resolution timing support functions provided by
;*              the Intel Pentium and compatible processors.
;*
;****************************************************************************

include "scitech.mac"           ; Memory model macros

header  _gatimer

begcodeseg  _gatimer

%macro mCPU_ID 0
db  00Fh,0A2h
%endmacro

%macro mRDTSC 0
db  00Fh,031h
%endmacro

;----------------------------------------------------------------------------
; bool _GA_haveCPUID(void)
;----------------------------------------------------------------------------
; Determines if we have support for the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _GA_haveCPUID

        enter_c
        pushfd                      ; Get original EFLAGS
        pop     eax
        mov     ecx, eax
        xor     eax, 200000h        ; Flip ID bit in EFLAGS
        push    eax                 ; Save new EFLAGS value on stack
        popfd                       ; Replace current EFLAGS value
        pushfd                      ; Get new EFLAGS
        pop     eax                 ; Store new EFLAGS in EAX
        xor     eax, ecx            ; Can not toggle ID bit,
        jnz     @@1                 ; Processor=80486
        mov     eax,0               ; We dont have CPUID support
        jmp     @@Done
@@1:    mov     eax,1               ; We have CPUID support
@@Done: leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; uint _GA_getCPUIDFeatures(void)
;----------------------------------------------------------------------------
; Determines the CPU type using the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _GA_getCPUIDFeatures

        enter_c

        xor     eax, eax            ; Set up for CPUID instruction
        mCPU_ID                     ; Get and save vendor ID
        cmp     eax, 1              ; Make sure 1 is valid input for CPUID
        jl      @@Fail              ; We dont have the CPUID instruction
        xor     eax, eax
        inc     eax
        mCPU_ID                     ; Get family/model/stepping/features
        mov     eax, edx
@@Done: leave_c
        ret

@@Fail: xor     eax,eax
        jmp     @@Done

cprocend

;----------------------------------------------------------------------------
; void  _GA_readTimeStamp(GA_largeInteger *time)
;----------------------------------------------------------------------------
; Reads the time stamp counter and returns the 64-bit result.
;----------------------------------------------------------------------------
cprocstart  _GA_readTimeStamp

        mRDTSC
        mov     ecx,[esp+4]     ; Access directly without stack frame
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; N_uint32 GA_TimerDifference(GA_largeInteger *a,GA_largeInteger *b)
;----------------------------------------------------------------------------
; Computes the difference between two 64-bit numbers (a-b)
;----------------------------------------------------------------------------
cprocstart  GA_TimerDifference

        ARG     a:DPTR, b:DPTR, t:DPTR

        enter_c

        mov     ecx,[a]
        mov     eax,[ecx]       ; EAX := b.low
        mov     ecx,[b]
        sub     eax,[ecx]
        mov     edx,eax         ; EDX := low difference
        mov     ecx,[a]
        mov     eax,[ecx+4]     ; ECX := b.high
        mov     ecx,[b]
        sbb     eax,[ecx+4]     ; EAX := high difference
        mov     eax,edx         ; Return low part

        leave_c
        ret

cprocend

; Macro to delay briefly to ensure that enough time has elapsed between
; successive I/O accesses so that the device being accessed can respond
; to both accesses even on a very fast PC.

%macro  DELAY_TIMER 0
        jmp     short $+2
        jmp     short $+2
        jmp     short $+2
%endmacro

;----------------------------------------------------------------------------
; void _OS_delay8253(N_uint32 microSeconds);
;----------------------------------------------------------------------------
; Delays for the specified number of microseconds, by directly programming
; the 8253 timer chips.
;----------------------------------------------------------------------------
cprocstart  _OS_delay8253

        ARG     microSec:UINT

        enter_c

; Start timer 2 counting

        mov     _ax,[microSec]      ; EAX := count in microseconds
        mov     ecx,1196
        mul     ecx
        mov     ecx,1000
        div     ecx
        mov     ecx,eax             ; ECX := count in timer ticks
        in      al,61h
        or      al,1
        out     61h,al

; Set the timer 2 count to 0 again to start the timing interval.

        mov     al,10110100b        ; set up to load initial (timer 2)
        out     43h,al              ; timer count
        DELAY_TIMER
        sub     al,al
        out     42h,al              ; load count lsb
        DELAY_TIMER
        out     42h,al              ; load count msb
        xor     di,di               ; Allow max 64K loop iterations

@@LoopStart:
        dec     di                  ; This is a guard against the possibility that
        jz      @@LoopEnd           ; someone eg. stopped the timer behind our back.
                                    ; After 64K iterations we bail out no matter what
                                    ; (and hope it wasn't too soon)
        mov     al,00000000b        ; latch timer 0
        out     43h,al
        DELAY_TIMER
        in      al,42h              ; least significant byte
        DELAY_TIMER
        mov     ah,al
        in      al,42h              ; most significant byte
        xchg    ah,al
        neg     ax                  ; Convert from countdown remaining
                                    ;  to elapsed count
        cmp     ax,cx               ; Has delay expired?
        jb      @@LoopStart         ; No, so loop till done

; Stop timer 2 from counting
@@LoopEnd:
        in      al,61H
        and     al,0FEh
        out     61H,al

; Some programs have a problem if we change the control port; better change it
; to something they expect (mode 3 - square wave generator)...
        mov     al,0B6h
        out     43h,al

        leave_c
        ret

cprocend

endcodeseg  _gatimer

        END

