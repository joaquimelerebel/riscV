# Makefile for CR-2022-002

.PHONY: report.pdf all clean

all: report.pdf

report.pdf: main.tex
	latexmk -use-make $<

cleanall:
	latexmk -C

clean:
	latexmk -c