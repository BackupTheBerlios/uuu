// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfstools/udb-instboot.c,v 1.3 2003/10/13 22:12:54 bitglue Exp $

/* udbfs-install-bootloader
 *
 * Installs a file as the bootloader for a udbfs filesystem. */

#include <udbfslib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <malloc.h>

#include "../conf.h"

#define BUFFER_SIZE 4096	// buffer size used to transfer data from source to target bootloader files

void print_usage()
{
    fprintf( stderr, "\
Usage: udbfs-install-bootloader DEVICE BOOTLOADER\n\
\n\
Installs BOOTLOADER on DEVICE, which must contain a valid udbfs filesystem.\n" );
}



int main( int argc, char *argv[] )
{
    UDBFSLIB_MOUNT *device;
    UDBFSLIB_INODE *target;
    FILE *source;
    void *buffer;
    int return_value;
    size_t i;

    return_value = 0;

    if( argc != 3 ) {
	print_usage();
	return -1;
    }

    source = fopen( argv[2], "rb" );
    if( source == NULL ) {
	fprintf( stderr, "unable to open '%s': %s\n", argv[2], strerror(errno) );
	return -1;
    }

    device = udbfs_mount( argv[1] );
    if( device == NULL ) {
	fprintf( stderr, "unable to mount udbfs on '%s'", argv[1] );
	return_value = -1;
	goto close_source;
    }

    if( device->boot_loader_inode != 0 ) {
	// bootloader inode already exists
	target = udbfs_open_inode( device, device->boot_loader_inode );
	if( target == NULL ) {
	    fprintf( stderr, "unable to open preexisting bootloader\n" );
	    return_value = -1;
	    goto unmount;
	}
    } else {
	// no bootloader exists
	target = udbfs_create_inode( device );
	if( target == NULL ) {
	    fprintf( stderr, "unable to create inode for bootloader\n" );
	    return_value = -1;
	    goto unmount;
	}
	udbfs_set_boot_loader_inode( device, target->id );
    }

    buffer = malloc( BUFFER_SIZE );
    if( buffer == NULL ) {
	perror( "unable to allocate transfer buffer" );
	return_value = -1;
	goto unmount;
    }

    do
    {
	i = fread( buffer, 1, BUFFER_SIZE, source );
	if( i )
	{
	    if( udbfs_write_to_inode( target, buffer, i ) != i ) {
		fprintf( stderr, "error while writing bootloader\n" );
		return_value = -1;
		goto close_inode;
	    }
	}
	if( ferror( source ) ) {
	    perror( "error while reading bootloader" );
	    return_value = -1;
	    goto close_inode;
	}
    }
    while( ! feof( source ) );

close_inode:
    udbfs_close_inode( target );
    free( buffer );
unmount:
    udbfs_unmount( device );
close_source:
    fclose( source );

    return return_value;
}
