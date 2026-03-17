CC := clang
CFLAGS := -fobjc-arc
FRAMEWORKS := -framework Foundation
LIBS := -lsqlite3
TARGET := listKindleBooks2
SRC := listKindleBooks2.m
BINDIR := /usr/local/bin

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(SRC) $(LIBS) -o $(TARGET)

clean:
	rm -f $(TARGET) *.o


install:    $(TARGET)
	install $(TARGET) $(BINDIR)
