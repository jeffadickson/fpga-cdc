# Generic CDC request/response mailbox — 1.1

`cdc_mailbox.sv` is an MIT-licensed, single-outstanding, bundled-data mailbox
between unrelated clock domains. It is independent of any bus protocol or FPGA board. Request and response widths are independently parameterized. It is
intended for control/status transfers, not continuous sample streams.

## Interface contract

| Interface | Domain | Meaning |
| --- | --- | --- |
| src_valid, src_ready, src_data | src_clk | Request accepted on valid AND ready; sender holds valid/data while stalled |
| src_rsp_valid, src_rsp_ready, src_rsp_data | src_clk | Response consumed on valid AND ready; mailbox holds valid/data while stalled |
| dst_valid, dst_ready, dst_data | dst_clk | Request committed on valid AND ready; mailbox holds valid/data while stalled |
| dst_rsp_data | dst_clk | Result captured on that same destination commit edge |
| reset | Both | Common asynchronous assertion, locally synchronized deassertion; aborts in-flight transport |

`REQ_WIDTH` and `RSP_WIDTH` default to 32; both must be positive.
`SYNC_STAGES` defaults to two and must be at least two. Additional stages increase
synchronization latency. All four synchronizer chains (request, acknowledgment,
and two reset-release chains) carry ASYNC_REG=TRUE and SHREG_EXTRACT=NO.

There is no second request acceptance until the previous response is consumed.
The interface intentionally includes a cycle between response consumption and
next request acceptance. No queue, timeout, automatic retry or cancellation is
provided. If a destination never commits or a source never consumes its response,
the mailbox stays occupied. A stopped clock preserves state but stops progress.

For an operation taking several destination cycles, keep dst_ready LOW until
its result is available. Track locally whether processing has started so that
holding dst_valid does not repeat the operation. Present dst_rsp_data before the
commit edge. For a one-way update, use RSP_WIDTH=1, tie dst_rsp_data to zero and
src_rsp_ready high; the response handshake then reports completion.

## How the crossing works

At source acceptance, src_payload captures the entire request and req_toggle
changes. The request toggle crosses a synchronizer; the destination then captures
the stable bus into dst_data and asserts dst_valid. On the destination commit
edge, dst_response captures the result and ack_toggle changes. That acknowledgment
crosses back; the source captures the stable response bus and asserts
src_rsp_valid. The source payload cannot change during that round trip.
The destination response cannot be overwritten until a later request commits.

The data bits are NOT individually synchronized. Coherence relies on holding
these bundled buses stable and constraining their propagation to fit inside the
control synchronization latency. RTL simulation does not model metastability.

## Reset and side effects

Connect the same reset assertion to both domains. Each domain synchronizes its
own reset release. Do not independently reset one side: toggle histories would
be lost and could create a phantom request or lose a completion. Reset discards
pending transport state and both visible valid flags after reset propagation.

Reset cannot undo a destination side effect that already committed. If reset
occurs after that side effect but before the source sees its response, software
must treat completion as unknown. Recovery must reconcile device state; blindly
retrying a non-idempotent command may execute it twice. Reset downstream operation
state coherently with this mailbox when the application requires it.

## Physical constraints

Source `cdc_mailbox_constraints.tcl` after synthesis and invoke it for each
retained hierarchy instance with the FASTEST supported source/destination clock
periods in nanoseconds. For example, for a 100 MHz source and 50 MHz destination:

```tcl
source rtl/common/cdc_mailbox_constraints.tcl
constrain_cdc_mailbox design/control_mailbox 10.0 20.0
```

Replace the instance path with the actual synthesized hierarchy. The helper
fails if expected register groups or first-stage synchronizers cannot be found.
It false-paths only the two toggle crossings into their first synchronizer
stages. It applies maximum datapath delay and bus-skew constraints to request
and response payload buses, using one receiving-clock period as the budget.
Interstage synchronizer paths retain normal receiving-clock timing.

Do not apply blanket asynchronous clock groups or broader false paths that
supersede those maximum-delay constraints. Board integration must also define
clocks and address the common reset tree and its recovery/removal requirements.
Inspect report_cdc, timing, exception coverage and synchronizer placement after
implementation. ASYNC_REG guides placement; it is not a guarantee of a measured
MTBF or of timing closure. The Tcl helper has not been run in Vivado here.

## Verification and integration status

```sh
python3 tests/cdc/run.py
```

The self-checking Verilator test covers source-fast, destination-fast and
coincident clock edges; request widths 1/32/65; response widths 1/16/37;
two/three synchronizer stages; request/response stalls; payload mutation after
source acceptance; exactly-once delivery and return; reset of an uncommitted
request; and restart. A watchdog fails hangs. The test is deterministic RTL
simulation. A separate Yosys formal example is in tests/cdc/formal/README.md:
run `python3 tests/cdc/formal/run.py --matrix` for three configurations covering
1/1-bit, 4/3-bit and 32/16-bit request/response widths and two/three synchronizer
stages. The expanded suite checks bounded safety, round-trip/stall witnesses,
reset-abort/restart at three phases, repeated toggle reuse, and four deliberate
faults. See the formal guide for exact bounds, results and assumptions. These
results are not an unbounded proof or physical CDC sign-off.

When integrating with another interface, distinguish request acceptance from
command completion. Source ready means REQUEST ACCEPTANCE; completion arrives
through the response handshake. Preserve the surrounding reset and side-effect
semantics when connecting a peripheral or software-visible bus.
