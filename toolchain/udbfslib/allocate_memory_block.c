#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"
#include <stdlib.h>
#include <stdio.h>


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

  if( inode == NULL ) {
    fprintf(stderr,"udbfslib: cannot allocate memory block to NULL inode\n");
    return( NULL );
  }
  if( linkpoint == NULL ) {
    fprintf(stderr,"udbfslib: must provide a link point when allocating a block memory structure\n");
    return( NULL );
  }

  //.:  Allocate memory for block memory structure
  block = (UDBFSLIB_BLOCK *)malloc(sizeof(UDBFSLIB_BLOCK));

  if( block == NULL ) {
    perror("udbfslib: unable to allocate memory for block storage");
    return( NULL );
  }

  block->next = NULL;
  block->previous = NULL;
  block->id= 0;
  block->offset_start = 0;
  block->offset_end = 0;
  block->device_offset = 0;
  block->inode = inode;

  udbfslib_link(
      linkpoint,
      block );
  
  return( block );
}


