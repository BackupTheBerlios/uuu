#! /bin/sh

# LINUX VERSION
# Set the place where SciTech Software is installed, and where each
# of the supported compilers is installed. These environment variables
# are used by the batch files in the SCITECH\BIN directory.
#
# Modify the as appropriate for your compiler configuration (you should
# only need to change things in this batch file).
#
# This version is for a normal Linux installation.
#
# Note that it is safe to call this again if you change $SCITECH to
# point to somewhere else.

# You may set the variable SCITOP to point to the top of your scitech
# tree (this is handy if you have more than one build tree). For example,
# if SCITECH is '/build/scitech/scitech', SCITOP would be '/build/scitech'.
# N.B. if you are using this scheme, it is assumed that all your files are
# under SCITOP, including the private tree. This allows you to use the
# following function to swap between active trees and P4CLIENTs.
#
# call it as so ... setscitech <new SCITOP> <new P4CLIENT>
# (you may want to set up a 'devel' and 'nodevel' alias in bash).

function setscitech()
{
    export SCITOP=$1
    export SCITECH=$SCITOP/scitech
    export SCITECH_LIB=$SCITOP/scitech
    export PRIVATE=$SCITOP/private
    export P4CLIENT=$2
    if [ "x$USE_PPC_BE" != x ]; then
        export USE_PPC_BE=1
        export PATH=$SCITECH/bin:$SCITECH/bin-linux:$SCITECH/bin-linux/ppc-be:$DEFPATH
    elif [ "x$USE_ALPHA" != x ]; then
        export USE_ALPHA=1
        export PATH=$SCITECH/bin:$SCITECH/bin-linux:$SCITECH/bin-linux/alpha:$DEFPATH
    else
        export PATH=$SCITECH/bin:$SCITECH/bin-linux:$SCITECH/bin-linux/x86:$DEFPATH
    fi
    . $SCITECH/bin/gcc-linux.sh
    echo set SCITOP to $SCITOP and P4CLIENT to $P4CLIENT
}

# The SCITECH variable points to where batch files, makefile startups,
# include files and source files will be found when compiling. If
# the MGL_ROOT variable is set, we set the SCITECH variable to point
# to the same location, unless SCITECH has already been set (in which
# case we presume it is set for a reason and don't override it).

if [ -z $SCITECH ]; then
    if [ "x$MGL_ROOT" != x ]; then
        export SCITECH=$MGL_ROOT
    fi
fi

# The SCITECH_LIB variable points to where the SciTech libraries live
# for installation and linking. This allows you to have the source and
# include files on local machines for compiling and have the libraries
# located on a common network machine (for network builds).

export SCITECH_LIB=$SCITECH

# The PRIVATE variable points to where private source files reside that
# do not live in the public source tree
if [ -z $PRIVATE ]; then export PRIVATE=$HOME/private ; fi

# The following define the locations of all the compilers that you may
# be using. Change them to reflect where you have installed your
# compilers.

export GCC_PATH=/usr/bin
export TEMP=/tmp TMP=/tmp

# save the default path so running this script again doesn't expand it
if [ -z $DEFPATH ]; then export DEFPATH=$PATH ; fi

# Change the path to include the scitech binaries.
if [ "x$USE_PPC_BE" != x ]; then
    export USE_PPC_BE=1
    export PATH=$HOME/bin:$SCITECH/bin:$SCITECH/bin-linux:$SCITECH/bin-linux/ppc-be:$DEFPATH
elif [ "x$USE_ALPHA" != x ]; then
    export USE_ALPHA=1
    export PATH=$HOME/bin:$SCITECH/bin:$SCITECH/bin-linux:$SCITECH/bin-linux/alpha:$DEFPATH
else
    export PATH=$HOME/bin:$SCITECH/bin:$SCITECH/bin-linux:$SCITECH/bin-linux/x86:$DEFPATH
fi

# Save the LD_LIBRARY_PATH so we can override this later if we switch between debug and release builds.
if [ -z $LD_LIBRARY_DEFPATH ]; then export LD_LIBRARY_DEFPATH=$LD_LIBRARY_PATH ; fi

# give LD_LIBRARY_DEFPATH a length of at least one character
if [ "q$LD_LIBRARY_DEFPATH" == "q" ]; then export LD_LIBRARY_DEFPATH=":" ; fi

