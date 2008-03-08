# Makefile for libicns and icns2png
#
# Copyright (C) 2001-2008 Mathew Eis <mathew@eisbox.net>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# VERSION 2 of the License, or (at your option) any later VERSION.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
#
#######################################################
# Update this section:

# Version information
# Note, versions are in the format of the following
# 0.0.0a
# See DEVNOTES for more information on versioning
LIBNAME = libicns
LIBVERMAJ = 0
LIBVERMIN = 5
LIBVERREL = 2

# Compile with debug flags and icns debug messages
DEBUG = false

# Compile with support for icons >= 256x256
# Use either Jasper or OpenJPEG, but not both
# As of 1.900.1, the Jasper library is still buggy when
# decompressing RGBA icons, so OpenJPEG is preferable
#JASPER = true
OPENJPEG = true

# Where make install puts libicns and icns2png
PREFIX ?= /usr
LIBPATH=$(PREFIX)/lib
BINPATH=$(PREFIX)/bin
INCPATH=$(PREFIX)/include

######################################################
# Operating system name
UNAME := $(shell uname)

VERSION = $(LIBVERMAJ).$(LIBVERMIN).$(LIBVERREL)
COMPATVER = $(LIBVERMAJ).$(LIBVERMIN).0
LIBSTATIC = $(LIBNAME).a
ifeq "$(UNAME)" "Darwin"
 LIBSO = $(LIBNAME).dylib
 LIBSOMAJ = $(LIBNAME).$(LIBVERMAJ).dylib
 LIBSOMIN = $(LIBNAME).$(LIBVERMAJ).$(LIBVERMIN).dylib
 LIBSOVER = $(LIBNAME).$(VERSION).dylib
else
 LIBSO = $(LIBNAME).so
 LIBSOMAJ = $(LIBSO).$(LIBVERMAJ)
 LIBSOMIN = $(LIBSO).$(LIBVERMAJ).$(LIBVERMIN)
 LIBSOVER = $(LIBSO).$(VERSION)
endif

# Development headers
LIBHDR = icns.h

# Utilities
CC=gcc
AR_RC=ar rc
RANLIB=ranlib
LT=libtool
MAKE=make

# Compiler flags
CFLAGS+=-Wall -I$(INCPATH)
ifeq "$(DEBUG)" "true"
CFLAGS+=-g -DICNS_DEBUG
endif
ifeq "$(JASPER)" "true"
CFLAGS+=-DICNS_JASPER
endif
ifeq "$(OPENJPEG)" "true"
CFLAGS+=-DICNS_OPENJPEG
endif

# Linker flags
LDFLAGS+=-L. -L$(LIBPATH)
ifeq "$(JASPER)" "true"
 LDFLAGS+=-lm -ljpeg -ljasper
endif
ifeq "$(OPENJPEG)" "true"
 LDFLAGS+=-lopenjpeg
endif

LDFLAGS_A+=$(LDFLAGS) $(LIBSTATIC)
ifeq "$(UNAME)" "Darwin"
 LDFLAGS_SO+=-licns $(LDFLAGS)
else
 LDFLAGS_SO+=-Wl,-rpath,. -licns $(LDFLAGS)
endif
LDFLAGS_PNG+=-lz -lm -lpng12

# Library object files
LIBOBJS = icns_debug.o icns_element.o icns_family.o icns_image.o icns_io.o icns_jp2.o icns_rle24.o icns_utils.o 
LIBOBJSDLL = $(LIBOBJS:.o=.pic.o)

# Utility programs included in library
LIBUTILS = icnsinfo icns2png icontainer2icns

# icnsinfo object files
ICNSINFOOBJS = icnsinfo.o

# icns2png object files
ICNS2PNGOBJS = icns2png.o

# icontainer2icns object files
ICONTOBJS = icontainer2icns.o

# All utility object files
UTILOBJS = $(ICNSINFOOBJS) $(ICNS2PNGOBJS) $(ICONTOBJS)

# Macros for makefile
.SUFFIXES:	.c .o .pic.o

.c.pic.o:
	$(CC) -c $(CFLAGS) -fPIC -o $@ $*.c

all: $(LIBSTATIC) $(LIBSO) $(LIBUTILS)

$(LIBSTATIC): $(LIBOBJS)
	$(AR_RC) $@ $(LIBOBJS)
	$(RANLIB) $@

$(LIBSO): $(LIBSOMAJ)
	ln -sf $(LIBSOMAJ) $(LIBSO)

$(LIBSOMAJ): $(LIBSOMIN)
	ln -sf $(LIBSOMIN) $(LIBSOMAJ)

$(LIBSOMIN): $(LIBSOVER)
	ln -sf $(LIBSOVER) $(LIBSOMIN)

$(LIBSOVER): $(LIBOBJSDLL)
ifeq "$(UNAME)" "Darwin"
	$(CC) -dynamiclib -install_name $(LIBSOMAJ) -current_version $(VERSION) \
	 -compatibility_version $(COMPATVER) -o $(LIBSOVER) $(LIBOBJSDLL)
else
	$(CC) -shared -W1,-soname,$(LIBSOMAJ) -o $(LIBSOVER) $(LIBOBJSDLL)
endif

icnsinfo: $(ICNSINFOOBJS) $(LIBSO)
	$(CC) -o icnsinfo $(CFLAGS) $(ICNSINFOOBJS) $(LDFLAGS_SO)

icns2png: $(ICNS2PNGOBJS) $(LIBSO)
	$(CC) -o icns2png $(CFLAGS) $(ICNS2PNGOBJS) $(LDFLAGS_PNG) $(LDFLAGS_SO)

icontainer2icns: $(ICONTOBJS)
	$(CC) -o icontainer2icns $(ICONTOBJS)

test: $(LIBUTILS)
	+@echo 'Test: Converting icon in native icns format...'; \
	./icns2png test1.icns; \
	echo 'Test: Converting icon in mac resource...'; \
	./icns2png test2.rsrc; \
	echo 'Test: Converting icon in macbinary resource...'; \
	./icns2png test3.bin; \

install-headers: $(LIBHDR)
	cp $(LIBHDR) $(INCPATH)/
	chmod 644 $(INCPATH)/$(LIBHDR)

install-static: install-headers $(LIBSTATIC) 
	-@if [ ! -d $(LIBPATH) ]; then mkdir -p $(LIBPATH); fi
	cp $(LIBSTATIC) $(LIBPATH)/
	chmod 644 $(LIBPATH)/$(LIBSTATIC)

install-shared: install-headers $(LIBSO)
	-@if [ ! -d $(LIBPATH) ]; then mkdir -p $(LIBPATH); fi	
	if [ "$(UNAME)" = "Darwin" ]; then install_name_tool -id $(LIBPATH)/$(LIBSOMAJ) $(LIBSOVER); fi
	cp $(LIBSOVER) $(LIBPATH)/
	chmod 755 $(LIBPATH)/$(LIBSOVER)
	(cd $(LIBPATH); \
	ln -sf $(LIBSOVER) $(LIBSOMAJ); \
	ln -sf $(LIBSOMAJ) $(LIBSO))

install-utils: $(LIBUTILS)
	-@if [ ! -d $(BINPATH) ]; then mkdir -p $(BINPATH); fi
	if [ "$(UNAME)" = "Darwin" ]; then install_name_tool -change $(LIBSOMAJ) $(LIBPATH)/$(LIBSOMAJ) icns2png; fi
	install -m 755 icns2png $(BINPATH)
	install -m 755 icontainer2icns $(BINPATH)

install: install-static install-shared install-utils
	
clean:
	rm -f $(LIBSTATIC) $(LIBSO) $(LIBSOMAJ) $(LIBSOMIN) \
		$(LIBSOVER) $(LIBUTILS) $(UTILOBJS) *.o *.png

