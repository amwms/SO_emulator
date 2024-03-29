PROJECT = so_emulator

export N=4

NASM = nasm
NASMFLAGS = -DCORES=$N -f elf64 -w+all -w+error
OBJS = so_emulator_example.o so_emulator.o
CC = gcc
CFLAGS = -DCORES=$N -Wall -Wextra -std=c17 -O2
LDFLAGS = -pthread

.PHONY : all clean valgrind

all : $(PROJECT)

$(PROJECT) : $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS)

%.o : %.asm
	$(NASM) $(NASMFLAGS) $< -o $@

so_emulator_example.o : so_emulator_example.c

clean :
	rm -f $(PROJECT) $(OBJS)

valgrind : $(PROJECT)
	valgrind --error-exitcode=123 --leak-check=full \
	--show-leak-kinds=all --errors-for-leak-kinds=all ./$(PROJECT)