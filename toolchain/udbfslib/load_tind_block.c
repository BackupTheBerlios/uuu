// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/load_tind_block.c,v 1.3 2003/10/12 19:25:40 instinc Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <malloc.h>
#include <stdio.h>
#include <unistd.h>



/* 11)	udbfslib_load_tind_block

   Allocate a UDBFSLIB_TINDBLOCK structure and load/link all the defined
   bi-indirect blocks

   On Success:
   	returns 0

   On Failure:
   	returns -1
 */
int		udbfslib_load_tind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    uint64_t			offset_modifier,
    UDBFSLIB_TINDBLOCK		**linkpoint ) {

  UDBFSLIB_TINDBLOCK *tind_block;
  UDBFSLIB_BLOCK *tmp_block;
  int i, ind_links = inode->mount->block_size>>3;

  if( (inode == NULL) || (linkpoint == NULL) ) {
    fprintf(stderr,"udbfslib: cannot load tri-indiret block with a NULL inode or NULL linkpoint\n");
    return( -1 );
  }

  if( block_id == 0 ) return(0);

  tind_block = (UDBFSLIB_TINDBLOCK *)malloc(
      sizeof(UDBFSLIB_TINDBLOCK) +
      (sizeof(UDBFSLIB_BINDBLOCK *) * (ind_links-1)) );

  if( tind_block == NULL ) {
    perror("udbfslib: unable to allocate tri-indirect block memory structure\n");
    return( -1 );
  }

  tmp_block = (UDBFSLIB_BLOCK *)malloc(inode->mount->block_size);
  if( tmp_block == NULL ) {

    perror("udbfslib: unable to allocate temporary storage of tri-indirect data\n");
    free( tind_block );
    return( -1 );
  }

  tind_block->device_offset = block_id * inode->mount->block_size;
  tind_block->id = block_id;

  if( (lseek( inode->mount->block_device, tind_block->device_offset, SEEK_SET ) != tind_block->device_offset) ||
      (read( inode->mount->block_device, tmp_block, inode->mount->block_size ) != inode->mount->block_size) ) {

    perror("udbfslib: unable to read tri-indirect block data\n");
    free( tmp_block );
    free( tind_block );
    return( -1 );
  }

  *linkpoint =  tind_block;

  for( i = 0; i<ind_links; i++ ) {
    if( ((uint64_t *)tmp_block)[i] == 0 ) {
      tind_block->bindblock[i] = NULL;
    } else {

      if(
	udbfslib_load_bind_block(
	    inode,
	    ((uint64_t *)tmp_block)[i],
	    offset_modifier,
	    &tind_block->bindblock[i] ) != 0 ) {

	fprintf(stderr,"udbfslib: error happened while loading bi-indirects of tri-indirect block [%016llX]\n", tind_block->id);
	return( -1 );
      }
    }

    offset_modifier += inode->mount->bind_storage;
  }

  fprintf(stderr,"udbfslib: tri-ind block [%016llX] OK!\n", tind_block->id);
  return(0);
}
