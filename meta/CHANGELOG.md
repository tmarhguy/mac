# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-01-15

### Added
-   Initial RTL implementation of 16-bit BF16 MAC Unit (`src/mac_core.sv`).
-   TinyTapeout Wrapper (`src/tt_um_tmarhguy_mac.v`).
-   Cocotb testbench with random regression (`test/test_mac.py`).
-   Build system (`Makefile`, `config.tcl`).
-   Documentation suite (`docs/`, `meta/`, `README.md`).

### Changed
-   Renamed top-level module from `tt_um_tmarhguy_mac` to `tt_um_tensor_mac` for clearer branding.
