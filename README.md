# UART Basic Verification Environment

This project implements a SystemVerilog class-based verification environment for a basic UART design. The RTL includes parameterized transmitter and receiver modules with configurable clock frequency and baud rate.

The verification environment is structured using transactions, generator, driver, monitor, scoreboard, and environment components. Mailboxes and events are used for synchronization and communication between verification blocks.

The testbench applies randomized and directed stimulus to verify UART transmit and receive functionality and performs end-to-end data checking to ensure functional correctness.
## Repository Structure

- `rtl/` – UART transmitter, receiver, and top-level RTL implementation
- `tb/`  – SystemVerilog class-based verification environment
  - Transaction, generator, driver, monitor, scoreboard, and environment
