#!/usr/bin/perl -w

# the last label encountered, used to insert automatically the name attributes
# in <proc> tags and the like

$last_label = '';


# tags for which to automatically insert name tags from last_label. The source
# file and line number will also be inserted.

$auto_name_tags = 'proc';


print "<?xml version=\"1.0\" ?>\n<uuudoc>\n";

while( <> )
{
  $last_label = $1 if /^\s*(\w*)\s*:/;

  next unless s/^\s*;!//;

  s/\<($auto_name_tags)(.*?)\>/<$1 name="$last_label" file="$ARGV" line="$."$2>/g;
  print;
}

print "</uuudoc>\n";
