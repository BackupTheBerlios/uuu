// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/create_inode.c,v 1.3 2003/10/13 00:36:35 instinc Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <stdio.h>
#include <malloc.h>

#include "extralib.h"


UDBFSLIB_INODE	*udbfs_create_inode(
    UDBFSLIB_MOUNT	*mount ) {


  //.:  Allocate inode memory entry
  UDBFSLIB_INODE *inode = udbfslib_allocate_memory_inode( mount );
  if( inode == NULL ) return( inode );

  //.:  Allocate inode ID
  inode->id = udbfslib_allocate_inode_id( mount );
  if( inode->id == 0 ) {
    fprintf(stderr, "udbfslib: no free inode\n");
    free( inode );
    return( NULL );
  }

  inode->physical_offset = 
    mount->inode_table_offset + (sizeof(UDBFS_INODE)*inode->id);

  return(inode);
}
