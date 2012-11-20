DC?=dmd

EXAMPLE_DIR=examples/sine_fit

MAIN=ES.d JCutils.d interface.d test.d
SINE=ES.d JCutils.d

main: 
	$(DC) MAIN -L-ldyaml -L-lorange -w -m64 -O
	
sine:
	$(DC) SINE $(EXAMPLE_DIR)/*.d -L-ldyaml -L-lorange -w -m64 -O -ofsine
	rm ES.o
	
run_main: main
	./ES
	
run_sine: sine
	./sine
	
clean:
	rm ES
