#include <unistd.h>
#include <fcntl.h>
#include <errno.h>



off_t file_offset = 0;
char file[] = "moo\n";
unsigned file_size = 4;
unsigned screen_pos = 0;
uint16_t *screen = (uint16_t *)0xb8000;

#define memfs_limit_fds		64
#define memfs_limit_files	32

unsigned screen_width = 80;
unsigned screen_height = 25;


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
  const char filename[];
} memfs_files[memfs_limit_files];

unsigned long numfiles = 0;

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



int read(int fd, void *buf, size_t count)
{
  if (memfs_fd[fd].bInUse == 1 && buf != 0 && count > 0)
  {
    unsigned long truecount = count;

    // Prevent reading past end of file
    if (count + memfs_fd[fd].file_pos_cur > memfs_fd[fd].file_pos_end)
      truecount = memfs_fd[fd].file_pos_end - memfs_fd[fd].file_pos_cur;

    // Slow, I know, but it works... copy 1 byte at a time
    int i;
    char *buffer = (char *)buf;
    for (i=0; i<truecount; i++)
      buffer[i] = memfs_fd[fd].data[memfs_fd[fd].file_pos_cur++];
    return i;
  }
  errno = EINVAL;
  return -1;
}



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
      printf("\nlseek(%u,%u,SEEK_SET)\n",fd,offset);
      memfs_fd[fd].file_pos_cur = offset;
      break;

    case SEEK_CUR:
      printf("\nlseek(%u,%u,SEEK_CUR)\n",fd,offset);
      memfs_fd[fd].file_pos_cur += offset;
      break;

    case SEEK_END:
      printf("\nlseek(%u,%u,SEEK_END)\n",fd,offset);
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
    printf("sought past end of file;");
    errno = EINVAL;
    return (off_t)-1;
  }

  // prevent seeking before start of file
  if (memfs_fd[fd].file_pos_cur < memfs_fd[fd].file_pos_start)
  {
    printf("sought before start of file;");
    errno = EINVAL;
    return (off_t)-1;
  }

  return memfs_fd[fd].file_pos_cur;
}

int memfs_addfile (const char *filename, void *data, unsigned long filesize)
{
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
  for (i=0; i<memfs_limit_fds; i++)
    memfs_fd[i].bInUse = 0;

  strcpy(memfs_files[0].filename, "stdin");
  strcpy(memfs_files[1].filename, "stdout");
  strcpy(memfs_files[2].filename, "stderr");
  numfiles = 3;
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

  if( fd == 0 || fd > 3 ) {
    errno = EBADF;
    return -1;
  }
  return 0;
}



int open(const char *pathname, int flags, ...)
{
  char bUse = 0;
  char bAvail = 0;
  char bFound = 0;
  char bVal = 0;
  if (pathname != 0)
  {
    int i=0;
    for (i=0; i<numfiles; i++)
    {
      if (strcmp(pathname, memfs_files[i].filename) == 0)
      {
        bFound = 1;
        bVal = i;
        i = numfiles;
      }
    }

    if (bFound == 1)
    {
      for (i=0; i<memfs_limit_fds; i++)
      {
        if (memfs_fd[i].bInUse == 1)
          continue;
        bUse = i;
        bAvail = 1;
        i = memfs_limit_fds;
      }
    }

    if (bAvail == 1)
    {
      memfs_fd[bUse].bInUse = 1;
      memfs_fd[bUse].data = memfs_files[bVal].data;
      memfs_fd[bUse].file_pos_start = 0;
      memfs_fd[bUse].file_pos_end = memfs_files[bVal].filesize;
      memfs_fd[bUse].file_pos_cur = 0;
      return bUse;
    }
  }

  if( (flags & O_ACCMODE) != O_RDONLY ) {
    errno = EROFS;
    return -1;
  }
  file_offset = 0;
  return 3;
}


int rename(const char *oldpath, const char *newpath)
{
  errno = EROFS;
  return -1;
}
