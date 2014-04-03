ifeq ($(TOPDIR),)
TOPDIR = ..
include $(TOPDIR)/common.inc
endif

FILES = $(wildcard *.c)
OBJECTS = $(addprefix $(OBJDIR),$(patsubst %.c,%.o,$(FILES)))
YACCFILES = $(wildcard *.y)
YACCOBJS = $(addprefix $(OBJDIR),$(patsubst %.y,%.o,$(YACCFILES)))
LEXFILES = $(wildcard *.l)
LEXOBJS = $(addprefix $(OBJDIR),$(patsubst %.l,%.o,$(LEXFILES)))

all: $(YACCOBJS) $(LEXOBJS) $(OBJECTS)

clean:
	$(RM) *.o lex.c parser.c parser.h

distclean: clean
	$(RM) *.d

include $(TOPDIR)/rules.inc
-include $(DEP)
