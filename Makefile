.PHONY: all test lint librelane librelane-check librelane-wrapper librelane-klayout librelane-openroad view-gds view-gds-preview clean

LL := python3 -m librelane --docker-no-tty --dockerized --pdk sky130A
LL_PATH := $(HOME)/Library/Python/3.9/bin
export PATH := $(LL_PATH):$(PATH)

all: test

lint:
	verilator --lint-only -Wall -I src src/tt_um_tensor_mac.v src/mac_core.sv

test:
	cd test && make

# Gate-level regression (requires PDK + gate_level_netlist.v from a harden run)
gl-test:
	cd test && make clean GATES=yes

# --- LibreLane (standalone, no Tiny Tapeout) ---

librelane-check:
	$(LL) --smoke-test

librelane:
	mkdir -p runs/mac
	$(LL) --run-tag mac --force-run-dir runs/mac librelane/mac_core.json

librelane-wrapper:
	mkdir -p runs/wrapper
	$(LL) --run-tag wrapper --force-run-dir runs/wrapper librelane/tt_um_tensor_mac.json

librelane-klayout:
	$(LL) --force-run-dir runs/mac --flow OpenInKLayout librelane/mac_core.json

librelane-openroad:
	$(LL) --force-run-dir runs/mac --flow OpenInOpenROAD librelane/mac_core.json

view-gds:
	python3 scripts/view_gds.py

view-gds-preview:
	python3 scripts/view_gds.py --png-only

clean:
	rm -rf test/sim_build test/__pycache__ test/results.xml test/tb.vcd runs
