ifeq ($(VERBOSE),on)
  echo=:
else
  echo=echo
  .SILENT:
endif


ifeq ($(COLOR),on)
entering=$(echo)	"[01;34mentering[00m"
cleaning=$(echo)	"[01;34mcleaning[00m"
archiving=$(echo)	"  [01;32marchiving[00m"
assembling=$(echo)	"  [01;32massembling[00m"
compiling=$(echo)	"  [01;32mcompiling[00m"
generating=$(echo)	"  [01;32mgenerating[00m"
compressing=$(echo)	"  [01;32mcompressing[00m"
linking=$(echo)		"  [01;32mlinking[00m"
else
entering=$(echo)	"entering"
cleaning=$(echo)	"cleaning"
archiving=$(echo)	"  archiving"
assembling=$(echo)	"  assembling"
compiling=$(echo)	"  compiling"
generating=$(echo)	"  generating"
compressing=$(echo)	"  compressing"
linking=$(echo)		"  linking"
endif
