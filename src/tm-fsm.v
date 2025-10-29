// Copyright (c) 2025 Yuanda Liu
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 10ps
`default_nettype none

module tm_fsm (
  input         clk,
  input         rst_n,
  // states table SPI
  output        state_spi_mosi,
  input         state_spi_miso,
  output        state_spi_cs,
  output        state_spi_sck,
  // tape SPI
  output        tape_spi_mosi,
  input         tape_spi_miso,
  output        tape_spi_cs,
  output        tape_spi_sck,
  // state
  input  [ 7:0] gpio_i,
  output [ 7:0] gpio_o
  );

  localparam [6:0] TM_STATE_INIT  = 7'h00;
  localparam [6:0] TM_STATE_IO_RD = 7'h7E;
  localparam [6:0] TM_STATE_IO_WR = 7'h7F;

  reg [6:0] tm_state = TM_STATE_INIT;
  reg       move_dir = 0;
  reg [7:0] tape_new_data = 0;

  reg [7:0] gpio_buffer = 0;
  assign gpio_o = gpio_buffer;

  localparam [1:0] STATE_READ  = 0;
  localparam [1:0] STATE_FETCH = 1;
  localparam [1:0] STATE_MOVE  = 2;

  reg [1:0] state = STATE_READ;

  wire [7:0] tape_data;

  wire [15:0] fetch_data;
  wire [15:0] fetch_addr = { tm_state, tape_data, 1'b0 };
  wire        fetch_done;
  tm_spi_read state_spi_reader (
    .clk      ( clk                  ),
    .rst_n    ( rst_n                ),
    // state SPI
    .spi_mosi ( state_spi_mosi       ),
    .spi_miso ( state_spi_miso       ),
    .spi_cs   ( state_spi_cs         ),
    .spi_sck  ( state_spi_sck        ),
    // controls
    .valid_i  ( state == STATE_FETCH ),
    .addr_i   ( fetch_addr           ),
    // read value
    .done_o   ( fetch_done           ),
    .data_o   ( fetch_data           )
  );

  wire       tape_move_done;
  wire       tape_valid;
  tm_tape tape (
    .clk           ( clk                 ),
    .rst_n         ( rst_n               ),
    // state SPI
    .tape_spi_mosi ( tape_spi_mosi       ),
    .tape_spi_miso ( tape_spi_miso       ),
    .tape_spi_cs   ( tape_spi_cs         ),
    .tape_spi_sck  ( tape_spi_sck        ),
    // controls
    .move_i        ( state == STATE_MOVE ),
    .move_dir_i    ( move_dir            ),
    .move_data_i   ( tape_new_data       ),
    .move_done_o   ( tape_move_done      ),
    // read value
    .data_o        ( tape_data           ),
    .valid_o       ( tape_valid          )
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tm_state <= TM_STATE_INIT;
      state <= STATE_READ;
      gpio_buffer <= 0;
    end else begin
      case (state)
        STATE_READ: begin
          if (tape_valid) begin
            state <= STATE_FETCH;
          end
        end
        STATE_FETCH: begin
          if (fetch_done) begin
            state <= STATE_MOVE;
            tm_state <= fetch_data[6:0];
            move_dir <= fetch_data[7];
            if (tm_state == TM_STATE_IO_RD) begin
              tape_new_data <= gpio_i;
            end else begin
              tape_new_data <= fetch_data[15:8];
            end
            if (tm_state == TM_STATE_IO_WR) begin
              gpio_buffer <= fetch_data[15:8];
            end
          end
        end
        STATE_MOVE: begin
          if (tape_move_done) begin
            state <= STATE_READ;
          end
        end
      endcase
    end
  end
endmodule
