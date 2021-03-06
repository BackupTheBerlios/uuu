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
  uint64_t			boot_loader_inode,	// 0x00
  				inode_first_block,	// 0x08
				unique_fs_signature,	// 0x10
				block_count,		// 0x18
				inode_count,		// 0x20
				free_block_count,	// 0x28
				free_inode_count,	// 0x30
				bitmaps_block,		// 0x38
				journal_inode,		// 0x40
				bad_block_inode,	// 0x48
				magic_number;		// 0x50
  udate				last_check,		// 0x58
				max_interval,		// 0x60
				last_mount;		// 0x68
  uint8_t			mount_count,		// 0x70
				max_mount_count,	// 0x71
				creator_os,		// 0x72
				superblock_version,	// 0x73
				block_size,		// 0x74
				inode_format;		// 0x75
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
  uint64_t inode_id;
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

