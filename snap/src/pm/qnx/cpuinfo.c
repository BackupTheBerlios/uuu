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
* Environment:  QNX
*
* Description:  QNX specific code for the CPU detection module.
*
****************************************************************************/

/*----------------------------- Implementation ----------------------------*/

/****************************************************************************
REMARKS:
Initialise the counter and return the frequency of the counter.
****************************************************************************/
static void GetCounterFrequency(
    CPU_largeInteger *freq)
{
    freq->low = CLOCKS_PER_SEC * 1000;
    freq->high = 0;
}

/****************************************************************************
REMARKS:
Read the counter and return the counter value.
****************************************************************************/
#define GetCounter(t)           \
{                               \
    (t)->low = clock() * 1000;  \
    (t)->high = 0;              \
}

