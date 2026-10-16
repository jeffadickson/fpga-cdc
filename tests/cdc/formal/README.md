# Yosys formal mailbox example

Run from a checkout with Python 3 and Yosys available:

```sh
python3 tests/cdc/formal/run.py
# Select a different installed executable if necessary:
YOSYS=/path/to/yosys python3 tests/cdc/formal/run.py
```

No third-party Python packages, SymbiYosys or external SMT solver are required.
The runner uses Yosys's SAT engine and `clk2fflogic` for the multiple clocks.
The recorded run used Yosys 0.33 (git sha1 2584903a060).

## Expanded suite — version 2

```sh
# One configurable instance (defaults: request 4, response 3, two stages)
python3 tests/cdc/formal/run.py
# Three independent parameter configurations; evidence kept in separate folders
python3 tests/cdc/formal/run.py --matrix --timeout 300 --out build/cdc-mailbox-formal-expanded
```

| Configuration | Request bits | Response bits | Synchronizer stages |
| --- | --- | --- | --- |
| req1-rsp1-sync2 | 1 | 1 | 2 |
| req4-rsp3-sync2 | 4 | 3 | 2 |
| req32-rsp16-sync3 | 32 | 16 | 3 |

Each configuration runs ten checks. The matrix command above uses a 300-second
per-target solver budget: the wide safety case exceeded the initial 120-second
budget in this environment. A timeout is inconclusive, not a counterexample.
The safety bound is unchanged when extending the solver time budget.

| Check | What it establishes | Default bound |
| --- | --- | --- |
| Safety | No counterexample to all assertions under the stated assumptions | 40 global steps |
| Two round trips with stalls | Both destination and response backpressure occur, followed by completion | 112 global steps |
| Reset in transit | Abort before destination presentation, then complete a new transfer | 112 global steps |
| Reset at destination | Abort while destination is stalled, then complete a new transfer | 112 global steps |
| Reset at response | Abort a held response after commit, then complete a new transfer | 112 global steps |
| Four round trips | Reuse both toggle values repeatedly without a reset in that accounting epoch | 112 global steps |
| Corrupt request | Reject inverted request capture | 40 global steps |
| Corrupt response | Reject inverted response capture | 40 global steps |
| Early acknowledgment | Reject acknowledgment at presentation rather than destination commit | 40 global steps |
| Drop stalled response | Reject clearing response valid before the consumer is ready | 40 global steps |

The cover bound increased to allow four round trips through the three-stage
configuration. A cover is an existential witness; it does not prove that every
allowed execution progresses or restarts successfully. Safety covers all allowed
executions only up to its own bound, not automatically up to the longer cover bound.

All 30 logical checks passed. The wide safety check needed a retry with a
300-second budget; its original 120-second timeout remains in the raw results.
The retry retained the same 40-step bound, RTL and properties.
Recorded expanded results and effective results summary are in evidence/expanded/. The earlier three-check
40/80-step result remains in evidence/ as a historical checkpoint imported from the earlier implementation; its source hashes intentionally differ from the expanded properties.
Each result records its exact parameters, source hashes and Yosys version.
The trace archives include full solver logs, generated scripts and witness VCDs.
Waveforms expose interface ports, transaction counters, toggles, held data and
reset-abort history to make failures easier to inspect.

Yosys prints `FAIL!` when a model disproves the proposition submitted to
`-prove`; this is EXPECTED for a cover (its signal is not always zero) and for a
deliberately faulty implementation. The runner requires a successful tool exit
and the exact expected result marker. A parse error or timeout is never counted
as a passing mutation test. Matrix mode returns failure if any configuration fails.

A global step is one step of the lowered multi-clock model, NOT one source or
destination clock cycle. Both clock inputs may change independently, coincide,
or stop. No fixed clock ratio, phase relationship or fairness is assumed.
The reachability witness shows that progress is possible, not that every allowed
clock/backpressure sequence eventually progresses.

## Properties and assumptions

An independent scoreboard counts source acceptances, destination commits and
source response consumptions. It checks that only one transaction is outstanding,
that destination and response presentations correspond to pending transactions,
and that neither commits nor responses appear out of order or duplicate an
operation within the checked bound. This does not establish eventual delivery
when a clock can stop or a consumer can hold ready low forever. Captured symbolic request and response values must remain intact.
The request toggle must equal the parity of source acceptances, and the
acknowledgment toggle must equal the parity of destination commits. Clock-edge
checks require each toggle to change only for its corresponding handshake.
Busy and response-valid cannot overlap, and both held buses must agree with
the independent captured reference values.

Request and response outputs must hold their valid flags and data while stalled;
the source-held bundled payload must remain stable while busy.

The environment starts with the common reset asserted. It may reassert that
reset later, aborting outstanding transport and restarting the scoreboard epoch.
The sender must hold src_valid/src_data while its request is stalled, except
across reset. Payload values, destination response values and ready signals are
otherwise unconstrained. Destination response data is sampled only at commit;
there is no assumption that it stays stable before commit.

Reset abort does not undo an external side effect, and these properties do not
model downstream peripherals. Independent domain resets are outside the module's
contract. See rtl/common/README.md for reset ambiguity and recovery requirements.

## How the example is constructed

The runner reads the production cdc_mailbox.sv and injects properties.svh into a
build-only copy. The hardware source is not edited. It then creates four separate
mutants targeting request data, response data, acknowledgment timing and response
backpressure. These mutants are never hardware sources. Generated .ys
scripts, instrumented sources, logs, results and witness VCDs go under
build/cdc-mailbox-formal/ (or --out). Matrix configurations use distinct
subdirectories. Old VCDs are removed before each target runs.

Parameters and bounds can be selected with --req-width, --rsp-width, --stages,
--depth, --cover-depth and --timeout. A different configuration needs a fresh
successful run; the recorded result does not prove all parameter combinations.
The cover bound must be large enough to accommodate reset release, four complete
round trips in the slowest configured handshake and the reset/stall scenarios.

These are bounded digital checks. They are not an inductive/unbounded proof,
a liveness proof, a four-state simulation, an MTBF analysis, or Vivado timing/CDC
sign-off. Bundled-data propagation constraints and synchronizer placement still
require physical implementation validation.
