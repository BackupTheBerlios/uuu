#include <unistd.h>
#include <fcntl.h>
#include <errno.h>



off_t file_offset = 0;
char file[] = "moo\n";
unsigned file_size = 4;
unsigned screen_pos = 0;
uint16_t *screen = (uint16_t *)0xb8000;

unsigned screen_width = 80;
unsigned screen_height = 25;



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
  errno = EINVAL;
  return -1;
}



off_t lseek(int fildes, off_t offset, int whence)
{
  switch( whence )
  {
    case SEEK_SET:
      file_offset = offset;
      break;

    case SEEK_CUR:
      file_offset += offset;
      break;

    case SEEK_END:
      file_offset = file_size + offset;

    default:
      errno = EINVAL;
      return (off_t)-1;
  }

  return file_offset;
}



int close(int fd)
{
  if( fd == 0 || fd > 3 ) {
    errno = EBADF;
    return -1;
  }
  return 0;
}



int open(const char *pathname, int flags, ...)
{
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