ifeq ($(TOPDIR),)
TOPDIR = ..
include $(TOPDIR)/common.inc
endif

TANSH_ARCHIVE = libtansh.a
FILES = $(wildcard *.c)
OBJECTS = $(addprefix $(OBJDIR),$(patsubst %.c,%.o,$(FILES)))

all: $(OBJECTS)
	$(AR) cr $(TANSH_ARCHIVE) $(OBJECTS)

clean:
	$(RM) *.o $(TANSH_ARCHIVE)

distclean: clean
	$(RM) *.d

include $(TOPDIR)/rules.inc
-include $(DEP)
