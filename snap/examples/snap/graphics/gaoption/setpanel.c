/****************************************************************************
*
*                    SciTech SNAP Graphics Architecture
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
* Environment:  Any 32-bit protected mode environment
*
* Description:  Simple program that allows the SciTech SNAP Graphics
*               options to be changed from the command line.
*
****************************************************************************/

#include "snap/graphics.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <ctype.h>

/*---------------------------- Global Variables ---------------------------*/

static GA_devCtx        *dc = NULL;
static GA_initFuncs     init;
static GA_options       opt;
GA_driverFuncs          driver;

/*----------------------------- Implementation ----------------------------*/

/****************************************************************************
REMARKS:
Display the help screen.
****************************************************************************/
static void help(void)
{
    printf("\nUsage:\n\n"
           "  setpanel show\n"
           "  setpanel [xRes] [yRes]\n");
    exit(-1);
}

/****************************************************************************
REMARKS:
Load the SNAP driver and intialise it.
****************************************************************************/
static void LoadDriver(
    int deviceIndex)
{
    if (!dc) {
        if ((dc = GA_loadDriver(deviceIndex,false)) == NULL)
            PM_fatalError(GA_errorMsg(GA_status()));
        init.dwSize = sizeof(init);
        if (!GA_queryFunctions(dc,GA_GET_INITFUNCS,&init))
            PM_fatalError("Unable to get device driver functions!");
        opt.dwSize = sizeof(opt);
        init.GetOptions(&opt);
        }
}

/****************************************************************************
REMARKS:
Show the current settings for the device.
****************************************************************************/
static void ShowSettings(
    int deviceIndex)
{
    LoadDriver(deviceIndex);
    printf("Panel size is currently set to %d x %d\n\n", opt.LCDPanelWidth, opt.LCDPanelHeight);
}

/****************************************************************************
REMARKS:
Main program entry point
****************************************************************************/
int main(
    int argc,
    char *argv[])
{
    /* Now handle the query */
    if (argc >= 2 && stricmp(argv[1],"show") == 0)
        ShowSettings(0);
    else if (argc >= 3) {
        LoadDriver(0);
        opt.LCDPanelWidth = atoi(argv[1]);
        opt.LCDPanelHeight = atoi(argv[2]);
        init.SetOptions(&opt);
        GA_saveOptions(dc,&opt);
        ShowSettings(0);
        }
    else
        help();
    if (dc)
        GA_unloadDriver(dc);
    return 0;
}

