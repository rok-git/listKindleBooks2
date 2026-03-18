CC := clang
CFLAGS := -fobjc-arc
FRAMEWORKS := -framework Foundation
LIBS := -lsqlite3
TARGET := listKindleBooks2
SRC := listKindleBooks2.m
BINDIR := /usr/local/bin
DB_PATH := $(HOME)/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite
SCHEMA_OUT := kindledb.sql

.PHONY: all clean install schema

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(SRC) $(LIBS) -o $(TARGET)

clean:
	rm -f $(TARGET) *.o

install: $(TARGET)
	install -d $(BINDIR)
	install $(TARGET) $(BINDIR)

schema:
	sqlite3 "$(DB_PATH)" ".schema" > "$(SCHEMA_OUT)"
