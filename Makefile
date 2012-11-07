DC?=dmd

EXAMPLE_DIR=examples/sine_fit

all: 
	$(DC) *.d $(EXAMPLE_DIR)/*.d -L-ldyaml -L-lorange -w -gc -m64 -debug
	rm ES.o
clean:
	rm ES
