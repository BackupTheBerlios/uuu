// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/mount.c,v 1.6 2003/10/12 23:23:45 instinc Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"
#include "private.h"

#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <malloc.h>

#include "extralib.h"



static UDBFS_SUPERBLOCK	*udbfslib_validate_superblock(
    UDBFSLIB_MOUNT 		*mount );


/* .    .   .  . .. ..... DATA ..... .. .  .   .     . */
static UDBFSLIB_MOUNT		*mounted_devices;



UDBFSLIB_MOUNT	*udbfs_mount(
    char		*block_device ) {

  int				mount_fd = 0;
  UDBFSLIB_MOUNT		*mount = NULL;

  //.:  Create File Descriptor
  if( (mount_fd = open(
	  block_device,
	  O_RDWR | O_LARGEFILE )
	) == -1 ) {
    
    perror(block_device);
    goto failed_mount;
  }

  //.:  Allocate memory for the mount structure
  if( (mount = (UDBFSLIB_MOUNT *)malloc(
	  sizeof(UDBFSLIB_MOUNT))
	) == NULL ) {

    perror("udbfslib: unable to allocate memory required to store the mount information");
    goto failed_mount;
  }

  //.:  Fill in default mount structure values
  mount->next			= NULL;
  mount->previous		= NULL;
  mount->block_device		= mount_fd;
  mount->block_bitmap		= NULL;
  mount->inode_bitmap		= NULL;
  mount->inode_count		= 0;
  mount->free_inode_count	= 0;
  mount->boot_loader_inode	= 0;
  mount->block_size		= 0;
  mount->block_count		= 0;
  mount->free_block_count	= 0;
  mount->block_bitmap_offset	= 0;
  mount->block_bitmap_size	= 0;
  mount->inode_bitmap_offset	= 0;
  mount->inode_bitmap_size	= 0;
  mount->inode_table_offset	= 0;
  mount->dir_storage		= 0;
  mount->ind_storage		= 0;
  mount->bind_storage		= 0;
  mount->tind_storage		= 0;

  //.:  Validate the superblock and fill-in mount structure
  {
    UDBFS_SUPERBLOCK *superblock;

    //..:  Validate superblock
    if( (superblock = udbfslib_validate_superblock( mount )) == NULL ) {
      
      fprintf(stderr,"udbfslib: superblock could not be validated.\n");
      goto failed_mount;
    }

    //..:  Fill-in mount structure
    mount->inode_count		= superblock->inode_count;
    mount->free_inode_count	= superblock->free_inode_count;
    mount->boot_loader_inode	= superblock->boot_loader_inode;
    mount->block_size		= 1<<superblock->block_size;
    mount->log_block_size	= superblock->block_size;
    mount->block_count		= superblock->block_count;
    mount->free_block_count	= superblock->free_block_count;
    mount->block_bitmap_offset	= superblock->bitmaps_block * mount->block_size;
    mount->block_bitmap_size	= (mount->block_count + 7)>>3;
    mount->inode_bitmap_offset	= mount->block_bitmap_offset + ((mount->block_count + 7)>>3);
    mount->inode_bitmap_size	= (mount->inode_count + 7)>>3;
    mount->inode_first_block	= superblock->inode_first_block;
    mount->inode_table_offset	= superblock->inode_first_block * mount->block_size;
    mount->opened_inodes	= NULL;
    mount->root_table_inode	= superblock->root_table_inode;
    mount->journal_inode	= superblock->journal_inode;
    mount->bad_block_inode	= superblock->bad_block_inode;
    mount->magic_number		= superblock->magic_number;
    mount->last_check		= superblock->last_check;
    mount->last_mount		= superblock->last_mount;
    mount->mount_count		= superblock->mount_count;
    mount->max_mount_count	= superblock->max_mount_count;
    mount->creator_os		= superblock->creator_os;
    mount->superblock_version	= superblock->superblock_version;
    mount->inode_format		= superblock->inode_format;
    mount->max_interval		= superblock->max_interval;
    
    //..:  Free temporary superblock structure
    free( superblock );
  }

  printf("inode bitmap size: %lli inode count: %lli\n", mount->inode_bitmap_size, mount->inode_count);
  
  //.:  Load block and inode bitmaps
  if( ((mount->block_bitmap = (uint8_t *)malloc(mount->block_bitmap_size)) == NULL) ||
      ((mount->inode_bitmap = (uint8_t *)malloc(mount->inode_bitmap_size)) == NULL)
    ) {

    fprintf(stderr,"udbfslib: unable to allocate memory for block/inode bitmaps\n");
    goto failed_mount;
  }
  if( (lseek( mount_fd, mount->block_bitmap_offset, SEEK_SET ) != mount->block_bitmap_offset ) ||
      (read( mount_fd, mount->block_bitmap, mount->block_bitmap_size ) != mount->block_bitmap_size ) ) {

    fprintf(stderr, "udbfslib: unable to load block bitmap\n");
    goto failed_mount;
  }
  if( (lseek( mount_fd, mount->inode_bitmap_offset, SEEK_SET ) != mount->inode_bitmap_offset ) ||
      (read( mount_fd, mount->inode_bitmap, mount->inode_bitmap_size ) != mount->inode_bitmap_size ) ) {

    fprintf(stderr,"udbfslib: unable to load inode bitmap\n");
    goto failed_mount;
  }

  mount->dir_storage = mount->block_size<<2;
  mount->ind_storage = (mount->block_size>>3) * mount->block_size;
  mount->bind_storage = (mount->block_size>>3) * mount->ind_storage;
  mount->tind_storage = (mount->block_size>>3) * mount->bind_storage;

  udbfslib_link( &mounted_devices, mount );
  return( mount );

failed_mount:
  if( mount_fd != 0 ) {
    close( mount_fd );
  }

  udbfs_unmount( mount );
  fprintf(stderr,"udbfslib: failed to mount [%s]\n", block_device );
  return( NULL );
}





void		udbfs_unmount(
    UDBFSLIB_MOUNT	*mount ) {

  UDBFS_SUPERBLOCK superblock;

  //.:  NULL pointer catch
  if( mount == NULL ) {

    fprintf(stderr, "udbfslib: WARNING: udbfs_unmount called with a NULL pointer\n");
    return;
  }


  //.:  Close any left open inode
  if( mount->opened_inodes != NULL ) {

    UDBFSLIB_INODE *next_inode, *inode;
    inode = mount->opened_inodes;
    while( inode ) {
      
      fprintf( stderr, "udbfslib: WARNING: inode [%016llX] left open, closing it\n", inode->id );

      next_inode = inode->next;
      udbfs_close_inode( inode );

      inode = next_inode;
    }
  }

  //.:  Save and free the block bitmap
  if( mount->block_bitmap != NULL ) {

    //..:  Save block bitmap on disk
    if( (lseek( mount->block_device, mount->block_bitmap_offset, SEEK_SET ) != mount->block_bitmap_offset) ||
	(write( mount->block_device, mount->block_bitmap, mount->block_bitmap_size ) != mount->block_bitmap_size ) ) {

      perror("udbfslib: unable to save block bitmap");
    }
    //..:  Free it
    free( mount->block_bitmap );
    mount->block_bitmap = NULL;
  }

  //.:  Save and free the inode bitmap
  if( mount->inode_bitmap != NULL ) {

    //..:  Save inode bitmap on disk
    if( (lseek( mount->block_device, mount->inode_bitmap_offset, SEEK_SET ) != mount->inode_bitmap_offset) ||
	(write( mount->block_device, mount->inode_bitmap, mount->inode_bitmap_size ) != mount->inode_bitmap_size ) ) {

      perror("udbfslib: unable to save inode bitmap");
    }
    //..: Free it
    free( mount->inode_bitmap );
    mount->inode_bitmap = NULL;
  }

  // save the superblock
  superblock.boot_loader_inode = mount->boot_loader_inode;
  superblock.inode_first_block = mount->inode_first_block;
  superblock.unique_fs_signature = mount->unique_fs_signature;
  superblock.block_count = mount->block_count;
  superblock.inode_count = mount->inode_count;
  superblock.free_block_count = mount->free_block_count;
  superblock.free_inode_count = mount->free_inode_count;
  superblock.bitmaps_block = mount->bitmaps_block;
  superblock.root_table_inode = mount->root_table_inode;
  superblock.journal_inode = mount->journal_inode;
  superblock.bad_block_inode = mount->bad_block_inode;
  superblock.magic_number = mount->magic_number;
  superblock.last_check =  mount->last_check;
  superblock.last_mount =  mount->last_mount;
  superblock.mount_count = mount->mount_count;
  superblock.max_mount_count = mount->max_mount_count;
  superblock.creator_os = mount->creator_os;
  superblock.superblock_version = mount->superblock_version;
  superblock.block_size = mount->log_block_size;
  superblock.inode_format = mount->inode_format;
  superblock.max_interval = mount->max_interval;

  if( (lseek( mount->block_device, 1024, SEEK_SET) != 1024 ) ||
      (write( mount->block_device, &superblock, sizeof(superblock)) != sizeof(superblock)) ) {
    perror("udbfslib: unable to save superblock");
  }

  // close the block device file descriptor
  if( mount->block_device != 0 ) {

    close( mount->block_device );
    mount->block_device = 0;
  }

  // free the mount structure
  udbfslib_unlink( &mounted_devices, mount );
  free( mount );
}


/* 1.) udbfslib_validate_superblock

   Validate the superblock structure for known symbols and limits.

   On Success:
   	pointer to a UDBFS_SUPERBLOCK is returned

   On Failure:
   	a NULL pointer is returned
 */
static UDBFS_SUPERBLOCK	*udbfslib_validate_superblock(
    UDBFSLIB_MOUNT 	*mount ) {
  
  //..:  Allocate temporary superblock structure
  UDBFS_SUPERBLOCK *superblock =
    (UDBFS_SUPERBLOCK *)malloc(
			       sizeof(UDBFS_SUPERBLOCK));
  
  //..:  Load superblock information
  if( (superblock == NULL) ||
      (lseek( mount->block_device, 1024, SEEK_SET) != 1024) ||
      (read( mount->block_device, superblock, sizeof(UDBFS_SUPERBLOCK)) != sizeof(UDBFS_SUPERBLOCK))
      ) {
    perror("udbfslib: unable to validate superblock");
    goto failed_validation;
  }
  
  //..: Make sure the information is valid
  if( superblock->magic_number != UDBFS_MAGIC ) {
    fprintf(stderr,"udbfslib: failed to locate superblock signature: [%016llX] found instead.\n", superblock->magic_number);
    goto failed_validation;
  }
  switch( superblock->superblock_version ) {
    case 1:

      //...:  Version 1 allows only for block_size log of 8 < x < 21
      if( (superblock->block_size < 9) ||
	  (superblock->block_size > 20) ) {

	fprintf(stderr,"udbfslib: invalid block_size log [%i]\n", superblock->block_size);
	goto failed_validation;
      }

      //...:  Check if the free inode/block count is above the inode/block count
      if( superblock->free_inode_count > superblock->inode_count ) {
	fprintf(stderr,"udbfslib: invalid free/total inode count relationship [%016llX/%016llX]\n", superblock->free_inode_count, superblock->inode_count );
	goto failed_validation;
      }
      if( superblock->free_block_count > superblock->block_count ) {
	fprintf(stderr,"udbfslib: invalid free/total block count relationship [%016llX/%016llX]\n", superblock->free_block_count, superblock->block_count );
	goto failed_validation;
      }
      break;

    default:
      fprintf(
	  stderr,
	  "udbfslib: unknown superblock version [%i]\n",
	  superblock->superblock_version);
      goto failed_validation;
  }


  return( superblock );


failed_validation:
  if( superblock != NULL ) {
    free(superblock);
  }

  return(NULL);
}
