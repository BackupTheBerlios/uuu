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


#define PACKED __attribute__((packed))




struct udbfs_superblock {
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
} PACKED;




struct udbfs_inode {
  uint64_t			size,
  				block[4],
				ind_block,
				bind_block,
				tind_block;
} PACKED;




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
} PACKED;



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
} PACKED;


typedef struct udbfs_superblock	UDBFS_SUPERBLOCK;
typedef struct udbfs_inode	UDBFS_INODE;
typedef struct udbfs_table	UDBFS_TABLE;
typedef struct udbfs_column	UDBFS_COLUMN;


// UDB Micro-Ops
#define UDBMO_ALTER_TABLE			0x0A
#define UDBMO_CHANGE_COLUMN_DATATYPE		0x0B
#define UDBMO_COMMIT				0x16
#define UDBMO_CREATE_FILE			0x11
#define UDBMO_CREATE_TABLE			0x10
#define UDBMO_DROP_COLUMN			0x04
#define UDBMO_DROP_INODE			0x13
#define UDBMO_DROP_NAME				0x14
#define UDBMO_DROP_ROW				0x03
#define UDBMO_END_OF_QUERY			0x09
#define UDBMO_GRANT				0x0C
#define UDBMO_GROUP				0x1A
#define UDBMO_INSERT_ROW			0x00
#define UDBMO_INSERT_COLUMN			0x02
#define UDBMO_LIMIT				0x19
#define UDBMO_MATCH				0x18
#define UDBMO_MOUNT				0x0E
#define UDBMO_NAME				0x12
#define UDBMO_ORDER				0x1B
#define UDBMO_RENAME_COLUMN			0x07
#define UDBMO_REPLACE_ROW			0x01
#define UDBMO_REVOKE				0x0D
#define UDBMO_ROLLBACK				0x17
#define UDBMO_SELECT				0x05
#define UDBMO_SET_DEFAULT_COLUMN_ORDERING	0x06
#define UDBMO_START_TRANSACTION			0x15
#define UDBMO_UNMOUNT				0x0F
#define UDBMO_UPDATE				0x08


// UDB Packets

  // Column descriptions
  struct __udbp_column_desc {
    uint32_t	column_id,
		offset,
		count,
		size;
    uint8_t	datatype;
  } PACKED;
  typedef struct __udbp_column_desc UDBP_COLUMN_DESC;

  // UDBMO_ALTER_TABLE
  struct __udbp_alter_table {
    uint16_t	revision;
    uint8_t	opcode;
    uint64_t	table_id;
  } PACKED;
  typedef struct __udbp_alter_table UDBP_ALTER_TABLE;

  // UDBMO_CHANGE_COLUMN_DATATYPE
  struct __udbp_change_column_datatype {
    uint16_t	revision;
    uint8_t	opcode;
    UDBP_COLUMN_DESC	column_desc;
    uint32_t	compression,
    		encryption,
		acl;
  } PACKED;
  typedef struct __udbp_change_column_datatype UDBP_CHANGE_COLUMN_DATATYPE;

  // UDBMO_COMMIT, UDBMO_END_OF_QUERY
  struct __udbp_simple {
    uint16_t	revision;
    uint8_t	opcode;
  } PACKED;
  typedef struct __udbp_simple UDBP_COMMIT;
  typedef struct __udbp_simple UDBP_END_OF_QUERY;

  // UDBMO_CREATE_FILE and UDBMO_CREATE_TABLE
  struct __udbp_create_file {
    uint16_t	revision;
    uint8_t	opcode;
    uint64_t	preallocated;
  } PACKED;
  typedef struct __udbp_create_file UDBP_CREATE_FILE;
  typedef struct __udbp_create_file UDBP_CREATE_TABLE;

  // UDBMO_DROP_ROW
  struct __udbp_drop_row {
    uint16_t	revision;
    uint8_t	opcode;
    uint64_t	table_id;
  } PACKED;
  typedef struct __udbp_drop_row UDBP_DROP_ROW;

  // UDBMO_DROP_COLUMN
  struct __udbp_drop_column {
    uint16_t	revision;
    uint8_t	opcode;
    uint32_t	column_id;
  } PACKED;
  typedef struct __udbp_drop_column UDBP_DROP_COLUMN;

  // UDBMO_INSERT_ROW and UDBMO_REPLACE_ROW
  struct __udbp_insert_row {
    uint16_t	revision;
    uint8_t	opcode;
    uint8_t	data_source;
    uint32_t	record_length;
    uint64_t	table_id;
    uint32_t	acl;
    UDBP_COLUMN_DESC	column_desc[0];
  } PACKED;
  typedef struct __udbp_insert_row UDBP_INSERT_ROW;
  typedef struct __udbp_insert_row UDBP_REPLACE_ROW;

  // UDBMO_INSERT_COLUMN
  struct __udbp_insert_column {
    uint16_t	revision;
    uint8_t	opcode;
    uint8_t	datatype;
    uint32_t	name[31],
    		count,
		size,
		acl,
		compression,
		encryption,
		sequence;
    uint8_t	list_index,
    		properties;
  } PACKED;
  typedef struct __udbp_insert_column UDBP_INSERT_COLUMN;

  // UDBMO_GRANT : TODO
  struct __udbp_grant {
    uint16_t	revision;
    uint8_t	opcode;
  } PACKED;
  typedef struct __udbp_grant UDBP_GRANT;

  // UDBMO_GROUP : TODO
  struct __udbp_group {
    uint16_t	revision;
    uint8_t	opcode;
  } PACKED;
  typedef struct __udbp_group UDBP_GROUP;

  // UDBMO_LIMIT
  struct __udbp_limit {
    uint16_t	revision;
    uint8_t	opcode;
    uint64_t	lower_bound,
    		upper_bound;
  } PACKED;
  typedef struct __udbp_limit UDBP_LIMIT;

  // UDBMO_


#endif

