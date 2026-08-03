# System Specifications

This document outlines the technical specifications for the 16-bit MAC Unit.

## General
-   **Process:** SkyWater 130nm (Open Source PDK)
-   **Frequency:** 50 MHz (Period: 20ns)
-   **Voltage:** 1.8V (Core)
-   **Area:** Estimated ~0.10 - 0.12 mm²
-   **Standard Cell Library:** `sky130_fd_sc_hd` (High Density)

## Numerical Formats

### Input: BFloat16 (Brain Floating Point)
Standard BFloat16 format, truncated from IEEE 754 FP32.

| Bit | Field | Description |
| :--- | :--- | :--- |
| 15 | Sign | 0=Positive, 1=Negative |
| 14:7 | Exponent | 8-bit, Bias 127 |
| 6:0 | Mantissa | 7-bit explicit (1 implied) |

### Accumulator: IEEE 754 Single Precision (FP32)
Standard 32-bit floating point for high-precision accumulation.

| Bit | Field | Description |
| :--- | :--- | :--- |
| 31 | Sign | 0=Positive, 1=Negative |
| 30:23 | Exponent | 8-bit, Bias 127 |
| 22:0 | Mantissa | 23-bit explicit (1 implied) |

## Performance Metrics

| Metric | Value | Notes |
| :--- | :--- | :--- |
| **Throughput** | 1 MAC / 4 Cycles | Limited by I/O streaming bandwidth (not core logic) |
| **Latency** | 2 Cycles | Core pipeline latency |
| **Dynamic Power** | ~10-20 mW | Estimated @ 50 MHz (Simulation) |
| **Static Power** | < 1 mW | Leakage (Sky130 HD) |

## Interface

| Port | Width | Direction | Description |
| :--- | :--- | :--- | :--- |
| `clk` | 1 | Input | System Clock (50 MHz) |
| `rst_n` | 1 | Input | Active-Low Asynchronous Reset |
| `ena` | 1 | Input | Chip Enable |
| `ui_in` | 8 | Input | Data Input Bus (Streaming A, B) |
| `uo_out` | 8 | Output | Data Output Bus (Result Low) |
| `uio_out` | 8 | Output | Data Output Bus (Result High/Secondary) |
| `uio_in` | 8 | Input | Unused |
| `uio_oe` | 8 | Output | Output Enable (Always 0xFF in this design) |
