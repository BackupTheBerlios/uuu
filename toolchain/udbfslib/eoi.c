// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/eoi.c,v 1.3 2003/10/13 22:12:54 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"


#include "../conf.h"

int udbfs_eoi(
    UDBFSLIB_INODE	*inode ) {

  if( inode->cursor == inode->size )
    return(1);

  return(0);
}
