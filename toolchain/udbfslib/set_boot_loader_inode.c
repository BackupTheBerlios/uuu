// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/set_boot_loader_inode.c,v 1.3 2003/10/12 21:27:32 instinc Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"

#include <stdio.h>

#include "extralib.h"


int		udbfs_set_boot_loader_inode(
    UDBFSLIB_MOUNT	*mount,
    uint64_t		inode_id ) {

  if( inode_id < mount->inode_count ) {
    mount->boot_loader_inode = inode_id;
  } else {
    fprintf(stderr,"udbfslib: attempt to set inode outside of valid range\n");
    return(1);
  }

  return(0);
}
