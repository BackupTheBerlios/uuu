UTILS = udbfslib mkudbfs udbfstools

include Make.conf

.PHONY: all install clean

# this is redefined because in the way we use $(making) here,
# we don't need the '@'

ifeq ($(VERBOSE),on)
  echo=:
endif

all:
	@$(foreach util,$(UTILS),$(making) $(util) && $(MAKE) -C $(util) && ) :

install clean:
	@$(foreach util,$(UTILS),$(making) '$@' in $(util) && $(MAKE) -C $(util) "$@" && ) :
