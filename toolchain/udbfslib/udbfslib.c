#define _LARGEFILE64_SOURCE
#define _LARGEFILE_SOURCE
#define _FILE_OFFSET_BITS 64
#define _POSIX_SOURCE

#include "udbfslib.h"
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>


static uint64_t allocate_bit( uint8_t *bitmap, uint64_t size );
static uint64_t allocate_block( UDBFS_MOUNT *mount );
static uint32_t allocate_inode( UDBFS_MOUNT *mount );
static int load_block_bitmap( UDBFS_MOUNT *mount );
static int load_inode_bitmap( UDBFS_MOUNT *mount );
static void link_mount( UDBFS_MOUNT *mount );
static void unlink_mount( UDBFS_MOUNT *mount );
static int validate_superblock( UDBFS_MOUNT *mount );


UDBFS_MOUNT *mounted_devices = NULL;



UDBFS_MOUNT *udbfs_mount( char *block_device ) {

  int mount_file;
  UDBFS_MOUNT *mount;

  printf("lib: request received to mount [%s]\n", block_device );

  if( (mount_file = open(block_device, O_RDWR | O_LARGEFILE )) == -1 ) {
    perror("lib: unable to open block device");
    return(NULL);
  }

  if( (mount = (UDBFS_MOUNT *)malloc(sizeof(UDBFS_MOUNT))) == NULL ) {
    close(mount_file);
    perror("lib: unable to allocate memory required to store the mount information");
    return(NULL);
  }

  mount->block_device = mount_file;
  mount->next = NULL;
  mount->previous = NULL;
  mount->inode_bitmap = NULL;
  mount->block_bitmap = NULL;

  link_mount( mount );

  if( (validate_superblock( mount ) != 0) ||
      (load_inode_bitmap( mount ) != 0) ||
      (load_block_bitmap( mount ) != 0) ) {

    udbfs_unmount( mount );
    return(NULL);
  }

  printf("lib: [%s] mounted as [%p]\n", block_device, mount );
  return(mount);
}



void udbfs_unmount( UDBFS_MOUNT *mount ) {

  if( mount == NULL ) return;

  printf("lib: closing mount [%p]\n", mount );

  unlink_mount( mount );

  // TODO: save all modified fs structure/data

  if( mount->inode_bitmap != NULL ) {
    free( mount->inode_bitmap );
    mount->inode_bitmap = NULL;
  }

  if( mount->block_bitmap != NULL ) {
    free( mount->block_bitmap );
    mount->block_bitmap = NULL;
  }

  if( mount->block_device != 0 ) {
    close( mount->block_device );
    mount->block_device = 0;
  }

  free( mount );
}







UDBFS_INODE *create_inode( UDBFS_MOUNT *mount ) {

  UDBFS_INODE *inode = (UDBFS_INODE *)malloc(sizeof(UDBFS_INODE));

  if( inode == NULL ) {

    perror("lib: unable to allocate memory for inode structure\n");

  } else {
    
    inode->next = NULL;
    inode->previous = NULL;
    inode->id = allocate_inode( mount );
    inode->file_size = 0;
    inode->current_offset = 0;
    inode->current_block = NULL;
    inode->blocks = NULL;

  }
  return( inode );
}



UDBFS_INODE *open_inode( UDBFS_MOUNT *mount, uint32_t inode_id ) {
  return(NULL);
}






static void link_mount( UDBFS_MOUNT *mount ) {
  
  mount->next = mounted_devices;
  mounted_devices = mount;

}



static void unlink_mount( UDBFS_MOUNT *mount ) {

  if( mount->previous != NULL ) {

    mount->previous->next = mount->next;

  } else {

    if( mounted_devices != mount ) {
      fprintf(stderr,"lib: dual unlinking of mount point from linked list caught.\n");
      return;
    }

    mounted_devices = mount->next;
  }


  if( mount->next != NULL ) {
    mount->next->previous = mount->previous;
  }

  mount->next = NULL;
  mount->previous = NULL;
}




static int validate_superblock( UDBFS_MOUNT *mount ) {

  if( (lseek( mount->block_device, 1024, SEEK_SET ) != 1024 ) ||
      (read( mount->block_device, &mount->superblock, sizeof(UDBFS_SUPERBLOCK)) != sizeof(UDBFS_SUPERBLOCK) )) {
    perror("lib: unable to read the superblock");
    return(-1);
  }

  if( mount->superblock.magic_number != UDBFS_MAGIC ) {
    fprintf(stderr,"lib: failed to locate superblock signature\n");
    return(-1);
  }
  if( mount->superblock.superblock_version != 1 ) {
    fprintf(stderr,"lib: unknown superblock version: %i\n", mount->superblock.superblock_version );
    return(-1);
  }

  if( mount->superblock.block_size < 9 ) {
    fprintf(stderr,"lib: recorded block size is invalid: too small\n");
    return(-1);
  }
  if( mount->superblock.block_size > 20 ) {
    fprintf(stderr,"lib: WARNING: block size is over 20bits: %i bits\n", mount->superblock.block_size );
  }

  return( 0 );
}




static int load_inode_bitmap( UDBFS_MOUNT *mount ) {

  int64_t offset = (1<<mount->superblock.block_size)*mount->superblock.bitmaps_block+((mount->superblock.block_count + 7)>>3);
  int64_t size = (mount->superblock.inode_count + 7)>>3;

  printf("lib: loading inode bitmap from offset [%016llX] for [%016llX]\n", offset, size);
  mount->inode_bitmap = (uint8_t *)malloc(size);
  if( mount->inode_bitmap == NULL ) {
    perror("lib: unable to allocate memory for inode bitmap");
    return(-1);
  }

  if( (lseek( mount->block_device, offset, SEEK_SET ) != offset) ||
      (read(mount->block_device, mount->inode_bitmap, size ) != size) ) {
    perror("lib: unable to load inode bitmap");
    return(-1);
  }

  return(0);
}




static int load_block_bitmap( UDBFS_MOUNT *mount ) {

  int64_t offset = (1<<mount->superblock.block_size)*mount->superblock.bitmaps_block;
  int64_t size = (mount->superblock.block_count + 7)>>3;

  printf("lib: loading block bitmap from offset [%016llX] for [%016llX]\n", offset, size);

  mount->block_bitmap = (uint8_t *)malloc(size);
  if( mount->block_bitmap == NULL ) {
    perror("lib: unable to allocate memory for block bitmap");
    return(-1);
  }

  if( (lseek( mount->block_device, offset, SEEK_SET ) != offset) ||
      (read( mount->block_device, mount->block_bitmap, size ) != size) ) {
    perror("lib: unable to load block bitmap");
    return(-1);
  }

  return(0);
}






static uint32_t allocate_inode( UDBFS_MOUNT *mount ) {

  uint32_t inode_id =(uint32_t)(allocate_bit( mount->inode_bitmap, mount->superblock.inode_count ) );

  if( inode_id == 0 ) {
    fprintf(stderr,"lib: [%p] out of inode entry\n", mount);
  }

  return( inode_id );
}





static uint64_t allocate_block( UDBFS_MOUNT *mount ) {

  uint64_t block_id =allocate_bit( mount->block_bitmap, mount->superblock.block_count );

  if( block_id == 0 ) {
    fprintf(stderr,"lib: [%p] out of disk block\n", mount);
  }

  return( block_id );
}





static uint64_t allocate_bit( uint8_t *bitmap, uint64_t bitmap_size ) {

  uint64_t bytesize = (bitmap_size + 7)>>3;
  uint64_t byte = 0;
  int bit = 0;

  while( byte <= bytesize ) {
    
    if( bitmap[byte] != 0x00 ) {

      while( ((1<<bit) & bitmap[byte]) == 0x00 ) {
	bit++;
      }
      bitmap[byte] = bitmap[byte] ^ (1<<bit);
      return( (byte<<3) + bit );
    }

    byte++;
  }

  return(0);
}



