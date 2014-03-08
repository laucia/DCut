# Quick D make file
# lauris jullien - lauris.jullien@telecom-paristech.org
# License: use freely for any purpose

DC = dmd
SRC = $(wildcard *.d)
OBJ = $(SRC:.d=.o)
EXE = $(shell basename `pwd`)

DFLAGS = -w 

.PHONY: clean

all: dev

profile:	DFLAGS += -profile
dev:		DFLAGS += -unittest
debug:  	DFLAGS += -g -gc -debug


dev debug profile: $(EXE)

$(EXE): $(OBJ)
	$(DC) $(DFLAGS) -of$@ $(OBJ)

%.o: %.d
	$(DC) $(DFLAGS) -c $<

clean:
	rm $(OBJ)
	rm $(EXE)