#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#include "extralib.h"

/* 14) udbfslib_unload_bind_block
 */
void udbfslib_unload_bind_block(
    UDBFSLIB_BINDBLOCK	**bindblock_hook,
    UDBFSLIB_INODE	*inode ) {

  int i, ind_links;
  uint64_t block_id;
  uint64_t device_offset;

  if( (inode == NULL) || (bindblock_hook == NULL) ) return;

  ind_links = inode->mount->block_size >> 3;

  if( *bindblock_hook == NULL) return;

  device_offset = (*bindblock_hook)->device_offset;

  for(i=0; i<ind_links; i++) {
    if( (*bindblock_hook)->indblock[i] == NULL ) {
      block_id = 0;
    } else {
      block_id = (*bindblock_hook)->indblock[i]->id;
      udbfslib_unload_ind_block( &(*bindblock_hook)->indblock[i], inode );
    }
    if( (lseek( inode->mount->block_device, device_offset, SEEK_SET) != device_offset ) ||
        (write( inode->mount->block_device, &block_id, sizeof(block_id) ) != sizeof(block_id)) ) {
      perror("udbfslib: unable to save part of bind block");
    }

    device_offset += sizeof(block_id);
  }

  free( *bindblock_hook );
}




/* 12) udbfslib_unload_block
 */
void udbfslib_unload_block(
    UDBFSLIB_BLOCK	**block_hook ) {

  if( *block_hook == NULL ) return;

  free(*block_hook);
  *block_hook = NULL;
}


/* 13) udbfslib_unload_ind_block
 */
void udbfslib_unload_ind_block(
    UDBFSLIB_INDBLOCK	**indblock_hook,
    UDBFSLIB_INODE	*inode ) {

  int i, ind_links;
  uint64_t block_id;

  if( (inode == NULL) || (indblock_hook == NULL) ) return;

  ind_links = inode->mount->block_size >> 3;

  if( *indblock_hook == NULL) return;

  if( lseek( inode->mount->block_device, (*indblock_hook)->device_offset, SEEK_SET ) != (*indblock_hook)->device_offset ) {
    perror("udbfslib: unable to seek to indirect block storage");
  }

  for(i=0; i<ind_links; i++) {
    if( (*indblock_hook)->block[i] == NULL ) {
      block_id = 0;
    } else {
      block_id = (*indblock_hook)->block[i]->id;
      udbfslib_unload_block( &(*indblock_hook)->block[i] );
    }
    write( inode->mount->block_device, &block_id, sizeof(block_id) );
  }
  free( (*indblock_hook) );
}



/* 15) udbfslib_unload_tind_block
 */
void udbfslib_unload_tind_block(
    UDBFSLIB_TINDBLOCK	**tindblock_hook,
    UDBFSLIB_INODE	*inode ) {

  int i, ind_links;
  uint64_t block_id;
  uint64_t device_offset;

  if( (inode == NULL) || (tindblock_hook == NULL) ) return;

  ind_links = inode->mount->block_size >> 3;

  if( *tindblock_hook == NULL) return;

  device_offset = (*tindblock_hook)->device_offset;

  for(i=0; i<ind_links; i++) {
    if( (*tindblock_hook)->bindblock[i] == NULL ) {
      block_id = 0;
    } else {
      block_id = (*tindblock_hook)->bindblock[i]->id;
      udbfslib_unload_bind_block( &(*tindblock_hook)->bindblock[i], inode );
    }
    if( (lseek( inode->mount->block_device, device_offset, SEEK_SET) != device_offset) ||
        (write( inode->mount->block_device, &block_id, sizeof(block_id) ) != sizeof(block_id)) ) {
      perror("udbfslib: unable to save part of tind block");
    }
    device_offset += sizeof(block_id);
  }

  free( *tindblock_hook );
}
