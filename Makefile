.PHONY: all test lint harden clean

all: test

# Fast lint
lint:
	verilator --lint-only -Wall src/*.sv src/*.v

# Fast test  
test:
	cd test && make

# OpenLane harden
harden:
	docker run --rm -v $(PWD):/work -w /work \
		efabless/openlane:latest flow.tcl -design .

clean:
	rm -rf test/sim_build test/__pycache__ runs
