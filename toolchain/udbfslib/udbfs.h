#ifndef _UDBFS_H_
#define _UDBFS_H_

#include <inttypes.h>

typedef uint64_t		udate;

#define UDBFS_MAGIC		0x75646221
#define DATATYPE_INT1           0x01
#define DATATYPE_INT2           0x02
#define DATATYPE_INT4           0x03
#define DATATYPE_INT8           0x04
#define DATATYPE_INT16          0x05
#define DATATYPE_INT32          0x06
#define DATATYPE_INT64          0x07
#define DATATYPE_INT128         0x08
#define DATATYPE_CHAR           0xF0
#define DATATYPE_VARCHAR        0xF1
#define DATATYPE_FLOAT          0xE0
#define DATATYPE_DATA           0xD0
#define DATATYPE_SHAREDDATA     0xC1
#define DATATYPE_DATETIME       0xB0
#define DATATYPE_ENUMERATION    0xA0





struct udbfs_superblock {
  uint32_t			magic_number,		// 0x00
  				boot_loader_inode;	// 0x04
  uint64_t			inode_first_block,	// 0x08
				unique_fs_signature,	// 0x10
				block_count,		// 0x18
				free_block_count,	// 0x20
				bitmaps_block;		// 0x28
  udate				last_check,		// 0x30
				max_interval,		// 0x38
				last_mount;		// 0x40
  uint32_t			inode_count,		// 0x48
				free_inode_count,	// 0x4C
				root_table_inode,	// 0x50
				bad_block_inode,	// 0x54
				journal_inode;		// 0x58
  uint8_t			mount_count,		// 0x5C
				max_mount_count,	// 0x5D
				creator_os,		// 0x5E
				superblock_version,	// 0x5F
				block_size,		// 0x60
				inode_format;		// 0x61
};




struct udbfs_inode {
  uint64_t			size,
  				block[4],
				ind_block,
				bind_block,
				tind_block;
};




struct udbfs_table {
  uint64_t			last_id,
  				row_count;
  uint32_t			record_size,
  				first_free_record_index,
				acl_index,
				owner;
  uint16_t			column_count;
  uint8_t			properties,
				reserved;
};



struct udbfs_column {
  uint32_t			name_length,
  				name[31],
				count,
				size,
				acl,
				compression,
				encryption,
				sequence,
				offset;
  uint8_t			list_index,
  				properties,
				type,
				shift;
};


typedef struct udbfs_superblock	UDBFS_SUPERBLOCK;
typedef struct udbfs_inode	UDBFS_INODE;
typedef struct udbfs_table	UDBFS_TABLE;
typedef struct udbfs_column	UDBFS_COLUMN;


#endif

