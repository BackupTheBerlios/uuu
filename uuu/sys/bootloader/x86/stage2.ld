/*
 * $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/stage2.ld,v 1.1 2003/10/31 22:32:06 bitglue Exp $
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


  .text : { *(.text) }
  .data : { *(.data) }
  .bss  : { *(.bss)  }


  /* this is used to store keyboard input to be parsed. */

  PROVIDE( command_buffer = . );
}
