# Contributing to 16-Bit MAC Unit

We welcome contributions! Please verify that your changes pass all tests before submitting a Pull Request.

## Workflow

1.  **Fork** the repository.
2.  **Create a branch** for your feature (`git checkout -b feature/amazing-feature`).
3.  **Commit** your changes (`git commit -m 'Add some amazing feature'`).
4.  **Push** to the branch (`git push origin feature/amazing-feature`).
5.  **Open a Pull Request**.

## Requirements

-   **Tests:** Use `cocotb` for all Verification. New features must include unit tests.
-   **Linting:** Ensure Verilog code is lint-clean (use `verilator --lint-only` if available).
-   **Documentation:** Update relevant docs in `docs/` if architecture or specs change.

## License
By contributing, you agree that your contributions will be licensed under the MIT License.
