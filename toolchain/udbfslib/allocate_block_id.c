// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/allocate_block_id.c,v 1.2 2003/10/12 18:14:07 instinc Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"



uint64_t	udbfs_allocate_block_id(
    UDBFSLIB_MOUNT	*mount ) {

  return( udbfslib_allocate_bit(
	mount->block_bitmap,
	mount->block_bitmap_size,
	&mount->free_block_count) );
}
