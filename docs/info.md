# BF16 MAC Unit

16-bit BFloat16 multiply–accumulate with an IEEE-754 FP32 accumulator, built for ML inference on Tiny Tapeout.

## How it works

The design streams two BF16 operands over the 8-bit `ui_in` bus across four clock cycles:

| Cycle | `ui_in` | Meaning |
| :--- | :--- | :--- |
| 0 | `A[7:0]` | Operand A low byte |
| 1 | `A[15:8]` | Operand A high byte |
| 2 | `B[7:0]` | Operand B low byte |
| 3 | `B[15:8]` | Operand B high byte (triggers MAC) |

The core is a 2-stage pipeline: BF16 multiply, then FP32 accumulate (`acc += A × B`). The 32-bit accumulator is multiplexed on `uo_out` and `uio_out`:

| `state_cnt[1]` | Bus | Bits |
| :--- | :--- | :--- |
| 0 | `uo_out`, `uio_out` | `result[15:0]` |
| 1 | `uo_out`, `uio_out` | `result[31:16]` |

Set `ena` high during normal operation. Assert `rst_n` low to reset registers and the accumulator.

## How to test

1. Assert `rst_n` low for several cycles, then release.
2. Set `ena` high.
3. Stream four bytes per MAC: A low, A high, B low, B high.
4. Read `uo_out` / `uio_out` while the 4-cycle counter runs; reconstruct the 32-bit FP32 result from the low and high 16-bit phases.

Run the cocotb suite from the `test/` directory:

```bash
cd test && make
```

Tests cover reset, a chained `1.0×2.0 + 1.5×2.0` case, and 1,000 random BF16 MAC operations against a Python golden model.

## External hardware

None required. The streaming interface uses only the dedicated Tiny Tapeout IO pins.
