// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/set_boot_loader_inode.c,v 1.1 2003/10/11 13:14:19 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"

#include <stdio.h>



int		udbfs_set_boot_loader_inode(
    UDBFSLIB_MOUNT	*mount,
    uint32_t		inode_id ) {

  if( inode_id < mount->inode_count ) {
    mount->boot_loader_inode = inode_id;
  } else {
    fprintf(stderr,"udbfslib: attempt to set inode outside of valid range\n");
    return(1);
  }

  return(0);
}
