// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/allocate_inode_id.c,v 1.5 2003/10/13 22:12:54 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include "../conf.h"


uint64_t	udbfslib_allocate_inode_id(
    UDBFSLIB_MOUNT	*mount ) {

  return( udbfslib_allocate_bit(
	mount->inode_bitmap,
	mount->inode_bitmap_size,
	&mount->free_inode_count) );
}
