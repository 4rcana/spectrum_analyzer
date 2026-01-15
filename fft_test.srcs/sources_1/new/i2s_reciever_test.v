`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 01:41:26 PM
// Design Name: 
// Module Name: i2s_reciever_test
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


module i2s_reciever_test// clk_blink_probe.v : blinks if axis_clk is running and reset deasserted
(
    input  wire        axis_clk,
    input  wire        axis_resetn,

    // From axis_i2s2
    input  wire [31:0] rx_axis_m_data,
    input  wire        rx_axis_m_valid,
    output wire        rx_axis_m_ready,
    input  wire        rx_axis_m_last,

    // To Basys3 LEDs (export in BD)
    output reg  [15:0] leds
);
    assign rx_axis_m_ready = 1'b1;   // Always accept data

    always @(posedge axis_clk) begin
        if (!axis_resetn) begin
            leds <= 16'h0000;
        end else if (rx_axis_m_valid) begin
            // LED0 lights whenever valid data arrives
            // LED1 shows which channel (0 = L, 1 = R)
            // The rest show MSBs of the sample
            leds[0]     <= 1'b1;                 // Data seen
            leds[1]     <= rx_axis_m_last;       // Channel indicator
            leds[15:2]  <= rx_axis_m_data[31:18];
        end
    end
endmodule
