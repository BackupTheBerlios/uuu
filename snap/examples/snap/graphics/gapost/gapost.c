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
* Description:  Simple program to cause all secondary adapters to be
*               warm booted and initialised by their respective BIOS'es.
*
*               Under QNX this requires linking with the VBIOS library
*               which is somewhat large under QNX4.  By executing this
*               program at boot time, other apps do not need to be linked
*               with the VBIOS library.
*
****************************************************************************/

#include "snap/gasdk.h"

/*---------------------------- Global Variables ---------------------------*/

#ifdef ISV_LICENSE
#include "isv.c"
#endif

/*----------------------------- Implementation ----------------------------*/

int main(int argc,char *argv[])
{
    /* Register the ISV license file if desired */
#ifdef  ISV_LICENSE
    GA_registerLicense(OemLicense,false);
#endif

    /* All we need to do is enumerate all the devices which automatically
     * POST's all the secondary controllers. Loading a device driver for
     * each device is not necessary.
     */
    GA_enumerateDevices(false);
    return 0;
}
