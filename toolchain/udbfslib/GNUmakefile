# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/GNUmakefile,v 1.11 2003/10/27 00:27:44 bitglue Exp $

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



libudbfs.a: libudbfs.a($(OBJS))

clean:
	rm -f libudbfs.a test *.o *.d

install: libudbfs.a
	$(installing) 'libudbfs.a' in '$(LIBDIR)'
	cp libudbfs.a '$(LIBDIR)'
	$(installing) 'udbfs.h' in '$(INCDIR)'
	cp udbfs.h udbfslib.h '$(INCDIR)'

-include $(OBJS:.o=.d)
