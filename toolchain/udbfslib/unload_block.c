#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"



/* 14) udbfslib_unload_bind_block
 */
void udbfslib_unload_bind_block(
    UDBFSLIB_BINDBLOCK	**bindblock_hook ) {
}



/* 12) udbfslib_unload_block
 */
void udbfslib_unload_block(
    UDBFSLIB_BLOCK	**block_hook) {
}


/* 13) udbfslib_unload_ind_block
 */
void udbfslib_unload_ind_block(
    UDBFSLIB_INDBLOCK	**indblock_hook ) {
}



/* 15) udbfslib_unload_tind_block
 */
void udbfslib_unload_tind_block(
    UDBFSLIB_TINDBLOCK	**tindblock_hook ) {
}
