// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/allocate_memory_inode.c,v 1.2 2003/10/12 21:31:42 instinc Exp $

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


/* 7.) udbfslib_allocate_memory_inode

   Allocate memory for a UDBFSLIB_INODE and default initialize it.

   On Success:
   	returns a pointer to the UDBFSLIB_INODE structure

   On Failure:
   	returns a NULL pointer
 */
UDBFSLIB_INODE *udbfslib_allocate_memory_inode(
    UDBFSLIB_MOUNT *mount ) {

  //.:  Allocate memory for inode structure
  UDBFSLIB_INODE *inode =
    (UDBFSLIB_INODE *)malloc(sizeof(UDBFSLIB_INODE));

  if( inode == NULL ) {
    perror("udbfslib: unable to allocate memory for inode");
    return( NULL );
  }

  //.:  Initialize inode structure
  inode->next = NULL;
  inode->previous = NULL;
  inode->id = 0;
  inode->cursor = 0;
  inode->size = 0;
  inode->block[0] = NULL;
  inode->block[1] = NULL;
  inode->block[2] = NULL;
  inode->block[3] = NULL;
  inode->ind_block = NULL;
  inode->bind_block = NULL;
  inode->tind_block = NULL;
  inode->mount = mount;

  //.:  Link inode in mount point and return inode
  udbfslib_link( &mount->opened_inodes, inode );
  return(inode);
}
