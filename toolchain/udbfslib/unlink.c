#define _LARGEFILE_SOURCE
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS		64
#define _POSIX_SOURCE

#include "udbfs.h"
#include "udbfslib.h"

#include <stdio.h>

#include "extralib.h"


/* 3.) udbfslib_unlink

   Unlink a node from a chained link list.
 */

void udbfslib_unlink(
    void *root,
    void *node_to_remove ) {

  struct linked_node {
    struct linked_node		*next,
    				*previous;
  } *link_node, **link_root;

  link_node			= (struct linked_node *)node_to_remove;
  link_root			= (struct linked_node **)root;

  if( link_node->previous == NULL ) {

    if( *link_root != link_node )
      goto list_out_of_sync;

    *link_root			= link_node->next;
    link_node->next		= NULL;

  } else {

    if( link_node->previous->next != link_node )
      goto list_out_of_sync;

    link_node->previous		= link_node->next;

    if( link_node->next != NULL ) {

      if( link_node->next->previous != link_node )
	goto list_out_of_sync;
      
      link_node->next->previous	= link_node->previous;
    }
  }
  link_node->next		= NULL;
  link_node->previous		= NULL;
  return;

list_out_of_sync:
  fprintf(stderr,"udbfslib: ERROR, list out of sync!\n");
}
