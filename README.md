# FPGA CDC examples

Reusable clock-domain crossing examples with simulation, formal checks and
integration guidance. The first example is a single-outstanding request/response
mailbox; additional examples can be added alongside it.

## Mailbox

- [Interface, reset and physical constraints](rtl/common/README.md) ([HTML](rtl/common/README.html))
- [Yosys formal guide](tests/cdc/formal/README.md) ([HTML](tests/cdc/formal/README.html))
- [Recorded formal results](tests/cdc/formal/evidence/expanded/summary.json)
- [Evidence provenance](EVIDENCE.md)

From the repository root:

```sh
python3 tests/cdc/run.py
python3 tests/cdc/formal/run.py --matrix --timeout 300
```

Simulation requires Python 3, Verilator 5.x, a C++ compiler and GNU Make.
Formal requires Python 3 and Yosys (recorded with 0.33); no Python packages,
SymbiYosys or external SMT solver are needed. Set YOSYS to select an executable.
Generated outputs stay under build/. Slow machines may need a larger timeout.

The mailbox RTL and Xilinx constraint helper live in rtl/common/. Simulation is
in tests/cdc/; formal properties, runner and recorded evidence are in
 tests/cdc/formal/. Widths and synchronizer depth are parameterized.

The imported evidence records 243 completed simulation transfers and 30 passing
bounded formal checks, including the documented wide-case timeout and retry.
It is not a new run after relocation, an unbounded proof, or physical CDC sign-off.
The constraint helper still needs validation in Vivado for the integrating design.

Regenerate the standalone HTML guides with:

```sh
python3 tools/render_reference.py rtl/common/README.md tests/cdc/formal/README.md
```

Source files marked SPDX-License-Identifier: MIT retain that license.
