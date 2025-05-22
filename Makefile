# Simplified Makefile for framebuffer
CC = gcc
CFLAGS = -m32 -O2

all: netsurf-fb

netsurf-fb:
	$(MAKE) -C nsfb all

clean:
	$(MAKE) -C nsfb clean