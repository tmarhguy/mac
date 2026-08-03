# Architecture

This document details the internal architecture of the **16-Bit BFloat16 (BF16) MAC Unit**, designed for ML acceleration constrained environments like TinyTapeout.

## High-Level Overview

The MAC unit performs a **Multiply-Accumulate** operation: $Result = Result + (A \times B)$.
It is designed with a **2-stage pipeline** to maximize throughput and achieve timing closure at 50 MHz on the SkyWater 130nm process.

### Data Types

- **Inputs (A, B):** **BFloat16 (BF16)**
  - 1 Sign bit
  - 8 Exponent bits
  - 7 Mantissa bits
  - *Dynamic Range:* ~1e-38 to ~3e38 (same as FP32)
  - *Precision:* Lower than FP16, but sufficient for Deep Learning training/inference.

- **Accumulator (Result):** **FP32 (IEEE 754 Single Precision)**
  - 1 Sign bit
  - 8 Exponent bits
  - 23 Mantissa bits
  - *Purpose:* Prevents overflow and precision loss during extended accumulation loops.

## Pipeline Stages

```mermaid
graph TD
    subgraph Stage 1: Multiplication
        A[Operand A (BF16)] --> M[Multiplier]
        B[Operand B (BF16)] --> M
        M --> P[Product Register (FP32)]
    end
    
    subgraph Stage 2: Accumulation
        P --> Add[Floating Point Adder]
        Acc[Accumulator Register] --> Add
        Add --> Acc
    end
    
    subgraph Interface
        Stream[8-bit Input Stream] --> Buffer[Input Buffers]
        Buffer --> A
        Buffer --> B
        Acc --> Mux[Output Multiplexer]
    end
```

### Stage 1: BF16 Multiplication
1.  **Sign Calculation:** XOR of input signs.
2.  **Exponent Addition:** $Exp_A + Exp_B - Bias$ (127).
3.  **Mantissa Multiplication:** $1.M_A \times 1.M_B$ (Implicit leading 1).
    - Checks for denormals (flush-to-zero).
    - Normalizes result if needed.
4.  **Output:** 32-bit Product (promoted to FP32 format).

### Stage 2: FP32 Accumulation
1.  **Alignment:** Aligns the smaller number's mantissa to match the larger exponent.
2.  **Addition/Subtraction:** Adds or subtracts mantissas based on sign.
3.  **Normalization:** Shifts result to restore implicit leading 1.
    - Handles status flags (Overflow, Underflow).
    - updates the internal 32-bit Accumulator register.

## Input/Output Interface (TinyTapeout Compatible)

Due to the limited I/O pins (8 inputs, 8 outputs) on the TinyTapeout template, a **4-cycle streaming protocol** is used.

### Input Protocol (`ui_in`)
| Cycle | Bits [7:0] | Description |
| :--- | :--- | :--- |
| 0 | `A[7:0]` | Lower byte of Operand A |
| 1 | `A[15:8]` | Upper byte of Operand A |
| 2 | `B[7:0]` | Lower byte of Operand B |
| 3 | `B[15:8]` | Upper byte of Operand B (Triggers Compute) |

### Output Protocol (`uo_out`, `uio_out`)
The 32-bit result is time-multiplexed over 2 phases:

| Phase | `uo_out` | `uio_out` | Description |
| :--- | :--- | :--- | :--- |
| 0 | `Res[7:0]` | `Res[15:8]` | Lower 16 bits of Accumulator |
| 1 | `Res[23:16]` | `Res[31:24]` | Upper 16 bits of Accumulator |

## Design Considerations

-   **Area:** Optimized for `< 0.12 mm²` to fit within a single TinyTapeout tile.
-   **Timing:** 2-stage pipeline ensures valid paths for **50 MHz** operation.
-   **Power:** Uses localized clock gating (implicit via enable signals) to reduce dynamic power.
