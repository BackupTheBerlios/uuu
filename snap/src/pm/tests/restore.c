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
* Environment:  Linux/QNX
*
* Description:  Program to restore the console state state from a previously
*               saved state if the program crashed while the console
*               was in graphics mode.
*
****************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include "pmapi.h"

void setVideoMode(int mode)
{
    RMREGS r;

    r.x.ax = mode;
    PM_int86(0x10, &r, &r);
}

int main(void)
{
    PM_HWND hwndConsole;
    ulong   stateSize;
    void    *stateBuf;
    FILE    *f;

    /* Write the saved console state buffer to disk */
    if ((f = fopen("/etc/pmsave.dat","rb")) == NULL) {
        printf("Unable to open /etc/pmsave.dat for reading!\n");
        return -1;
        }
    fread(&stateSize,1,sizeof(stateSize),f);
    if (stateSize != PM_getConsoleStateSize()) {
        printf("Size mismatch in /etc/pmsave.dat!\n");
        return -1;
        }
    if ((stateBuf = PM_malloc(stateSize)) == NULL) {
        printf("Unable to allocate console state buffer!\n");
        return -1;
        }
    fread(stateBuf,1,stateSize,f);
    fclose(f);

    /* Open the console */
    hwndConsole = PM_openConsole(0,0,0,0,0,true);

    /* Forcibly set 80x25 text mode using the BIOS */
    setVideoMode(0x3);

    /* Restore the previous console state */
    PM_restoreConsoleState(stateBuf,0);
    PM_closeConsole(hwndConsole);
    PM_free(stateBuf);
    printf("Console state successfully restored from /etc/pmsave.dat\n");
    return 0;
}

