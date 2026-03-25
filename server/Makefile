CC=gcc
CFLAGS=-I. -Imongoose -Wall -DMG_MAX_RECV_SIZE=104857600
LDFLAGS=-lpcap -lpthread
TARGET=arpahound-server
SRCDIR=src

# All source files
SOURCES := $(wildcard $(SRCDIR)/*.c)
SOURCES += mongoose/mongoose.c

OBJECTS=$(SOURCES:.c=.o)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(TARGET) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)
