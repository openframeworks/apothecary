#!/bin/make
#
# Makefile for libsvgtiny
#
# Copyright 2009-2015 John-Mark Bell <jmb@netsurf-browser.org>

# Component settings
COMPONENT := svgtiny
COMPONENT_VERSION := 0.1.4
# Default to a static library
COMPONENT_TYPE ?= lib-static
RANLIB ?= ranlib

# Setup the tooling
#PREFIX ?= /opt/netsurf
#NSSHARED ?= $(PREFIX)/share/netsurf-buildsystem
#include $(NSSHARED)/makefiles/Makefile.tools

# Reevaluate when used, as BUILDDIR won't be defined yet
TESTRUNNER = test/runtest.sh $(BUILDDIR) $(EXEEXT)

# Toolchain flags
WARNFLAGS := -Wall -W -Wundef -Wpointer-arith \
	-Wwrite-strings -Wstrict-prototypes -Wmissing-prototypes \
	-Wmissing-declarations -Wnested-externs
# BeOS/Haiku/AmigaOS standard library headers create warnings
ifneq ($(BUILD),i586-pc-haiku)
  ifneq ($(findstring amigaos,$(BUILD)),amigaos)
    WARNFLAGS := $(WARNFLAGS)
  endif
endif

CFLAGS := $(CFLAGS) $(CUSTOM_CFLAGS) -D_BSD_SOURCE -D_DEFAULT_SOURCE -DWITHOUT_ICONV_FILTER \
	-fPIC \
	-I$(CURDIR)/include/ -I$(CURDIR)/src \
	$(WARNFLAGS)
ifneq ($(GCCVER),2)
  CFLAGS := $(CFLAGS) -std=c99
else
  # __inline__ is a GCCism
  CFLAGS := $(CFLAGS) -Dinline="__inline__"
endif

# libdom
CFLAGS := $(CFLAGS) -Ilibdom/include -Ilibdom/src -Ilibdom/bindings -Ilibwapcaplet/include -Ilibparserutils/include -Ilibparserutils/src -Ilibxml2/include
LDFLAGS := -ldom -lwapcaplet -lexpat -lm

#include $(NSBUILD)/Makefile.top

# Extra installation rules
I := /$(INCLUDEDIR)
INSTALL_ITEMS := $(INSTALL_ITEMS) $(I):include/svgtiny.h
INSTALL_ITEMS := $(INSTALL_ITEMS) /$(LIBDIR)/pkgconfig:lib$(COMPONENT).pc.in
INSTALL_ITEMS := $(INSTALL_ITEMS) /$(LIBDIR):$(OUTPUT)

SRC := $(wildcard src/*.c)
SRC += $(wildcard libdom/src/*/*.c)
SRC += libdom/bindings/xml/libxml_xmlparser.c
SRC += $(wildcard libwapcaplet/src/*.c)
SRC += $(wildcard libparserutils/src/*.c)
SRC += $(wildcard libparserutils/src/*/*.c)
SRC += $(wildcard libparserutils/src/*/*/*.c)
OBJS := $(patsubst %.c,%.o,$(SRC))

all: libsvgtiny.a

libsvgtiny.a: $(OBJS)
	$(AR) ruv "$@" $(OBJS)
	$(RANLIB) "$@"

%.o: %.c
	$(CC) -c $< -o $@ -O2 $(CFLAGS)

clean:
	rm -f $(OBJS) libsvgtiny.a
