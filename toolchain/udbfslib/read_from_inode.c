// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/read_from_inode.c,v 1.4 2003/10/13 20:43:23 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <stdio.h>
#include <unistd.h>

#include "extralib.h"


int		udbfs_read_from_inode(
    UDBFSLIB_INODE	*inode,
    uint8_t		*data,
    uint32_t		size ) {

  UDBFSLIB_BLOCK *block;
  int partial_read_size;
  int data_offset = 0;
  uint64_t physical_offset;

  if( inode == NULL ) return(0);

  /* make sure we don't read past end of data */
  partial_read_size = inode->size - inode->cursor;
  size = size < partial_read_size ? size : partial_read_size;

  while( size > 0 ) {
 
    block = udbfslib_select_active_inode_block( inode );
    if( block == NULL ) {
      fprintf(stderr,"huh.. we got a problem.\n");
    }

    partial_read_size = block->offset_end - inode->cursor;
    partial_read_size = partial_read_size > size ? size : partial_read_size;

    physical_offset = block->device_offset + inode->cursor - block->offset_start;

    printf("reading %08X bytes to file offset %016" UINT64_FORMAT "X from disk physical offset %016" UINT64_FORMAT "X...\n", partial_read_size, inode->cursor, physical_offset);
 

    if( (lseek(inode->mount->block_device, physical_offset, SEEK_SET) != physical_offset ) ||
        (read(inode->mount->block_device, &data[data_offset], partial_read_size) != partial_read_size ) ) {

      perror("udbfslib: error reading from block device");
      return(data_offset);
    }

    size = size - partial_read_size;
    inode->cursor += partial_read_size;
    data_offset += partial_read_size;
  }
  return( data_offset );
}
