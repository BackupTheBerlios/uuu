/*
 * $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bimage/x86/bimage.ld,v 1.1 2003/12/23 02:25:03 bitglue Exp $
 *
 * ld script for x86 boot image
 */

ENTRY(_start)

SECTIONS
{
  /* waste of space... */
  /DISCARD/ :
  {
    *(.note*)
    *(.comment)
  }

  /* set output to be fixed at 2M */
  . = 2M;

  .data	: { *(.data) }
  .text	: { *(.text) }
  .bss	: { *(.bss) }
}
