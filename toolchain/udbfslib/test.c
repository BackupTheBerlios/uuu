#include "udbfslib.h"
#define _LARGEFILE64_SOURCE
#define _LARGEFILE_SOURCE
#define _FILE_OFFSET_BITS 64

#include <stdlib.h>
#include <stdio.h>



int main(int argc, char **argv) {

  UDBFSLIB_MOUNT *mount = udbfs_mount("disk.bin");
  
  printf("app: mounted as [%p]\n", mount);
  udbfs_unmount( mount );
  return(0);
}
