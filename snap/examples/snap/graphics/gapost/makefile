############################################################################
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
# Descripton:   Makefile script to build the SNAP Graphics gapost program.
#
#############################################################################

.IMPORT .IGNORE : ISV_LICENSE

#----------------------------------------------------------------------------
# DOS extender dependant flags
#----------------------------------------------------------------------------

CFLAGS      += $(DX_CFLAGS)
ASFLAGS     += $(DX_ASFLAGS)

# Indicate that this program uses SNAP device drivers (so needs I/O access)
NEEDS_IO    := 1
USE_BIOS    := 1

.IF $(ISV_LICENSE)
CFLAGS      += -DISV_LICENSE
.ENDIF

#----------------------------------------------------------------------------
# Define the lists of object files
#----------------------------------------------------------------------------

GATST_OBJS  = gapost$O

#----------------------------------------------------------------------------
# Define the targets to build the test programs and analysis tools
#----------------------------------------------------------------------------

all: gapost$E

gapost$E:   $(GATST_OBJS)

#----------------------------------------------------------------------------
# Define the list of object files to create dependency information for
#----------------------------------------------------------------------------

DEPEND_OBJ      = $(GATST_OBJS)
DEPEND_SRC      = $(PRIVATE)/src/graphics;$(PRIVATE)/src/graphics/conform

.INCLUDE: "$(SCITECH)/makedefs/common.mk"
