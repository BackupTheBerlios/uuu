#!/usr/bin/python -u

# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/mkfont.py,v 1.1 2003/09/23 03:46:22 bitglue Exp $

# This is a utility script used to convert the font from something readable to
# something that can be assembled.

import sys
import re

inline = sys.stdin.readline()[:-1]
outline = ''

while inline :
  if inline[0] != ';' :
    outline += inline
    if len(outline) >= 8*5 :
      outline = re.sub( "\#", "1", re.sub( "\.", "0", outline[:8*5] ) )
      print 'dd', outline[:32] + 'b'
      print 'db', outline[32:32+8] + 'b'
      outline = outline[8*5:]
  else :
    print inline
  inline = sys.stdin.readline()[:-1]
