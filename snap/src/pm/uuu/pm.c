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
* Environment:  Unununium
*
* Description:  Implementation for the OS Portability Manager Library, which
*               contains functions to implement OS specific services in a
*               generic, cross platform API. Porting the OS Portability
*               Manager library is the first step to porting any SciTech
*               products to a new platform.
*
* Credits:      Fernando Fernandes Neto
*               Dave Poirier
*               Davison Avery
****************************************************************************/

#include "pmapi.h"
#include "clib/os/os.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*--------------------------- Global variables ----------------------------*/

static void (PMAPIP fatalErrorCleanup)(void) = NULL;

/*----------------------------- Implementation ----------------------------*/

void PMAPI PM_init(void)
{
    // TODO: Do any initialisation in here. This includes getting IOPL
    //       access for the process calling PM_init. This will get called
    //       more than once.

    // TODO: If you support the supplied MTRR register stuff (you need to
    //       be at ring 0 for this!), you should initialise it in here.

/* MTRR_init(); */
}

long PMAPI PM_getOSType(void)
{ return _OS_UNSUPPORTED; }

char * PMAPI PM_getOSName(void)
{ return "Unununium Operating Engine"; }

int PMAPI PM_getModeType(void)
{ return PM_386; }

void PMAPI PM_backslash(char *s)
{
    uint pos = strlen(s);
    if (s[pos-1] != '/') {
        s[pos] = '/';
        s[pos+1] = '\0';
        }
}

void PMAPI PM_setFatalErrorCleanup(
    void (PMAPIP cleanup)(void))
{
    fatalErrorCleanup = cleanup;
}

void PMAPI PM_fatalError(const char *msg)
{
    // TODO: If you are running in a GUI environment without a console,
    //       this needs to be changed to bring up a fatal error message
    //       box and terminate the program.
    if (fatalErrorCleanup)
        fatalErrorCleanup();
    // fprintf(stderr,"%s\n", msg);
    exit(1);
}

// Unununium does not use paging

int PMAPI PM_lockDataPages(void *p, uint len, PM_lockHandle *lh)
{
  return 0;
}

int PMAPI PM_lockCodePages(__codePtr p, uint len, PM_lockHandle *lh)
{
  return 0;
}

int PMAPI PM_unlockDataPages(void *p, uint len, PM_lockHandle *lh)
{
  return 0;
}

int PMAPI PM_unlockCodePages(__codePtr p, uint len, PM_lockHandle *lh)
{
  return 0;
}

void * PMAPI PM_getProcAddress(PM_MODULE hModule, const char *szProcName)
{
  return NULL;
}

void PMAPI PM_freePage(void *p)
{
  return;
}

void * PMAPI PM_allocPage(ibool locked)
{
  return NULL;
}

// No BIOS access for the Unununium

ibool PMAPI PM_haveBIOSAccess(void)
{
    return false;
}

void * PMAPI PM_getVESABuf(uint *len,uint *rseg,uint *roff)
{
    return NULL;
}

// We don't have OS specific code

PM_MODULE PMAPI PM_loadLibrary(const char *szDLLName)
{
     return NULL;
}

void PMAPI PM_freeLibrary(PM_MODULE hModule)
{
    return;
}

void PMAPI PM_flushTLB(void)
{
   return;      // do nothing on Unununium
}

// We don't care with the AppCallBack, because it will be GUI based, and we won't have a 
// fullscreen console mode

void PMAPI PM_setSuspendAppCallback(PM_suspendApp_cb saveState)
{
   return;
}

int PMAPI PM_kbhit(void)
{
    // TODO: This function checks if a key is available to be read. This
    //       should be implemented, but is mostly used by the test programs
    //       these days.
    return true;
}

int PMAPI PM_getch(void)
{
    // TODO: This returns the ASCII code of the key pressed. This
    //       should be implemented, but is mostly used by the test programs
    //       these days.
    return 0xD;
}

PM_HWND PMAPI PM_openConsole(PM_HWND hwndUser,int device,int xRes,int yRes,int bpp,ibool fullScreen)
{
    // TODO: Opens up a fullscreen console for graphics output. If your
    //       console does not have graphics/text modes, this can be left
    //       empty. The main purpose of this is to disable console switching
    //       when in graphics modes if you can switch away from fullscreen
    //       consoles (if you want to allow switching, this can be done
    //       elsewhere with a full save/restore state of the graphics mode).
    return 0;
}

int PMAPI PM_getConsoleStateSize(void)
{
    // TODO: Returns the size of the console state buffer used to save the
    //       state of the console before going into graphics mode. This is
    //       used to restore the console back to normal when we are done.
    return 1;
}

void PMAPI PM_saveConsoleState(void *stateBuf,PM_HWND hwndConsole)
{
    // TODO: Saves the state of the console into the state buffer. This is
    //       used to restore the console back to normal when we are done.
    //       We will always restore 80x25 text mode after being in graphics
    //       mode, so if restoring text mode is all you need to do this can
    //       be left empty.
}

void    PMAPI PM_restoreConsoleState(const void *stateBuf,PM_HWND hwndConsole)
{
    // TODO: Restore the state of the console from the state buffer. This is
    //       used to restore the console back to normal when we are done.
    //       We will always restore 80x25 text mode after being in graphics
    //       mode, so if restoring text mode is all you need to do this can
    //       be left empty.
}

void    PMAPI PM_closeConsole(PM_HWND hwndConsole)
{
    // TODO: Close the console when we are done, going back to text mode.
}

void PM_setOSCursorLocation(int x,int y)
{
    // TODO: Set the OS console cursor location to the new value. This is
    //       generally used for new OS ports (used mostly for DOS).
}

void PM_setOSScreenWidth(int width,int height)
{
    // TODO: Set the OS console screen width. This is generally unused for
    //       new OS ports.
}

ibool PMAPI PM_setRealTimeClockHandler(PM_intHandler ih, int frequency)
{
    // TODO: Install a real time clock interrupt handler. Normally this
    //       will not be supported from most OS'es in user land, so an
    //       alternative mechanism is needed to enable software stereo.
    //       Hence leave this unimplemented unless you have a high priority
    //       mechanism to call the 32-bit callback when the real time clock
    //       interrupt fires.
    return false;
}

void PMAPI PM_setRealTimeClockFrequency(int frequency)
{
    // TODO: Set the real time clock interrupt frequency. Used for stereo
    //       LC shutter glasses when doing software stereo. Usually sets
    //       the frequency to around 2048 Hz.
}

/****************************************************************************
REMARKS:
Stops the real time clock from ticking. Note that when we are actually
using IRQ0 instead, this functions does nothing (unlike calling
PM_setRealTimeClockFrequency directly).
****************************************************************************/
void PMAPI PM_stopRealTimeClock(void)
{
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
    PM_setRealTimeClockFrequency(frequency);
}

void PMAPI PM_restoreRealTimeClockHandler(void)
{
    // TODO: Restores the real time clock handler.
}

char * PMAPI PM_getCurrentPath(
    char *path,
    int maxLen)
{
    char *path = "/";
    return path;
}

char PMAPI PM_getBootDrive(void)
{ return '/'; }

const char * PMAPI PM_getSNAPPath(void)
{
    char *env = "/";
    return env;
}

const char * PMAPI PM_getSNAPConfigPath(void)
{
    char *config = "/";
    return config;
}

const char * PMAPI PM_getUniqueID(void)
{
    char *machine = "UUU-box";
    return machine;
}

const char * PMAPI PM_getMachineName(void)
{
    char *networkname = "unununium.org";
    return networkname;
}

void * PMAPI PM_getBIOSPointer(void)
{
    // No BIOS access on the BeOS
    return NULL;
}

void * PMAPI PM_getA0000Pointer(void)
{
    return (void *)0xA0000;
}

void * PMAPI PM_mapPhysicalAddr(ulong base,ulong limit,ibool isCached)
{
    return ((void *)base);
}

void PMAPI PM_freePhysicalAddr(void *ptr,ulong limit)
{
    // TODO: This function will free a physical memory mapping previously
    //       allocated with PM_mapPhysicalAddr() if at all possible. If
    //       you can't free physical memory mappings, simply do nothing.
}

ulong PMAPI PM_getPhysicalAddr(void *p)
{
    return (ulong)p;
}

ibool PMAPI PM_getPhysicalAddrRange(void *p, ulong length, ulong *physAddress)
{
  // As in Unununium, all the Physical Address == Linear Address
  // it's just convert directly and store it in the array.
  // So, there's no reason to return false

  while (length > 0)
  {
   (ulong *)physAddress[length] = p + length;
   -- length;
  }
  return true;
}

// Filesystem Functions
// Don't make able directory creation/destruction

ibool PMAPI PM_mkdir(const char *filename)
{
  return false;
}

ibool PMAPI PM_rmdir(const char *filename)
{
  return false;
}

// Return false, until we can provide something better

ibool PMAPI PM_getFileTime(const char *filename, ibool gmTime, PM_time *time)
{
  return false;
}

ibool PMAPI PM_setFileTime(const char *filename, ibool gmTime, PM_time *time)
{
  return false;
}

uint PMAPI PM_getFileAttr(const char *filename)
{
  return 0;
}

void PMAPI PM_sleep(ulong milliseconds)
{
    // TODO: Put the process to sleep for milliseconds
}

int PMAPI PM_getCOMPort(int port)
{
    // TODO: Re-code this to determine real values using the Plug and Play
    //       manager for the OS.
    switch (port) {
        case 0: return 0x3F8;
        case 1: return 0x2F8;
        }
    return 0;
}

int PMAPI PM_getLPTPort(int port)
{
    // TODO: Re-code this to determine real values using the Plug and Play
    //       manager for the OS.
    switch (port) {
        case 0: return 0x3BC;
        case 1: return 0x378;
        case 2: return 0x278;
        }
    return 0;
}

void * PMAPI PM_mallocShared(long size)
{
    // TODO: This is used to allocate memory that is shared between process
    //       that all access the common SNAP drivers via a common display
    //       driver DLL. If your OS does not support shared memory (or if
    //       the display driver does not need to allocate shared memory
    //       for each process address space), this should just call PM_malloc.
    return PM_malloc(size);
}

void PMAPI PM_freeShared(void *ptr)
{
    // TODO: Free the shared memory block. This will be called in the context
    //       of the original calling process that allocated the shared
    //       memory with PM_mallocShared. Simply call free if you do not
    //       need this.
    PM_free(ptr);
}

void * PMAPI PM_mapRealPointer(uint r_seg,uint r_off)
{
    // No BIOS access on the BeOS
    return NULL;
}

void * PMAPI PM_allocRealSeg(uint size,uint *r_seg,uint *r_off)
{
    // No BIOS access on the BeOS
    return NULL;
}

void PMAPI PM_freeRealSeg(void *mem)
{
    // No BIOS access on the BeOS
}

int PMAPI PM_int86(int intno, RMREGS *in, RMREGS *out)
{
    // No BIOS access on the BeOS
    return 0;
}

int PMAPI PM_int86x(int intno, RMREGS *in, RMREGS *out,
    RMSREGS *sregs)
{
    // No BIOS access on the BeOS
    return 0;
}

void PMAPI PM_callRealMode(uint seg,uint off, RMREGS *in,
    RMSREGS *sregs)
{
    // No BIOS access on the BeOS
}

void * PMAPI PM_allocLockedMem(uint size,ulong *physAddr,ibool contiguous,ibool below16Meg)
{
    // TODO: Allocate a block of locked, physical memory of the specified
    //       size. This is used for bus master operations. If this is not
    //       supported by the OS, return NULL and bus mastering will not
    //       be used.
    return NULL;
}

void PMAPI PM_freeLockedMem(void *p,uint size,ibool contiguous)
{
    // TODO: Free a memory block allocated with PM_allocLockedMem.
}

ibool PMAPI PM_enableWriteCombine(ulong base,ulong length,uint type)
{
    // TODO: This function should enable Pentium Pro and Pentium II MTRR
    //       write combining for the passed in physical memory base address
    //       and length. Normally this is done via calls to an OS specific
    //       device driver as this can only be done at ring 0.
    //
    // NOTE: This is a *very* important function to implement! If you do
    //       not implement, graphics performance on the latest Intel chips
    //       will be severly impaired. For sample code that can be used
    //       directly in a ring 0 device driver, see the MSDOS implementation
    //       which includes assembler code to do this directly (if the
    //       program is running at ring 0).
    return false;
}

/****************************************************************************
REMARKS:
Function to enumerate all write combine regions currently enabled for the
processor.
****************************************************************************/
int PMAPI PM_enumWriteCombine(
    PM_enumWriteCombine_t callback)
{
    return 0;
}

/****************************************************************************
REMARKS:
Function to find the first file matching a search criteria in a directory.
****************************************************************************/
void *  PMAPI PM_findFirstFile(const char *filename,PM_findData *findData)
{
    (void)filename;
    (void)findData;
    return NULL;
}

/****************************************************************************
REMARKS:
Function to find the next file matching a search criteria in a directory.
****************************************************************************/
ibool   PMAPI PM_findNextFile(void *handle,PM_findData *findData)
{
    (void)handle;
    (void)findData;
    return false;
}

/****************************************************************************
REMARKS:
Function to close the find process
****************************************************************************/
void    PMAPI PM_findClose(void *handle)
{
    (void)handle;
}

/****************************************************************************
REMARKS:
Function to get the current working directory for the specififed drive.
Under Unix this will always return the current working directory regardless
of what the value of 'drive' is.
****************************************************************************/
void PMAPI PM_getdcwd(
    int drive,
    char *dir,
    int len)
{
    (void)drive;
    (void)len;
    
    dir = "/";
}

/****************************************************************************
REMARKS:
Function to change the file attributes for a specific file.
****************************************************************************/
void PMAPI PM_setFileAttr(
    const char *filename,
    uint attrib)
{
    // TODO: Set the file attributes for a file
    (void)filename;
    (void)attrib;
}

/****************************************************************************
REMARKS:
Increase the thread priority to maximum, if possible.
****************************************************************************/
ulong   PMAPI PM_setMaxThreadPriority(void)
{
    return 0;
}

/****************************************************************************
REMARKS:
Restore the original thread priority.
****************************************************************************/
void    PMAPI PM_restoreThreadPriority(ulong oldPriority)
{
  (void)oldPriority;
  return;
}

/****************************************************************************
REMARKS:
Returns true if SDD is the active display driver in the system.
****************************************************************************/
ibool PMAPI PM_isSDDActive(void)
{
    return false;
}

/****************************************************************************
REMARKS:
This is not relevant to this OS.
****************************************************************************/
ibool PMAPI PM_runningInAWindow(void)
{
    return false;
}

