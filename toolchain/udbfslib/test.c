#include "udbfslib.h"
#define _LARGEFILE64_SOURCE
#define _LARGEFILE_SOURCE
#define _FILE_OFFSET_BITS 64

#include <stdlib.h>
#include <stdio.h>



int main(int argc, char **argv) {

  UDBFSLIB_MOUNT *mount = udbfs_mount("disk.bin");
  UDBFSLIB_INODE *bootrecord_inode;

  if( mount == NULL) return(-1);
  
  printf("app: mounted as [%p]\n", mount);
  
  printf("attempting to create a new file...\n");
  bootrecord_inode = udbfs_create_inode( mount );
  if( bootrecord_inode == NULL ) {
    fprintf(stderr,"huh..shit\n");
  } else {
    FILE *fp_src;
    char buffer[512];
    int length;

    printf("inode [%016llX] created\n", bootrecord_inode->id);
    fp_src = fopen("testfile.txt","rb");
    if(fp_src == NULL) {
      perror("testfile.txt");
      goto quick_exit;
    }

    while( !feof(fp_src)) {
      length = fread(buffer,1,512,fp_src);
      udbfs_write_to_inode( bootrecord_inode, buffer, length );
    }

    udbfs_close_inode( bootrecord_inode );
  }

quick_exit:
  udbfs_unmount( mount );
  return(0);
}
