// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/select_active_inode_block.c,v 1.1 2003/10/11 13:14:19 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"

#include <stdio.h>



/* 17) udbfslib_select_active_inode_block
 */
UDBFSLIB_BLOCK *udbfslib_select_active_inode_block(
    UDBFSLIB_INODE *inode ) {

  uint64_t adjusted_offset;

  if( inode->cursor < inode->mount->dir_storage ) {
    int id = inode->cursor / inode->mount->block_size;

    return( inode->block[id] );
  }
  adjusted_offset = inode->cursor - inode->mount->dir_storage;

  if( inode->cursor < (inode->mount->ind_storage + inode->mount->dir_storage) ) {
    int id = adjusted_offset / inode->mount->block_size;

    if( inode->ind_block == NULL )
      return(NULL);

    return( inode->ind_block->block[id] );
  }
  adjusted_offset -= inode->mount->ind_storage;

  if( inode->cursor < (inode->mount->bind_storage + inode->mount->ind_storage + inode->mount->dir_storage) ) {
    int ind_id = adjusted_offset / inode->mount->ind_storage;
    int id = (adjusted_offset % inode->mount->ind_storage) / inode->mount->block_size;

    if( inode->bind_block == NULL )
      return(NULL);

    if( inode->bind_block->indblock[ind_id] == NULL )
      return(NULL);
    
    return(inode->bind_block->indblock[ind_id]->block[id]);
  }
  adjusted_offset -= inode->mount->bind_storage;

  if( inode->cursor < (inode->mount->tind_storage + inode->mount->bind_storage + inode->mount->ind_storage + inode->mount->dir_storage) ) {
    int bind_id = adjusted_offset / inode->mount->bind_storage;
    uint64_t ind_adjusted_offset = adjusted_offset % inode->mount->bind_storage;
    int ind_id = ind_adjusted_offset / inode->mount->ind_storage;
    int id = (ind_adjusted_offset % inode->mount->ind_storage) / inode->mount->block_size;

    if( inode->tind_block == NULL )
      return(NULL);

    if( inode->tind_block->bindblock[bind_id] == NULL )
      return(NULL);

    if( inode->tind_block->bindblock[bind_id]->indblock[ind_id] == NULL )
      return(NULL);

    return( inode->tind_block->bindblock[bind_id]->indblock[ind_id]->block[id] );
  }

  fprintf(stderr,"udbfslib: file cursor is past maximum file size limit\n");
  return(NULL);
}
