#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"

#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>



/* .    .   .  . .. ..... DATA ..... .. .  .   .     . */
static UDBFSLIB_MOUNT		*mounted_devices;





/* .    .   .  . .. ..... PRIVATE FUNCTION PROTOTYPES ..... .. .  .   .     . */

static UDBFS_SUPERBLOCK	*udbfslib_validate_superblock(
    UDBFSLIB_MOUNT 		*mount );

static uint64_t		udbfslib_allocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count );

static UDBFSLIB_INODE	*udbfslib_allocate_memory_inode(
    UDBFSLIB_MOUNT		*mount );

static int		udbfslib_deallocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count,
    uint64_t			bit_id );

static void		udbfslib_link(
    void			*root,
    void			*new_node );

static int		udbfslib_load_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_BLOCK		**block_hook );

static int		udbfslib_load_ind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_INDBLOCK		**ind_block );

static int		udbfslib_load_bind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_INDBLOCK		**ind_block );

static int		udbfslib_load_tind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_INDBLOCK		**ind_block );

static void		udbfslib_unlink(
    void			*root,
    void			*node_to_remove );





/* .    .   .  . .. ..... PUBLIC FUNCTIONS ..... .. .  .   .     . */

UDBFSLIB_MOUNT	*udbfs_mount(
    char		*block_device ) {

  int				mount_fd = 0;
  UDBFSLIB_MOUNT		*mount;

  //.:  Create File Descriptor
  if( (mount_fd = open(
	  block_device,
	  O_RDWR | O_LARGEFILE )
	) == -1 ) {
    
    perror("udbfslib: unable to open block device");
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
    mount->block_count		= superblock->block_count;
    mount->free_block_count	= superblock->free_block_count;
    mount->block_bitmap_offset	= superblock->bitmaps_block * mount->block_size;
    mount->block_bitmap_size	= (mount->block_count + 7)>>3;
    mount->inode_bitmap_offset	= mount->block_bitmap_offset + ((mount->block_count + 7)>>3);
    mount->inode_bitmap_size	= (mount->inode_count + 7)>>3;
    mount->inode_table_offset	= superblock->inode_first_block * mount->block_size;
    mount->opened_inodes	= NULL;
    
    //..:  Free temporary superblock structure
    free( superblock );
  }

  
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
      
      fprintf( stderr, "udbfslib: WARNING: inode [%08X] left open, closing it\n", inode->id );

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

  // close the block device file descriptor
  if( mount->block_device != 0 ) {

    close( mount->block_device );
    mount->block_device = 0;
  }

  // free the mount structure
  udbfslib_unlink( &mounted_devices, mount );
  free( mount );
}









uint32_t	udbfs_allocate_inode_id(
    UDBFSLIB_MOUNT	*mount ) {

  return( (uint32_t)udbfslib_allocate_bit(
	mount->inode_bitmap,
	mount->inode_bitmap_size,
	&mount->free_inode_count) );
}



uint64_t	udbfs_allocate_block_id(
    UDBFSLIB_MOUNT	*mount ) {

  return( (uint32_t)udbfslib_allocate_bit(
	mount->block_bitmap,
	mount->block_bitmap_size,
	&mount->free_block_count) );
}



UDBFSLIB_TABLE	*udbfs_create_table(
    UDBFSLIB_MOUNT	*mount ) {

  return(NULL);
}



UDBFSLIB_TABLE	*udbfs_open_table(
    UDBFSLIB_MOUNT	*mount,
    uint32_t		inode_id ) {

  return(NULL);
}



int		udbfs_add_column(
    UDBFSLIB_TABLE	*table,
    char		*name,
    uint8_t		datatype,
    uint32_t		size,
    uint32_t		count,
    uint32_t		compression,
    uint32_t		encryption ) {

  return(-1);
}



int		udbfs_regenerate_table(
    UDBFSLIB_TABLE	*table ) {

  return(-1);
}



UDBFSLIB_INODE	*udbfs_create_inode(
    UDBFSLIB_MOUNT	*mount ) {

  //.:  Allocate inode memory entry
  UDBFSLIB_INODE *inode = udbfslib_allocate_memory_inode( mount );
  if( inode == NULL ) return( inode );

  //.:  Allocate inode ID
  inode->id = udbfslib_allocate_bit( mount->inode_bitmap, mount->inode_bitmap_size, &mount->free_inode_count );
  if( inode->id == 0 ) {
    fprintf(stderr, "udbfslib: no free inode\n");
    free( inode );
    return( NULL );
  }

  return(inode);
}



UDBFSLIB_INODE *udbfs_open_inode(
    UDBFSLIB_MOUNT	*mount,
    uint32_t		inode_id ) {

  UDBFS_INODE udbfs_inode;

  //.:  Allocate inode memory entry
  UDBFSLIB_INODE *inode = udbfslib_allocate_memory_inode( mount );
  if( inode == NULL ) return( inode );

  inode->id = inode_id;

  //.:  Locate and Read the physical inode structure
  inode->physical_offset =
    mount->inode_table_offset + (sizeof(UDBFS_INODE)*inode_id);
  if( (lseek( mount->block_device, inode->physical_offset, SEEK_SET) != inode->physical_offset) ||
      (read( mount->block_device, &udbfs_inode, sizeof(UDBFS_INODE) ) != sizeof(UDBFS_INODE)) ) {

    fprintf(stderr,"udbfslib: unable to acquire inode [%08X] data\n", inode_id );
    udbfs_close_inode( inode );
    return(NULL);
  }

  inode->size = udbfs_inode.size;
  if( (udbfslib_load_block( inode, udbfs_inode.block[0], &inode->block[0] ) == 0) &&
      (udbfslib_load_block( inode, udbfs_inode.block[1], &inode->block[1] ) == 0) &&
      (udbfslib_load_block( inode, udbfs_inode.block[2], &inode->block[2] ) == 0) &&
      (udbfslib_load_block( inode, udbfs_inode.block[3], &inode->block[3] ) == 0) &&
      (udbfslib_load_ind_block( inode, udbfs_inode.ind_block, &inode->ind_block ) == 0 ) &&
      (udbfslib_load_bind_block( inode, udbfs_inode.bind_block, &inode->bind_block ) == 0) ) {
    udbfslib_load_tind_block( inode, udbfs_inode.tind_block, &inode->tind_block );
  }

  return( inode );
}



int		udbfs_close_inode(
    UDBFSLIB_INODE	*inode ) {

  if( inode == NULL ) {
    fprintf(stderr,"udbfslib: WARNING: udbfs_close_inode called with NULL pointer\n");
    return(0);
  }

  

  return(-1);
}



int		udbfs_free_inode(
    UDBFSLIB_MOUNT	*mount,
    uint32_t		inode_id ) {

  return(udbfslib_deallocate_bit( mount->inode_bitmap, mount->inode_bitmap_size, &mount->free_inode_count, inode_id ));
}




/* .    .   .  . .. ..... PRIVATE FUNCTIONS ..... .. .  .   .     . */

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
    fprintf(stderr,"udbfslib: failed to locate superblock signature: [%08X] found instead.\n", superblock->magic_number);
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
	fprintf(stderr,"udbfslib: invalid free/total inode count relationship [%08X/%08X]\n", superblock->free_inode_count, superblock->inode_count );
	goto failed_validation;
      }
      if( superblock->free_block_count > superblock->block_count ) {
	fprintf(stderr,"udbfslib: invalid free/total block count relationship [%016llX/%016llX]\n", superblock->free_block_count, superblock->block_count );
	goto failed_validation;
      }

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






static void udbfslib_link(
    void *root,
    void *new_node ) {

  struct linked_node {
    struct linked_node		*next,
    				*previous;
  } *link_node, **link_root;

  link_root = root;
  link_node = new_node;

  link_node->next = *link_root;
  *link_root = link_node;

  if( link_node->next != NULL ) {
    link_node->next->previous = link_node;
  }
}





static void udbfslib_unlink(
    void *root,
    void *node_to_remove ) {

  struct linked_node {
    struct linked_node		*next,
    				*previous;
  } *link_node, **link_root;

  if( link_node->previous == NULL ) {

    if( *link_root != link_node )
      goto list_out_of_sync;

    *link_root = link_node->next;
    link_node->next = NULL;

  } else {

    if( link_node->previous->next != link_node )
      goto list_out_of_sync;

    link_node->previous = link_node->next;

    if( link_node->next != NULL ) {

      if( link_node->next->previous != link_node )
	goto list_out_of_sync;
      
      link_node->next->previous = link_node->previous;
    }
  }
  link_node->next = NULL;
  link_node->previous = NULL;
  return;

list_out_of_sync:
  fprintf(stderr,"udbfslib: ERROR, list out of sync!\n");
}




static uint64_t		udbfslib_allocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count ) {

  uint64_t	byte;
  uint8_t	bit;

  if( *free_count > (bitmap_size<<3) ) {
    fprintf(stderr,"udbfslib: ERROR, udbfslib_allocate_bit reports higher free count than bitmap allows [%016llX:%016llX]\n", *free_count, bitmap_size<<3);
    return(0);
  }

  byte = 0;
  bit = 0;
  while(
      (byte < bitmap_size) &&
      (bitmap[byte] == 0))
    byte++;

  if( byte == bitmap_size ) {
    fprintf(stderr,"udbfslib: ERROR, bitmap free count does not match bitmap content\n");
    return(0);
  }

  while( ((1<<bit) & bitmap[byte]) == 0x00 )
    bit++;

  bitmap[byte] = bitmap[byte] ^ (1<<bit);
  *free_count--;
  return( (byte<<3)+bit );
}



static int		udbfslib_deallocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count,
    uint64_t			bit_id ) {
  
  uint64_t	byte;
  uint8_t	bit;

  if( (*free_count + 1) > (bitmap_size<<3) ) {
    fprintf(stderr,"udbfslib: ERROR, udbfslib_deallocate_bit reports free count would be higher than bitmap allows, aborting [%016llX:%016llX]\n", *free_count + 1, bitmap_size<<3);
    return(-1);
  }

  byte = bit_id>>3;
  bit = bit_id & 0x03;
  if( (bitmap[byte] & (1<<bit)) != 0x00 ) {
    fprintf(stderr,"udbfslib: ERROR, udbfslib_deallocate_bit was requested to free an already freed bit [%016llX]\n", bit_id);
    return(-1);
  }

  bitmap[byte] = bitmap[byte] | (1<<bit);
  return(0);
}


static UDBFSLIB_INODE *udbfslib_allocate_memory_inode(
    UDBFSLIB_MOUNT *mount ) {

  //.:  Allocate memory for inode structure
  UDBFSLIB_INODE *inode =
    (UDBFSLIB_INODE *)malloc(sizeof(UDBFSLIB_INODE));

  if( inode == NULL ) {
    perror("udbfslib: unable to allocate memory for inode");
    return( NULL );
  }

  //.:  Initialize inode structure
  inode->next = NULL;
  inode->previous = NULL;
  inode->id = 0;
  inode->cursor = 0;
  inode->size = 0;
  inode->block[0] = NULL;
  inode->block[1] = NULL;
  inode->block[2] = NULL;
  inode->block[3] = NULL;
  inode->ind_block = NULL;
  inode->bind_block = NULL;
  inode->tind_block = NULL;
  inode->mount = mount;

  //.:  Link inode in mount point and return inode
  udbfslib_link( &mount->opened_inodes, inode );
  return(inode);
}




static int		udbfslib_load_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_BLOCK		**block_hook ) {
  return(-1);
}

static int		udbfslib_load_ind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_INDBLOCK		**ind_block ) {
  return(-1);
}

static int		udbfslib_load_bind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_INDBLOCK		**ind_block ) {
  return(-1);
}

static int		udbfslib_load_tind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_INDBLOCK		**ind_block ) {
  return(-1);
}
