src := dbudget.d decimal.d account.d

dbudget: $(src)
	dmd -debug -unittest -wi $(src) -of$@

clean: 
	rm -rf dbudget dbudget.o
.PHONY: clean
