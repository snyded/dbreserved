# makefile
# This makes "dbreserved"

CC=esql
#CC=c4gl

dbreserved: dbreserved.ec keyword.h
	$(CC) -O dbreserved.ec -o dbreserved -s
	@rm -f dbreserved.c
