// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/load_ind_block.c,v 1.6 2003/10/12 20:12:41 instinc Exp $

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



/* 9.) udbfslib_load_ind_block

   Allocate a UDBFSLIB_INDBLOCK and load/link all indirect blocks defined

   On Success:
   	returns 0

   On Failure:
   	returns -1
 */
int		udbfslib_load_ind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    uint64_t			offset_modifier,
    UDBFSLIB_INDBLOCK		**linkpoint ) {

  UDBFSLIB_INDBLOCK *ind_block = NULL;
  UDBFSLIB_BLOCK *tmp_block = NULL;

  int i, ind_links;  

  if( (inode == NULL) || (linkpoint == NULL) ) {
    fprintf(stderr,"udbfslib: cannot load indiret block with a NULL inode or NULL linkpoint\n");
    return( -1 );
  }

  if( block_id == 0 ) return(0);

  ind_links = inode->mount->block_size>>3;

  ind_block = (UDBFSLIB_INDBLOCK *)malloc(
      sizeof(UDBFSLIB_INDBLOCK) +
      (sizeof(UDBFSLIB_BLOCK *) * ind_links) );

  printf("ind_block [%016llX] allocated to [%p]\n", block_id, ind_block);

  if( ind_block == NULL ) {
    perror("udbfslib: unable to allocate indirect block memory structure\n");
    return( -1 );
  }

  tmp_block = (UDBFSLIB_BLOCK *)malloc(inode->mount->block_size);
  if( tmp_block == NULL ) {

    perror("udbfslib: unable to allocate temporary storage of indirect data\n");
    free( ind_block );
    return( -1 );
  }

  ind_block->device_offset = block_id * inode->mount->block_size;
  ind_block->id = block_id;

  if( (lseek( inode->mount->block_device, ind_block->device_offset, SEEK_SET ) != ind_block->device_offset) ||
      (read( inode->mount->block_device, tmp_block, inode->mount->block_size ) != inode->mount->block_size) ) {

    perror("udbfslib: unable to read indirect block data\n");
    free( tmp_block );
    free( ind_block );
    return( -1 );
  }

  *linkpoint = ind_block;

  for( i = 0; i<ind_links; i++ ) {

    if( ((uint64_t *)tmp_block)[i] == 0 ) {
      ind_block->block[i] = NULL;
    } else {
    
      if(
	udbfslib_load_block(
	    inode,
	    ((uint64_t *)tmp_block)[i],
	    offset_modifier,
	    &ind_block->block[i] ) != 0 ) {

	fprintf(stderr,"udbfslib: error happened while loading bi-indirects of tri-indirect block [%016llX]\n", ind_block->id);
	return( -1 );
      }
    }

    offset_modifier += inode->mount->block_size;
  }
  free(tmp_block);

  return(0);
}
