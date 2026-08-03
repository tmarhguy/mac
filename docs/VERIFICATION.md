# Verification Strategy

Verification of the MAC unit is performed using **cocotb** (Coroutine Cosimulation Testbench), a Python-based verification framework that allows for rapid development of complex test scenarios.

## Methodology

The verification strategy focuses on comparing the RTL implementation against a **Golden Model** written in Python (using standard floating-point arithmetic).

### Test Levels

1.  **Reset Test:**
    -   Verifies that the core correctly initializes all registers to zero upon assertion of `rst_n`.
    -   Checks that output buffers are cleared.

2.  **Corner Case Testing:**
    -   **Zero inputs:** $0 \times N = 0$.
    -   **Identity:** $1 \times N = N$.
    -   **Sign flipping:** Checking correct sign handling in multiplication.

3.  **Randomized Regression (1,000 Vectors):**
    -   Generates random floating-point numbers in the range $[-2.0, 2.0]$.
    -   Converts them to BF16 format (software emulation).
    -   Drives the RTL simulation via the pseudo-SPI streaming interface.
    -   Simulates the expected result in Python using truncation to match BF16 precision behavior.
    -   Compares the RTL output against the Python model with a relaxed tolerance (due to BF16 precision loss).

## Tools

| Tool | Purpose |
| :--- | :--- |
| **Icarus Verilog** | Verilog Simulator (Event-driven) |
| **cocotb** | Python Testbench Framework |
| **pytest** | Test runner and reporting |
| **NumPy** | Numerical reference generation |

## Running Tests

Tests are executed via `make` in the `test/` directory.

```bash
# Run all tests
cd test
make
```

### Expected Output
```text
test_mac.test_reset                 PASS
test_mac.test_bf16_mac_simple       PASS
test_mac.test_random_1000_bf16      PASS
```

## Coverage Goal
The current suite targets **100% Functional Coverage** of the pipeline control logic and meaningful arithmetic coverage for standard ML workload ranges.
