# Cocotb Makefile for MAC Unit Testing

# Add cocotb-config to PATH
export PATH := $(HOME)/Library/Python/3.9/bin:$(PATH)

# Cocotb paths - set these to override cocotb-config calls
COCOTB_SHARE := $(shell python3 -m cocotb.config --share)
COCOTB_MAKEFILES := $(shell python3 -m cocotb.config --makefiles)
COCOTB_MAKEFILES_DIR := $(COCOTB_MAKEFILES)
export COCOTB_SHARE
export COCOTB_MAKEFILES
export COCOTB_MAKEFILES_DIR

# Defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Source files
# Source files
VERILOG_SOURCES += "$(CURDIR)/../src/tt_um_tensor_mac.v"
VERILOG_SOURCES += "$(CURDIR)/../src/mac_core.sv"

# Top-level module
TOPLEVEL = tt_um_tensor_mac

# Python test module
MODULE = test_mac

# Include cocotb's make rules
include $(COCOTB_MAKEFILES)/Makefile.sim
