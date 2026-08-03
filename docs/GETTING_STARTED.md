# Getting Started

## Prerequisites

-   **Python 3.8+**
-   **Icarus Verilog** (`iverilog`)
-   **cocotb** (`pip install cocotb`)

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/tmarhguy/mac.git
    cd mac
    ```

2.  **Install Python dependencies:**
    ```bash
    pip install -r requirements.txt # if available, or just cocotb
    pip install cocotb numpy pytest
    ```

## Running Simulations

To run the verification suite:

```bash
cd test
make
```

You should see output indicating passed tests:

```text
test_mac.test_reset                 PASS
test_mac.test_bf16_mac_simple       PASS
test_mac.test_random_1000_bf16      PASS
```

## Hardware Build (OpenLane)

To harden the design using OpenLane:

```bash
make harden
```

*Note: Requires OpenLane installation.*
