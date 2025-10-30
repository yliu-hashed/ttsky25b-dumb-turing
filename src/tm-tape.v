// Copyright (c) 2025 Yuanda Liu
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 10ps
`default_nettype none

module tm_tape (
  input  wire        clk,
  input  wire        rst_n,
  // SPI
  output wire        tape_spi_mosi,
  input  wire        tape_spi_miso,
  output wire        tape_spi_cs,
  output wire        tape_spi_sck,
  // control
  input  wire        move_i,
  input  wire        move_dir_i, // right is 1, left is 0
  input  wire [ 7:0] move_data_i,
  output wire        move_done_o,
  // read data
  output wire [ 7:0] data_o,
  output wire        valid_o
  );

  parameter CACHE_BITS = 3;
  localparam CACHE_SIZE = 2 ** CACHE_BITS;
  parameter [CACHE_BITS:0] CACHE_R_FETCH_MAX = 4;
  parameter [CACHE_BITS:0] CACHE_R_FETCH_MIN = 2;
  parameter [CACHE_BITS:0] CACHE_L_FETCH_MAX = 4;
  parameter [CACHE_BITS:0] CACHE_L_FETCH_MIN = 2;

  localparam [1:0] STATE_IDLE      = 0;
  localparam [1:0] STATE_MOVE_DONE = 2;
  localparam [1:0] STATE_FETCH     = 3;
  reg [1:0] state = STATE_IDLE;

  reg [7:0] cache [CACHE_SIZE-1:0];
  reg [CACHE_BITS:0] valid_count_r = 0;
  reg [CACHE_BITS:0] valid_count_l = 0;

  reg [15:0] addr = 0;

  assign data_o = cache[addr[CACHE_BITS - 1:0]];
  assign valid_o = (valid_count_r != 0) && (valid_count_l != 0) && state != STATE_FETCH;

  wire data_match = data_o == move_data_i;

  assign move_done_o = state == STATE_MOVE_DONE;

  // SPI read write ------------------------------------------------------------
  reg  [ 4:0] counter = 0;

  reg         spi_pending = 0;
  reg         spi_ctl_iswr;
  reg  [15:0] spi_ctl_addr;
  reg  [ 7:0] spi_ctl_data;

  wire [ 7:0] spi_data;
  wire        spi_done;

  tm_spi spi (
    .clk       ( clk             ),
    .rst_n     ( rst_n           ),
    // SPI
    .spi_mosi  ( tape_spi_mosi   ),
    .spi_miso  ( tape_spi_miso   ),
    .spi_cs    ( tape_spi_cs     ),
    .spi_sck   ( tape_spi_sck    ),
    // controls
    .valid_i   ( spi_pending     ),
    .iswr_i    ( spi_ctl_iswr    ),
    .addr_i    ( spi_ctl_addr    ),
    .data_i    ( spi_ctl_data    ),
    // read value
    .done_o    ( spi_done        ),
    .data_o    ( spi_data        )
  );

  // tape movement predictor ---------------------------------------------------

  wire move_pred_r;
  wire move_pred_l;
  tm_tape_pred predictor (
    .clk        ( clk                   ),
    .rst_n      ( rst_n                 ),
    // control
    .move_i     ( state == STATE_MOVE_DONE ),
    .dir_i      ( move_dir_i            ), // right is 1, left is 0
    // read data
    .pred_r_o   ( move_pred_r           ),
    .pred_l_o   ( move_pred_l           )
  );

  wire [CACHE_BITS:0] cache_r_fetch_cnt = move_pred_r ? CACHE_R_FETCH_MAX : CACHE_R_FETCH_MIN;
  wire [CACHE_BITS:0] cache_l_fetch_cnt = move_pred_l ? CACHE_L_FETCH_MAX : CACHE_L_FETCH_MIN;

  // wire [CACHE_BITS:0] cache_r_fetch_cnt = 2;
  // wire [CACHE_BITS:0] cache_l_fetch_cnt = 4;

  wire [CACHE_BITS:0] move_r_fetch_l_max = CACHE_SIZE + 1 - cache_r_fetch_cnt;
  wire [CACHE_BITS:0] move_l_fetch_r_max = CACHE_SIZE + 1 - cache_l_fetch_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spi_pending <= 0;
      valid_count_r <= 0;
      valid_count_l <= 0;
      addr <= 0;
      state <= STATE_IDLE;
    end else begin
      if (spi_pending && spi_done) begin
        spi_pending <= 0;
      end

      case (state)
        STATE_IDLE: begin
          if (move_i) begin
            if (data_match || !spi_pending) begin
              if (move_dir_i) begin
                addr <= addr + 1;
                valid_count_r <= valid_count_r - 1;
                if (valid_count_l != CACHE_SIZE) valid_count_l <= valid_count_l + 1;
              end else begin
                addr <= addr - 1;
                valid_count_l <= valid_count_l - 1;
                if (valid_count_r != CACHE_SIZE) valid_count_r <= valid_count_r + 1;
              end
              if (!data_match) begin
                spi_pending  <= 1;
                spi_ctl_iswr <= 1;
                spi_ctl_addr <= addr;
                spi_ctl_data <= move_data_i;
                cache[addr[CACHE_BITS-1:0]] <= move_data_i;
              end
              state <= STATE_MOVE_DONE;
            end
          end else if (!spi_pending) begin
            if (valid_count_r == 0) begin // fill the right side
              state <= STATE_FETCH;
              counter <= cache_r_fetch_cnt - 1;
              spi_pending <= 1;
              spi_ctl_iswr <= 0;
              spi_ctl_addr <= addr;
              // compute valid range
              valid_count_r <= cache_r_fetch_cnt;
              if (valid_count_l > move_r_fetch_l_max) valid_count_l <= move_r_fetch_l_max;
              if (valid_count_l == 0) valid_count_l <= 1;
            end else if (valid_count_l == 0) begin // fill the left side
              state <= STATE_FETCH;
              counter <= cache_l_fetch_cnt - 1;
              spi_pending <= 1;
              spi_ctl_iswr <= 0;
              spi_ctl_addr <= addr - (cache_l_fetch_cnt - 1);
              // compute valid range
              valid_count_l <= cache_l_fetch_cnt;
              if (valid_count_r > move_l_fetch_r_max) valid_count_r <= move_l_fetch_r_max;
              if (valid_count_r == 0) valid_count_r <= 1;
            end
          end
        end
        STATE_MOVE_DONE: begin
          state <= STATE_IDLE;
        end
        STATE_FETCH: begin
          if (!spi_pending) begin
            cache[spi_ctl_addr[CACHE_BITS - 1:0]] <= spi_data;
            if (counter != 0) begin
              spi_pending <= 1;
              spi_ctl_iswr <= 0;
              counter <= counter - 1;
              spi_ctl_addr <= spi_ctl_addr + 1;
            end else begin
              state <= STATE_IDLE;
            end
          end
        end
      endcase
    end
  end

endmodule
