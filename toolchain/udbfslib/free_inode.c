// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/free_inode.c,v 1.6 2003/10/13 22:12:54 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <stdio.h>
#include "../conf.h"



static int		udbfslib_deallocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count,
    uint64_t			bit_id );


int		udbfs_free_inode(
    UDBFSLIB_MOUNT	*mount,
    uint64_t		inode_id ) {

  UDBFSLIB_INODE	*inode;

  inode = mount->opened_inodes;
  while( inode ) {
    if( inode->id == inode_id ) {
      fprintf(stderr,"udbfslib: cannot free an opened inode! close it first! [%016" UINT64_FORMAT "X]\n", inode_id);
      return(-1);
    }
    inode = inode->next;
  }

  return(udbfslib_deallocate_bit( mount->inode_bitmap, mount->inode_bitmap_size, &mount->free_inode_count, inode_id ));
}



/* 5.) udbfslib_deallocate_bit

   Deallocate a bit from a bitmap.

   On Success:
   	returns 0

   On Failure:
   	returns -1
 */
static int		udbfslib_deallocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count,
    uint64_t			bit_id ) {
  
  uint64_t	byte;
  uint8_t	bit;

  if( (*free_count + 1) > (bitmap_size<<3) ) {
    fprintf(stderr,"udbfslib: ERROR, udbfslib_deallocate_bit reports free count would be higher than bitmap allows, aborting [%016" UINT64_FORMAT "X:%016" UINT64_FORMAT "X]\n", *free_count + 1, bitmap_size<<3);
    return(-1);
  }

  byte = bit_id>>3;
  bit = bit_id & 0x03;
  if( (bitmap[byte] & (1<<bit)) != 0x00 ) {
    fprintf(stderr,"udbfslib: ERROR, udbfslib_deallocate_bit was requested to free an already freed bit [%016" UINT64_FORMAT "X]\n", bit_id);
    return(-1);
  }

  bitmap[byte] = bitmap[byte] | (1<<bit);
  return(0);
}
