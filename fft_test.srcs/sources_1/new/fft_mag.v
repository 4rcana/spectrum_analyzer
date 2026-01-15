`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2025 01:42:25 PM
// Design Name: 
// Module Name: fft_mag
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


// Input:  AXI-Stream, 48 bits: {IM[47:24], RE[23:0]}
// Output: AXI-Stream, 25 bits magnitude (|Re| + |Im|), same TLAST

module fft_mag #(
   parameter W = 24  // per-component width
)(
    input  wire             aclk,
    input  wire             aresetn,

    // from FFT
    input  wire [2*W-1:0]   s_tdata,   // {IM, RE}
    input  wire             s_tvalid,
    output wire             s_tready,
    input  wire             s_tlast,

    // to next stage / ILA
    output reg  [31:0]      m_tdata,   // 32-bit, AXIS-friendly
    output reg              m_tvalid,
    input  wire             m_tready,
    output reg              m_tlast
);

    // flow-through
    assign s_tready = m_tready;

    // split complex
    wire signed [W-1:0] re_s = s_tdata[W-1:0];
    wire signed [W-1:0] im_s = s_tdata[2*W-1:W];

    // absolute values
    wire [W-1:0] abs_re = re_s[W-1] ? (~re_s + 1'b1) : re_s;
    wire [W-1:0] abs_im = im_s[W-1] ? (~im_s + 1'b1) : im_s;

    // cheap magnitude (max width = W+1 = 25 for W=24)
    wire [W:0] mag_sum = abs_re + abs_im;

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_tvalid <= 1'b0;
            m_tdata  <= 32'd0;
            m_tlast  <= 1'b0;
        end else begin
            if (s_tvalid && m_tready) begin
                m_tvalid <= 1'b1;
                m_tdata  <= { { (32-(W+1)){1'b0} }, mag_sum };  // zero-extend to 32
                m_tlast  <= s_tlast;
            end else if (m_tvalid && !m_tready) begin
                // hold
                m_tvalid <= m_tvalid;
                m_tdata  <= m_tdata;
                m_tlast  <= m_tlast;
            end else begin
                m_tvalid <= 1'b0;
                m_tlast  <= 1'b0;
            end
        end
    end

endmodule
