#define _LARGEFILE64_SOURCE
#define _POSIX_SOURCE

#include "udbfslib.h"
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>

static void link_mount( UDBFS_MOUNT *mount );
static void unlink_mount( UDBFS_MOUNT *mount );
static int validate_superblock( UDBFS_MOUNT *mount );


UDBFS_MOUNT *mounted_devices = NULL;



UDBFS_MOUNT *udbfs_mount( char *block_device ) {

  int mount_file;
  UDBFS_MOUNT *mount;

  printf("lib: request received to mount [%s]\n", block_device );

  if( (mount_file = open(block_device, O_RDWR | O_LARGEFILE )) == 0 ) {
    perror("unable to open block device");
    return(NULL);
  }

  if( (mount = (UDBFS_MOUNT *)malloc(sizeof(UDBFS_MOUNT))) == NULL ) {
    close(mount_file);
    perror("unable to allocate memory required to store the mount information");
    return(NULL);
  }

  mount->block_device = mount_file;
  mount->next = NULL;
  mount->previous = NULL;
  mount->inode_bitmap = NULL;
  mount->block_bitmap = NULL;

  if( validate_superblock( mount ) == 0 ) {
    free( mount );
    close( mount_file );
    return(NULL);
  }

  link_mount( mount );

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
  if( mount->superblock.block_size < 20 ) {
    fprintf(stderr,"lib: WARNING: block size is over 20bits: %i bits\n", mount->superblock.block_size );
  }

  return( 0 );
}





