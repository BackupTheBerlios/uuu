#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"
#include <stdlib.h>
#include <stdio.h>

#include "extralib.h"

/* 6.) udbfslib_allocate_memory_block

   Allocate memory for a UDBFSLIB_BLOCK and default initialize it.

   On Success:
   	returns a pointer to the UDBFSLIB_BLOCK structure

   On Failure:
	returns a NULL pointer
 */
UDBFSLIB_BLOCK *udbfslib_allocate_memory_block(
    UDBFSLIB_INODE *inode,
    UDBFSLIB_BLOCK **linkpoint ) {

  UDBFSLIB_BLOCK *block;

  if( (inode == NULL) || (linkpoint == NULL)) {
    fprintf(stderr,"udbfslib: cannot allocate memory block with NULL inode/linkpoint\n");
    return( NULL );
  }

  //.:  Allocate memory for block memory structure
  block = (UDBFSLIB_BLOCK *)malloc(sizeof(UDBFSLIB_BLOCK));

  if( block == NULL ) {
    perror("udbfslib: unable to allocate memory for block storage");
    return( NULL );
  }

  block->id= 0;
  block->offset_start = 0;
  block->offset_end = 0;
  block->device_offset = 0;
  block->inode = inode;

  *linkpoint = block;

  return( block );
}


