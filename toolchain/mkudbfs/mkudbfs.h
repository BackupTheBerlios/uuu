#include <inttypes.h>

#define udate	uint64_t
#define udbfs_magic 0x75646221


#define DATATYPE_INT1		0x01
#define DATATYPE_INT2		0x02
#define DATATYPE_INT4		0x03
#define DATATYPE_INT8		0x04
#define DATATYPE_INT16		0x05
#define DATATYPE_INT32		0x06
#define DATATYPE_INT64		0x07
#define DATATYPE_INT128		0x08
#define DATATYPE_CHAR		0x10
#define DATATYPE_VARCHAR	0x11
#define DATATYPE_FLOAT		0x20
#define DATATYPE_DATA		0x30
#define DATATYPE_SHAREDDATA	0x31
#define DATATYPE_DATETIME	0x40
#define DATATYPE_ENUMERATION	0x50


struct __udbfs_superblock {
  
  uint32_t	magic_number,
		boot_loader_inode;
  uint64_t	inode_first_block,
		unique_fs_signature,
		block_count,
		free_block_count,
		bitmaps_block;
  udate		last_check,
		max_interval,
		last_mount;
  uint32_t	inode_count,
		free_inode_count,
		root_table_inode,
		bad_block_inode,
		persistence_inode,
		component_inode,
		error_inode,
		journal_inode;
  uint8_t	mount_count,
		max_mount_count,
		creator_os,
		superblock_version,
		block_size,
		inode_format;
};

struct __udbfs_inode {

  uint64_t	size,
		block[4],
		ind_block,
		bind_block,
		tind_block;
};

struct __udbfs_table {

  uint64_t	last_id,
		row_count;
  uint32_t	record_size,
		first_free_record_index,
		acl_index,
		owner;
  uint16_t	column_count;
  uint8_t	properties,
		reserved;
};

struct __udbfs_column {
  
  uint32_t	name_length,
		name[31],
		count,
		size_or_enumeration,
		acl,
		compression,
		encryption,
		sequence,
		offset;
  uint8_t	list_index,
		properties,
		type,
		shift;
};


struct _udbfs_block {
  struct _udbfs_block *next;
  uint64_t block_id;
  uint8_t *data;
  int offset_start, offset_end;
};


struct _udbfs_file {
  struct _udbfs_block *blocks, *current_block;
  uint32_t inode_id;
  int current_offset, file_size, block_count;
};

struct _udbfs_column_desc {
  struct _udbfs_column_desc *next;
  struct __udbfs_column column;
  int encoded_size, natural_boundary;
};

struct _udbfs_table {
  struct __udbfs_table table;
  struct _udbfs_column_desc *cols;
  struct _udbfs_file *file;
};

