#include "udbfslib.h"
#include <stdlib.h>
#include <stdio.h>

int main(int argc, char **argv) {

  UDBFS_MOUNT *mount = udbfs_mount("disk.bin");
  
  printf("app: mounted as [%p]\n", mount);
  udbfs_unmount( mount );
  return(0);
}
