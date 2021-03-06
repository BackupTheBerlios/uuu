// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/allocate_bit.c,v 1.6 2003/10/13 22:12:54 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"

#include <stdio.h>

#include "../conf.h"


/* 4.) udbfslib_allocate_bit

   Allocate a bit from a provided bitmap.  This function assumes bit ID 0
   cannot be allocated and uses it as Failure Notice.

   On Success:
   	returns the 64bit ID of the allocate bit

   On Failure:
   	returns 0
 */

uint64_t		udbfslib_allocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count ) {

  uint64_t	byte;
  uint8_t	bit;

  if( *free_count > (bitmap_size<<3) ) {
    fprintf(stderr,"udbfslib: ERROR, udbfslib_allocate_bit reports higher free count than bitmap allows [%016" UINT64_FORMAT "X:%016" UINT64_FORMAT "X]\n", *free_count, bitmap_size<<3);
    return(0);
  }

  if( *free_count == 0 )
    return(0);

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

  bitmap[byte]			= bitmap[byte] ^ (1<<bit);
  *free_count = (*free_count) - 1;
  return( (byte<<3)+bit );
}
