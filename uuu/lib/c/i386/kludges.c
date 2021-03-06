#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>



unsigned screen_pos = 0;
uint16_t *screen = (uint16_t *)0xb8000;

int memfs_addfile (const char *filename, void *data, unsigned long filesize);
int memfs_init();

#define memfs_limit_fds		64
#define memfs_limit_files	32

unsigned screen_width = 80;
unsigned screen_height = 25;
unsigned numfiles = 0;


struct _memfs_fd
{
  unsigned char bInUse;
  const char *data;
  unsigned long file_pos_start;
  unsigned long file_pos_end;
  unsigned long file_pos_cur;
} memfs_fd[memfs_limit_fds];

struct _memfs_filedata
{
  const char *data;
  unsigned long filesize;
  char filename[64];
} memfs_files[memfs_limit_files];



int write(int fd, const void *buf, size_t count)
{
  const char *string = buf;
  size_t remaining = count;
  unsigned i;

  if( fd != 1 && fd != 2 ) {
    errno = EINVAL;
    return -1;
  }

  while( remaining )
  {
    if( screen_pos >= screen_width * screen_height )
    {
      memmove( screen, &screen[screen_width], screen_width * (screen_height-1) * sizeof(unsigned) );
      for( i = screen_width * (screen_height-1) ; i < screen_width * screen_height ; ++i ) {
	screen[i] = 0x0720;
      }
      screen_pos = screen_width * (screen_height-1);
    }

    switch( *string )
    {
      case '\n':
	screen_pos += screen_width;
	screen_pos -= screen_pos % screen_width;
	break;

      default:
	screen[screen_pos++] = *string + 0x0700;
    }

    ++string;
    --remaining;
  }
  return count;
}
int __libc_write(const char*fn,int flags,...) __attribute__((weak,alias("write")));



int read(int fd, void *buf, size_t count)
{
  if( count == 0 ) return 0;
  if (memfs_fd[fd].bInUse == 1 )
  {
    unsigned long truecount = count;

    // Prevent reading past end of file
    if (count + memfs_fd[fd].file_pos_cur > memfs_fd[fd].file_pos_end)
      truecount = memfs_fd[fd].file_pos_end - memfs_fd[fd].file_pos_cur;

    memcpy( buf, &memfs_fd[fd].data[ memfs_fd[fd].file_pos_cur ], truecount );
    memfs_fd[fd].file_pos_cur += truecount;
    return truecount;
  }
  errno = EINVAL;
  return -1;
}
int __libc_read(const char*fn,int flags,...) __attribute__((weak,alias("read")));



off_t lseek(int fd, off_t offset, int whence)
{
  if( ! memfs_fd[fd].bInUse )
  {
    errno = EBADF;
    return (off_t)-1;
  }

  switch( whence )
  {
    case SEEK_SET:
      memfs_fd[fd].file_pos_cur = offset;
      break;

    case SEEK_CUR:
      memfs_fd[fd].file_pos_cur += offset;
      break;

    case SEEK_END:
      memfs_fd[fd].file_pos_cur = memfs_fd[fd].file_pos_end + offset;
      break;

    default:
      errno = EINVAL;
      return (off_t)-1;
  }

  // prevent seeking past end of file. Technically, this should be allowed,
  // just not today.
  if (memfs_fd[fd].file_pos_cur > memfs_fd[fd].file_pos_end)
  {
    errno = EINVAL;
    return (off_t)-1;
  }

  // prevent seeking before start of file
  if (memfs_fd[fd].file_pos_cur < memfs_fd[fd].file_pos_start)
  {
    errno = EINVAL;
    return (off_t)-1;
  }

  return memfs_fd[fd].file_pos_cur;
}



int memfs_addfile (const char *filename, void *data, unsigned long filesize)
{
  printf( "adding file %s at %p, size %lu\n", filename, data, filesize );
  if (numfiles < memfs_limit_files)
  {
    strcpy(memfs_files[numfiles].filename, filename);
    memfs_files[numfiles].data = data;
    memfs_files[numfiles].filesize = filesize;
    numfiles++;
    return 1;
  }
  return 0;
}



int memfs_init()
{
  int i=0;
  for (i=0; i<3; i++)
    memfs_fd[i].bInUse = 1;
  for (i=3; i<memfs_limit_fds; i++)
    memfs_fd[i].bInUse = 0;

  strcpy(memfs_files[0].filename, "stdin");
  strcpy(memfs_files[1].filename, "stdout");
  strcpy(memfs_files[2].filename, "stderr");
  numfiles = 3;
  return 0;
}



int close(int fd)
{
  if (memfs_fd[fd].bInUse == 1)
  {
    memfs_fd[fd].data = 0;
    memfs_fd[fd].file_pos_start = 0;
    memfs_fd[fd].file_pos_end = 0;
    memfs_fd[fd].file_pos_cur = 0;
    memfs_fd[fd].bInUse = 0;
    return 0;
  }
  errno = EBADF;
  return -1;
}
int __libc_close(const char*fn,int flags,...) __attribute__((weak,alias("close")));



int open(const char *pathname, int flags, ...)
{
  int bUse = 0;
  int bVal = 0;

  printf( "open( %s, %x )\n", pathname, flags );

  if( (flags & O_ACCMODE) != O_RDONLY ) {
    errno = EROFS;
    return -1;
  }

  unsigned i;
  printf( "%u files exist\n", numfiles );
  for( i=0; i < numfiles; i++ )
  {
    printf( "looking for %s, found %s\n", pathname, memfs_files[i].filename );
    if (strcmp(pathname, memfs_files[i].filename) == 0)
    {
      bVal = i;
      printf( "found file, bVal: %u\n", bVal );
      for (i=0; i<memfs_limit_fds; i++)
      {
	if (memfs_fd[i].bInUse == 1)
	  continue;
	bUse = i;
	printf( "found file descriptor, bUse: %u\n", bUse );
	memfs_fd[bUse].bInUse = 1;
	memfs_fd[bUse].data = memfs_files[bVal].data;
	memfs_fd[bUse].file_pos_start = 0;
	memfs_fd[bUse].file_pos_end = memfs_files[bVal].filesize;
	memfs_fd[bUse].file_pos_cur = 0;
	return bUse;
      }
    }
  }


  errno = ENOENT;
  return -1;
}
int __libc_open(const char*fn,int flags,...) __attribute__((weak,alias("open")));



int rename(const char *oldpath, const char *newpath)
{
  errno = EROFS;
  return -1;
}

  //(*__errno_location())=ENOMEM;
time_t time(time_t *t) {
  static time_t fake_time = 1073591226;
  fake_time += 1;	// my...time is odd around here!
  if( t ) *t = fake_time;
  return fake_time;
}

int access (const char *__name, int __type) {
  return 0;
}

int unlink(const char *pathname) {
  (*__errno_location()) = EROFS;
  return -1;
}

int ioctl(int d, int request, ...) {
  (*__errno_location()) = EINVAL;
  return -1;
}

pid_t getpid(void) {
  static pid_t pid = 2;
  return pid++;
}

int kill(pid_t pid, int sig) {
  return 0; // we arn't so violent here
}

int rmdir(const char *pathname) {
  (*__errno_location()) = EROFS;
  return -1;
}

pid_t fork(void) {
  (*__errno_location()) = ENOMEM;
  return -1; // yeah..out of memory! that's it!
}

pid_t waitpid(pid_t pid, int *status, int options) {
  (*__errno_location()) = ECHILD;
  return -1;
}

int execve(const char *filename, char *const argv [], char *const envp[]) {
  (*__errno_location()) = EACCES;
  return -1;
}
