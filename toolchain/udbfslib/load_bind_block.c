// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/load_bind_block.c,v 1.11 2003/10/13 22:12:54 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <stdio.h>
#include <malloc.h>
#include <unistd.h>

#include "../conf.h"


/* 10) udbfslib_load_bind_block

   Allocate a UDBFSLIB_BINDBLOCK structure and load/link all the indirect
   blocks defined

   On Success:
   	returns 0

   On Failure:
   	returns -1
 */
int		udbfslib_load_bind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    uint64_t			offset_modifier,
    UDBFSLIB_BINDBLOCK		**linkpoint ) {

  UDBFSLIB_BINDBLOCK *bind_block = NULL;
  UDBFSLIB_BLOCK *tmp_block = NULL;

  int i, ind_links;

  if( (inode == NULL) || (linkpoint == NULL) ) {
    fprintf(stderr,"udbfslib: cannot load bi-indiret block with a NULL inode or NULL linkpoint\n");
    return( -1 );
  }

  if( block_id == 0 ) return(0);

  ind_links = inode->mount->block_size>>3;

  bind_block = (UDBFSLIB_BINDBLOCK *)malloc(
      sizeof(UDBFSLIB_BINDBLOCK) +
      (sizeof(UDBFSLIB_INDBLOCK *) * ind_links) );

  if( bind_block == NULL ) {
    perror("udbfslib: unable to allocate bi-indirect block memory structure\n");
    return( -1 );
  }

  tmp_block = (UDBFSLIB_BLOCK *)malloc(inode->mount->block_size);
  if( tmp_block == NULL ) {

    perror("udbfslib: unable to allocate temporary storage of bi-indirect data\n");
    free( bind_block );
    return( -1 );
  }

  bind_block->device_offset = block_id * inode->mount->block_size;
  bind_block->id = block_id;

  if( (lseek( inode->mount->block_device, bind_block->device_offset, SEEK_SET ) != bind_block->device_offset) ||
      (read( inode->mount->block_device, tmp_block, inode->mount->block_size ) != inode->mount->block_size) ) {

    perror("udbfslib: unable to read bi-indirect block data\n");
    free( tmp_block );
    free( bind_block );
    return( -1 );
  }

  *linkpoint = bind_block;

  for( i = 0; i<ind_links; i++ ) {
    if( ((uint64_t *)tmp_block)[i] == 0 ) {
      bind_block->indblock[i] = NULL;
    } else {

      if(
	udbfslib_load_ind_block(
	    inode,
	    ((uint64_t *)tmp_block)[i],
	    offset_modifier,
	    &bind_block->indblock[i] ) != 0 ) {

	fprintf(stderr,"udbfslib: error happened while loading indirects of bi-indirect block [%016" UINT64_FORMAT "X]\n", bind_block->id);
	return( -1 );
      }
    }

    offset_modifier += inode->mount->ind_storage;
  }
  free(tmp_block);

  return(0);
}
