; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/include/udbfs.inc,v 1.2 2003/10/13 01:14:55 bitglue Exp $

%ifndef _UDBFS_INC_
%define _UDBFS_INC_

%define udbfs_magic		0x75646221
%define udbfs_datatype_int1           0x01
%define udbfs_datatype_int2           0x02
%define udbfs_datatype_int4           0x03
%define udbfs_datatype_int8           0x04
%define udbfs_datatype_int16          0x05
%define udbfs_datatype_int32          0x06
%define udbfs_datatype_int64          0x07
%define udbfs_datatype_int128         0x08
%define udbfs_datatype_char           0xf0
%define udbfs_datatype_varchar        0xf1
%define udbfs_datatype_float          0xe0
%define udbfs_datatype_data           0xd0
%define udbfs_datatype_shareddata     0xc1
%define udbfs_datatype_datetime       0xb0
%define udbfs_datatype_enumeration    0xa0



struc udbfs_superblock
  .boot_loader_inode:	resq 1	; 0x00
  .inode_first_block:	resq 1	; 0x08
  .unique_fs_signature:	resq 1	; 0x10
  .block_count:		resq 1	; 0x18
  .inode_count:		resq 1	; 0x20
  .free_block_count:	resq 1	; 0x28
  .free_inode_count:	resq 1	; 0x30
  .bitmaps_block:	resq 1	; 0x38
  .root_table_inode:	resq 1	; 0x40
  .journal_inode:	resq 1	; 0x48
  .bad_block_inode:	resq 1	; 0x50
  .magic_number:	resq 1	; 0x58
  .last_check:		resq 1	; 0x60
  .max_interval:	resq 1	; 0x68
  .last_mount:		resq 1	; 0x70

  .mount_count:		resb 1	; 0x78
  .max_mount_count:	resb 1	; 0x79
  .creator_os:		resb 1	; 0x7A
  .superblock_version:	resb 1	; 0x7B
  .block_size:		resb 1	; 0x7C
  .inode_format:	resb 1	; 0x7D
endstruc



struc udbfs_inode
  .size:		resq 1
  .block:		resq 4
  .ind_block:		resq 1
  .bind_block:		resq 1
  .tind_block:		resq 1
endstruc



struc udbfs_table
  .last_id:		resq 1
  .row_count:		resq 1

  .record_size:		resd 1
  .first_free_record_index:	resd 1
  .acl_index:		resd 1
  .owner:		resd 1

  .column_count:	resw 1

  .properties:		resb 1
  .reserved:		resb 1
endstruc



struc udbfs_column
  .name_length:		resd 1
  .name:		resd 31
  .count:		resd 1
  .size:		resd 1
  .acl:			resd 1
  .compression:		resd 1
  .encryption:		resd 1
  .sequence:		resd 1
  .offset:		resd 1

  .list_index:		resb 1
  .properties:		resb 1
  .type:		resb 1
  .shift:		resb 1
endstruc



%endif

; vim: syntax=nasm
