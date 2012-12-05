DC?=dmd

MAIN=ES.d JCutils.d solution.d test.d

main: 
	$(DC) $(MAIN) -L-ldyaml -L-lorange -w -m64 -gc -noboundscheck
	
run: main
	./ES
	
clean:
	rm ES
