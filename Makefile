ROM=citysim.sms

all: $(ROM)

main.o: main.asm
	wla-z80 -o $@ $<

$(ROM): main.o linkfile
	wlalink -v linkfile $(ROM)

clean:
	rm -f main.o $(ROM)
