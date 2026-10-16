// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module mailbox_case #(parameter S=5, D=7, W=32, R=16, N=2)(output reg done=0);
    reg src_clk=0,dst_clk=0,reset=1;
    always #(S) src_clk=~src_clk;
    always #(D) dst_clk=~dst_clk;
    reg sv=0,rr=0,dr=0;
    wire sr,rv,dv;
    reg [W-1:0] sd=0;
    wire [W-1:0] dd;
    wire [R-1:0] rd;
    wire [R-1:0] response=R'(dd)^R'('h5a39);
    cdc_mailbox #(.REQ_WIDTH(W),.RSP_WIDTH(R),.SYNC_STAGES(N)) dut(
        .src_clk(src_clk),.dst_clk(dst_clk),.reset(reset),
        .src_valid(sv),.src_ready(sr),.src_data(sd),
        .src_rsp_valid(rv),.src_rsp_ready(rr),.src_rsp_data(rd),
        .dst_valid(dv),.dst_ready(dr),.dst_data(dd),.dst_rsp_data(response));
    integer accepted=0,committed=0,returned=0;
    reg [W-1:0] expected;
    always @(posedge src_clk) if(!reset) begin
        if(sv&&sr) begin accepted=accepted+1; expected=sd; end
        if(rv&&rr) begin
            if(rd !== (R'(expected)^R'('h5a39))) $fatal(1,"Response mismatch");
            returned=returned+1;
            if(returned>committed) $fatal(1,"Response before commit");
        end
    end
    always @(posedge dst_clk) if(!reset && dv&&dr) begin
        if(dd !== expected) $fatal(1,"Torn or wrong request");
        committed=committed+1;
        if(committed>accepted) $fatal(1,"Duplicate/spurious commit");
    end
    task send(input integer value);
        @(negedge src_clk); sd=(W'(value) ^ (W'(value) << (W/2)) ^ {W{value[0]}});sv=1;
        do @(posedge src_clk); while(!sr);
        @(negedge src_clk); sv=0;sd=~sd;
    endtask
    initial begin
        #23; reset=0;
        for(integer i=0;i<80;i=i+1) begin
            send(i*7919+1);
            wait(dv);
            // Hold destination request; unrelated source data must not leak.
            repeat(3) begin
                @(negedge dst_clk);
                if(!dv || dd!==expected) $fatal(1,"Request changed under stall");
            end
            dr=1;@(negedge dst_clk);dr=0;
            wait(rv);
            repeat(4) begin
                @(negedge src_clk);
                if(!rv || sr || rd!==(R'(expected)^R'('h5a39)))
                    $fatal(1,"Response changed or request accepted under stall");
            end
            rr=1;@(negedge src_clk);rr=0;
        end
        if(accepted!=80 || committed!=80 || returned!=80) $fatal(1,"Lost transaction");
        // Reset cancels a request stalled at destination; no ghost response.
        send(123);wait(dv); #1;reset=1;
        #31;reset=0;
        repeat(20) @(negedge src_clk);
        if(dv||rv||!sr) $fatal(1,"Reset did not flush transaction");
        // Restart toggle sequence and counters after coordinated reset.
        accepted=0;committed=0;returned=0;
        send(456);wait(dv);@(negedge dst_clk);dr=1;
        @(negedge dst_clk);dr=0;
        wait(rv);@(negedge src_clk);rr=1;
        @(negedge src_clk);rr=0;
        if(accepted!=1||committed!=1||returned!=1) $fatal(1,"Restart failed");
        $display("PASS S=%0d D=%0d W=%0d R=%0d N=%0d",S,D,W,R,N);done=1;
    end
endmodule
module tb_cdc_mailbox;
    wire a,b,c;
    mailbox_case #(.S(5),.D(7)) fast_source(a);
    mailbox_case #(.S(11),.D(3),.W(65),.R(37),.N(3)) fast_destination(b);
    mailbox_case #(.S(4),.D(4),.W(1),.R(1)) coincident_edges(c);
    initial begin wait(a&&b&&c);$display("PASS generic CDC mailbox");$finish;end
    initial begin #1000000;$fatal(1,"Watchdog timeout");end
endmodule
