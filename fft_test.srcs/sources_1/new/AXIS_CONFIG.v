`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.01.2026 19:40:35
// Design Name: 
// Module Name: AXIS_CONFIG
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


module axis_fft_config_once #(
    parameter integer CFG_W = 16,                 // set to your S_AXIS_CONFIG TDATA width
    parameter [CFG_W-1:0] CFG_WORD = {CFG_W{1'b0}} // put your desired config bits here
)(
    input  wire                 aclk,
    input  wire                 aresetn,

    output reg  [CFG_W-1:0]     m_axis_tdata,
    output reg                  m_axis_tvalid,
    input  wire                 m_axis_tready
);

    reg sent;

    always @(posedge aclk) begin
        if (!aresetn) begin
            sent          <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= CFG_WORD;
        end else begin
            if (!sent) begin
                m_axis_tdata  <= CFG_WORD;
                m_axis_tvalid <= 1'b1;
                if (m_axis_tready) begin
                    sent          <= 1'b1;   // handshake happened
                    m_axis_tvalid <= 1'b0;   // stop sending
                end
            end
        end
    end
endmodule
