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
* Environment:  32-bit Windows NT device drivers.
*
* Description:  Implementation for the NT driver IRQ management functions
*               for the PM library.
*
****************************************************************************/

#include "pmapi.h"
#include "pmint.h"
#include "clib/os/os.h"
#include "sdd/sddhelp.h"
#include "mtrr.h"
#include "oshdr.h"

/*--------------------------- Global variables ----------------------------*/

static int          globalDataStart;
static uchar        _PM_oldCMOSRegA;
static uchar        _PM_oldCMOSRegB;
static uchar        _PM_oldRTCPIC2;
static ulong        RTC_idtEntry;
static KIRQL        _PM_rtcIRQL;
static KAFFINITY    _PM_rtcAffinity;
static PKINTERRUPT  _PM_rtcInterrupt = NULL;	
static ibool        usingIRQ0 = false;
static int          _PM_rtcFrequency = 0;
PM_intHandler       _PM_rtcHandler = NULL;
PMFARPTR    _VARAPI _PM_prevRTC = PMNULL;

/*----------------------------- Implementation ----------------------------*/

/* Functions to read and write CMOS registers */

uchar   _ASMAPI _PM_readCMOS(int index);
void    _ASMAPI _PM_writeCMOS(int index,uchar value);
void    _ASMAPI _PM_rtcISR(void);
void    _ASMAPI _PM_rtcISRAlt(void);
void    _ASMAPI _PM_getISR(int irq,PMFARPTR *handler);
void    _ASMAPI _PM_setISR(int irq,void *handler);
void    _ASMAPI _PM_restoreISR(int irq,PMFARPTR *handler);
void    _ASMAPI _PM_irqCodeStart(void);
void    _ASMAPI _PM_irqCodeEnd(void);

/****************************************************************************
REMARKS:
Set the real time clock frequency (for stereo modes).
****************************************************************************/
void PMAPI PM_setRealTimeClockFrequency(
    int frequency)
{
    static short convert[] = {
        8192,
        4096,
        2048,
        1024,
        512,
        256,
        128,
        64,
        32,
        16,
        8,
        4,
        2,
        -1,
        };
    int i,timerCount;

    if (usingIRQ0) {
        /* We are using IRQ0 instead of IRQ8, so re-program the
         * system timer tick to the appropriate frequency.
         */
        if (frequency == 0) {
            /* Reset timer 0 back to default settings */
            PM_outpb(0x0043, 0x34);
            PM_outpb(0x0040, 0x00);
            PM_outpb(0x0040, 0x00);
            }
        else {
            /* Change system timer to appropriate frequency */
            timerCount = 1193200L / frequency;
            PM_outpb(0x0043, 0x34);
            PM_outpb(0x0040, timerCount & 0xFF);
            PM_outpb(0x0040, timerCount >> 8);
            }
        }
    else {
        /* First clear any pending RTC timeout if not cleared */
        _PM_readCMOS(0x0C);
        if (frequency == 0) {
            /* Disable RTC timout */
            _PM_writeCMOS(0x0A,(uchar)_PM_oldCMOSRegA);
            _PM_writeCMOS(0x0B,(uchar)(_PM_oldCMOSRegB & 0x0F));
            }
        else {
            /* Convert frequency value to RTC clock indexes */
            for (i = 0; convert[i] != -1; i++) {
                if (convert[i] == frequency)
                    break;
                }

            /* Set RTC timout value and enable timeout */
            _PM_writeCMOS(0x0A,(uchar)(0x20 | (i+3)));
            _PM_writeCMOS(0x0B,(uchar)((_PM_oldCMOSRegB & 0x0F) | 0x40));
            }
        }
}

/****************************************************************************
REMARKS:
Stops the real time clock from ticking. Note that when we are actually
using IRQ0 instead, this functions does nothing (unlike calling
PM_setRealTimeClockFrequency directly).
****************************************************************************/
void PMAPI PM_stopRealTimeClock(void)
{
    if (!usingIRQ0)
        PM_setRealTimeClockFrequency(0);
}

/****************************************************************************
REMARKS:
Restarts the real time clock ticking. Note that when we are actually using
IRQ0 instead, this functions does nothing.
****************************************************************************/
void PMAPI PM_restartRealTimeClock(
    int frequency)
{
    if (!usingIRQ0)
        PM_setRealTimeClockFrequency(frequency);
}

/****************************************************************************
PARAMETERS:
interrupt       - Pointer to the Interrupt object
serviceContext  - Pointer to the Device Extension

RETURNS:
TRUE if we handled the interrupt, FALSE if not.

REMARKS:
Real time clock interrupt handler, which calls the user registered C code.
****************************************************************************/
static BOOLEAN PM_rtcISR(
	PKINTERRUPT interrupt,
	PVOID serviceContext)
{
    return TRUE;
}

/****************************************************************************
PARAMETERS:
th          - Pointer to interrupt handler
frequency   - Frequency to program the real time clock to

RETURNS:
True if successfully installed, false if not.

REMARKS:
Installs the real time clock interrupt handler.

NOTE:   On some Intel i810/815 systems, the RTC (IRQ8) appears to be used for
        system time keeping purposes. On these systems however we are
        able to hook the system timer 0 (IRQ0) as this does not appear to
        be used for anything. Hence although this function is intended to
        hook the real time clock, internally we will simulate the same
        functionality using the system timer 0 clock when necessary. The
        hack we use to determine which one to use is to attempt to translate
        IRQ0. If this succeeds, the Intel machines are present and we use
        IRQ0. If this fails, we continue to use IRQ8 the same as before.
****************************************************************************/
ibool PMAPI PM_setRealTimeClockHandler(
    PM_intHandler th,
    int frequency)
{
	NTSTATUS    status;

    /* Save the old CMOS real time clock values */
    _PM_oldCMOSRegA = _PM_readCMOS(0x0A);
    _PM_oldCMOSRegB = _PM_readCMOS(0x0B);

    /* If the RTC is enabled it is being used by the OS, so instead we use timer 0
     * which will not be used by the OS (it appears either one or the other is used).
     */
    if (_PM_oldCMOSRegB & 0x40) {
    	if ((RTC_idtEntry = HalGetInterruptVector(Isa,0,0,0,&_PM_rtcIRQL,&_PM_rtcAffinity)) == 0)
            return false;

    	/* Connect up our interrupt handler to IRQ0 */
        status = IoConnectInterrupt(&_PM_rtcInterrupt,PM_rtcISR,NULL,NULL,
            RTC_idtEntry,_PM_rtcIRQL,_PM_rtcIRQL,Latched,FALSE,_PM_rtcAffinity,FALSE);
        if (!NT_SUCCESS(status))
            return false;

        /* Install the interrupt handler directly into the IDT so we get it first */
        _PM_getISR(RTC_idtEntry, &_PM_prevRTC);
        _PM_rtcHandler = th;
        _PM_setISR(RTC_idtEntry, _PM_rtcISRAlt);

        /* Indicate that we are now using IRQ0 instead of IRQ8 */
        usingIRQ0 = true;
        }
    else {
        /* Install the interrupt handler */
        RTC_idtEntry = 0x38;
        _PM_getISR(RTC_idtEntry, &_PM_prevRTC);
        _PM_rtcHandler = th;
        _PM_setISR(RTC_idtEntry, _PM_rtcISR);

        /* Unmask IRQ8 in the PIC2 */
        _PM_oldRTCPIC2 = PM_inpb(0xA1);
        PM_outpb(0xA1,(uchar)(_PM_oldRTCPIC2 & 0xFE));

        /* Indicate that we are now using IRQ8 instead of IRQ0 */
        usingIRQ0 = false;
        }

    /* Program the real time clock default frequency */
    PM_setRealTimeClockFrequency(frequency);
    return true;
}

void PMAPI PM_restoreRealTimeClockHandler(void)
{
    if (_PM_rtcHandler) {
        if (usingIRQ0) {
            PM_setRealTimeClockFrequency(0);
            if (_PM_rtcInterrupt) {
                _PM_restoreISR(RTC_idtEntry, &_PM_prevRTC);
    	    	IoDisconnectInterrupt(_PM_rtcInterrupt);
                _PM_rtcInterrupt = NULL;
                }
            }
        else {
            /* Restore CMOS registers and mask RTC clock */
            _PM_writeCMOS(0x0A,_PM_oldCMOSRegA);
            _PM_writeCMOS(0x0B,_PM_oldCMOSRegB);
            PM_outpb(0xA1,(uchar)((PM_inpb(0xA1) & 0xFE) | (_PM_oldRTCPIC2 & ~0xFE)));

            /* Restore the interrupt vector */
            _PM_restoreISR(RTC_idtEntry, &_PM_prevRTC);
            }
        _PM_rtcHandler = NULL;
        }
}

