// SPDX-License-Identifier: MIT
// Injected into the real mailbox for formal builds only.
// Arbitrary independent binary clocks: no frequency/phase/fairness assumption.
always @($global_clock) if ($initstate) assume(reset);
reg f_src_live=0, f_dst_live=0;
reg [3:0] f_sent, f_committed, f_returned;
reg [REQ_WIDTH-1:0] f_request;
reg [RSP_WIDTH-1:0] f_response;
reg f_dst_stall, f_rsp_stall;
wire [3:0] f_pending = f_sent - f_returned;
wire [3:0] f_to_commit = f_sent - f_committed;
wire [3:0] f_to_return = f_committed - f_returned;
(* keep *) wire f_cover = f_src_live && f_dst_live && !reset &&
    !src_reset && !dst_reset && f_returned == 2 && f_pending == 0 &&
    f_dst_stall && f_rsp_stall;

always @(posedge src_clk or posedge src_reset) begin
    if(src_reset) begin
        f_src_live<=0;f_sent<=0;f_returned<=0;f_request<=0;f_rsp_stall<=0;
    end else begin
        f_src_live<=1;
        if(src_valid && src_ready) begin f_sent<=f_sent+1'b1; f_request<=src_data; end
        if(src_rsp_valid && src_rsp_ready) f_returned<=f_returned+1'b1;
        if(src_rsp_valid && !src_rsp_ready) f_rsp_stall<=1;
    end
end
always @(posedge dst_clk or posedge dst_reset) begin
    if(dst_reset) begin f_dst_live<=0;f_committed<=0;f_response<=0;f_dst_stall<=0; end
    else begin
        f_dst_live<=1;
        if(dst_valid && dst_ready) begin
            f_committed<=f_committed+1'b1; f_response<=dst_rsp_data;
        end
        if(dst_valid && !dst_ready) f_dst_stall<=1;
    end
end
// Modulo counters independently track protocol events. The occupancy bounds
// rule out duplication/reordering; arbitrary data checks rule out torn payloads.
always @* if(f_src_live && f_dst_live && !reset && !src_reset && !dst_reset) begin
    assert(f_pending <= 1);
    assert(f_to_commit <= 1);
    assert(f_to_return <= 1);
    if(dst_valid) begin assert(f_to_commit == 1); assert(dst_data == f_request); end
    if(src_rsp_valid) begin assert(f_to_return == 1); assert(src_rsp_data == f_response); end
    if(src_ready) assert(f_pending == 0);
end
always @(posedge src_clk) begin
    if(f_src_live && !src_reset && !$past(src_reset) && !reset && !$past(reset)) begin
        // Environment contract: a stalled sender must hold its request.
        if($past(src_valid && !src_ready)) begin
            assume(src_valid); assume(src_data == $past(src_data));
        end
        if($past(src_rsp_valid && !src_rsp_ready)) begin
            assert(src_rsp_valid); assert(src_rsp_data == $past(src_rsp_data));
        end
        if($past(busy) && busy) assert(src_payload == $past(src_payload));
    end
end
always @(posedge dst_clk) begin
    if(f_dst_live && !dst_reset && !$past(dst_reset) && !reset && !$past(reset)) begin
        if($past(dst_valid && !dst_ready)) begin
            assert(dst_valid); assert(dst_data == $past(dst_data));
        end
    end
end

// Tie protocol state to independently counted handshakes, not merely occupancy.
always @* if(f_src_live && f_dst_live && !reset && !src_reset && !dst_reset) begin
    assert(req_toggle == f_sent[0]);
    assert(ack_toggle == f_committed[0]);
    assert(!(busy && src_rsp_valid));
    if(busy || src_rsp_valid) assert(src_payload == f_request);
    assert(dst_response == f_response);
end
always @(posedge src_clk)
    if(f_src_live && !src_reset && !$past(src_reset) && !reset && !$past(reset))
        assert(req_toggle == ($past(req_toggle) ^ $past(src_valid && src_ready)));
always @(posedge dst_clk)
    if(f_dst_live && !dst_reset && !$past(dst_reset) && !reset && !$past(reset))
        assert(ack_toggle == ($past(ack_toggle) ^ $past(dst_valid && dst_ready)));

// History survives common reset only in the formal observer. Each cover needs
// an actual reset of a specified in-flight phase, then a new completed transfer.
reg f_abort_transit=0, f_abort_dst=0, f_abort_response=0;
always @($global_clock) if(!$initstate && reset && !$past(reset)) begin
    if($past(f_src_live && f_dst_live && !src_reset && !dst_reset)) begin
        if($past(f_pending==1 && f_to_commit==1 && !dst_valid)) f_abort_transit<=1;
        if($past(dst_valid && !dst_ready)) f_abort_dst<=1;
        if($past(src_rsp_valid && !src_rsp_ready)) f_abort_response<=1;
    end
end
wire f_restarted = f_src_live && f_dst_live && !reset && !src_reset &&
    !dst_reset && f_returned==1 && f_pending==0;
(* keep *) wire f_cover_reset_transit = f_abort_transit && f_restarted;
(* keep *) wire f_cover_reset_destination = f_abort_dst && f_restarted;
(* keep *) wire f_cover_reset_response = f_abort_response && f_restarted;
// Exercise toggle reuse with more than one round trip, without requiring reset.
(* keep *) wire f_cover_four = f_src_live && f_dst_live && !reset &&
    !src_reset && !dst_reset && f_returned==4 && f_pending==0;
