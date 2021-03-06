#include <endian.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifndef __NO_STAT64
extern size_t __pwrite(int fd, void *buf, size_t count, off_t a,off_t b);

size_t __libc_pwrite64(int fd, void *buf, size_t count, off64_t offset);
size_t __libc_pwrite64(int fd, void *buf, size_t count, off64_t offset) {
  return __pwrite(fd,buf,count,__LONG_LONG_PAIR ((off_t)(offset&0xffffffff),(off_t)(offset>>32)));
}

int pwrite64(int fd, void *buf, size_t count, off_t offset) __attribute__((weak,alias("__libc_pwrite64")));
#endif
