#include <inttypes.h>
#include <fcntl.h>
#include <unistd.h>

typedef uint64_t		udate;

#define UDBFS_MAGIC		0x75646221


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




struct udbfs_mount {
  struct udbfs_mount		*next,
				*previous;

  int				block_device;

  uint8_t			*block_bitmap,
				*inode_bitmap;

  struct udbfs_superblock	superblock;
};



typedef struct udbfs_mount UDBFS_MOUNT;
typedef struct udbfs_superblock UDBFS_SUPERBLOCK;


UDBFS_MOUNT *udbfs_mount( char *block_device );
void udbfs_unmount( UDBFS_MOUNT *mount );
