PREFIX = /usr/local

src := dbudget.d decimal.d account.d

dbudget: $(src)
	dmd -debug -unittest -wi $(src) -of$@

install: dbudget
	install -D dbudget $(PREFIX)/bin/dbudget

clean: 
	rm -rf dbudget dbudget.o
.PHONY: clean
