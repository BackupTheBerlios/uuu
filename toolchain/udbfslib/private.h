uint64_t		udbfslib_allocate_bit(
    uint8_t			*bitmap,
    uint64_t			bitmap_size,
    uint64_t			*free_count );


UDBFSLIB_INODE	*udbfslib_allocate_memory_inode(
    UDBFSLIB_MOUNT		*mount );

void		udbfslib_link(
    void			*root,
    void			*new_node );

int		udbfslib_load_ind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_INDBLOCK		**linkpoint );

int		udbfslib_load_bind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_BINDBLOCK		**linkpoint );

int		udbfslib_load_tind_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_TINDBLOCK		**linkpoint );

UDBFSLIB_BLOCK	*udbfslib_select_active_inode_block(
    UDBFSLIB_INODE		*inode );

void		udbfslib_unlink(
    void			*root,
    void			*node_to_remove );

void		udbfslib_unload_tind_block(
    UDBFSLIB_TINDBLOCK		**tindblock_hook );

void		udbfslib_unload_ind_block(
    UDBFSLIB_INDBLOCK		**indblock_hook );

void		udbfslib_unload_block(
    UDBFSLIB_BLOCK		**block_hook );

void		udbfslib_unload_bind_block(
    UDBFSLIB_BINDBLOCK		**bindblock_hook );

int		udbfslib_load_block(
    UDBFSLIB_INODE		*inode,
    uint64_t			block_id,
    UDBFSLIB_BLOCK		**block_hook );
