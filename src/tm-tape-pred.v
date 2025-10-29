// Copyright (c) 2025 Yuanda Liu
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 10ps
`default_nettype none

module tm_tape_pred (
  input  wire clk,
  input  wire rst_n,
  // control
  input  wire move_i,
  input  wire dir_i, // right is 1, left is 0
  // read data
  output wire pred_r_o,
  output wire pred_l_o
  );

  parameter PRED_HIST_BITS = 2;
  localparam COUNTER_COUNT = 2 ** PRED_HIST_BITS;

  localparam HISTORY_BITS = PRED_HIST_BITS + 3;

  reg [HISTORY_BITS-1:0] history = -1;
  wire [PRED_HIST_BITS-1:0] recent_hist = history[PRED_HIST_BITS-1:0];

  wire [PRED_HIST_BITS-1:0] past_hist = history[HISTORY_BITS-1:3];
  wire [2:0] past_result = history[2:0];
  wire past_dir_r = past_result == 3'b111;
  wire past_dir_l = past_result == 3'b000;

  reg [1:0] counters [COUNTER_COUNT-1:0];

  wire [1:0] counter = counters[recent_hist];
  assign pred_r_o = counter == 2'b11;
  assign pred_l_o = counter == 2'b00;

  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      history <= -1;
      for (i = 0; i < COUNTER_COUNT; i = i + 1) begin
        counters[i] <= 1;
      end
    end else if (move_i) begin
      if (past_dir_r) begin
        counters[past_hist] <= counters[past_hist] == 2'd3 ? 2'd3 : counters[past_hist] + 1;
      end else if (past_dir_l) begin
        counters[past_hist] <= counters[past_hist] == 2'd0 ? 2'd0 : counters[past_hist] - 1;
      end
      history <= { history[HISTORY_BITS-2:0], dir_i };
    end
  end

endmodule
