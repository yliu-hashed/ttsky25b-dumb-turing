// Copyright (c) 2025 Yuanda Liu
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 10ps
`default_nettype none

module tm_spi (
  input  wire        clk,
  input  wire        rst_n,
  // SPI
  output wire        spi_mosi,
  input  wire        spi_miso,
  output wire        spi_cs,
  output wire        spi_sck,
  // controls
  input  wire        valid_i,
  input  wire        iswr_i,
  input  wire [15:0] addr_i,
  input  wire [ 7:0] data_i,
  // read value
  output wire        done_o,
  output wire [ 7:0] data_o
  );

  reg [15:0] addr;
  reg [ 7:0] buffer;
  assign spi_mosi = buffer[7];
  assign data_o = buffer;

  reg sck = 0;
  reg cs  = 0;
  assign spi_sck = sck;
  assign spi_cs  = cs;

  reg cache_bit = 0;

  localparam [7:0] SPI_RCMD = 8'h03;
  localparam [7:0] SPI_WCMD = 8'h02;

  localparam [2:0] STATE_IDLE = 0;
  localparam [2:0] STATE_WCMD = 1;
  localparam [2:0] STATE_ADR1 = 2;
  localparam [2:0] STATE_ADR2 = 3;
  localparam [2:0] STATE_WORK = 4;

  reg       dirty   = 0;
  reg       iswr    = 0;
  reg [2:0] state   = STATE_IDLE;
  reg [5:0] counter = 0;

  assign done_o = (state == STATE_WORK) && (counter == 0);

  wire step_done = counter == 0 || (counter == 1 && sck);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dirty   <= 0;
      cs      <= 0;
      sck     <= 0;
      state   <= STATE_IDLE;
      counter <= 0;
    end else begin
      if (!spi_cs) begin
        cs <= 1;
      end else begin
        if (sck) begin
          sck     <= 0;
          counter <= counter - 1;
          buffer  <= { buffer[6:0], cache_bit };
        end else if (counter != 0) begin
          sck       <= 1;
          cache_bit <= spi_miso;
        end

        case (state)
          STATE_IDLE: begin
            if (valid_i) begin
              dirty   <= 1;
              if (dirty && iswr == iswr_i && addr == addr_i && addr_i != 16'h0000) begin
                // continuous
                state   <= STATE_WORK;
                buffer  <= data_i;
                counter <= 8;
              end else begin
                // fresh
                iswr    <= iswr_i;
                cs      <= 0;
                addr    <= addr_i;
                state   <= STATE_WCMD;
                buffer  <= iswr_i ? SPI_WCMD : SPI_RCMD;
                counter <= 8;
              end
            end
          end
          STATE_WCMD: begin
            if (step_done) begin
              state   <= STATE_ADR1;
              buffer  <= addr[15:8];
              counter <= 8;
            end
          end
          STATE_ADR1: begin
            if (step_done) begin
              state   <= STATE_ADR2;
              buffer  <= addr[7:0];
              counter <= 8;
            end
          end
          STATE_ADR2: begin
            if (step_done) begin
              state   <= STATE_WORK;
              buffer  <= data_i;
              counter <= 8;
            end
          end
          STATE_WORK: begin
            if (step_done && !valid_i) begin
              state <= STATE_IDLE;
              addr  <= addr + 1;
            end
          end
          default: begin
            // BAD
          end
        endcase
      end
    end
  end

endmodule
