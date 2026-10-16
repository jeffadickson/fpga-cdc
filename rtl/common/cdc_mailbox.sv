// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Single outstanding request/response across unrelated clocks. See README.md.
module cdc_mailbox #(
    parameter integer REQ_WIDTH = 32,
    parameter integer RSP_WIDTH = 32,
    parameter integer SYNC_STAGES = 2
)(
    input wire src_clk, dst_clk,
    // Common asynchronous assertion; release is synchronized in each domain.
    // Reset aborts outstanding work. Independent domain reset is unsupported.
    input wire reset,
    input wire src_valid,
    output wire src_ready,
    input wire [REQ_WIDTH-1:0] src_data,
    output reg src_rsp_valid,
    input wire src_rsp_ready,
    output reg [RSP_WIDTH-1:0] src_rsp_data,
    output reg dst_valid,
    input wire dst_ready,
    output reg [REQ_WIDTH-1:0] dst_data,
    // Response sampled on dst_valid && dst_ready (the commit edge).
    input wire [RSP_WIDTH-1:0] dst_rsp_data
);
    initial begin
        if (REQ_WIDTH < 1 || RSP_WIDTH < 1 || SYNC_STAGES < 2)
            $fatal(1, "cdc_mailbox requires positive widths and SYNC_STAGES >= 2");
    end
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [SYNC_STAGES-1:0] src_reset_sync, dst_reset_sync;
    always @(posedge src_clk or posedge reset)
        if (reset) src_reset_sync <= '1;
        else src_reset_sync <= {src_reset_sync[SYNC_STAGES-2:0],1'b0};
    always @(posedge dst_clk or posedge reset)
        if (reset) dst_reset_sync <= '1;
        else dst_reset_sync <= {dst_reset_sync[SYNC_STAGES-2:0],1'b0};
    wire src_reset = src_reset_sync[SYNC_STAGES-1];
    wire dst_reset = dst_reset_sync[SYNC_STAGES-1];

    // Payloads are held until their opposite-domain capture has completed.
    // Synchronize only toggles; constrain both bundled-data buses physically.
    (* KEEP="TRUE" *) reg req_toggle, ack_toggle;
    (* KEEP="TRUE" *) reg [REQ_WIDTH-1:0] src_payload;
    (* KEEP="TRUE" *) reg [RSP_WIDTH-1:0] dst_response;
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [SYNC_STAGES-1:0] req_sync, ack_sync;
    reg busy;
    assign src_ready = !reset && !src_reset && !busy && !src_rsp_valid;

    always @(posedge src_clk or posedge src_reset) begin
        if (src_reset) begin
            req_toggle <= 0; ack_sync <= 0; src_payload <= 0;
            busy <= 0; src_rsp_valid <= 0; src_rsp_data <= 0;
        end else begin
            ack_sync <= {ack_sync[SYNC_STAGES-2:0],ack_toggle};
            if (src_rsp_valid && src_rsp_ready) src_rsp_valid <= 0;
            if (src_valid && src_ready) begin
                src_payload <= src_data;
                req_toggle <= ~req_toggle;
                busy <= 1;
            end
            if (busy && ack_sync[SYNC_STAGES-1] == req_toggle) begin
                src_rsp_data <= dst_response;
                src_rsp_valid <= 1;
                busy <= 0;
            end
        end
    end
    always @(posedge dst_clk or posedge dst_reset) begin
        if (dst_reset) begin
            req_sync <= 0; ack_toggle <= 0; dst_response <= 0;
            dst_valid <= 0; dst_data <= 0;
        end else begin
            req_sync <= {req_sync[SYNC_STAGES-2:0],req_toggle};
            if (!dst_valid && req_sync[SYNC_STAGES-1] != ack_toggle) begin
                dst_data <= src_payload;
                dst_valid <= 1;
            end
            if (dst_valid && dst_ready) begin
                dst_response <= dst_rsp_data;
                dst_valid <= 0;
                ack_toggle <= req_sync[SYNC_STAGES-1];
            end
        end
    end
endmodule
