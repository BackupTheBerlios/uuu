// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/close_inode.c,v 1.5 2003/10/13 22:12:54 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <stdio.h>
#include <unistd.h>
#include <malloc.h>

#include "../conf.h"


int		udbfs_close_inode(
    UDBFSLIB_INODE	*inode ) {

  UDBFS_INODE physical_inode;

  if( inode == NULL ) {
    fprintf(stderr,"udbfslib: WARNING: udbfs_close_inode called with NULL pointer\n");
    return(0);
  }

  printf("udbfslib: closing inode [%016" UINT64_FORMAT "X] final size [%016" UINT64_FORMAT "X]\n", inode->id, inode->size);
  // remove inode from link_list
  udbfslib_unlink(
      &inode->mount->opened_inodes,
      inode );

  // flush all UDBFSLIB_BLOCK structures and fill in the physical_inode
  physical_inode.size		= inode->size;
  physical_inode.block[0]	= 0;
  physical_inode.block[1]	= 0;
  physical_inode.block[2]	= 0;
  physical_inode.block[3]	= 0;
  physical_inode.ind_block	= 0;
  physical_inode.bind_block	= 0;
  physical_inode.tind_block	= 0;

  if( inode->block[0] != NULL ) {
    physical_inode.block[0]	= inode->block[0]->id;
    udbfslib_unload_block( &inode->block[0] );
  }
  
  if( inode->block[1] != NULL ) {
    physical_inode.block[1]	= inode->block[1]->id;
    udbfslib_unload_block( &inode->block[1] );
  }
  
  if( inode->block[2] != NULL ) {
    physical_inode.block[2]	= inode->block[2]->id;
    udbfslib_unload_block( &inode->block[2] );
  }
  
  if( inode->block[3] != NULL ) {
    physical_inode.block[3]	= inode->block[3]->id;
    udbfslib_unload_block( &inode->block[3] );
  }

  if( inode->ind_block != NULL ) {
    physical_inode.ind_block	= inode->ind_block->id;
    udbfslib_unload_ind_block( &inode->ind_block, inode );
  }

  if( inode->bind_block != NULL ) {
    physical_inode.bind_block	= inode->bind_block->id;
    udbfslib_unload_bind_block( &inode->bind_block, inode );
  }

  if( inode->tind_block != NULL ) {
    physical_inode.tind_block	= inode->tind_block->id;
    udbfslib_unload_tind_block( &inode->tind_block, inode );
  }

  if( (lseek( inode->mount->block_device, inode->physical_offset, SEEK_SET ) != inode->physical_offset) ||
      (write( inode->mount->block_device, &physical_inode, sizeof(physical_inode)) != sizeof(physical_inode) ) ) {

    perror("udbfslib: unable to save inode on block device");
  }

  free(inode);
  return(0);
}
