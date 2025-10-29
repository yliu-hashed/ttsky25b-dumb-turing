/*
 * Copyright (c) 2025 Yuanda Liu
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_dumb_turing_yliu_hashed (
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
  );

  assign uio_oe  = 8'b10111011;
  assign uio_out[2] = 0;
  assign uio_out[6] = 0;
  wire _unused = &{
    ena,
    uio_in[0], uio_in[1], uio_in[3],
    uio_in[4], uio_in[5], uio_in[7],
    1'b0
  };

  wire spi_st_mosi;
  wire spi_st_miso;
  wire spi_st_cs;
  wire spi_st_sck;

  assign uio_out[0] = !spi_st_cs;
  assign uio_out[1] = spi_st_mosi;
  assign spi_st_miso = uio_in[2];
  assign uio_out[3] = spi_st_sck;

  wire spi_tp_mosi;
  wire spi_tp_miso;
  wire spi_tp_cs;
  wire spi_tp_sck;

  assign uio_out[4] = !spi_tp_cs;
  assign uio_out[5] = spi_tp_mosi;
  assign spi_tp_miso = uio_in[6];
  assign uio_out[7] = spi_tp_sck;

  tm_fsm core (
    .clk   (clk),
    .rst_n (rst_n),
    // instruction SPI
    .state_spi_mosi  ( spi_st_mosi ),
    .state_spi_miso  ( spi_st_miso ),
    .state_spi_cs    ( spi_st_cs   ),
    .state_spi_sck   ( spi_st_sck  ),
    // data SPI
    .tape_spi_mosi   ( spi_tp_mosi ),
    .tape_spi_miso   ( spi_tp_miso ),
    .tape_spi_cs     ( spi_tp_cs   ),
    .tape_spi_sck    ( spi_tp_sck  ),
    // general purpose inputs
    .gpio_i          ( ui_in       ),
    .gpio_o          ( uo_out      )
  );

endmodule
