DC?=dmd
EXTRA?=
MAIN?=test.d
INCLUDES=ES.d JCutils.d solution.d

main: 
	$(DC) $(MAIN) $(INCLUDES) -L-ldyaml -L-lorange -w -m64 -gc
	#-O -inline -release -noboundscheck $(EXTRA)
	
run: main
	./ES
	
clean:
	rm ES
