// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/add_column.c,v 1.1 2003/10/11 13:14:19 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"



int		udbfs_add_column(
    UDBFSLIB_TABLE	*table,
    char		*name,
    uint8_t		datatype,
    uint32_t		size,
    uint32_t		count,
    uint32_t		compression,
    uint32_t		encryption ) {

  return(-1);
}