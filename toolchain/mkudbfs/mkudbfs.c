/* mkudbfs - make tool for the Unununium Database File System
   Copyright (C) 2003 - Dave Poirier
   Distributed under the BSD license

   see http://developer.berlios.de/projects/uuu/ for more details.
*/

#define _LARGEFILE64_SOURCE
#define _LARGEFILE_SOURCE
#define _FILE_OFFSET_BITS 64

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/ioctl.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mkudbfs.h"
#include "../conf.h"

#define BLOCK_SIZE	(1<<(7+superblock->block_size))

int				add_column(
    struct _udbfs_table *table,
    char *colname,
    uint8_t datatype,
    int size,
    int count,
    int list_index );


uint32_t			allocate_bit(
    uint8_t *bitmap );


int close_file(
    struct _udbfs_file *file );


struct _udbfs_directory	*	create_directory(
    struct _udbfs_directory *parent, char *name );


struct _udbfs_file *		create_file(
    void);


struct _udbfs_table *		create_table(
    void);


uint8_t *			generate_bitmap(
    int bits,
    int *size );

int mkfs(
    int fs,
    uint64_t fs_size );


void				sync_offset(
    struct _udbfs_file *file );


int write_block(
    struct _udbfs_block *block );


int				write_boot_loader(
    struct _udbfs_file *u_file,
    char *boot_filename );


int				write_inode(
    int inode_id,
    struct __udbfs_inode *inode );


int				generate_table_definition(
    struct _udbfs_table *table,
    uint8_t alignment );


struct __udbfs_superblock *	superblock;
uint8_t *inode_bitmap, *	block_bitmap;
int				block_map_size,
				inode_map_size,
				inode_dir_limit,
				inode_ind_limit,
				inode_bind_limit,
				inode_tind_limit;


int fs;





int main(
    int argc,
    char **argv) {
//-----------------------------------------------------------------------------

  /* parameters:

1: size of the file to create

  */
  
  int64_t fs_size = 0;
  struct stat status;

  char *filename;

  switch( argc ) {
    case 2:
      filename = argv[1];
      break;
    case 3:
      filename = argv[2];
      sscanf(argv[1],"%" UINT64_FORMAT "u", &fs_size);
      printf("fs size [ %" UINT64_FORMAT "u ]\n", fs_size );
      break;
    default:
      fprintf(stderr, "Usage: mkudbfs [fs_size] file_to_format\n");
      return(-1);
  }

  if( stat( filename, &status ) != 0 ) {
    perror(filename);
    exit(-1);
  }
  
  if( fs_size <= 0 ) {

    if( (status.st_mode & S_IFMT) == S_IFBLK ) {
	
      // manually search for file size
      int64_t delta = 1<<30;
      int64_t validated_offset = 0;
      int64_t attempted_offset = 0;

      fs = open( filename, O_RDONLY|O_LARGEFILE );
      if( fs <= 0 ) {
	perror( filename );
	exit(-1);
      }
      while( delta > 0 ) {
	
	attempted_offset = validated_offset + delta;
	if( lseek( fs, attempted_offset, SEEK_SET ) != attempted_offset ) {

	  delta = delta >> 1;

	} else {

	  validated_offset = attempted_offset;

	}
      }
      fs_size = validated_offset;
      close( fs );
    } else {

      fs_size = status.st_size;
    }
  }

      

  fs = open( filename, O_RDWR|O_LARGEFILE );
  if( fs <= 0 ) {
    perror( filename );
    exit(-1);
  }

  mkfs(fs, fs_size );
  close( fs );
  printf(":. completed.\n");
  return( 0 );
}





int mkfs(
    int fs,
    uint64_t fs_size ) {
//-----------------------------------------------------------------------------

  int i;
  struct _udbfs_file *tmp_file;
  struct _udbfs_table *root_table;

  printf("generating %" UINT64_FORMAT "i kb file system\n", fs_size);
  
  superblock = malloc(sizeof(struct __udbfs_superblock));
  if( superblock == NULL ) {
    perror("super block is NULL");
    return(-1);
  }

  superblock->block_size = 6;
  superblock->block_count = 0;
  while( superblock->block_size >= 2 &&
      superblock->block_count < 2000 ) {
    
    superblock->block_size--;
    superblock->block_count = (int)(fs_size / BLOCK_SIZE);
  } 
  printf(":. fs split into %" UINT64_FORMAT "i blocks of %i bytes\n", superblock->block_count, BLOCK_SIZE);

  superblock->inode_first_block = 1;
  if( superblock->block_size < 4 ) {
    superblock->inode_first_block = 1<<(4-superblock->block_size);
  }

  i = 1<<(superblock->block_size+4);
  inode_dir_limit = 4;
  inode_ind_limit = i;
  inode_bind_limit = i*i;
  inode_tind_limit = inode_bind_limit*i;

  printf(":. block redirections [%i,%i,%i,%i]\n", inode_dir_limit, inode_ind_limit, inode_bind_limit, inode_tind_limit);

  superblock->last_check = 0;
  superblock->max_interval = 0;
  superblock->last_mount = 0;

  superblock->inode_count = fs_size / (128*1024);
  if( superblock->inode_count < 64 ) {
    superblock->inode_count = 64;
  }

  inode_bitmap = generate_bitmap( superblock->inode_count, &inode_map_size );
  block_bitmap = generate_bitmap( superblock->block_count, &block_map_size );

  superblock->magic_number = udbfs_magic; 
  superblock->mount_count = 0;
  superblock->max_mount_count = 0;
  superblock->creator_os = 0;
  superblock->superblock_version = 1;
  superblock->inode_format = 1;
  superblock->free_block_count = superblock->block_count;
  superblock->free_inode_count = superblock->inode_count;

  // Mark up all blocks from below 2kb as used
  for(i=0; i< superblock->inode_first_block; i++) {
    allocate_bit( block_bitmap );
  }
  // Mark up all blocks used by the inode table as used
  i = ((superblock->inode_count * sizeof(struct __udbfs_inode)) + BLOCK_SIZE - 1) / BLOCK_SIZE;
  while(i--) {
    allocate_bit( block_bitmap );
  }
  // Reserve space for the block and inode bitmaps
  i = (inode_map_size + block_map_size + BLOCK_SIZE - 1) / BLOCK_SIZE;
  printf(":. reserving %i block(s) for block and inode bitmaps\n", i);
  superblock->bitmaps_block = allocate_bit( block_bitmap );
  while( --i ) {
    allocate_bit( block_bitmap );
  }

  printf(":. creating root hierarchy table\n");
  root_table = create_table();
  add_column( root_table, "id", DATATYPE_INT32, 1, 1, 0);
  add_column( root_table, "table_id", DATATYPE_INT32, 1, 1, 0);
  add_column( root_table, "name", DATATYPE_VARCHAR, 255, 1, 1);
  add_column( root_table, "row_id", DATATYPE_INT32, 1, 1, 0);
  add_column( root_table, "parents", DATATYPE_INT32, 1, 4, 0);
  generate_table_definition( root_table, 2 );

  printf(":. creating maintenance files:\n\tbad blocks\n");
  tmp_file = create_file();
  superblock->bad_block_inode = tmp_file->inode_id;
  close_file( tmp_file );

  printf("\tjournal\n");
  tmp_file = create_file();
  superblock->journal_inode = tmp_file->inode_id;
  close_file( tmp_file );


  // Save the superblock
  printf(":. writing superblock\n");
  if( (lseek( fs, 1024, SEEK_SET ) != 1024 ) ||
      (write( fs, superblock, sizeof(struct __udbfs_superblock) ) != sizeof(struct __udbfs_superblock))) {
    perror("failed to write superblock, aborting");
    exit(-1);
  }

  // Save the block bitmap
  printf(":. saving block and inode bitmaps\n");
  {
    int offset = BLOCK_SIZE * superblock->bitmaps_block;
    lseek( fs, offset, SEEK_SET );
    write( fs, block_bitmap, block_map_size );
    write( fs, inode_bitmap, inode_map_size );
  }
  

  return(0);
}




uint8_t *generate_bitmap(
    int bits,
    int *size ) {
//-----------------------------------------------------------------------------

  int bytes = ((bits + 7)&(-8))>>3;
  uint8_t last_byte = 0x00;

  uint8_t *bitmap = (uint8_t *)malloc( bytes );
  if( bitmap == NULL ) {
    fprintf(stderr, "major problem..");
  }

  bits = bits>>3;
  while(bits--) {
    last_byte = (last_byte<<1) | 1;
  }

  *size = bytes;

  while(bytes--) {
    bitmap[bytes] = last_byte;
    last_byte = 0xFF;
  }
    
  return bitmap;
}





uint32_t allocate_bit(
    uint8_t *bitmap ) {
//-----------------------------------------------------------------------------
  
  int byte = 0;
  int bit = 0;

  if( bitmap == block_bitmap ) {
    if( superblock->free_block_count == 0 ) {
      fprintf(stderr,"ran out of free blocks, aborting.\n");
      exit(-1);
    }
    superblock->free_block_count--;
  } else {
    if( superblock->free_inode_count == 0 ) {
      fprintf(stderr,"ran out of free inodes, aborting.\n");
      exit(-1);
    }
    superblock->free_inode_count--;
  }
  
  while( bitmap[byte] == 0 ) { byte++; }
  while( (bitmap[byte] & (1<<bit)) == 0 ) { bit ++; }
  
  bitmap[byte] = bitmap[byte]-(1<<bit);
  return ((byte<<3)+bit);
}







struct _udbfs_file *create_file(
    void) {
//-----------------------------------------------------------------------------

  struct _udbfs_file *file = (struct _udbfs_file *)malloc(sizeof(struct _udbfs_file));

  file->blocks = NULL;
  file->current_block = NULL;
  file->inode_id = allocate_bit( inode_bitmap );
  file->current_offset = 0;
  file->file_size = 0;
  file->block_count = 0;

  return( file );
}







uint64_t generate_ind(
    struct _udbfs_file *file ) {
//-----------------------------------------------------------------------------

  struct _udbfs_block index_block;
  uint64_t index[BLOCK_SIZE-3];
  int block_count = inode_ind_limit;
  int i;

  for(i=0; i<(BLOCK_SIZE-3); i++ ) {
    index[i] = 0;
  }

  index_block.block_id = allocate_bit( block_bitmap );
  index_block.data = (uint8_t *)&index[0];

  if( block_count > file->block_count ) {
    block_count = file->block_count;
  }

  for(i=0; i < block_count; i++) {
    index[i] = allocate_bit( block_bitmap );
    file->current_block->block_id = index[i];
    write_block(file->current_block);
    file->current_block = file->current_block->next;
    file->block_count--;
  }

  write_block( &index_block );
  return(index_block.block_id);
}





uint64_t generate_bind(
    struct _udbfs_file *file ) {
//-----------------------------------------------------------------------------

  struct _udbfs_block index_block;
  int ind_count = 1<<(superblock->block_size+4);
  uint64_t index[ind_count];
  int i;

  for(i=0; i < ind_count; i++ ) {
    index[i] = 0;
  }
  i = 0;

  index_block.block_id = allocate_bit( block_bitmap );
  index_block.data = (uint8_t *)&index[0];

  while( ind_count-- ) {
    index[i++] = generate_ind( file );
    if( file->block_count == 0 ) { break; }
  }

  write_block( &index_block );
  return(index_block.block_id);
}





uint64_t generate_tind(
    struct _udbfs_file *file ) {
//-----------------------------------------------------------------------------
  struct _udbfs_block index_block;
  int bind_count = 1<<(superblock->block_size+4);
  uint64_t index[bind_count];
  int i;

  for(i=0; i < bind_count; i++ ) {
    index[i] = 0;
  }
  i = 0;

  index_block.block_id = allocate_bit( block_bitmap );
  index_block.data = (uint8_t *)&index[0];
  
  while( bind_count-- ) {
    index[i++] = generate_bind( file );
    if( file->block_count == 0 ) { break; }
  }

  write_block( &index_block );
  return(index_block.block_id);
}




  

int close_file(
    struct _udbfs_file *file ) {
//-----------------------------------------------------------------------------

  struct __udbfs_inode inode;
  int block_count,i;

  inode.size = file->file_size;
  inode.block[0] = 0;
  inode.block[1] = 0;
  inode.block[2] = 0;
  inode.block[3] = 0;
  inode.ind_block = 0;
  inode.bind_block = 0;
  inode.tind_block = 0;

  // store direct blocks
  block_count = inode_dir_limit;
  if( block_count > file->block_count ) {
    block_count = file->block_count;
  }

  file->current_block = file->blocks;
  for(i = 0; i < block_count; i++ ) {
    inode.block[i] = allocate_bit( block_bitmap );
    file->current_block->block_id = inode.block[i];
    write_block(file->current_block);
    file->current_block = file->current_block->next;
    file->block_count--;
  }

  if( file->block_count > 1 ) {
    inode.ind_block = generate_ind( file );
  }
  if( file->block_count > 1 ) {
    inode.bind_block = generate_bind( file );
  }
  if( file->block_count > 1 ) {
    inode.tind_block = generate_tind( file );
  }

  write_inode( file->inode_id, &inode );

  // Deallocate all the structures
  {
    struct _udbfs_block *block, *next_block;

    block = file->blocks;
    if( block != NULL ) {
      while( block ) {
	next_block = block->next;
	free(block);
	block = next_block;
      }
    }
    free( file );
  }

  return(0);
}





int write_inode(
    int inode_id,
    struct __udbfs_inode *inode ) {
//-----------------------------------------------------------------------------
  
  int offset = inode_id * sizeof(struct __udbfs_inode) + (superblock->inode_first_block * BLOCK_SIZE);

  if( (lseek( fs, offset, SEEK_SET) != offset) ||
      (write( fs, inode, sizeof( struct __udbfs_inode) ) != sizeof(struct __udbfs_inode) )) {
    perror("error writing inode");
    exit(-1);
  }

  return(0);
}





int write_block(
    struct _udbfs_block *block ) {
//-----------------------------------------------------------------------------

  int offset;

  offset = BLOCK_SIZE * block->block_id;

  if( (lseek( fs, offset, SEEK_SET ) != offset ) ||
      (write( fs, block->data, BLOCK_SIZE ) != BLOCK_SIZE ) ) {
    perror("error writing block");
    exit(-1);
  }
  return(0);
}






struct _udbfs_block *allocate_block_to_file(
    struct _udbfs_file *file ) {
//-----------------------------------------------------------------------------

  uint8_t *block;
  struct _udbfs_block *new_block, *next_block;

  int block_size = BLOCK_SIZE+ sizeof(struct _udbfs_block);

  block = (uint8_t *)malloc( block_size );
  if( block == NULL ) {
    perror("block == NULL");
    return( NULL );
  }

  new_block = (struct _udbfs_block *)block;
  new_block->next = NULL;
  new_block->block_id = 0;
  new_block->data = &block[sizeof(struct _udbfs_block)];

  file->block_count++;

  if( file->blocks == NULL ) {
    file->blocks = new_block;
    new_block->offset_start = 0;
    new_block->offset_end = BLOCK_SIZE;
  } else {

    next_block = file->blocks;
    while( next_block->next != NULL ) { next_block = next_block->next; }

    next_block->next = new_block;
    new_block->offset_start = next_block->offset_end;
    new_block->offset_end = new_block->offset_start + BLOCK_SIZE;
    
  }

  return(new_block);
}





  






int seek_file(
    struct _udbfs_file *file,
    int offset ) {
//-----------------------------------------------------------------------------

  struct _udbfs_block *block;

  if( offset > file->file_size ) {
    fprintf(stderr,"seeking past end of file!");
    return(-1);
  }

  block = file->blocks;
  file->current_offset = offset;
  file->current_block = block;

  sync_offset(file);

  return(0);
}







void sync_offset(
    struct _udbfs_file *file ) {
//-----------------------------------------------------------------------------
  
  file->current_block = file->blocks;
  while( file->current_offset > file->current_block->offset_end ) {
    
    if( file->current_block->next == NULL ) {

      if( file->current_offset == file->current_block->offset_end ) {
	return;
      }

      fprintf(stderr,"ERROR: current_offset set past allocated blocks\n");
    }
    file->current_block = file->current_block->next;
  }
}






int write_to_file(
    struct _udbfs_file *file,
    void *data,
    int size ) {
//-----------------------------------------------------------------------------

  uint8_t *uint8_data = data;
  int write_size, completed = 0, block_offset;

  while( size > 0) {
    if( file->current_block == NULL ) {
      file->current_block = allocate_block_to_file( file );
    }

    write_size = file->current_block->offset_end - file->current_offset;
    block_offset = file->current_offset - file->current_block->offset_start;
    write_size = write_size > size ? size : write_size;
    size -= write_size;
    file->current_offset += write_size;
    
    if( (file->current_offset < file->current_block->offset_start) ||
	(file->current_offset > file->current_block->offset_end) ) {
      fprintf(stderr,"YOO!! we are writing outside our own boundaries!\n current offset: %08X\tblock start: %08X end: %08X\n", file->current_offset, file->current_block->offset_start, file->current_block->offset_end);
      exit(-1);
    }

    while( write_size -- ) {
      file->current_block->data[block_offset++] = uint8_data[completed++];
    }
    if( file->current_offset == file->current_block->offset_end ) {
      file->current_block = file->current_block->next;
    }
  }
  if( file->current_offset > file->file_size ) {
    file->file_size = file->current_offset;
  }

  return(0);
}




int write_boot_loader(
    struct _udbfs_file *u_file,
    char *boot_filename ) {
//-----------------------------------------------------------------------------

  FILE *boot_loader;

  int size;
  uint8_t *data;

  boot_loader = fopen(boot_filename, "rb");
  
  fseek(boot_loader, 0, SEEK_END );
  size = ftell( boot_loader );
  fseek(boot_loader, 0, SEEK_SET );

  data = (uint8_t *)malloc(size);
  if( data == NULL ) { perror("can't allocate mem for boot loader"); }

  fread( data, size, 1, boot_loader );
  fclose(boot_loader);

  write_to_file( u_file, data, size );
  free(data);

  return(0);
}









struct _udbfs_table *create_table(
    void) {
//-----------------------------------------------------------------------------

  struct _udbfs_table *table = (struct _udbfs_table *)malloc(sizeof(struct _udbfs_table));

  table->table.last_id = 0;
  table->table.row_count = 0;
  table->table.record_size = 0;
  table->table.first_free_record_index = 0;
  table->table.acl_index = 0;
  table->table.owner = 0;
  table->table.column_count = 0;
  table->table.properties = 0;
  table->table.reserved = 0;
  table->cols = NULL;
  table->file = create_file();

  return(table);
}





int add_column(
    struct _udbfs_table *table,
    char *colname,
    uint8_t datatype,
    int size,
    int count,
    int list_index ) {
//-----------------------------------------------------------------------------

  struct _udbfs_column_desc *column = (struct _udbfs_column_desc *)malloc(sizeof(struct _udbfs_column_desc));
  int i;

  if( column == NULL ) { perror("can't allocate memory for column"); }
  column->column.name_length = strlen( colname );
  column->column.name_length = column->column.name_length > 31 ? 31 : column->column.name_length;
  for(i=0; i< column->column.name_length; i++) {
    column->column.name[i] = (uint32_t)(colname[i]);
  }
  column->column.type = datatype;
  column->column.count= count;
  column->column.size_or_enumeration = size;
  column->column.list_index = list_index;

  column->column.acl = 0;
  column->column.compression = 0;
  column->column.encryption = 0;
  column->column.sequence = 0;
  column->column.properties = 0;
  column->column.shift = 0;
  column->column.offset = 0;
  column->next = table->cols;
  table->cols = column;

  switch( column->column.type ) {
    case DATATYPE_INT1:
      column->encoded_size = 1;
      column->natural_boundary = 1;
      break;
    case DATATYPE_INT2:
      column->encoded_size = 2;
      column->natural_boundary = 2;
      break;
    case DATATYPE_INT4:
      column->encoded_size = 4;
      column->natural_boundary = 4;
      break;
    case DATATYPE_INT8:
      column->encoded_size = 8;
      column->natural_boundary = 8;
      break;
    case DATATYPE_INT16:
      column->encoded_size = 16;
      column->natural_boundary = 16;
      break;
    case DATATYPE_INT32:
      column->encoded_size = 32;
      column->natural_boundary = 32;
      break;
    case DATATYPE_INT64:
      column->encoded_size = 64;
      column->natural_boundary = 64;
      break;
    case DATATYPE_INT128:
      column->encoded_size = 128;
      column->natural_boundary = 128;
      break;
    case DATATYPE_CHAR:
      column->encoded_size = 32;
      column->natural_boundary = 32;
      break;
    case DATATYPE_VARCHAR:
      column->encoded_size = 32;
      column->natural_boundary = 32;
      break;
    case DATATYPE_FLOAT:
      column->encoded_size = 64;
      column->natural_boundary = 64;
      break;
    case DATATYPE_DATA:
      column->encoded_size = 32;
      column->natural_boundary = 32;
      break;
    case DATATYPE_SHAREDDATA:
      column->encoded_size = 32+64;
      column->natural_boundary = 32;
      break;
    case DATATYPE_DATETIME:
      column->encoded_size = 64;
      column->natural_boundary = 64;
      break;
    case DATATYPE_ENUMERATION:
      column->encoded_size = 32;
      column->natural_boundary = 32;
      break;
    default:
      fprintf(stderr,"unknown column datatype: %i", column->column.type);
      return(-1);
  }

  if( column->column.type == DATATYPE_ENUMERATION ) {
    column->encoded_size =
      column->encoded_size
      * column->column.count;
  } else {
    column->encoded_size =
      column->encoded_size
      * column->column.size_or_enumeration
      * column->column.count;
  }

  if( column->column.type == DATATYPE_VARCHAR ) {
    column->encoded_size +=
      column->column.count * 32;
  }
  if( column->encoded_size > 8 ) {
    column->encoded_size =
      (column->encoded_size + 7) & (-8);
  }

  return(0);
}






void reorder_columns_by_size(
    struct _udbfs_table *table ) {
//-----------------------------------------------------------------------------

  struct _udbfs_column_desc
    *unsorted,
    *previous,
    *previous_to_largest,
    *last_sorted,
    *sorted,
    *largest,
    *search;

  unsorted = table->cols;
  sorted = NULL;
  last_sorted = NULL;
  while( unsorted ) {
    
    search = unsorted;
    largest = unsorted;
    while( search != NULL) {
      if (search->natural_boundary > largest->natural_boundary) {
	previous_to_largest = previous;
	largest = search;
      }
      previous = search;
      search = search->next;
    }

    if( largest == unsorted ) {
      unsorted = unsorted->next;
    } else {
      previous_to_largest->next = largest->next;
    }

    if( sorted == NULL ) {
      sorted = largest;
      last_sorted = largest;
    } else {
      last_sorted->next = largest;
      last_sorted = largest;
    }
    last_sorted->next = NULL;
  }
  table->cols = sorted;
}






int generate_table_definition(
    struct _udbfs_table *table,
    uint8_t alignment ) {
//-----------------------------------------------------------------------------

  struct _udbfs_column_desc *column;

  reorder_columns_by_size( table );

  column = table->cols;
  while( column ) {
    table->table.column_count ++;
    column->column.offset = (table->table.record_size & (-8))>>3;
    column->column.shift = table->table.record_size & 7;
    table->table.record_size += column->encoded_size;
    column = column->next;
  }
  table->table.record_size =
    ((table->table.record_size+7) & (-8))>>3;

  table->table.record_size =
    (table->table.record_size+(1<<alignment)-1) & -(1<<alignment);

  if( table->table.record_size < 4 ) {
    table->table.record_size = 4;
  }

  write_to_file( table->file, &table->table, sizeof(struct __udbfs_table));
  column = table->cols;
  while( column != NULL ) {
    write_to_file( table->file, &column->column, sizeof(struct __udbfs_column));
    column = column->next;
  }
  close_file( table->file );
  free( table );

  return(0);
}

