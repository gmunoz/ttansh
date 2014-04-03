# Contains all common environment variables. Useful for inclusion when
# working directly in a sub-directory.

CC = gcc
LD = ld
AR = ar
RM = rm -f

LIBDIR = $(TOPDIR)/lib
INCDIRS = -I../lib -I.. -I. -Ilib

ifeq ($(CC),gcc)
CFLAGS_TANSH = -Wall -g
LD = ld
endif
ifeq ($(CC),icc)
CFLAGS_TANSH = -Wall -g
LD = xild
endif

LDFLAGS = -ltansh -lfl
