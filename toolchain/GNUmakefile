UTILS = udbfslib mkudbfs udbfstools

.PHONY: all install clean

all:
	set -e
	$(foreach util,$(UTILS),$(MAKE) -C $(util); )

install clean:
	set -e
	$(foreach util,$(UTILS),$(MAKE) -C $(util) "$@"; )
