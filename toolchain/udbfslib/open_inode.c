// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/open_inode.c,v 1.1 2003/10/11 13:14:19 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <stdio.h>
#include <unistd.h>



UDBFSLIB_INODE *udbfs_open_inode(
    UDBFSLIB_MOUNT	*mount,
    uint32_t		inode_id ) {

  UDBFS_INODE udbfs_inode;

  //.:  Allocate inode memory entry
  UDBFSLIB_INODE *inode = udbfslib_allocate_memory_inode( mount );
  if( inode == NULL ) return( inode );

  inode->id = inode_id;

  //.:  Locate and Read the physical inode structure
  inode->physical_offset =
    mount->inode_table_offset + (sizeof(UDBFS_INODE)*inode_id);
  if( (lseek( mount->block_device, inode->physical_offset, SEEK_SET) != inode->physical_offset) ||
      (read( mount->block_device, &udbfs_inode, sizeof(UDBFS_INODE) ) != sizeof(UDBFS_INODE)) ) {

    fprintf(stderr,"udbfslib: unable to acquire inode [%08X] data\n", inode_id );
    udbfs_close_inode( inode );
    return(NULL);
  }

  inode->size = udbfs_inode.size;
  if( (udbfslib_load_block( inode, udbfs_inode.block[0], &inode->block[0] ) == 0) &&
      (udbfslib_load_block( inode, udbfs_inode.block[1], &inode->block[1] ) == 0) &&
      (udbfslib_load_block( inode, udbfs_inode.block[2], &inode->block[2] ) == 0) &&
      (udbfslib_load_block( inode, udbfs_inode.block[3], &inode->block[3] ) == 0) &&
      (udbfslib_load_ind_block( inode, udbfs_inode.ind_block, &inode->ind_block ) == 0 ) &&
      (udbfslib_load_bind_block( inode, udbfs_inode.bind_block, &inode->bind_block ) == 0) ) {
    udbfslib_load_tind_block( inode, udbfs_inode.tind_block, &inode->tind_block );
  }

  printf("udbfslib: inode [%i] size [%lli] opened\n", inode->id, inode->size );
  return( inode );
}