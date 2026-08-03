#!/bin/bash
export PATH=$HOME/Library/Python/3.9/bin:$PATH

# Compile
echo "Compiling..."
iverilog -o sim.vvp -s tt_um_tensor_mac -g2012 "../src/tt_um_tensor_mac.v" "../src/mac_core.sv"

if [ $? -ne 0 ]; then
    echo "Compilation failed"
    exit 1
fi

# Run
echo "Running Simulation..."
# Get cocotb lib path
LIB_DIR=$(cocotb-config --lib-dir)
# Note: On macOS, library extension is .dylib or .so. cocotb uses libcocotbvpi_icarus.vpl usually?
# Actually: -M path -m libcocotbvpi_icarus
# Let's check what cocotb-config says.

export MODULE=test_mac
export TOPLEVEL=tt_um_tensor_mac
# export COCOTB_REDUCED_LOG_FMT=1
export LIBPYTHON_LOC=$(cocotb-config --libpython)

# vvp -M $LIB_DIR -m libcocotbvpi_icarus sim.vvp
# Note: cocotb 1.5+ uses standard mechanism.
# Let's try standard way:
vvp -M $LIB_DIR -m libcocotbvpi_icarus sim.vvp
