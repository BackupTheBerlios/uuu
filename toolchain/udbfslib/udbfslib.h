#ifndef _UDBFSLIB_H_
#define _UDBFSLIB_H_

#include <inttypes.h>

struct udbfslib_mount;
struct udbfslib_inode;
struct udbfslib_block;
struct udbfslib_indblock;
struct udbfslib_table;
struct udbfslib_column;



struct udbfslib_mount {
  struct udbfslib_mount		*next,
				*previous;

  int				block_device;

  uint8_t			*block_bitmap,
				*inode_bitmap,
				mount_count,
				max_mount_count,
				creator_os,
				superblock_version,
				log_block_size,
				inode_format;

  uint64_t			block_size,
				block_count,
				inode_count,
				free_block_count,
				free_inode_count,
				block_bitmap_offset,
				block_bitmap_size,
				inode_bitmap_offset,
				inode_bitmap_size,
				inode_table_offset,
				dir_storage,
				ind_storage,
				bind_storage,
				tind_storage,
				boot_loader_inode;

  uint64_t			inode_first_block,
  				unique_fs_signature,
				bitmaps_block,
				journal_inode,
				bad_block_inode,
				magic_number,
				last_check,
				last_mount,
				max_interval;

  struct udbfslib_inode		*opened_inodes;
};




struct udbfslib_inode {
  struct udbfslib_inode		*next,
				*previous;
  uint64_t			id,
				cursor,
				size,
				physical_offset;
  struct udbfslib_block		*block[4];
  struct udbfslib_indblock	*ind_block;
  struct udbfslib_bindblock	*bind_block;
  struct udbfslib_tindblock	*tind_block;
  struct udbfslib_mount		*mount;
};




struct udbfslib_indblock {
  uint64_t			id,
				device_offset;
  struct udbfslib_block		*block[0];
};

struct udbfslib_bindblock {
  uint64_t			id,
				device_offset;
  struct udbfslib_indblock	*indblock[0];
};

struct udbfslib_tindblock {
  uint64_t			id,
				device_offset;
  struct udbfslib_bindblock	*bindblock[0];
};




struct udbfslib_block {
  uint64_t			id,
				offset_start,
				offset_end,
				device_offset;
  struct udbfslib_inode		*inode;
};




struct udbfslib_table {
  struct udbfslib_table		*next,
  				*previous;

  struct udbfslib_column	*columns;
  
  uint32_t			record_size;

  uint64_t			offset_to_data,
				last_id,
				row_count,
				first_free_record,
				acl_index,
				owner;

  uint8_t			properties;
};


struct udbfslib_column {
  struct udbfslib_column	*next,
  				*previous;

  uint32_t			name_length,
  				name[31],
				count,
				size,
				compression,
				encryption,
				sequence,
				offset;
  uint8_t			list_index,
				properties,
				type,
				shift;
};



typedef struct udbfslib_block		UDBFSLIB_BLOCK;
typedef struct udbfslib_indblock	UDBFSLIB_INDBLOCK;
typedef struct udbfslib_bindblock	UDBFSLIB_BINDBLOCK;
typedef struct udbfslib_tindblock	UDBFSLIB_TINDBLOCK;
typedef struct udbfslib_inode		UDBFSLIB_INODE;
typedef struct udbfslib_mount		UDBFSLIB_MOUNT;
typedef struct udbfslib_table		UDBFSLIB_TABLE;
typedef struct udbfslib_column		UDBFSLIB_COLUMN;






UDBFSLIB_MOUNT	*udbfs_mount(
    char		*block_device );


void		udbfs_unmount(
    UDBFSLIB_MOUNT	*mount );


uint64_t	udbfs_allocate_inode_id(
    UDBFSLIB_MOUNT	*mount );


uint64_t	udbfs_allocate_block_id(
    UDBFSLIB_MOUNT	*mount );


UDBFSLIB_TABLE	*udbfs_create_table(
    UDBFSLIB_MOUNT	*mount );


UDBFSLIB_TABLE	*udbfs_open_table(
    UDBFSLIB_MOUNT	*mount,
    uint64_t		inode_id);


int		udbfs_add_column(
    UDBFSLIB_TABLE	*table,
    char		*name,
    uint8_t		datatype,
    uint32_t		size,
    uint32_t		count,
    uint32_t		compression,
    uint32_t		encryption );


int		udbfs_regenerate_table(
    UDBFSLIB_TABLE	*table );


UDBFSLIB_INODE	*udbfs_create_inode(
    UDBFSLIB_MOUNT	*mount);



UDBFSLIB_INODE	*udbfs_open_inode(
    UDBFSLIB_MOUNT	*mount,
    uint64_t		inode_id);


int		udbfs_close_inode(
    UDBFSLIB_INODE	*inode);


int		udbfs_free_inode(
    UDBFSLIB_MOUNT	*mount,
    uint64_t		inode_id);

int		udbfs_write_to_inode(
    UDBFSLIB_INODE	*inode,
    uint8_t		*data,
    uint32_t		size );

int		udbfs_read_from_inode(
    UDBFSLIB_INODE	*inode,
    uint8_t		*data,
    uint32_t		size );

int		udbfs_eoi(
    UDBFSLIB_INODE	*inode );

int		udbfs_set_boot_loader_inode(
    UDBFSLIB_MOUNT	*mount,
    uint64_t		inode_id );

#endif
