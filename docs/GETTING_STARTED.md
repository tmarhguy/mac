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

## Hardware Build (GDS / LibreLane)

Tiny Tapeout 07 builds GDS in CI via the `gds` GitHub Action (`TinyTapeout/tt-gds-action@tt07`). Push to GitHub and confirm the **gds** workflow is green before shuttle submission.

### Local hardening

1. Install [LibreLane](https://librelane.readthedocs.io/) and set `PDK_ROOT`, `PDK=sky130A`, and `LIBRELANE_TAG=3.0.3` (see [Tiny Tapeout local hardening guide](https://tinytapeout.com/guides/local-hardening/)).
2. Clone support tools and run:

```bash
make librelane
```

Local hardening uses the LibreLane configs under `librelane/` (see [LIBRELANE.md](LIBRELANE.md)). For Tiny Tapeout shuttle builds, CI runs the `gds` workflow. Do not edit `src/config.tcl` below the “DO NOT CHANGE” line unless you know what you are doing.
