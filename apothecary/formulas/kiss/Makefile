CC=gcc
CFLAGS=-I.

LIB=libkiss.a
LIBDEST=./lib/$(TARGET_DIR)/

LIBSRC=kiss_fft.c tools/kiss_fftr.c

LIBOBJ=$(LIBSRC:.c=.o)

install: $(LIB)
	@echo lib Makefile - installing $(LIB)
	@mkdir -p $(LIBDEST)
	@install -m 444 $(LIB) $(LIBDEST)

$(LIB): $(LIBOBJ)
	@echo lib Makefile - archiving $(LIB)
	@$(AR) r $(LIB) $(LIBOBJ)

%.o: %.c
	@echo lib Makefile - compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@


