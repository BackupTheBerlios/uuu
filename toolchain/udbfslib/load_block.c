#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"



/* 8.) udbfslib_load_block

   Allocate a UDBFSLIB_BLOCK and link it with the represented physical block
   information.

   On Success:
   	returns 0

   On Failure:
   	returns -1
 */
int		udbfslib_load_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
//    uint64_t			file_offset,
    UDBFSLIB_BLOCK		**block_hook) {

/*  UDBFSLIB_BLOCK *block = udbfslib_allocate_memory_block;

  *block_hook = block;

  block->id = block_id;
  block->inode = inode;
  block->device_offset = inode->mount->block_size * block->id;
  block->offset_start = file_offset;
  block->offset_end = file_offset + inode->mount->block_size; */

  return(-1);
}