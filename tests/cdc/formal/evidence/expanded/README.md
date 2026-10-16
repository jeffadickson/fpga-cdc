# Expanded formal results

All 30 logical checks passed across req1/rsp1/stages2, req4/rsp3/stages2 and
req32/rsp16/stages3. Safety bound: 40 global steps. Cover bound: 112 steps.
Source RTL is unchanged. The properties include arbitrary common-reset
reassertions and unconstrained independent clocks, subject to sender handshake
rules. No fairness or eventual-completion claim is made.

The raw wide results.json records the initial safety timeout at 120 seconds;
that file is deliberately preserved, not relabeled as a proof success. Only
that safety target was retried using safety-retry.ys with a 300-second solver
budget, the SAME 40-step bound, RTL and properties. It passed with exit 0 and
Yosys's no-model SUCCESS marker (270.65 user CPU seconds). summary.json combines
the passing retry with the other 29 passing checks and records that history.

Each configuration directory has its raw results and traces.tar.gz containing
full solver logs, generated scripts, build-only checked/mutant RTL and witness
VCDs. The wide archive includes BOTH safety attempts. No VCD is expected for a
successful safety proof without a counterexample. Relative to the repository,
run `python3 tests/cdc/formal/run.py --matrix --timeout 300` to repeat the matrix;
slow machines may need a larger solver time limit without changing the bounds.
