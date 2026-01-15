`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 04:13:22 PM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top;

  // 1) clocks
  reg sys_clk = 0;
  always #5 sys_clk = ~sys_clk;   // 100 MHz

  reg i2s_clk = 0;
  always #50 i2s_clk = ~i2s_clk;  // 10 MHz example

  // 2) resets
  reg sys_resetn = 0;
  reg i2s_resetn = 0;

  initial begin
    sys_resetn = 0;
    i2s_resetn = 0;
    #200;
    sys_resetn = 1;
    i2s_resetn = 1;
  end

  // 3) instantiate the BD wrapper
  design_3_wrapper DUT (
    // you must match these port names to whatever Vivado generated
    .sys_clk    (sys_clk),
    .i2s_clk    (i2s_clk),
    .sys_resetn (sys_resetn),
    .i2s_resetn (i2s_resetn)
    // + any other top ports BD made
  );
  

endmodule