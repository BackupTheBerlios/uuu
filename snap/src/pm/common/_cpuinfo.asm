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
;* Description: Code to determine the Intel processor type.
;*
;****************************************************************************

include "scitech.mac"

header      _cpuinfo

begdataseg  _cpuinfo                ; Start of data segment

cache_id    db  "01234567890123456"
intel_id    db  "GenuineIntel"      ; Intel vendor ID
cyrix_id    db  "CyrixInstead"      ; Cyrix vendor ID
amd_id      db  "AuthenticAMD"      ; AMD vendor ID
idt_id      db  "CentaurHauls"      ; IDT vendor ID
geode_id    db  "Geode by NSC"      ; NSC/Geode vendor ID

CPU_IDT     EQU 01000h              ; Flag for IDT processors
CPU_Cyrix   EQU 02000h              ; Flag for Cyrix processors
CPU_AMD     EQU 04000h              ; Flag for AMD processors
CPU_Intel   EQU 08000h              ; Flag for Intel processors
CPU_VIA     EQU 10000h              ; Flag for VIA processors
CPU_Geode   EQU 20000h              ; Flag for NSC/Geode processors

enddataseg  _cpuinfo

begcodeseg  _cpuinfo                ; Start of code segment

%macro mCPU_ID 0
db  00Fh,0A2h
%endmacro

%macro mRDTSC 0
db  00Fh,031h
%endmacro

;----------------------------------------------------------------------------
; bool _CPU_check80386(void)
;----------------------------------------------------------------------------
; Determines if we have an i386 processor.
;----------------------------------------------------------------------------
cprocstart  _CPU_check80386

        enter_c

        xor     edx,edx             ; EDX = 0, not an 80386
        mov     bx, sp
        and     sp, ~3
        pushfd                      ; Push original EFLAGS
        pop     eax                 ; Get original EFLAGS
        mov     ecx, eax            ; Save original EFLAGS
        xor     eax, 40000h         ; Flip AC bit in EFLAGS
        push    eax                 ; Save new EFLAGS value on
                                    ;   stack
        popfd                       ; Replace current EFLAGS value
        pushfd                      ; Get new EFLAGS
        pop     eax                 ; Store new EFLAGS in EAX
        xor     eax, ecx            ; Can't toggle AC bit,
                                    ;   processor=80386
        jnz     @@Done              ; Jump if not an 80386 processor
        inc     edx                 ; We have an 80386

@@Done: push    ecx
        popfd
        mov     sp, bx
        mov     eax, edx
        leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; bool _CPU_check80486(void)
;----------------------------------------------------------------------------
; Determines if we have an i486 processor.
;----------------------------------------------------------------------------
cprocstart  _CPU_check80486

        enter_c

; Distinguish between the i486 and Pentium by the ability to set the ID flag
; in the EFLAGS register. If the ID flag is set, then we can use the CPUID
; instruction to determine the final version of the chip. Otherwise we
; simply have an 80486.

; Distinguish between the i486 and Pentium by the ability to set the ID flag
; in the EFLAGS register. If the ID flag is set, then we can use the CPUID
; instruction to determine the final version of the chip. Otherwise we
; simply have an 80486.

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
        mov     eax,1               ; We dont have a Pentium
        jmp     @@Done
@@1:    mov     eax,0               ; We have Pentium or later
@@Done: leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; bool _CPU_checkClone(void)
;----------------------------------------------------------------------------
; Checks if the i386 or i486 processor is a clone or genuine Intel.
;----------------------------------------------------------------------------
cprocstart  _CPU_checkClone

        enter_c

        mov     ax,5555h            ; Check to make sure this is a 32-bit processor
        xor     dx,dx
        mov     cx,2h
        div     cx                  ; Perform Division
        clc
        jnz     @@NoClone
        jmp     @@Clone
@@NoClone:
        stc
@@Clone:
        pushfd
        pop     eax                 ; Get the flags
        and     eax,1
        xor     eax,1               ; EAX=0 is probably Intel, EAX=1 is a Clone

        leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; bool _CPU_haveCPUID(void)
;----------------------------------------------------------------------------
; Determines if we have support for the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _CPU_haveCPUID

        enter_c

ifdef flatmodel
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
else
        mov     eax,0               ; CPUID requires 32-bit pmode
endif
@@Done: leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; uint _CPU_checkCPUID(void)
;----------------------------------------------------------------------------
; Determines the CPU type using the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _CPU_checkCPUID

        enter_c

        xor     eax, eax            ; Set up for CPUID instruction
        mCPU_ID                     ; Get and save vendor ID
        cmp     eax, 1              ; Make sure 1 is valid input for CPUID
        jl      @@Fail              ; We dont have the CPUID instruction
        xor     eax,eax             ; Assume vendor is unknown

; Check for GenuineIntel processors

        LEA_L   esi,intel_id
        cmp     [DWORD esi], ebx
        jne     @@NotIntel
        cmp     [DWORD esi+4], edx
        jne     @@NotIntel
        cmp     [DWORD esi+8], ecx
        jne     @@NotIntel
        mov     eax,CPU_Intel       ; Flag that we have GenuineIntel
        jmp     @@FoundVendor

; Check for CyrixInstead processors

@@NotIntel:
        LEA_L   esi,cyrix_id
        cmp     [DWORD esi], ebx
        jne     @@NotCyrix
        cmp     [DWORD esi+4], edx
        jne     @@NotCyrix
        cmp     [DWORD esi+8], ecx
        jne     @@NotCyrix
        mov     eax,CPU_Cyrix       ; Flag that we have CyrixInstead
        jmp     @@FoundVendor

; Check for AuthenticAMD processors

@@NotCyrix:
        LEA_L   esi,amd_id
        cmp     [DWORD esi], ebx
        jne     @@NotAMD
        cmp     [DWORD esi+4], edx
        jne     @@NotAMD
        cmp     [DWORD esi+8], ecx
        jne     @@NotAMD
        mov     eax,CPU_AMD         ; Flag that we have AuthenticAMD
        jmp     @@FoundVendor

; Check for CentaurHauls processors

@@NotAMD:
        LEA_L   esi,idt_id
        cmp     [DWORD esi], ebx
        jne     @@NotIDT
        cmp     [DWORD esi+4], edx
        jne     @@NotIDT
        cmp     [DWORD esi+8], ecx
        jne     @@NotIDT
        mov     eax,CPU_IDT         ; Flag that we have AuthenticIDT
        jmp     @@FoundVendor

; Check for Geode processors

@@NotIDT:
        LEA_L   esi,geode_id
        cmp     [DWORD esi], ebx
        jne     @@NotGeode
        cmp     [DWORD esi+4], edx
        jne     @@NotGeode
        cmp     [DWORD esi+8], ecx
        jne     @@NotGeode
        mov     eax,CPU_Geode       ; Flag that we have Geode
        jmp     @@FoundVendor

@@NotGeode:

@@FoundVendor:
        push    eax
        xor     eax, eax
        inc     eax
        mCPU_ID                     ; Get family/model/stepping/features
        and     eax, 0F00h
        shr     eax, 8              ; Isolate CPU family
        and     eax, 0Fh
        cmp     eax, 0Fh            ; Check for Pentium 4 which is an 0Fh!
        jne     @@NotP4
        mov     eax, 07h            ; Change P4 ID to 7 for consistency
@@NotP4:
        pop     ecx
        or      eax,ecx             ; Combine in the CPU vendor flag
@@Done: leave_c
        ret

@@Fail: xor     eax,eax
        jmp     @@Done

cprocend

;----------------------------------------------------------------------------
; uint _CPU_getCPUIDModel(void)
;----------------------------------------------------------------------------
; Determines the CPU type using the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _CPU_getCPUIDModel

        enter_c

        xor     eax, eax            ; Set up for CPUID instruction
        mCPU_ID                     ; Get and save vendor ID
        cmp     eax, 1              ; Make sure 1 is valid input for CPUID
        jl      @@Fail              ; We dont have the CPUID instruction
        xor     eax, eax
        inc     eax
        mCPU_ID                     ; Get family/model/stepping/features
        and     eax, 0F0h
        shr     eax, 4              ; Isolate model
@@Done: leave_c
        ret

@@Fail: xor     eax,eax
        jmp     @@Done

cprocend

;----------------------------------------------------------------------------
; uint _CPU_getCPUIDStepping(void)
;----------------------------------------------------------------------------
; Determines the CPU type using the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _CPU_getCPUIDStepping

        enter_c

        xor     eax, eax            ; Set up for CPUID instruction
        mCPU_ID                     ; Get and save vendor ID
        cmp     eax, 1              ; Make sure 1 is valid input for CPUID
        jl      @@Fail              ; We dont have the CPUID instruction
        xor     eax, eax
        inc     eax
        mCPU_ID                     ; Get family/model/stepping/features
        and     eax, 00Fh           ; Isolate stepping
@@Done: leave_c
        ret

@@Fail: xor     eax,eax
        jmp     @@Done

cprocend

;----------------------------------------------------------------------------
; uint _CPU_getCPUIDFeatures(void)
;----------------------------------------------------------------------------
; Determines the CPU type using the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _CPU_getCPUIDFeatures

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
; uint _CPU_getCacheSize(void)
;----------------------------------------------------------------------------
; Determines the CPU cache size for Intel processors
;----------------------------------------------------------------------------
cprocstart  _CPU_getCacheSize

        enter_c
        xor     eax, eax            ; Set up for CPUID instruction
        mCPU_ID                     ; Get and save vendor ID
        cmp     eax,2               ; Make sure 2 is valid input for CPUID
        jl      @@Fail              ; We dont have the CPUID instruction
        mov     eax,2
        mCPU_ID                     ; Get cache descriptors
        LEA_L   esi,cache_id        ; Get address of cache ID (-fPIC aware)
        shr     eax,8
        mov     [esi+0],eax
        mov     [esi+3],ebx
        mov     [esi+7],ecx
        mov     [esi+11],edx
        xor     eax,eax
        LEA_L   esi,cache_id        ; Get address of cache ID (-fPIC aware)
        mov     edi,15
@@ScanLoop:
        cmp     [BYTE esi],41h
        mov     eax,128
        je      @@Done
        cmp     [BYTE esi],42h
        mov     eax,256
        je      @@Done
        cmp     [BYTE esi],43h
        mov     eax,512
        je      @@Done
        cmp     [BYTE esi],44h
        mov     eax,1024
        je      @@Done
        cmp     [BYTE esi],45h
        mov     eax,2048
        je      @@Done
        inc     esi
        dec     edi
        jnz     @@ScanLoop

@@Done: leave_c
        ret

@@Fail: xor     eax,eax
        jmp     @@Done

cprocend

;----------------------------------------------------------------------------
; uint _CPU_have3DNow(void)
;----------------------------------------------------------------------------
; Determines the CPU type using the CPUID instruction.
;----------------------------------------------------------------------------
cprocstart  _CPU_have3DNow

        enter_c

        mov     eax,80000000h       ; Query for extended functions
        mCPU_ID                     ; Get extended function limit
        cmp     eax,80000001h
        jbe     @@Fail              ; Nope, we dont have function 800000001h
        mov     eax,80000001h       ; Setup extended function 800000001h
        mCPU_ID                     ; and get the information
        test    edx,80000000h       ; Bit 31 is set if 3DNow! present
        jz      @@Fail              ; Nope, we dont have 3DNow support
        mov     eax,1               ; Yep, we have 3DNow! support!
@@Done: leave_c
        ret

@@Fail: xor     eax,eax
        jmp     @@Done

cprocend

;----------------------------------------------------------------------------
; ulong _CPU_quickRDTSC(void)
;----------------------------------------------------------------------------
; Reads the time stamp counter and returns the low order 32-bits
;----------------------------------------------------------------------------
cprocstart  _CPU_quickRDTSC

        mRDTSC
        ret

cprocend

;----------------------------------------------------------------------------
; void _CPU_runBSFLoop(ulong interations)
;----------------------------------------------------------------------------
; Runs a loop of BSF instructions for the specified number of iterations
;----------------------------------------------------------------------------
cprocstart  _CPU_runBSFLoop

        ARG     iterations:ULONG

        push    _bp
        mov     _bp,_sp
        push    _bx

        mov     edx,[iterations]
        mov     eax,80000000h
        mov     ebx,edx

        ALIGN   4

@@loop: bsf     ecx,eax
        dec     ebx
        jnz     @@loop

        pop     _bx
        pop     _bp
        ret

cprocend

;----------------------------------------------------------------------------
; void  _CPU_readTimeStamp(CPU_largeInteger *time);
;----------------------------------------------------------------------------
; Reads the time stamp counter and returns the 64-bit result.
;----------------------------------------------------------------------------
cprocstart  _CPU_readTimeStamp

        mRDTSC
        mov     ecx,[esp+4]     ; Access directly without stack frame
        mov     [ecx],eax
        mov     [ecx+4],edx
        ret

cprocend

;----------------------------------------------------------------------------
; ulong _CPU_diffTime64(CPU_largeInteger *t1,CPU_largeInteger *t2,CPU_largeInteger *t)
;----------------------------------------------------------------------------
; Computes the difference between two 64-bit numbers.
;----------------------------------------------------------------------------
cprocstart  _CPU_diffTime64

        ARG     t1:DPTR, t2:DPTR, t:DPTR

        enter_c

        mov     ecx,[t2]
        mov     eax,[ecx]       ; EAX := t2.low
        mov     ecx,[t1]
        sub     eax,[ecx]
        mov     edx,eax         ; EDX := low difference
        mov     ecx,[t2]
        mov     eax,[ecx+4]     ; ECX := t2.high
        mov     ecx,[t1]
        sbb     eax,[ecx+4]     ; EAX := high difference

        mov     ebx,[t]         ; Store the result
        mov     [ebx],edx       ; Store low part
        mov     [ebx+4],eax     ; Store high part
        mov     eax,edx         ; Return low part
ifndef flatmodel
        shld    edx,eax,16      ; Return in DX:AX
endif
        leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; ulong _CPU_calcMicroSec(CPU_largeInteger *count,ulong freq);
;----------------------------------------------------------------------------
; Computes the value in microseconds for the elapsed time with maximum
; precision. The formula we use is:
;
;   us = (((diff * 0x100000) / freq) * 1000000) / 0x100000)
;
; The power of two multiple before the first divide allows us to scale the
; 64-bit difference using simple shifts, and then the divide brings the
; final result into the range to fit into a 32-bit integer.
;----------------------------------------------------------------------------
cprocstart  _CPU_calcMicroSec

        ARG     count:DPTR, freq:ULONG

        enter_c

        mov     ecx,[count]
        mov     eax,[ecx]       ; EAX := low part
        mov     edx,[ecx+4]     ; EDX := high part
        shld    edx,eax,20
        shl     eax,20          ; diff * 0x100000
        div     [DWORD freq]    ; (diff * 0x100000) / freq
        mov     ecx,1000000
        xor     edx,edx
        mul     ecx             ; ((diff * 0x100000) / freq) * 1000000)
        shrd    eax,edx,20      ; ((diff * 0x100000) / freq) * 1000000) / 0x100000
ifndef flatmodel
        shld    edx,eax,16      ; Return in DX:AX
endif
        leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; ulong _CPU_mulDiv(ulong a,ulong b,ulong c);
;----------------------------------------------------------------------------
; Computes the following with 64-bit integer precision:
;
;   result = (a * b) / c
;
;----------------------------------------------------------------------------
cprocstart  _CPU_mulDiv

        ARG     a:ULONG, b:ULONG, c:ULONG

        enter_c
        mov     eax,[a]
        imul    [ULONG b]
        idiv    [ULONG c]
ifndef flatmodel
        shld    edx,eax,16      ; Return in DX:AX
endif
        leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; int PM_getIOPL(void)
;----------------------------------------------------------------------------
; Returns current IOPL, callable from any ring, any OS, any day of the week
; (as long as it's 386 compatible). Sort of CPU information too.
;----------------------------------------------------------------------------
cprocstart  PM_getIOPL

        pushfd
        pop     eax
        and     eax,0011000000000000b
        shr     eax,12
        ret

cprocend


endcodeseg  _cpuinfo

        END

