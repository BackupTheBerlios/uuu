;****************************************************************************
;*
;*                      SciTech SNAP Audio Architecture
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
;* Description: Module to implement the import stubs for all the SciTech
;*              SNAP Audio API functions for Intel binary compatible drivers.
;*
;****************************************************************************

include "scitech.mac"           ; Memory model macros

BEGIN_IMPORTS_DEF   _AA_exports
SKIP_IMP    AA_status                     ; Implemented in C code
SKIP_IMP    AA_errorMsg                   ; Implemented in C code
SKIP_IMP    AA_getDaysLeft                ; Implemented in C code
SKIP_IMP    AA_registerLicense            ; Implemented in C code
SKIP_IMP    AA_enumerateDevices           ; Implemented in C code
SKIP_IMP    AA_loadDriver                 ; Implemented in C code
DECLARE_IMP AA_unloadDriver
DECLARE_IMP AA_saveOptions
END_IMPORTS_DEF

        END

