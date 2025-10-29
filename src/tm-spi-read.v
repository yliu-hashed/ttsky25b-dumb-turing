// Copyright (c) 2025 Yuanda Liu
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 10ps
`default_nettype none

module tm_spi_read (
  input  wire        clk,
  input  wire        rst_n,
  // instruction SPI
  output wire        spi_mosi,
  input  wire        spi_miso,
  output wire        spi_cs,
  output wire        spi_sck,
  // controls
  input  wire        valid_i,
  input  wire [15:0] addr_i,
  // read value
  output wire        done_o,
  output wire [15:0] data_o
  );

  reg [15:0] addr;
  reg [15:0] buffer;
  assign spi_mosi = buffer[15];
  assign data_o = buffer;

  reg sck = 0;
  reg cs  = 0;
  assign spi_sck = sck;
  assign spi_cs  = cs;

  reg cache_bit = 0;

  localparam [7:0] SPI_RCMD = 8'h03;

  localparam [1:0] STATE_WCMD = 0;
  localparam [1:0] STATE_IDLE = 1;
  localparam [1:0] STATE_ADDR = 2;
  localparam [1:0] STATE_WORK = 3;

  reg       dirty   = 0;
  reg [1:0] state   = 0;
  reg [5:0] counter = 0;

  assign done_o = (state == STATE_WORK) && (counter == 0);

  wire step_done = counter == 0 || (counter == 1 && sck);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs      <= 0;
      sck     <= 0;
      state   <= STATE_WCMD;
      buffer  <= { SPI_RCMD, 8'h00 };
      counter <= 8;
    end else begin
      if (!cs) begin
        cs <= 1;
      end else begin
        if (sck) begin
          sck     <= 0;
          counter <= counter - 1;
          buffer  <= { buffer[14:0], cache_bit };
        end else if (counter != 0) begin
          sck       <= 1;
          cache_bit <= spi_miso;
        end

        case (state)
          STATE_WCMD: begin
            if (step_done) begin
              state <= STATE_IDLE;
            end
          end
          STATE_IDLE: begin
            if (valid_i) begin
              state <= STATE_ADDR;
              buffer <= addr_i;
              counter <= 16;
            end
          end
          STATE_ADDR: begin
            if (step_done) begin
              state   <= STATE_WORK;
              counter <= 16;
            end
          end
          STATE_WORK: begin
            if (step_done && !valid_i) begin
              cs      <= 0;
              state   <= STATE_WCMD;
              buffer  <= { SPI_RCMD, 8'h00 };
              counter <= 8;
            end
          end
        endcase
      end
    end
  end

endmodule
