#############################################################################
#
#                       SciTech Makefile Utilities
#
#  ========================================================================
#
#   Copyright (C) 1991-2002 SciTech Software, Inc. All rights reserved.
#
#   This file may be distributed and/or modified under the terms of the
#   GNU General Public License version 2 as published by the Free
#   Software Foundation and appearing in the file LICENSE.GPL included
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
# Descripton:   Generic DMAKE startup makefile definitions file. Assumes
#               that the SCITECH environment variable has been set to point
#               to where all our stuff is installed. You should not need
#               to change anything in this file.
#
#               Linux version for GNU C/C++.
#
#############################################################################

# Disable warnings for macros redefined here that were given
# on the command line.
__.SILENT       := $(.SILENT)
.SILENT         := yes

# Import enivornment variables that we use common to all compilers
.IMPORT .IGNORE : TEMP SHELL INCLUDE LIB SCITECH PRIVATE SCITECH_LIB
.IMPORT .IGNORE : DBG OPT OPT_SIZE SHW BETA CHECKED USE_X11 USE_FREEBSD
.IMPORT .IGNORE : USE_EGCS USE_PGCC STATIC_LIBS
   TMPDIR       := $(TEMP)

# Standard file suffix definitions
#
# NOTE: Linux does not require any extenion for executeable files, but you
#       can use an extension if you wish. We use the .x extension for building
#       executeable files so that we can use implicit rules to make the
#       makefiles simpler and more portable between systems. When you install
#       the files to a local bin directory, you will probably want to remove
#       the .x extension.
   L            := .a       # Libraries
   E            := .x       # Executables
   O            := .o       # Objects
   A            := .asm     # Assembler sources
   S            := .s       # GNU assembler sources
   P            := .cpp     # C++ sources

# File prefix/suffix definitions. The following prefixes are defined, and are
# used primarily to abstract between the Unix style libXX.a naming convention
# and the DOS/Windows/OS2 naming convention of XX.lib.
   LP           := lib      # LP - Library file prefix (name of file on disk)
   LL           := -l       # Library link prefix (name of library on link command line)
   LE           :=          # Library link suffix (extension of library on link command line)

# We use the Unix shell at all times
   SHELL        := /bin/sh
   SHELLFLAGS   := -c

# Definition of $(MAKE) macro for recursive makes.
   MAKE = $(MAKECMD) $(MFLAGS)

# Macro to install a library file
   INSTALL      := cp

# DMAKE uses this recipe to remove intermediate targets
.REMOVE :; $(RM) -f $<

# Turn warnings back to previous setting.
.SILENT := $(__.SILENT)

# We dont use TABS in our makefiles
.NOTABS         := yes

# Define that we are compiling for FreeBSD
   USE_LINUX    := 1

# Default commands for compiling, assembling linking and archiving.
.IF $(USE_EGCS)
   CC           := egcs
.ELIF $(USE_PGCC)
   CC       := pgcc
.ELSE
   CC           := gcc
.ENDIF
   CFLAGS       := -Wall -I. -Iinclude $(INCLUDE)
   CXX          := g++
   AS           := nasm
# TODO: On earlier versions of FreeBSD (<3.0) a.out is used instead of ELF
   ASFLAGS      := -f -O2 elf -d__FLAT__ -iinclude -i$(SCITECH)/include -d__NOU__
   LD           := g++
   LDFLAGS      := -L.
   LIB          := ar
   LIBFLAGS     := rcs

# Link to static libraries if requested
.IF $(STATIC_LIBS)
   LDFLAGS      += -static
.ENDIF

# Optionally turn on debugging information
.IF $(DBG)
   CFLAGS       += -g
.ELSE
# NASM does not support debugging information yet
   ASFLAGS      +=
.ENDIF

# Optionally turn on optimisations
.IF $(OPT_MAX)
   CFLAGS       += -O6
.ELIF $(OPT)
   CFLAGS       += -O2
.ELIF $(OPT_SIZE)
   CFLAGS       += -O1
.ENDIF

# Optionally turn on direct i387 FPU instructions
.IF $(FPU)
   CFLAGS       += -DFPU387
   ASFLAGS      += -dFPU387
.END

# Optionally compile a beta release version of a product
.IF $(BETA)
   CFLAGS       += -DBETA
   ASFLAGS      += -dBETA
.ENDIF

# Disable standard C runtime library

.IF $(NO_RUNTIME)
CFLAGS          += -fno-builtin -nostdinc
.ENDIF

# Compile flag for whether to build X11 or non-X11 lib
.IF $(USE_X11)
   CFLAGS       += -D__X11__
.ENDIF

# Target environment dependant flags
   CFLAGS       += -D__FREEBSD__
   ASFLAGS      += -d__FREEBSD__ -d__UNIX__

# Define the base directory for library files

.IF $(CHECKED)
LIB_BASE_DIR    := $(SCITECH_LIB)/lib/debug
CFLAGS      += -DCHECKED=1
.ELSE
LIB_BASE_DIR    := $(SCITECH_LIB)/lib/release
.ENDIF

# Use X86 assembler code for this compiler
   USE_X86          := 1

# Define where to install library files
   LIB_DEST     := $(LIB_BASE_DIR)/freebsd/gcc
   LDFLAGS      += -L$(LIB_DEST)

# Place to look for PMODE library files

PMLIB           := -lpm

# Define which file contains our rules

   RULES_MAK    := gcc_freebsd.mk
