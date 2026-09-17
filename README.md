# RTL-to-GDSII 64-bit Calculator

A memory-mapped 64-bit calculator taken through the full front-end-to-back-end VLSI flow — RTL design, functional verification, and physical design — completed as part of Silicon Jackets' Spring 2026 onboarding across all three tracks (Digital Design, Design Verification, Physical Design).

## Overview

The design performs 64-bit addition on operand pairs stored in SRAM: a controller FSM sequences memory reads, drives two 32-bit values into an adder, buffers the combined 64-bit result, and writes it back to memory. The same RTL was verified with a SystemVerilog/UVM-style testbench and carried through synthesis and place-and-route to a physical layout.

## Repo structure

```
digital_design/    RTL modules and onboarding write-up (waveform screenshots are embedded in the write-up)
verification/      Testbench, test plan, coverage report, simulation log
physical_design/   OpenLane physical design flow write-up (screenshots embedded in the write-up)
```

## Digital Design

RTL modules (`digital_design/rtl/`):

| Module | Role |
|---|---|
| `adder32.sv` | 32-bit adder |
| `full_adder.sv` | Full-adder building block used by the adder |
| `result_buffer.sv` | Buffers the assembled 64-bit result before write-back |
| `controller.sv` | FSM that sequences the whole operation |
| `top_lvl.sv` | Top-level module, ties everything to the SRAM interface |
| `calculator_pkg.sv` | Shared types/parameters |
| `tb_calculator.sv` | Standalone testbench used during RTL bring-up |
| `CF_SRAM_1024x32.tt_180V_25C.v` | Foundry SRAM macro model (1024x32) |

**Controller FSM.** Five states, defined in `controller.sv`:
- `S_IDLE` — post-reset state; de-asserts read/write and initializes address pointers, then moves to `S_READ`
- `S_READ` — asserts `read` and drives `r_addr`; entered twice per operation to fetch both 32-bit operands from the two parallel SRAMs
- `S_ADD` — performs the 32-bit addition and buffers the result
- `S_WRITE` — asserts `write`, drives `w_addr`/`w_data` with the combined 64-bit result, then loops back to `S_READ` or advances to `S_END`
- `S_END` — terminal state; holds until reset

## Verification

Testbench (`verification/tb/`): `calc_tb_top.sv`, `calc_driver.svh`, `calc_monitor.svh`, `calc_sb.svh`, `calc_seq_item.svh` — a driver/monitor/scoreboard environment run against the RTL.

Test plan (`verification/docs/`) covers:
- **Functional tests** — memory initialization, standard 64-bit addition, monitor/scoreboard sync
- **Corner cases** — zero addition, max-value overflow, mid-flight reset
- **Constrained-random testing** — 2000-iteration random address sweeps, toggle coverage sweeps with out-of-bounds addresses
- **Assertions** — async reset protocol, LSB-to-MSB sequencing, carry integrity

Simulated in Cadence Xcelium; coverage analyzed in Verdi (`verification/coverage/`, `verification/logs/simulation.log`).

## Physical Design

`physical_design/` documents the RTL-to-GDSII flow followed via the OpenLane Colab notebook (floorplanning, PDN generation, GDS streamout), the open-source flow used to illustrate what SiliconJackets' Cadence-based Physical Design track does in industry.

## Tools

SystemVerilog · Cadence Xcelium (simulation) · Verdi (coverage/debug) · OpenLane (physical design flow)
