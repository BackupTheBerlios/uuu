// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/conf.h,v 1.1 2003/10/13 22:12:54 bitglue Exp $

/*
 * This file is included by nearly every file in the Uuu toolchain. Most likely
 * it should not need to be edited; instead changes can be made by passing
 * parameters to 'make'.
 */

#ifdef DMALLOC
#include <dmalloc.h>
#endif

#ifndef UINT64_FORMAT
#define UINT64_FORMAT "ll"
#endif
