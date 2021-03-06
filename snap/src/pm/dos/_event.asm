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
;* Environment: IBM PC (MSDOS)
;*
;* Description: Assembly language support routines for the event module.
;*
;****************************************************************************

include "scitech.mac"           ; Memory model macros

ifdef flatmodel

header  _event                  ; Set up memory model

begdataseg  _event

    cextern  _EVT_biosPtr,DPTR

%define KB_HEAD     WORD esi+01Ah   ; Keyboard buffer head in BIOS data area
%define KB_TAIL     WORD esi+01Ch   ; Keyboard buffer tail in BIOS data area
%define KB_START    WORD esi+080h   ; Start of keyboard buffer in BIOS data area
%define KB_END      WORD esi+082h   ; End of keyboard buffer in BIOS data area

enddataseg  _event

begcodeseg  _event              ; Start of code segment

    cpublic _EVT_codeStart

;----------------------------------------------------------------------------
; int _EVT_getKeyCode(void)
;----------------------------------------------------------------------------
; Returns the key code for the next available key by extracting it from
; the BIOS keyboard buffer.
;----------------------------------------------------------------------------
cprocstart  _EVT_getKeyCode

        enter_c

        mov     esi,[_EVT_biosPtr]
        xor     ebx,ebx
        xor     eax,eax
        mov     bx,[KB_HEAD]
        cmp     bx,[KB_TAIL]
        jz      @@Done
        xor     eax,eax
        mov     ax,[esi+ebx]    ; EAX := character from keyboard buffer
        inc     _bx
        inc     _bx
        cmp     bx,[KB_END]     ; Hit the end of the keyboard buffer?
        jl      @@1
        mov     bx,[KB_START]
@@1:    mov     [KB_HEAD],bx    ; Update keyboard buffer head pointer

@@Done: leave_c
        ret

cprocend

;----------------------------------------------------------------------------
; void _EVT_pumpMessages(void)
;----------------------------------------------------------------------------
; This function would normally do nothing, however due to strange bugs
; in the Windows 3.1 and OS/2 DOS boxes, we don't get any hardware keyboard
; interrupts unless we periodically call the BIOS keyboard functions. Hence
; this function gets called every time that we check for events, and works
; around this problem (in essence it tells the DOS VDM to pump the
; keyboard events to our program ;-).
;
; Note that this bug is not present under Win 9x DOS boxes.
;----------------------------------------------------------------------------
cprocstart  _EVT_pumpMessages

        mov     ah,11h          ; Function - Check keyboard status
        int     16h             ; Call BIOS

        mov     ax, 0Bh         ; Reset Move Mouse
        int     33h
        ret

cprocend

;----------------------------------------------------------------------------
; int _EVT_disableInt(void);
;----------------------------------------------------------------------------
; Return processor interrupt status and disable interrupts.
;----------------------------------------------------------------------------
cprocstart  _EVT_disableInt

        pushf                   ; Put flag word on stack
        cli                     ; Disable interrupts!
        pop     eax             ; deposit flag word in return register
        ret

cprocend

;----------------------------------------------------------------------------
; void _EVT_restoreInt(int ps);
;----------------------------------------------------------------------------
; Restore processor interrupt status.
;----------------------------------------------------------------------------
cprocstart  _EVT_restoreInt

        ARG     ps:UINT

        push    ebp
        mov     ebp,esp         ; Set up stack frame
        push    [DWORD ps]
        popf                    ; Restore processor status (and interrupts)
        pop     ebp
        ret

cprocend

;----------------------------------------------------------------------------
; int EVT_rdinx(int port,int index)
;----------------------------------------------------------------------------
; Reads an indexed register value from an I/O port.
;----------------------------------------------------------------------------
cprocstart  EVT_rdinx

        ARG     port:UINT, index:UINT

        push    ebp
        mov     ebp,esp
        mov     edx,[port]
        mov     al,[BYTE index]
        out     dx,al
        inc     dx
        in      al,dx
        movzx   eax,al
        pop     ebp
        ret

cprocend

;----------------------------------------------------------------------------
; void EVT_wrinx(int port,int index,int value)
;----------------------------------------------------------------------------
; Writes an indexed register value to an I/O port.
;----------------------------------------------------------------------------
cprocstart  EVT_wrinx

        ARG     port:UINT, index:UINT, value:UINT

        push    ebp
        mov     ebp,esp
        mov     edx,[port]
        mov     al,[BYTE index]
        mov     ah,[BYTE value]
        out     dx,ax
        pop     ebp
        ret

cprocend

    cpublic _EVT_codeEnd

endcodeseg  _event

endif

        END                         ; End of module
