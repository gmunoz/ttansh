.EXPORT_ALL_VARIABLES:

TOPDIR := $(shell pwd)

include common.inc

TARGET = msh
TEST_PARSER_TARGET = test_parser

CFLAGS =

LIB_DIR = $(TOPDIR)/lib
SHELL_DIR = $(TOPDIR)/shell
SUBDIRS = $(LIB_DIR) $(SHELL_DIR)

SHELL_FILES = $(wildcard $(SHELL_DIR)/*.c)
LEX_FILE = $(wildcard $(SHELL_DIR)/*.l)
YACC_FILE = $(wildcard $(SHELL_DIR)/*.y)
SHELL_OBJS = $(addprefix $(OBJDIR),$(patsubst %.c,%.o,$(SHELL_FILES)))
#SHELL_OBJS += $(addprefix $(OBJDIR),$(patsubst %.l,%.o,$(LEX_FILE)))
SHELL_OBJS += $(addprefix $(OBJDIR),$(patsubst %.y,%.o,$(YACC_FILE)))
LIB_OBJS = $(LIB_DIR)/libtansh.a

all:
	@for dir in $(SUBDIRS); \
		do ($(MAKE) -C $$dir all); \
	done
	$(CC) $(CFLAGS) $(CFLAGS_TANSH) -o $(TARGET) $(LIB_OBJS) $(SHELL_OBJS) -L$(LIB_DIR) $(LDFLAGS)

clean:
	@for dir in $(SUBDIRS); \
		do ($(MAKE) -C $$dir clean); \
	done
	$(RM) $(TARGET) $(TEST_PARSER_TARGET)

distclean: clean
	@for dir in $(SUBDIRS); \
		do ($(MAKE) -C $$dir distclean); \
	done
	$(RM) $(TARGET) $(TEST_PARSER_TARGET)

include rules.inc
