/*
 * $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage2.ld,v 1.2 2003/11/01 00:46:37 bitglue Exp $
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
    *(.note)
    *(.comment)
  }

  /* set output to be fixed at 1M */
  . = 1M;


  /* make sure the multiboot header comes first */

  .data	: { stage2.o(multiboot) *(.data) }
  .text	: { *(.text) }
  .bss	: { *(.bss)  }


  /* this is used to store keyboard input to be parsed. This must be changed,
   * to support multiboot, because the bootloader wouldn't know this space is
   * reserved. */

  PROVIDE( command_buffer = . );
}
