#include <inttypes.h>
#include <fcntl.h>
#include <unistd.h>

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


struct udbfs_mount_struct;
struct udbfs_inode_struct;
struct udbfs_table_struct;




struct udbfs_superblock {
  uint32_t			magic_number,
  				boot_loader_inode;
  uint64_t			inode_first_block,
				unique_fs_signature,
				block_count,
				free_block_count,
				bitmaps_block;
  udate				last_check,
				max_interval,
				last_mount;
  uint32_t			inode_count,
				free_inode_count,
				root_table_inode,
				bad_block_inode,
				journal_inode;
  uint8_t			mount_count,
				max_mount_count,
				creator_os,
				superblock_version,
				block_size,
				inode_format;
};




struct udbfs_mount_struct {
  struct udbfs_mount_struct	*next,
				*previous;

  int				block_device;

  uint8_t			*block_bitmap,
				*inode_bitmap;

  struct udbfs_superblock	superblock;
};




struct udbfs_inode_struct {
  struct udbfs_inode_struct	*next,
  				*previous;
  uint32_t			id;
  uint64_t			file_size,
  				current_offset;
  struct udbfs_block_struct	*blocks,
  				*current_block;
};


typedef struct udbfs_inode_struct UDBFS_INODE;
typedef struct udbfs_mount_struct UDBFS_MOUNT;
typedef struct udbfs_superblock UDBFS_SUPERBLOCK;


UDBFS_MOUNT *udbfs_mount( char *block_device );
void udbfs_unmount( UDBFS_MOUNT *mount );
