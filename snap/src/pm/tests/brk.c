/****************************************************************************
*
*                   SciTech OS Portability Manager Library
*
*  ========================================================================
*
*   Copyright (C) 1991-2002 SciTech Software, Inc. All rights reserved.
*
*   This file may be distributed and/or modified under the terms of the
*   GNU Lesser General Public License version 2.1 as published by the Free
*   Software Foundation and appearing in the file LICENSE.LGPL included
*   in the packaging of this file.
*
*   Licensees holding a valid Commercial License for this product from
*   SciTech Software, Inc. may use this file in accordance with the
*   Commercial License Agreement provided with the Software.
*
*   This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING
*   THE WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
*   PURPOSE.
*
*   See http://www.scitechsoft.com/license/ for information about
*   the licensing options available and how to purchase a Commercial
*   License Agreement.
*
*   Contact license@scitechsoft.com if any conditions of this licensing
*   are not clear to you, or you have questions about licensing options.
*
*  ========================================================================
*
* Language:     ANSI C
* Environment:  any
*
* Description:  Test program to check the ability to install a C based
*               control C/break interrupt handler.
*
*               Functions tested:   PM_installBreakHandler()
*                                   PM_ctrlCHit()
*                                   PM_ctrlBreakHit()
*                                   PM_restoreBreakHandler()
*
****************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include "pmapi.h"

int main(void)
{
    PM_installBreakHandler();
    printf("Control C/Break interrupt handler installed\n");
    while (1) {
        if (PM_ctrlCHit(1)) {
            printf("Code termimated with Ctrl-C.\n");
            break;
            }
        if (PM_ctrlBreakHit(1)) {
            printf("Code termimated with Ctrl-Break.\n");
            break;
            }
        if (PM_kbhit() && PM_getch() == 0x1B) {
            printf("No break code detected!\n");
            break;
            }
        printf("Hit Ctrl-C or Ctrl-Break to exit!\n");
        }

    PM_restoreBreakHandler();
    return 0;
}