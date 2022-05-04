
TGT = init.a
OBJS = main.o

INCLUDE := /root/fairy/include/

all: $(OBJS)
	ar rc $(TGT) $<

clean:
	rm -f $(TGT) $(OBJS)

.c.o:
	gcc -o $@ -c $< -nostdinc -fno-builtin -m32 -I$(INCLUDE)

.PHONY: all clean

