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
# Descripton:   Rules makefile definitions, which define the rules used to
#               build targets. We include them here at the end of the
#               makefile so the generic project makefiles can override
#               certain things with macros (such as linking C++ programs
#               differently).
#
#############################################################################

# Take out PMLIB if we don't need to link with it

.IF $(NO_PMLIB)
PMLIB :=
.ENDIF

# Extra C flags based on makefile settings

.IF $(STOP_ON_WARN)
    _CFLAGS     += -we
.ENDIF
.IF $(NO_DEFAULT_LIBS)
    _CFLAGS     += -zl
.ENDIF
.IF $(UNSIGNED_CHAR)
.ELSE
    _CFLAGS     += -j
.ENDIF

# Compile and link against C runtime library DLL if desired. We have this
# option in here so that we can allow makefiles to turn this on and off
# as desired.
.IF $(DLL_CRTL)
   _CFLAGS       += -br
.END

# Use a larger stack during linking if requested, or use a default stack
# of 200k. The usual default stack provided by Watcom C++ is *way* to small
# for real 32 bit code development. We also need a *huge* stack for OpenGL
# software rendering also!
.IF $(USE_QNX4)
    # Not necessary for QNX code.
.ELSE
.IF $(USE_LINUX)
    # Not necessary for Linux code.
.ELSE
.IF $(STKSIZE)
    _LDFLAGS     += OP STACK=$(STKSIZE)
.ELSE
    _LDFLAGS     += OP STACK=204800
.ENDIF
.ENDIF
.ENDIF

# Turn on runtime type information as necessary
.IF $(USE_RTTI)
    _CPFLAGS     += -xr
.ENDIF

# Optionally turn on pre-compiled headers
.IF $(PRECOMP_HDR)
    _CFLAGS      += -fhq
.ENDIF

.IF $(USE_QNX)
# Whether to link in real VBIOS library, or just the stub library
.IF $(USE_BIOS)
VBIOSLIB := vbios.lib,
.ELSE
VBIOSLIB := vbstubs.lib,
.END
# Require special privledges for SNAP programs (requires root access)
.IF $(NEEDS_IO)
_LDFLAGS     += OP PRIV=1
.ENDIF
.ENDIF

# Implicit generation rules for making object files
.IF $(WC_LIBBASE) == WC10A
%$O: %.c ; $(CC) $(_CFLAGS) $(<:s,/,\)
%$O: %$P ; $(CPP) $(_CFLAGS) $(_CPFLAGS) $(<:s,/,\)
.ELSE
%$O: %.c ; $(CC) @$(mktmp $(_CFLAGS:s/\/\\)) $(<:s,/,\)
%$O: %$P ; $(CPP) @$(mktmp $(_CFLAGS:s/\/\\) $(_CPFLAGS:s/\/\\)) $(<:s,/,\)
.ENDIF
.IF $(USE_WASM)
%$O: %$A ; wasm -q -fo=$@ $(_ASFLAGS) $(<:s,/,\)
.ELSE
%$O: %$A ; $(AS) @$(mktmp -o $@ $(_ASFLAGS:s/\/\\)) $(<:s,/,\)
%$O: %.tsm ; $(TASM) @$(mktmp $(TASMFLAGS:s/\/\\)) $(<:s,/,\)
.ENDIF

# Implit rule to compile .S assembler files. The first version
# uses GAS directly and the second uses the GNU pre-processor to
# produce NASM code.

.IF $(USE_GAS)
.IF $(HAVE_WC11)
%$O: %$S ; $(GAS) -c @$(mktmp $(GAS_FLAGS:s/\/\\)) $(<:s,/,\)
.ELSE
# Black magic to build asm sources with Watcom 10.6 (requires sed)
%$O: %$S ;
    $(GAS) -c @$(mktmp $(GAS_FLAGS:s/\/\\)) $(<:s,/,\)
    wdisasm \\ -a $(*:s,/,\).o > $(*:s,/,\).lst
    sed -e "s/\.text/_TEXT/; s/\.data/_DATA/; s/\.bss/_BSS/; s/\.386/\.586/; s/lar *ecx,cx/lar ecx,ecx/" $(*:s,/,\).lst > $(*:s,/,\).asm
    wasm \\ $(WFLAGS) -zq -fr=nul -fp3 -fo=$@ $(*:s,/,\).asm
    $(RM) -S $(mktmp $(*:s,/,\).o)
    $(RM) -S $(mktmp $(*:s,/,\).lst)
    $(RM) -S $(mktmp $(*:s,/,\).asm)
.ENDIF
.ELSE
%$O: %$S ;
    @$(CC) @$(mktmp $(_CFLAGS:s/\/\\) -DNASM_ASSEMBLER -p -za $(<:s/\/\\)) > $(*:s,/,\).asm
    nasm @$(mktmp -f obj -o $@ $(_ASFLAGS:s/\/\\)) $(*:s,/,\).asm
    @$(RM) -S $(mktmp $(*:s,/,\).asm)
.ENDIF

# Implicit rule for building resource files
%$R: %.rc ; $(RC) $(RCFLAGS) -r $< /fo=$@

# Implicit rule for building a DLL using a response file
.IF $(IMPORT_DLL)
.ELSE
.IF $(USE_OS232)
%$D: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet,impl=$(LIBFILE) SYS os2v2 dll\nN $@\nF $(&:t",\n":s/\/\\)\nLIBR $(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELIF $(USE_SNAP_DRV)
%$D: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet,impl=$*.lib option osname='SNAP binary portable' format windows nt dll\nN $@\nF $(&:t",\n":s/\/\\)\nLIBR $(DEFLIBS),$(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELIF $(USE_WIN32)
%$D: ;
.IF $(NO_RUNTIME)
    @trimlib $(mktmp $(_LDFLAGS) OP quiet,impl=$*.lib SYS format windows nt dll\nN $@\nF $(&:t",\n":s/\/\\)\nLIBR $(PMLIB)$(DEFLIBS)$(EXELIBS:t",")) $*.lnk
.ELSE
    @trimlib $(mktmp $(_LDFLAGS) OP quiet,impl=$(LIBFILE) SYS nt_dll\nN $@\nF $(&:t",\n":s/\/\\)\nLIBR $(PMLIB)$(DEFLIBS)$(EXELIBS:t",")) $*.lnk $*.ref
.ENDIF
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELSE
%$D: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet SYS win386\nN $*.rex\nF $(&:t",\n":s/\/\\)\nLIBR $(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
    wbind $* -d -q -n
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ENDIF
.ENDIF

# Implicit rule for building a library file using response file (DLL import library
# is built along with the DLL itself).
.IF $(BUILD_DLL)
.ELIF $(IMPORT_DLL)
%$L: ;
    @$(RM) $@
    $(ILIB) $(ILIBFLAGS) $@ +$?
.ELSE
%$L: ;
    @$(RM) $@
    $(LIB) $(LIBFLAGS) $@ @$(mktmp,$*.rsp +$(&:t"\n+":s/\/\\)\n)
.ENDIF

# Implicit rule for building an executable file using response file
.IF $(USE_X32)
%$E: ;
    @trimlib $(mktmp OP quiet\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(EXELIBS:t",")) $*.lnk
    $(LD) $(_LDFLAGS) @$*.lnk
    x32fix $@
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELIF $(USE_OS232)
.IF $(USE_OS2GUI)
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet SYS os2v2_pm\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.IF $(LXLITE)
    lxlite $@
.ENDIF
.ELSE
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet SYS os2v2\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.IF $(LXLITE)
    lxlite $@
.ENDIF
.ENDIF
.ELIF $(USE_SNAP)
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet SYS snap\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(DEFLIBS)$(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELIF $(USE_WIN32)
.IF $(WIN32_GUI)
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet SYS win95\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(DEFLIBS)$(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELSE
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet SYS nt\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(DEFLIBS)$(EXELIBS:t",")) $*.lnk
    rclink $(LD) $(RC) $@ $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ENDIF
.ELIF $(USE_WIN386)
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet SYS win386\nN $*.rex\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(EXELIBS:t",")) $*.lnk
    rclink $(LD) wbind $*.rex $*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELIF $(USE_TNT)
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet\nN $@\nF $(&:t",":s/\/\\)\nLIBR dosx32.lib,tntapi.lib,$(PMLIB)$(EXELIBS:t",")) $*.lnk
    $(LD) @$*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.IF $(DOSSTYLE)
    @markphar $@
.ENDIF
.ELIF $(USE_QNX4)
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(VBIOSLIB)$(EXELIBS:t",")) $*.lnk
    @+if exist $*.exe attrib -s $*.exe > NUL
    $(LD) @$*.lnk
    @attrib +s $*.exe
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ELSE
%$E: ;
    @trimlib $(mktmp $(_LDFLAGS) OP quiet\nN $@\nF $(&:t",":s/\/\\)\nLIBR $(PMLIB)$(EXELIBS:t",")) $*.lnk
    $(LD) @$*.lnk
.IF $(LEAVE_LINKFILE)
.ELSE
    @$(RM) -S $(mktmp *.lnk)
.ENDIF
.ENDIF

