// Copyright (c) 2025 Yuanda Liu
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 10ps
`default_nettype none

module tm_tape_cache (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [CACHE_BITS-1:0] rd_addr_i,
  output wire [ 7:0] rd_data_o,

  input  wire        wr_en_i,
  input  wire [CACHE_BITS-1:0] wr_addr_i,
  input  wire [ 7:0] wr_data_i,
  output wire        wr_done_o
  );

  parameter CACHE_BITS = 3;
  localparam CACHE_SIZE = 2 ** CACHE_BITS;

  wire [7:0] values [CACHE_SIZE-1:0];
  assign rd_data_o = values[rd_addr_i];

  reg [CACHE_BITS-1:0] addr;
  reg [7:0] tmp;

  localparam [1:0] STATE_IDLE = 0;
  localparam [1:0] STATE_WAIT = 2;
  localparam [1:0] STATE_DONE = 3;

  reg [1:0] state = STATE_IDLE;
  wire write = state == STATE_WAIT;
  assign wr_done_o = state == STATE_DONE;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (wr_en_i) begin
            state <= STATE_WAIT;
            tmp   <= wr_data_i;
            addr  <= wr_addr_i;
          end
        end
        STATE_WAIT: begin
          state <= STATE_DONE;
        end
        STATE_DONE: begin
          if (!wr_en_i) begin
            state <= STATE_IDLE;
          end
        end
        default: begin
          state <= STATE_IDLE;
          // BAD
        end
      endcase
    end
  end

  genvar i;
  generate
    for (i = 0; i < CACHE_SIZE; i = i + 1) begin
      reg [7:0] latch;
      assign values[i] = latch;

      (* keep *)
      reg we = 0;
      always @(tmp or we) begin
        if (we) latch <= tmp;
      end

      always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
          we <= 0;
        end else if (write && addr == i) begin
          we <= 1;
        end else begin
          we <= 0;
        end
      end
    end
  endgenerate
endmodule
