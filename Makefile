dbudget: dbudget.d
	dmd -debug -unittest -wi $< -of$@

clean: 
	rm -rf dbudget dbudget.o
.PHONY: clean
