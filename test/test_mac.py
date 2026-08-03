import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import random
import struct

# ==============================================================================
# Helper Functions for BF16 / FP32
# ==============================================================================

def float_to_bf16(f):
    """Convert float to 16-bit integer representing BF16."""
    # IEEE 754 float32: [31] Sign, [30:23] Exp, [22:0] Mantissa
    # BF16:             [15] Sign, [14:7] Exp, [6:0] Mantissa
    # Essentially top 16 bits of FP32.
    packed = struct.pack('>f', f)
    val_int = struct.unpack('>I', packed)[0]
    return (val_int >> 16) & 0xFFFF

def bf16_to_float(i):
    """Convert 16-bit integer (BF16) to float."""
    val_int = (i & 0xFFFF) << 16
    packed = struct.pack('>I', val_int)
    return struct.unpack('>f', packed)[0]

def int_to_float(i):
    """Reinterpret 32-bit integer as float."""
    packed = struct.pack('>I', i & 0xFFFFFFFF)
    return struct.unpack('>f', packed)[0]

# ==============================================================================
# Testbench
# ==============================================================================

@cocotb.test()
async def test_reset(dut):
    """Basic reset test"""
    clock = Clock(dut.clk, 20, unit="ns") # 50 MHz
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)
    
    # Check outputs are zero (or undefined, but reset should zero them)
    # Note: result_buffer reset to 0
    assert dut.uo_out.value == 0, "Reset failed on uo_out"
    assert dut.uio_out.value == 0, "Reset failed on uio_out"

@cocotb.test()
async def test_bf16_mac_simple(dut):
    """Test simple BF16 accumulation: 1.0 * 2.0 + 1.5 * 2.0"""
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.ena.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    dut.ena.value = 1
    
    # Inputs: (A=1.0, B=2.0) -> Prod=2.0
    a1, b1 = 1.0, 2.0
    a1_int = float_to_bf16(a1)
    b1_int = float_to_bf16(b1)
    
    # Send Inputs (4 cycles)
    # Cycle 0: A Low
    dut.ui_in.value = a1_int & 0xFF
    await RisingEdge(dut.clk)
    
    # Cycle 1: A High
    dut.ui_in.value = (a1_int >> 8) & 0xFF
    await RisingEdge(dut.clk)
    
    # Cycle 2: B Low
    dut.ui_in.value = b1_int & 0xFF
    await RisingEdge(dut.clk)
    
    # Cycle 3: B High -> COMPUTING TRIGGERED
    dut.ui_in.value = (b1_int >> 8) & 0xFF
    await RisingEdge(dut.clk)
    
    # Wait for result to appear. 
    # Valid latency is ~2 cycles after trigger?
    # And we read it in streaming pattern.
    # Let's verify next inputs: (A=1.5, B=2.0) -> Prod=3.0. Acc=5.0
    
    a2, b2 = 1.5, 2.0
    a2_int = float_to_bf16(a2)
    b2_int = float_to_bf16(b2)
    
    # Cycle 4 (State 0): Send A2 Low
    dut.ui_in.value = a2_int & 0xFF
    # At this point, result buffer *might* contain 2.0 from first op.
    await RisingEdge(dut.clk)
    
    # Cycle 5 (State 1): Send A2 High
    dut.ui_in.value = (a2_int >> 8) & 0xFF
    await RisingEdge(dut.clk)
    
    # Cycle 6 (State 2): Send B2 Low
    dut.ui_in.value = b2_int & 0xFF
    await RisingEdge(dut.clk)
    
    # Cycle 7 (State 3): Send B2 High -> COMPUTING TRIGGERED
    dut.ui_in.value = (b2_int >> 8) & 0xFF
    await RisingEdge(dut.clk)
    
    # Allow some cycles for pipeline to flush and result to become visible
    # We continue dummy cycles to read output
    dut.ui_in.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk)
        
    # Read Result
    # Need to synchronize with state to know when High/Low words are valid?
    # States 0,1: Low. States 2,3: High.
    # We can just read continuously and reconstruct.
    
    # Wait for State 2 (Output High) to capture full result?
    # Best way: wait until state_cnt == 0, capture Low. Wait state_cnt == 2, capture High.
    
    # Wait for stable state
    await RisingEdge(dut.clk) 
    
    raw_val_low = 0
    raw_val_high = 0
    
    # Simple polling for correct phases
    for i in range(4):
        state = int(dut.state_cnt.value)
        lo_byte = int(dut.uo_out.value)
        hi_byte = int(dut.uio_out.value)
        
        if state in [0, 1]:
            # Outputting Result[15:0]
            raw_val_low = lo_byte | (hi_byte << 8)
        else:
            # Outputting Result[31:16]
            raw_val_high = lo_byte | (hi_byte << 8)
        
        await RisingEdge(dut.clk)
        
    final_int = raw_val_low | (raw_val_high << 16)
    final_float = int_to_float(final_int)
    
    expected = (a1 * b1) + (a2 * b2) # 2.0 + 3.0 = 5.0
    
    dut._log.info(f"Got: {final_float} (0x{final_int:08x}), Expected: {expected}")
    
    # Tolerance for FP arithmetic
    assert abs(final_float - expected) < 0.1, f"Expected {expected}, got {final_float}"

@cocotb.test()
async def test_random_1000_bf16(dut):
    """1000 Random MAC operations"""
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    dut.ena.value = 1
    
    acc_expected = 0.0
    
    # Run 1000 MACs
    for i in range(1000):
        a = random.uniform(-2.0, 2.0)
        b = random.uniform(-2.0, 2.0)
        
        ai = float_to_bf16(a)
        bi = float_to_bf16(b)
        
        # Approximate expected (BF16 truncation simulation)
        # Convert back to float to simulate precision loss
        a_bf = bf16_to_float(ai)
        b_bf = bf16_to_float(bi)
        acc_expected += a_bf * b_bf
        
        # Send Data
        dut.ui_in.value = ai & 0xFF
        await RisingEdge(dut.clk)
        
        dut.ui_in.value = (ai >> 8) & 0xFF
        await RisingEdge(dut.clk)
        
        dut.ui_in.value = bi & 0xFF
        await RisingEdge(dut.clk)
        
        dut.ui_in.value = (bi >> 8) & 0xFF
        await RisingEdge(dut.clk)
        
    # Flush
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 10)
    
    # Read Result
    raw_val_low = 0
    raw_val_high = 0
    
    # Capture stable result
    for _ in range(4):
        state = int(dut.state_cnt.value)
        val = int(dut.uo_out.value) | (int(dut.uio_out.value) << 8)
        if state < 2: raw_val_low = val
        else: raw_val_high = val
        await RisingEdge(dut.clk)
        
    final_int = raw_val_low | (raw_val_high << 16)
    final_float = int_to_float(final_int)
    
    dut._log.info(f"Final Accumulator: {final_float}, Expected: {acc_expected}")
    
    # Relaxed tolerance for BF16 accumulation noise
    assert abs(final_float - acc_expected) < (abs(acc_expected) * 0.1) + 1.0, f"Mismatch: Got {final_float}, Exp {acc_expected}"
