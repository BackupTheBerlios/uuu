/*
 * $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage2.ld,v 1.3 2003/11/07 20:55:38 bitglue Exp $
 *
 * ld script for the stage2 bootloader
 */

OUTPUT(stage2)
ENTRY(_start)

SECTIONS
{
  /* waste of space... */
  /DISCARD/ :
  {
    *(.note*)
    *(.comment)
  }

  /* the boot section is loaded after .bss, and is then copied to 0x500 by code
   * in stage2.asm. The boot section contains the code that does the
   * uncompressing and setup of the RAM image after it has been loaded. */

  boot 0x500 : AT( ADDR(.bss) + SIZEOF(.bss) )
  {
    PROVIDE( boot_dest = . );

    /* everything in boot.asm goes in the boot section */

    boot.o


    /* These are all the objects in the zlib archive. It seems there is no way
     * to match the archive itself. We want all code from zlib to go in the
     * boot section. If there is a cleaner way to do this, please let me know.
     *
     * Phil Frost <pfrost@bitglue.com> */

    *adler32.o(*)
    *compress.o(*)
    *crc32.o(*)
    *gzio.o(*)
    *uncompr.o(*)
    *deflate.o(*)
    *trees.o(*)
    *zutil.o(*)
    *inflate.o(*)
    *infblock.o(*)
    *inftrees.o(*)
    *infcodes.o(*)
    *infutil.o(*)
    *inffast.o(*)

    PROVIDE( boot_size = ALIGN(4) - boot_dest );

    /* this is used to store keyboard input to be parsed. This must be changed,
     * to support multiboot, because the bootloader wouldn't know this space is
     * reserved. We put it below 1M because GRUB won't use it. */

    PROVIDE( command_buffer = . );
  }

  /* set output to be fixed at 1M */
  . = 1M;


  /* make sure the multiboot header comes first */

  .data	: { stage2.o(multiboot) *(.data) }
  .text	: { *(.text) }
  .bss	: { *(.bss)  }

  /* the boot section (defined above) follows .bss */
  PROVIDE( boot_source = . );

  /* place our stack beneath video ram */
  PROVIDE( stack_top = 0xa0000 );
}
