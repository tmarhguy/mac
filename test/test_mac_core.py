import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import struct

FP32_QNAN = 0x7FC00000
FP32_INF = 0x7F800000
FP32_NEG_INF = 0xFF800000


def bf16_raw(sign, exp, mant=0):
    return ((sign & 1) << 15) | ((exp & 0xFF) << 7) | (mant & 0x7F)


def int_to_float(i):
    packed = struct.pack(">I", i & 0xFFFFFFFF)
    return struct.unpack(">f", packed)[0]


def float_to_bf16(f):
    packed = struct.pack(">f", f)
    val_int = struct.unpack(">I", packed)[0]
    return (val_int >> 16) & 0xFFFF


async def reset_core(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.clr_acc.value = 0
    dut.en.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def mac_pulse(dut, a, b):
    """Single MAC: acc += a*b. Two cycles after en until valid."""
    dut.a.value = a
    dut.b.value = b
    dut.en.value = 1
    await RisingEdge(dut.clk)
    dut.en.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_multiply_overflow(dut):
    """Large BF16 exponents produce FP32 Inf and assert overflow."""
    await reset_core(dut)

    a = bf16_raw(0, 200)
    b = bf16_raw(0, 200)
    await mac_pulse(dut, a, b)

    assert int(dut.overflow.value) == 1, "multiply overflow flag expected"
    assert int(dut.result.value) == FP32_INF, (
        f"expected +Inf, got 0x{int(dut.result.value):08x}"
    )


@cocotb.test()
async def test_nan_propagation(dut):
    """BF16 NaN operand produces FP32 quiet NaN in accumulator."""
    await reset_core(dut)

    nan_bf16 = bf16_raw(0, 0xFF, 0x40)
    await mac_pulse(dut, nan_bf16, bf16_raw(0, 127))

    result = int(dut.result.value)
    assert (result & 0x7F800000) == 0x7F800000 and (result & 0x007FFFFF) != 0, (
        f"expected NaN, got 0x{result:08x}"
    )
    assert int(dut.overflow.value) == 0, "NaN should not set overflow"


@cocotb.test()
async def test_inf_times_zero(dut):
    """Inf * 0 is NaN (IEEE invalid operation)."""
    await reset_core(dut)

    await mac_pulse(dut, bf16_raw(0, 0xFF, 0), 0)

    result = int(dut.result.value)
    assert (result & 0x7F800000) == 0x7F800000 and (result & 0x007FFFFF) != 0, (
        f"expected NaN, got 0x{result:08x}"
    )


@cocotb.test()
async def test_inf_plus_neg_inf(dut):
    """+Inf accumulated with -Inf yields NaN."""
    await reset_core(dut)

    await mac_pulse(dut, bf16_raw(0, 0xFF, 0), bf16_raw(0, 127, 0))
    assert int(dut.result.value) == FP32_INF

    await mac_pulse(dut, bf16_raw(1, 0xFF, 0), bf16_raw(0, 127, 0))
    result = int(dut.result.value)
    assert (result & 0x7F800000) == 0x7F800000 and (result & 0x007FFFFF) != 0, (
        f"expected NaN after Inf + -Inf, got 0x{result:08x}"
    )


@cocotb.test()
async def test_accumulate_overflow(dut):
    """Repeated large products overflow accumulator and stick overflow flag."""
    await reset_core(dut)

    huge = bf16_raw(0, 250, 0x7F)
    await mac_pulse(dut, huge, huge)
    first = int(dut.result.value)
    dut._log.info(f"after first MAC: 0x{first:08x} ovf={int(dut.overflow.value)}")

    await mac_pulse(dut, huge, huge)
    assert int(dut.overflow.value) == 1, "accumulate overflow flag expected"
    assert int(dut.result.value) == FP32_INF, (
        f"expected +Inf after accumulate overflow, got 0x{int(dut.result.value):08x}"
    )


@cocotb.test()
async def test_overflow_clear_on_clr_acc(dut):
    """clr_acc clears sticky overflow and accumulator."""
    await reset_core(dut)

    await mac_pulse(dut, bf16_raw(0, 200), bf16_raw(0, 200))
    assert int(dut.overflow.value) == 1

    dut.clr_acc.value = 1
    await RisingEdge(dut.clk)
    dut.clr_acc.value = 0
    await RisingEdge(dut.clk)

    assert int(dut.overflow.value) == 0
    assert int(dut.result.value) == 0


@cocotb.test()
async def test_sign_accumulation(dut):
    """Mixed-sign accumulation: (+2) + (-3) = -1."""
    await reset_core(dut)

    await mac_pulse(dut, float_to_bf16(2.0), float_to_bf16(1.0))
    await mac_pulse(dut, float_to_bf16(-3.0), float_to_bf16(1.0))

    result = int_to_float(int(dut.result.value))
    assert abs(result - (-1.0)) < 0.01, f"expected -1.0, got {result}"
