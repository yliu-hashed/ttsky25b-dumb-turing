`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg spi_rst = 0;
  reg ena;
  reg  [7:0] ui_in;
  wire [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  wire sio2 = 1'bZ;
  wire holdn = 1;

  M23LC512 st_ram (
    uio_out[1],
    uio_in[2],
    uio_out[3],
    uio_out[0],
    sio2,
    holdn,
    spi_rst
  );

  M23LC512 tp_ram (
    uio_out[5],
    uio_in[6],
    uio_out[7],
    uio_out[4],
    sio2,
    holdn,
    spi_rst
  );

  // Replace tt_um_example with your module name:
  tt_um_dumb_turing_yliu_hashed user_project (
    // Include power ports for the Gate Level test:
`ifdef GL_TEST
    .VPWR(VPWR),
    .VGND(VGND),
`endif
    .ui_in  (ui_in),    // Dedicated inputs
    .uo_out (uo_out),   // Dedicated outputs
    .uio_in (uio_in),   // IOs: Input path
    .uio_out(uio_out),  // IOs: Output path
    .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
    .ena    (ena),      // enable - goes high when design is selected
    .clk    (clk),      // clock
    .rst_n  (rst_n)     // not reset
  );

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  integer i;
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    $readmemh("table_io.hex", st_ram.MemoryBlock);
    for (i = 0; i < 65536; i = i + 1) begin
      tp_ram.MemoryBlock[i] = 0;
    end
    #1;
  end

endmodule
