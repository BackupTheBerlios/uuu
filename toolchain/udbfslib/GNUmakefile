# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/GNUmakefile,v 1.9 2003/10/13 21:27:20 bitglue Exp $

include ../Make.conf

.PHONY: all clean install

OBJS=\
 add_column.o\
 allocate_bit.o\
 allocate_block_id.o\
 allocate_inode_id.o\
 allocate_memory_block.o\
 allocate_memory_inode.o\
 close_inode.o\
 create_inode.o\
 create_table.o\
 eoi.o\
 free_inode.o\
 link.o\
 load_bind_block.o\
 load_block.o\
 load_ind_block.o\
 load_tind_block.o\
 mount.o\
 open_inode.o\
 open_table.o\
 read_from_inode.o\
 regenerate_table.o\
 select_active_inode_block.o\
 set_boot_loader_inode.o\
 unlink.o\
 unload_block.o\
 write_to_inode.o



libudbfs.a: libudbfs.a($(OBJS)) private.h

clean:
	rm -f libudbfs.a test *.o

install: libudbfs.a
	cp libudbfs.a "$(LIBDIR)"
	cp udbfs.h udbfslib.h "$(INCDIR)"
