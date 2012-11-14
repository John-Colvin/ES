DC?=dmd

EXAMPLE_DIR=examples/sine_fit

run: all
	./ES
all: 
	$(DC) *.d $(EXAMPLE_DIR)/*.d -L-ldyaml -L-lorange -w -m64 -O
	rm ES.o
clean:
	rm ES
