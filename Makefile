DC?=dmd

EXAMPLE_DIR=examples/sine_fit

all: 
	$(DC) *.d $(EXAMPLE_DIR)/*.d -L-ldyaml -L-lorange -w -m64 -O
	rm ES.o
run: all
	./ES
clean:
	rm ES
