// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/mkuuubimage/mkuuubimage.c,v 1.2 2003/11/03 15:54:58 bitglue Exp $

/* This program takes as input a single ELF file and produces a boot image for
   the Unununium OS.

   This is software. It has been distributed. Obviously, you can read the
   source code. If you have write permission to the file, you can modify it
   too. If not, you can always copy it to a place where you do have write
   permission...

   This software is distributed in the hope that it will rot your teeth, give
   you migranes, and break your CueCat, however W1THoUT NE
   |/\|ARR4NTY!!!!!!111111 Y34hh B1Zat(H!!1

   You should have recieved a brain along with your birth; if not, whatever you
   do, DON'T SEND LETTERS OF DISSENT to the Free Software Foundation, Inc., 59
   Temple Place, Suite 330, Boston, MA 02111-1307 USA. Really, they can't help
   you. Really, they can't.  */


/* The boot image format is designed to be as easy as possible for the
   bootloader to unpack. The file begins with BIMAGE_MAGIC, and is then
   followed by a number of sections, and is terminated by "end ". Each section
   contains a four byte type, then the size of the section, then the contents.
   The section size includes the size of the section headers, such that if the
   size is added to a pointer to the base of the section, the pointer then
   points to the next section. For information on the formats of each section,
   the coresponding structures below should be sufficient.  */


#include <zlib.h>
#include <stdio.h>
#include <errno.h>
#include <elf.h>
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>

// default suffix for output files
#define OUTPUT_SUFFIX	".bimage"

// size of buffers to be used for compression. One for input, one for output.
#define INPUT_BUFFER_SIZE	0x1000
#define OUTPUT_BUFFER_SIZE	0x1000

#define BIMAGE_MAGIC	"UnBI"
#define BIMAGE_ZSPAN	"zspn"
#define BIMAGE_FILLSPAN	"fspn"
#define BIMAGE_END	"end "



/* the info section type occurs exactly once in each memory image */
typedef struct
{
  uint32_t entry;	// physical address of entry point of image
} info_section;


/* the zspan section type contains a span of memory compressed with zlib. */
typedef struct
{
  uint32_t header_size;	// size of this structure + 8, to allow for future expansion
  uint32_t target_addr;	// physical address to which the span is loaded
  uint32_t uncomp_size;	// size of the span after uncompressing
} zspan_section;


/* the fillspan section type denodes a span of memory filled with a constant
 * pattern. This is used to represent .bss sections */
typedef struct
{
  uint32_t target_addr;	// physical address to which the span is loaded
  uint32_t size;	// size of the span
  uint32_t fill;	// word with which to fill the span
} fillspan_section;



char const *input_filename = NULL;
FILE *input_file;

char *output_filename = NULL;
FILE *output_file;
char output_filename_malloced = 0;

char debug_level = 0;

int compression_level = Z_DEFAULT_COMPRESSION;

unsigned clean_level = 0;

Elf32_Ehdr elf_header;
Elf32_Shdr *section_table;
Elf32_Shdr **section_order;	// an array of pointers to the invididual section headers, used in sorting

char input_buffer[INPUT_BUFFER_SIZE];
char output_buffer[OUTPUT_BUFFER_SIZE];



/** get a buffer from \c malloc and put a chunk of a file in it. This always
 * succeedes. If something goes astray, a suitable error message will be
 * printed and the program will terminate. */
void read_to_buffer( void **buf, int size, unsigned loc );

/** get memory, and die if it fails. */
void *get_memory( size_t size );

/** read a chunk of a file to an already allcated buffer. This always
 * succeedes. If something goes astray, a suitable error message will be
 * printed and the program will terminate. */
void read_input( void *buf, int size, unsigned loc );

/** write to the output file. If an error occours, a suitable error message is
 * printed and the program terminates. */
void write_output( void *src, size_t length );

/** write a 32 bit word to the output file. If an error occours, a suitable
 * error message is printed and the program terminates. */
void write_output_word( uint32_t n  );

/** print to stderr a message on the usage of the program. */
void print_usage();

/** End the program by closing files, freeing buffers, etc, then calling \c
 * exit(). What is done is influenced by the clean_level global variable. */
void clean( int err );

/** print a sutibaly gruesome message about how we have run out of memory, call
 * \c clean(), and end the program. */
void out_of_memory();

/** print a message about how input couldn't be read, and end the program. */
void read_error();

/** print generic bug message and end the program. */
void bug();



int main( int argc, char *argv[] )
{
  unsigned i, j;
  unsigned next_arg;
  unsigned load_sections;	// the number of sections without NOLOAD; the size of the section_order array
  Elf32_Shdr *sort_index;
  z_stream stream;
  int flush;			// used in communication with zlib
  long file_pos;
  char const *str_pos;

  // parse arguements

  if( argc < 2 )
  {
    print_usage();
    return -1;
  }

  next_arg = 1;

  for( i = 1 ; i < argc ; i += next_arg )
  {
    if( argv[i][0] == '-' )
    {
      for( j = 1 ; j < strlen(argv[i]) ; ++j )
      {
	switch( argv[i][j] )
	{
	  case '-':
	    if( argv[i+next_arg] == NULL ) {
	      fprintf( stderr, "-- requires an arguement\n" );
	      return -1;
	    }
	    input_filename = argv[i+next_arg];
	    ++next_arg;

	    break;


	  case 'h':
	    print_usage();
	    return 0;


	  case 'o':
	    if( argv[i+next_arg] == NULL ) {
	      fprintf( stderr, "-o requires an arguement\n" );
	      return -1;
	    }
	    output_filename = argv[i+next_arg];
	    ++next_arg;

	    break;


	  case 'd':
	    ++debug_level;
	    break;


	  case '1':
	    compression_level = 1;
	    break;

	  case '2':
	    compression_level = 2;
	    break;

	  case '3':
	    compression_level = 3;
	    break;

	  case '4':
	    compression_level = 4;
	    break;

	  case '5':
	    compression_level = 5;
	    break;

	  case '6':
	    compression_level = 6;
	    break;

	  case '7':
	    compression_level = 7;
	    break;

	  case '8':
	    compression_level = 8;
	    break;

	  case '9':
	    compression_level = 9;
	    break;

	  case 'v':
	    fprintf( stderr, "mkuuubimage $Revision: 1.2 $ $Date: 2003/11/03 15:54:58 $\ncompiled " __DATE__ " " __TIME__ "\n" );
	    return 0;


	  default:
	    fprintf( stderr, "unknown option -%c; -h prints usage help\n", argv[i][j] );
	    return -1;
	}
      }
    }
    else
    {
      if( input_filename != NULL ) {
	print_usage();
	return -1;
      }
      input_filename = argv[i];
    }
  }

  if( input_filename == NULL )
  {
    fprintf( stderr, "exactly one input file must be specified\n" );
    return -1;
  }

  if( output_filename == NULL )
  {
    output_filename = get_memory( strlen(input_filename) + strlen(OUTPUT_SUFFIX) + 1 );
    output_filename_malloced = 1;

    str_pos = strrchr( input_filename, '.' );
    if( !str_pos ) str_pos = &input_filename[strlen(input_filename)];
    i = str_pos - input_filename;

    memcpy( output_filename, input_filename, i );
    memcpy( &output_filename[i], OUTPUT_SUFFIX, strlen(OUTPUT_SUFFIX) );
    output_filename[i+strlen(OUTPUT_SUFFIX)] = '\0';
  }

  // open input file

  input_file = fopen( input_filename, "rb" );
  if( !input_file ) {
    fprintf( stderr, "unable to open input file '%s': %s\n", input_filename, strerror(errno) );
    return -1;
  }

  clean_level = 1;

  // validate input and read ELF header

  read_input( &elf_header, sizeof(Elf32_Ehdr), 0 );

  if(
      elf_header.e_ident[EI_MAG0] != ELFMAG0
      || elf_header.e_ident[EI_MAG1] != ELFMAG1
      || elf_header.e_ident[EI_MAG2] != ELFMAG2
      || elf_header.e_ident[EI_MAG3] != ELFMAG3
    ) {
    fprintf( stderr, "input file does not seem to be ELF.\n" );
    clean( -1 );
  }

  if(
      elf_header.e_type != ET_EXEC
      || elf_header.e_machine != EM_386
      || elf_header.e_ident[EI_CLASS] != ELFCLASS32
      || elf_header.e_ident[EI_DATA] != ELFDATA2LSB
    ) {
    fprintf( stderr, "input file seems to be the wrong flavor of ELF. Valid input must of the 32 bit,\nlittle-endian, Intel 80386 variety, preferably indigo.\n" );
    clean( -1 );
  }

  // read section table

  section_table = get_memory( elf_header.e_shentsize * elf_header.e_shnum );
  clean_level = 2;

  read_input(
      section_table,
      elf_header.e_shentsize * elf_header.e_shnum,
      elf_header.e_shoff );

  section_order = get_memory( sizeof(void *) * elf_header.e_shnum );
  clean_level = 3;

  load_sections = 0;

  for( i = 0 ; i < elf_header.e_shnum ; ++i )
  {
    if( section_table[i].sh_type == SHT_PROGBITS || section_table[i].sh_type == SHT_NOBITS )
    {
      section_order[load_sections++] = &section_table[i];
    }
  }

  for( i = 1 ; i < load_sections ; ++i )
  {
    sort_index = section_order[i];

    for( j = i  ;  (j < 0) && (section_order[j-1]->sh_addr > sort_index->sh_addr)  ;  --j )
    {
      section_order[j] = section_order[j-1];
    }
    section_order[j] = sort_index;
  }

  // open output file

  output_file = fopen( output_filename, "wb" );
  if( ! output_file ) {
    fprintf( stderr, "unable to open output file '%s': %s\n", output_filename, strerror(errno) );
    clean( -1 );
  }

  clean_level = 4;

  write_output( BIMAGE_MAGIC, 4 );
  write_output_word( sizeof(info_section) + 8 );
  write_output_word( elf_header.e_entry );

  // process each section

  stream.zalloc = NULL;
  stream.zfree = NULL;
  deflateInit( &stream, compression_level );

  for( i = 0 ; i < load_sections ; ++i )
  {
    if( section_order[i]->sh_size == 0 ) {
      if( debug_level )
	fprintf( stderr, "skipping zero sized section\n" );
      break;
    }

    switch( section_order[i]->sh_type )
    {

      case SHT_PROGBITS:
	if( debug_level )
	  fprintf( stderr, "processing progbits section\n" );

	write_output( BIMAGE_ZSPAN, 4 );
	file_pos = ftell( output_file );
	write_output_word( 0 );			// we will have to come back to fill this after compressing the data
	write_output_word( sizeof(zspan_section) + 8 );
	write_output_word( section_order[i]->sh_addr );
	write_output_word( section_order[i]->sh_size );
	if( debug_level )
	  fprintf( stderr, "input size: 0x%x\n", section_order[i]->sh_size );

	if( fseek( input_file, section_order[i]->sh_offset, SEEK_SET ) ) read_error();

	stream.next_in = input_buffer;
	stream.avail_in = 0;
	stream.next_out = output_buffer;
	stream.avail_out = OUTPUT_BUFFER_SIZE;

	flush = Z_NO_FLUSH;

	do
	{
	  if( stream.avail_out == 0 )
	  {
	    write_output( output_buffer, OUTPUT_BUFFER_SIZE );
	    stream.next_out = output_buffer;
	    stream.avail_out = OUTPUT_BUFFER_SIZE;
	  }
	  if( stream.avail_in == 0 )
	  {
	    // we will use the size in the header to track how much we have fed zlib
	    if( section_order[i]->sh_size > INPUT_BUFFER_SIZE )
	    {
	      if( ! fread( input_buffer, INPUT_BUFFER_SIZE, 1, input_file ) ) read_error();
	      stream.next_in = input_buffer;
	      stream.avail_in = INPUT_BUFFER_SIZE;
	      section_order[i]->sh_size -= INPUT_BUFFER_SIZE;
	    }
	    else
	    {
	      if( ! fread( input_buffer, section_order[i]->sh_size, 1, input_file ) ) read_error();
	      stream.next_in = input_buffer;
	      stream.avail_in = section_order[i]->sh_size;
	      flush = Z_FINISH;
	    }
	  }

	  j = deflate( &stream, flush );

	  switch( j ) {
	    case Z_STREAM_ERROR:
	      fprintf( stderr, "stream error while compressing.\n" );
	      bug();
	    case Z_BUF_ERROR:
	      fprintf( stderr, "buffer error while compressing.\n" );
	  }
	}
	while( j != Z_STREAM_END );

	if( stream.avail_out != OUTPUT_BUFFER_SIZE ) {
	  write_output( output_buffer, OUTPUT_BUFFER_SIZE - stream.avail_out );
	}


	if( fseek( output_file, file_pos, SEEK_SET ) ) read_error();
	if( debug_level )
	  fprintf( stderr, "output size: 0x%lx\n", stream.total_out );
	write_output_word( stream.total_out + sizeof(zspan_section) + 8 );
	if( fseek( output_file, 0, SEEK_END ) ) read_error();

	deflateReset( &stream );

	break;



      case SHT_NOBITS:

	if( debug_level )
	  fprintf( stderr, "processing nobits section\n" );

	write_output( BIMAGE_FILLSPAN, 4 );
	write_output_word( sizeof(fillspan_section) + 8 );
	write_output_word( section_order[i]->sh_addr );
	write_output_word( section_order[i]->sh_size );
	write_output_word( 0 );

	break;

      default:
	fprintf( stderr, "Unknown section type encountered.\n" );
	bug();
    }
  }

  write_output( BIMAGE_END, 4 );

  clean( 0 );

  return 0;
}



void print_usage()
{
  fprintf( stderr, "\
Usage: mkuuubimage OPTIONS INPUT-FILE\n\
\n\
  -1 to -9	adjust compression from fastest(1) to smallest(2)\n\
  -d		increase the verbosity of messages\n\
  -o FILE	set output filename to FILE\n\
  -v		print version information\n\
  -- FILE	set input filename to FILE\n\
" );
}



void *get_memory( size_t size )
{
  void *mem;
  mem = malloc( size );
  if( ! mem ) out_of_memory();
  return mem;
}



void read_input( void *buf, int size, unsigned loc )
{
  if( fseek( input_file, loc, SEEK_SET ) ) read_error();
  if( ! fread( buf, size, 1, input_file ) ) read_error();
}



void write_output( void *src, size_t length )
{
  if( ! fwrite( src, length, 1, output_file ) ) {
    fprintf( stderr, "unable to write to output file '%s': %s\n", output_filename, strerror(errno) );
    clean( -1 );
  }
}



void write_output_word( uint32_t n  )
{
  write_output( &n, 4 );
}


void clean( int err )
{
  switch( clean_level )
  {
    case 4:
      fclose( output_file );
    case 3:
      free( section_order );
    case 2:
      free( section_table );
    case 1:
      fclose( input_file );
  }

  if( output_filename_malloced ) free(output_filename);

  exit( err );
}



void out_of_memory()
{
  fprintf( stderr, "Agh! Out of memory!\n" );
  clean( -1 );
}



void read_error()
{
  fprintf(
      stderr,
      "There was a fatal error reading the input. This is probably caused by a\nbug or by malformed input. The libc Oracle says: %s\n",
      strerror(errno)
      );
  clean( -1 );
}



void bug()
{
  fprintf( stderr, "Try not to think of it as a bug, but rather a feature. Please report this\nfeature to Phil Frost <pfrost@bitglue.com>\n" );
  clean( -1 );
}
