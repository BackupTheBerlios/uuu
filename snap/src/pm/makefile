#############################################################################
#
#  ========================================================================
#
#   Copyright (C) 1991-2002 SciTech Software, Inc. All rights reserved.
#
#   This file may be distributed and/or modified under the terms of the
#   GNU Lesser General Public License version 2.1 as published by the Free
#   Software Foundation and appearing in the file LICENSE.LGPL included
#   in the packaging of this file.
#
#   Licensees holding a valid Commercial License for this product from
#   SciTech Software, Inc. may use this file in accordance with the
#   Commercial License Agreement provided with the Software.
#
#   This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING
#   THE WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#   PURPOSE.
#
#   See http://www.scitechsoft.com/license/ for information about
#   the licensing options available and how to purchase a Commercial
#   License Agreement.
#
#   Contact license@scitechsoft.com if any conditions of this licensing
#   are not clear to you, or you have questions about licensing options.
#
#  ========================================================================
#
# Descripton:   Generic makefile for the PM library. Builds the library
#               file and all test programs.
#
#############################################################################

.IMPORT .IGNORE : DEBUG_AGP_DRIVER TEST_HARNESS DEBUG_SDDPMI DEBUG_MATROX
.IMPORT .IGNORE : NO_THREADS AGP_TEST_HARNESS

USE_CXX_LINKER  := 1

#----------------------------------------------------------------------------
# Add DOS extender dependant flags to command line
#----------------------------------------------------------------------------

CFLAGS          += $(DX_CFLAGS)
ASFLAGS         += $(DX_ASFLAGS)
.IF $(USE_LINUX)
# On Linux I have yet to figure out how to link against a library in the
# current directory, so you first need to install the library before
# building the sample programs.
.ELSE
NO_PMLIB        := 1
.ENDIF

#----------------------------------------------------------------------------
# Include definitions specific for the target system
#----------------------------------------------------------------------------

.IF $(USE_VXD)

# Building for Win32 VxD (minimal PM library implementation)

LIBNAME         = pm
OBJECTS         = pm$O gztimer$O gcpuinfo$O mtrr$O fileio$O pcilib$O \
                  agp$O malloc$O vgastate$O gavxd$O _pm$O _mtrr$O \
                  _cpuinfo$O _int64$O _pcihelp$O
DEPEND_SRC      := vxd;common;codepage;tests

.ELIF $(USE_NTDRV)

# Building for NT device drivers (minimal PM library implementation)

LIBNAME         = pm
OBJECTS         = pm$O gztimer$O gcpuinfo$O mtrr$O mem$O irq$O int86$O \
                  stdio$O stdlib$O pcilib$O agp$O malloc$O vgastate$O gantdrv$O \
                  _pm$O _mtrr$O _cpuinfo$O _int64$O _pcihelp$O _irq$O
DEPEND_SRC      := ntdrv;common;codepage;tests

.ELIF $(USE_WIN32)

# Building for Win32

CFLAGS          += -DUSE_OS_JOYSTICK
LIBNAME         = pm
OBJECTS         = pm$O gevent$O ddraw$O gztimer$O gcpuinfo$O pcilib$O \
                  agp$O malloc$O vgastate$O gawin32$O ntservc$O _joy$O \
                  _cpuinfo$O _int64$O _pcihelp$O
DEPEND_SRC      := win32;common;codepage;tests

.ELIF $(USE_OS232)

# Building for OS/2

.IF $(USE_OS2GUI)
LIBNAME         = pm_pm
.ELSE
LIBNAME         = pm
.ENDIF
OBJECTS         = pm$O gevent$O gztimer$O gcpuinfo$O mtrr$O pcilib$O \
                  agp$O malloc$O vgastate$O gaos2$O _pmos2$O _joy$O \
                  _cpuinfo$O _int64$O _pcihelp$O os2/dossctl$O
DEPEND_SRC      := os2;common;codepage;tests

.ELIF $(USE_QNX)

# Building for QNX

USE_BIOS        := 1
.IF $(USE_PHOTON)
LIBNAME         = pm_ph
.ELIF $(USE_X11)
LIBNAME         = pm_x11
.ELSE
LIBNAME         = pm
.ENDIF
OBJECTS         = pm$O gevent$O gztimer$O gcpuinfo$O mtrr$O pcilib$O \
                  agp$O malloc$O mtrrqnx$O unixio$O vgastate$O gaqnx$O \
                  _joy$O _mtrrqnx$O _cpuinfo$O _int64$O _pcihelp$O
DEPEND_SRC      := qnx;common;codepage;tests

# Indicate that this program needs I/O port access
NEEDS_IO        := 1

.ELIF $(USE_LINUX)

# Building for Linux

CFLAGS          += -DENABLE_MTRR
.IF $(NO_THREADS)
CFLAGS          += -DNO_THREADS
SHOW_CFLAGS     += -DNO_THREADS
.ENDIF
.IF $(USE_X11)
LIBNAME         = pm_x11
.ELSE
LIBNAME         = pm
.ENDIF
OBJECTS         = pm$O gevent$O mouse$O gztimer$O gcpuinfo$O pcilib$O \
                  agp$O malloc$O unixio$O vgastate$O galinux$O
.IF $(USE_X86)
OBJECTS         += _cpuinfo$O _int64$O _pcihelp$O
.ELSE
OBJECTS         += _int64$O io$O
.ENDIF
DEPEND_SRC      := linux;common;codepage;tests;x11

.ELIF $(USE_UUU)

# Building for Unununium

CFLAGS          += -DNO_THREADS
SHOW_CFLAGS     += -DNO_THREADS
LIBNAME         = pm
OBJECTS         = pm$O gevent$O gztimer$O gcpuinfo$O pcilib$O \
                  agp$O malloc$O vgastate$O gauuu$O mtrr$O _mtrr$O _cpuinfo$O _joy$O _int64$O _pcihelp$O
DEPEND_SRC      := uuu;common;codepage;tests

.ELIF $(USE_BEOS)

# Building for BeOS GUI

LIBNAME         = pm
OBJECTS         = pm$O gevent$O gztimer$O gcpuinfo$O pcilib$O \
                  agp$O malloc$O vgastate$O gabeos$O _joy$O \
                  _cpuinfo$O _int64$O _pcihelp$O
DEPEND_SRC      := beos;common;codepage;tests

.ELIF $(USE_SMX32)

# Building for SMX

LIBNAME         = pm
OBJECTS         = pm$O pmsmx$O gevent$O gztimer$O gcpuinfo$O mtrr$O pcilib$O \
                  agp$O malloc$O vgastate$O gasmx$O _pm$O _pmsmx$O _mtrr$O \
                  _event$O _joy$O _cpuinfo$O _int64$O _pcihelp$O _lztimer$O
DEPEND_SRC      := smx;common;codepage;tests

.ELIF $(USE_RTTARGET)

# Building for RTTarget-32

LIBNAME         = pm
OBJECTS         = pm$O gevent$O gztimer$O gcpuinfo$O mtrr$O pcilib$O \
                  agp$O malloc$O vgastate$O gartt$O _joy$O \
                  _cpuinfo$O _int64$O _pcihelp$O pmrtos$O _pmrtos$O
DEPEND_SRC      := rttarget;common;codepage;tests

.ELSE

# Building for MSDOS

LIBNAME         = pm
OBJECTS         = pm$O pmdos$O gevent$O gztimer$O gcpuinfo$O mtrr$O \
                  agp$O malloc$O pcilib$O vgastate$O gados$O \
                  _pm$O _pmdos$O _mtrr$O _event$O _joy$O _pcihelp$O \
                  _cpuinfo$O _int64$O _lztimer$O _dma$O
DEPEND_SRC      := dos;common;codepage;tests

.ENDIF

# Object modules for keyboard code pages

OBJECTS         += us_eng$O

# Common object modules

OBJECTS         += common$O debug$O

# SNAP loader library object modules. Note that when compiling a test harness
# library we need to exclude the SNAP loader library.

.IF $(AGP_TEST_HARNESS)
TEST_HARNESS    := 1
CFLAGS          += -DAGP_TEST_HARNESS
SHOW_CFLAGS     += -DAGP_TEST_HARNESS
.IF $(BUILD_SO)
LIBS            += $(LL)n_agp$(LE)
.ENDIF
.ENDIF
.IF $(TEST_HARNESS)
CFLAGS          += -DTEST_HARNESS -DPMLIB
SHOW_CFLAGS     += -DTEST_HARNESS
.IF $(BUILD_SO)
LIBS            += $(LL)n_driver$(LE) $(LL)n_ref2d$(LE)
.IF $(DEBUG_MATROX)
LIBS            += $(LL)mgahal$(LE)
.ENDIF
.ELSE
LIBNAME         := pm_test
.ENDIF
.ELSE
OBJECTS         += galib$O gaoption$O
.IF $(USE_X86)
OBJECTS         += _ga_imp$O
.ENDIF
.ENDIF

.IF $(DEBUG_SDDPMI)
CFLAGS          += -DDEBUG_SDDPMI
.ENDIF

# AGP library object modules

.IF $(DEBUG_AGP_DRIVER)
CFLAGS          += -DDEBUG_AGP_DRIVER
OBJECTS         += agplib$O
.ELSE
OBJECTS         += agplib$O peloader$O libcimp$O
.IF $(USE_X86) || $(USE_PPC_BE)
OBJECTS         += _gatimer$O
.ENDIF
.ENDIF

#----------------------------------------------------------------------------
# Name of library and generic object files required to build it
#----------------------------------------------------------------------------

.IF $(STKCALL)
LIBFILE         = s$(LP)$(LIBNAME)$L
.ELSE
LIBFILE         = $(LP)$(LIBNAME)$L
.ENDIF
LIBCLEAN        = *.lib *.a

#----------------------------------------------------------------------------
# Change destination for library file depending the extender being used. This
# is only necessary for DOS extender since the file go into a subdirectory
# in the normal library directory, one for each supported extender. Other
# OS'es put the file into the regular library directory, since there is
# only one per OS in this case.
#----------------------------------------------------------------------------

MK_PMODE        = 1

.IF $(TEST_HARNESS)
LIB_DEST        := $(LIB_BASE)
.ELIF $(USE_TNT)
LIB_DEST        := $(LIB_BASE)\tnt
.ELIF $(USE_DOS4GW)
LIB_DEST        := $(LIB_BASE)\dos4gw
.ELIF $(USE_X32)
LIB_DEST        := $(LIB_BASE)\x32
.ELIF $(USE_DPMI16)
LIB_DEST        := $(LIB_BASE)\dpmi16
.ELIF $(USE_DPMI32)
LIB_DEST        := $(LIB_BASE)\dpmi32
.ELIF $(USE_DOSX)
LIB_DEST        := $(LIB_BASE)\dosx
.END

#----------------------------------------------------------------------------
# Names of all executable files built
#----------------------------------------------------------------------------

.IF $(USE_REALDOS)
EXEFILES        = memtest$E biosptr$E video$E isvesa$E callreal$E       \
                  mouse$E tick$E irq$E key$E key15$E brk$E altbrk$E     \
                  critical$E altcrit$E rtc$E getch$E           \
                  cpu$E timerc$E showpci$E uswc$E block$E timercpp$E    \
                  test$E hello$E bpdpath$E fatal$E
.ELSE
EXEFILES        = memtest$E video$E isvesa$E callreal$E getch$E \
                  cpu$E timerc$E showpci$E uswc$E block$E save$E restore$E \
                  name$E timercpp$E shmem$E test$E hello$E bpdpath$E fatal$E
.ENDIF

all: $(EXEFILES)

$(EXEFILES): $(LIBFILE)

memtest$E:  memtest$O
name$E:     name$O
biosptr$E:  biosptr$O
video$E:    video$O
isvesa$E:   isvesa$O
mouse$E:    mouse$O
tick$E:     tick$O
irq$E:      irq$O
key$E:      key$O
key15$E:    key15$O
brk$E:      brk$O
altbrk$E:   altbrk$O
critical$E: critical$O
altcrit$E:  altcrit$O
callreal$E: callreal$O
rtc$E:      rtc$O
getch$E:    getch$O
cpu$E:      cpu$O
timerc$E:   timerc$O
timercpp$E: timercpp$O
showpci$E:  showpci$O
uswc$E:     uswc$O
block$E:    block$O
save$E:     save$O
restore$E:  restore$O
shmem$E:    shmem$O
test$E:     test$O
hello$E:    hello$O
bpdpath$E:  bpdpath$O
fatal$E:    fatal$O

#----------------------------------------------------------------------------
# Define the list of object files to create dependency information for
#----------------------------------------------------------------------------

DEPEND_OBJ      := $(OBJECTS) memtest$O biosptr$O video$O isvesa$O mouse$O  \
                   tick$O key$O key$O brk$O altbrk$O critical$O altcrit$O   \
                   callreal$O getch$O timercpp$O

.INCLUDE: "$(SCITECH)/makedefs/common.mk"

