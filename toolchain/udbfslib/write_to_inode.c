// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/write_to_inode.c,v 1.2 2003/10/12 15:21:10 instinc Exp $

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



static UDBFSLIB_BLOCK	*udbfslib_extend_tindblock(
    UDBFSLIB_TINDBLOCK		*tindblock,
    UDBFSLIB_INODE		*inode,
    uint64_t			modifier_offset );

static UDBFSLIB_BLOCK	*udbfslib_extend_inode(
    UDBFSLIB_INODE		*inode );

static UDBFSLIB_BLOCK	*udbfslib_extend_indblock(
    UDBFSLIB_INDBLOCK		*indblock,
    UDBFSLIB_INODE		*inode,
    uint64_t			modifier_offset );

static UDBFSLIB_BLOCK	*udbfslib_extend_bindblock(
    UDBFSLIB_BINDBLOCK		*bindblock,
    UDBFSLIB_INODE		*inode,
    uint64_t			modifier_offset );

static UDBFSLIB_INDBLOCK *udbfslib_allocate_memory_indblock(
    UDBFSLIB_INODE		*inode,
    UDBFSLIB_INDBLOCK		**linkpoint);

static UDBFSLIB_BINDBLOCK *udbfslib_allocate_memory_bindblock(
    UDBFSLIB_INODE		*inode,
    UDBFSLIB_BINDBLOCK		**linkpoint);

static UDBFSLIB_TINDBLOCK *udbfslib_allocate_memory_tindblock(
    UDBFSLIB_INODE		*inode,
    UDBFSLIB_TINDBLOCK		**linkpoint);



int		udbfs_write_to_inode(
    UDBFSLIB_INODE	*inode,
    uint8_t		*data,
    uint32_t		size ) {

  UDBFSLIB_BLOCK *block;
  int partial_write_size;
  int data_offset = 0;
  uint64_t physical_offset;

  if( inode == NULL ) return(0);

  while( size > 0 ) {
    
    block = udbfslib_select_active_inode_block( inode );
    if( block == NULL ) {
      block = udbfslib_extend_inode( inode );
    }

    partial_write_size = block->offset_end - inode->cursor;
    partial_write_size = partial_write_size > size ? size : partial_write_size;

    physical_offset = block->device_offset + inode->cursor - block->offset_start;

    printf("writing %08X bytes from file offset %016llX to disk physical offset %016llX...\n", partial_write_size, inode->cursor, physical_offset);
 

    if( (lseek(inode->mount->block_device, physical_offset, SEEK_SET) != physical_offset ) ||
        (write(inode->mount->block_device, &data[data_offset], partial_write_size) != partial_write_size ) ) {

      perror("udbfslib: error writing to block device");
      return(data_offset);
    }

    size = size - partial_write_size;
    inode->cursor += partial_write_size;
    data_offset += partial_write_size;
    if( inode->cursor > inode->size )
      inode->size = inode->cursor;
  }
  return( data_offset );
}


/* 19) udbfslib_allocate_memory_bindblock
 */
static UDBFSLIB_BINDBLOCK *udbfslib_allocate_memory_bindblock(
    UDBFSLIB_INODE	*inode,
    UDBFSLIB_BINDBLOCK	**linkpoint ) {

  UDBFSLIB_BINDBLOCK *block;
  int blocks = inode->mount->block_size >> 3;

  if( inode == NULL ) {
    fprintf(stderr,"udbfslib: cannot allocate memory bindblock to NULL inode\n");
    return( NULL );
  }
  if( linkpoint == NULL ) {
    fprintf(stderr,"udbfslib: must provide a link point when allocating a bindblock memory structure\n");
    return( NULL );
  }

  //.:  Allocate memory for bindblock memory structure
  block = (UDBFSLIB_BINDBLOCK *)malloc(sizeof(UDBFSLIB_BINDBLOCK) + inode->mount->block_size);

  if( block == NULL ) {
    perror("udbfslib: unable to allocate memory for bindblock storage");
    return( NULL );
  }

  block->id= 0;
  block->device_offset = 0;
  while( blocks-- ) {
    block->indblock[blocks] = NULL;
  }

  *linkpoint = block;
  return( block );
}



/* 20) udbfslib_allocate_memory_tindblock
 */
static UDBFSLIB_TINDBLOCK *udbfslib_allocate_memory_tindblock(
    UDBFSLIB_INODE	*inode,
    UDBFSLIB_TINDBLOCK	**linkpoint ) {

  UDBFSLIB_TINDBLOCK *block;
  int blocks = inode->mount->block_size >> 3;

  if( inode == NULL ) {
    fprintf(stderr,"udbfslib: cannot allocate memory tindblock to NULL inode\n");
    return( NULL );
  }
  if( linkpoint == NULL ) {
    fprintf(stderr,"udbfslib: must provide a link point when allocating a tindblock memory structure\n");
    return( NULL );
  }

  //.:  Allocate memory for tindblock memory structure
  block = (UDBFSLIB_TINDBLOCK *)malloc(sizeof(UDBFSLIB_TINDBLOCK) + inode->mount->block_size);

  if( block == NULL ) {
    perror("udbfslib: unable to allocate memory for tindblock storage");
    return( NULL );
  }

  block->id= 0;
  block->device_offset = 0;
  while( blocks-- ) {
    block->bindblock[blocks] = NULL;
  }

  *linkpoint = block;
  return( block );
}




/* 18) udbfslib_allocate_memory_indblock
 */
static UDBFSLIB_INDBLOCK *udbfslib_allocate_memory_indblock(
    UDBFSLIB_INODE	*inode,
    UDBFSLIB_INDBLOCK	**linkpoint ) {

  UDBFSLIB_INDBLOCK *block;
  int blocks = inode->mount->block_size >> 3;

  if( inode == NULL ) {
    fprintf(stderr,"udbfslib: cannot allocate memory indblock to NULL inode\n");
    return( NULL );
  }
  if( linkpoint == NULL ) {
    fprintf(stderr,"udbfslib: must provide a link point when allocating a indblock memory structure\n");
    return( NULL );
  }

  //.:  Allocate memory for indblock memory structure
  block = (UDBFSLIB_INDBLOCK *)malloc(sizeof(UDBFSLIB_INDBLOCK) + inode->mount->block_size);

  if( block == NULL ) {
    perror("udbfslib: unable to allocate memory for indblock storage");
    return( NULL );
  }

  block->id= 0;
  block->device_offset = 0;
  while( blocks-- ) {
    block->block[blocks] = NULL;
  }

  *linkpoint = block;
  return( block );
}



/* 22) udbfslib_extend_bindblock
 */
static UDBFSLIB_BLOCK *udbfslib_extend_bindblock(
    UDBFSLIB_BINDBLOCK	*bindblock,
    UDBFSLIB_INODE	*inode,
    uint64_t		modifier_offset ) {

  int indblocks;
  int i;
  UDBFSLIB_BLOCK *block;

  /* security catch */
  if( (bindblock == NULL) || (inode == NULL) )
    return(NULL);
  
  indblocks = inode->mount->block_size >> 3;
  for(i=0; i< indblocks; i++) {
    
    if( bindblock->indblock[i] == NULL ) {
      UDBFSLIB_INDBLOCK *indblock = udbfslib_allocate_memory_indblock(
        inode,
	&bindblock->indblock[i] );
      indblock->id = udbfslib_allocate_bit(
        inode->mount->block_bitmap,
	inode->mount->block_bitmap_size,
	&inode->mount->free_block_count );
      return( udbfslib_extend_indblock( indblock, inode, modifier_offset ) );
    } else {

      block = udbfslib_extend_indblock(
        bindblock->indblock[i],
	inode,
	modifier_offset );
      
      if( block != NULL )
        return( block );

    }

    modifier_offset += inode->mount->block_size;
  }
  return(NULL);
}



/* 21) udbfslib_extend_indblock
 */
static UDBFSLIB_BLOCK *udbfslib_extend_indblock(
    UDBFSLIB_INDBLOCK	*indblock,
    UDBFSLIB_INODE	*inode,
    uint64_t		modifier_offset ) {

  int blocks;
  int i;

  /* security catch */
  if( (indblock == NULL) || (inode == NULL) )
    return(NULL);

  blocks = inode->mount->block_size >> 3;

  for(i=0; i < blocks; i++) {
    if( indblock->block[i] == NULL ) {
      UDBFSLIB_BLOCK *block = udbfslib_allocate_memory_block(
        inode,
	&indblock->block[i] );
      block->offset_start = modifier_offset + (i * inode->mount->block_size);
      return(block);
    }
  }
  return(NULL);
}



/* 16) udbfslib_extend_inode
 */
static UDBFSLIB_BLOCK *udbfslib_extend_inode(
    UDBFSLIB_INODE	*inode ) {

  UDBFSLIB_BLOCK *block = NULL;

  if( inode->block[0] == NULL ) {
    block = udbfslib_allocate_memory_block( inode, &inode->block[0] );
    block->offset_start = 0;
    goto finalize;
  }

  if( inode->block[1] == NULL ) {
    block = udbfslib_allocate_memory_block( inode, &inode->block[1] );
    block->offset_start = inode->mount->block_size;
    goto finalize;
  }

  if( inode->block[2] == NULL ) {
    block = udbfslib_allocate_memory_block( inode, &inode->block[2] );
    block->offset_start = inode->mount->block_size * 2;
    goto finalize;
  }

  if( inode->block[3] == NULL ) {
    block = udbfslib_allocate_memory_block( inode, &inode->block[3] );
    block->offset_start = inode->mount->block_size * 3;
    goto finalize;
  }

  if( inode->ind_block == NULL ) {
    inode->ind_block = udbfslib_allocate_memory_indblock( inode, &inode->ind_block );
    inode->ind_block->id = udbfslib_allocate_bit( inode->mount->block_bitmap, inode->mount->block_bitmap_size, &inode->mount->free_block_count );

  }
  block = udbfslib_extend_indblock( inode->ind_block, inode, inode->mount->dir_storage );
  if( block != NULL )
    goto finalize;

  if( inode->bind_block == NULL ) {
    inode->bind_block = udbfslib_allocate_memory_bindblock( inode, &inode->bind_block );
    inode->bind_block->id = udbfslib_allocate_bit( inode->mount->block_bitmap, inode->mount->block_bitmap_size, &inode->mount->free_block_count );

  }
  block = udbfslib_extend_bindblock( inode->bind_block, inode, inode->mount->dir_storage + inode->mount->ind_storage );
  if( block != NULL )
    goto finalize;

  if( inode->tind_block == NULL ) {
    inode->tind_block = udbfslib_allocate_memory_tindblock( inode, &inode->tind_block );
    inode->tind_block->id = udbfslib_allocate_bit( inode->mount->block_bitmap, inode->mount->block_bitmap_size, &inode->mount->free_block_count );
  }
  block = udbfslib_extend_tindblock( inode->tind_block, inode, inode->mount->dir_storage + inode->mount->ind_storage + inode->mount->bind_storage );
  if( block != NULL )
    goto finalize;

  fprintf(stderr,"udbfslib: cannot extend inode, out of disk space or file too large.\n");
  return(NULL);

finalize:
  block->id = udbfslib_allocate_bit( inode->mount->block_bitmap, inode->mount->block_bitmap_size, &inode->mount->free_block_count );
  block->offset_end = block->offset_start + inode->mount->block_size;
  block->device_offset = block->id * inode->mount->block_size;

  printf("udbfslib: block [%lli] allocated to inode [%i] carrying offset [%016llX-%016llX] at device offset [%016llX]\n", block->id, inode->id, block->offset_start, block->offset_end, block->device_offset);
  return(block);
}



/* 23) udbfslib_extend_tindblock
 */
static UDBFSLIB_BLOCK *udbfslib_extend_tindblock(
    UDBFSLIB_TINDBLOCK	*tindblock,
    UDBFSLIB_INODE	*inode,
    uint64_t		modifier_offset ) {

  int bindblocks;
  int i;
  UDBFSLIB_BLOCK *block;

  /* security catch */
  if( (tindblock == NULL) || (inode == NULL) )
    return(NULL);

  bindblocks = inode->mount->block_size >> 3;
  for(i=0; i< bindblocks; i++) {
    
    if( tindblock->bindblock[i] == NULL ) {
      UDBFSLIB_BINDBLOCK *bindblock = udbfslib_allocate_memory_bindblock(
        inode,
	&tindblock->bindblock[i] );
      bindblock->id = udbfslib_allocate_bit(
        inode->mount->block_bitmap,
	inode->mount->block_bitmap_size,
	&inode->mount->free_block_count );
      return( udbfslib_extend_bindblock( bindblock, inode, modifier_offset ) );
    } else {
      
      block = udbfslib_extend_bindblock(
        tindblock->bindblock[i],
	inode,
	modifier_offset );

      if( block != NULL )
        return( block );
    }

    modifier_offset += inode->mount->block_size;
  }
  return(NULL);
}
