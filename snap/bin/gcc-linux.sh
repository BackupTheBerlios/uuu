#! /bin/sh

# Setup for compiling with GCC/G++ for Linux

if [ "$CHECKED" = "1" ]; then
    echo Checked debug build enabled.
else
    echo Release build enabled.
fi

export INCLUDE="-Iinclude -I$SCITECH/include -I$PRIVATE/include"
export USE_LINUX=1
export MAKESTARTUP=$SCITECH/makedefs/gcc_linux.mk

if [ "x$USE_PPC_BE" != x ]; then
    export LD_LIBRARY_PATH=$SCITECH/lib/debug/linux/gcc/ppc-be/so:$LD_LIBRARY_DEFPATH
    echo "GCC Linux console compilation environment set up (PPC Big Endian)"
elif [ "x$USE_ALPHA" != x ]; then
    export LD_LIBRARY_PATH=$SCITECH/lib/debug/linux/gcc/alpha/so:$LD_LIBRARY_DEFPATH
    echo "GCC Linux console compilation environment set up (Alpha)"
else
    export LD_LIBRARY_PATH=$SCITECH/lib/debug/linux/gcc/x86/so:$LD_LIBRARY_DEFPATH
    echo "GCC Linux console compilation environment set up (x86)"
fi
