
TGT = init.a
OBJS = main.o

all: $(OBJS)
	ar rc $(TGT) $<

clean:
	rm -f $(TGT) $(OBJS)

.c.o:
	gcc -o $@ -c $< -nostdinc -fno-builtin -m32

.PHONY: all clean

