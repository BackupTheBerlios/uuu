// $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfslib/link.c,v 1.1 2003/10/11 13:14:19 bitglue Exp $

#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"

#include <stdio.h>



/* 2.) udbfslib_link

   Link a node in a chained link list.
 */
void udbfslib_link(
    void *root,
    void *new_node ) {

  struct linked_node {
    struct linked_node		*next,
    				*previous;
  } *link_node, **link_root;

  link_root			= root;
  link_node			= new_node;

  if( (link_node->previous != NULL) || (link_node->next != NULL) ) {
    fprintf(stderr,"udbfslib: attempting to link an already linked node\n");
    return;
  }

  link_node->next		= *link_root;
  link_node->previous		= NULL;
  *link_root			= link_node;

  if( link_node->next != NULL ) {
    link_node->next->previous	= link_node;
  }
}
