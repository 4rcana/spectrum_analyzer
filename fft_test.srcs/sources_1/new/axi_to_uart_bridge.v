`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2025 04:42:04 PM
// Design Name: 
// Module Name: axi_to_uart_bridge
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


module axi_to_uart_bridge#(
    parameter LITTLE_ENDIAN = 1
)(
    input  wire        clk,
    input  wire        rstn,

    // 32-bit AXIS input (slave)
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [31:0] s_axis_tdata,

    // 8-bit AXIS output (master)
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire [7:0]  m_axis_tdata
);

    // -------------------------
    // Two-entry skid buffer for 32-bit words
    // -------------------------
    reg        act_valid;     // active word present
    reg [31:0] act_word;      // active word
    reg  [1:0] act_bidx;      // byte index 0..3 (which byte)
    reg        act_nib;       // 0: send high nibble first, 1: low nibble

    reg        skid_valid;    // second buffered word
    reg [31:0] skid_word;

    // Ready when any one slot is free
    assign s_axis_tready = (~act_valid) || (~skid_valid);

    // -------------------------
    // Byte and nibble selection (combinational)
    // -------------------------
    wire [7:0] b0 = act_word[7:0];
    wire [7:0] b1 = act_word[15:8];
    wire [7:0] b2 = act_word[23:16];
    wire [7:0] b3 = act_word[31:24];

    reg [7:0] cur_byte;
    always @* begin
        if (LITTLE_ENDIAN) begin
            case (act_bidx)
                2'd0: cur_byte = b0;
                2'd1: cur_byte = b1;
                2'd2: cur_byte = b2;
                default: cur_byte = b3;
            endcase
        end else begin
            case (act_bidx)
                2'd0: cur_byte = b3;
                2'd1: cur_byte = b2;
                2'd2: cur_byte = b1;
                default: cur_byte = b0;
            endcase
        end
    end

    wire [3:0] nib_hi = cur_byte[7:4];
    wire [3:0] nib_lo = cur_byte[3:0];
    wire [3:0] cur_nib = (act_nib == 1'b0) ? nib_hi : nib_lo;

    // hex nibble -> ASCII (uppercase)
    function [7:0] hex2ascii;
        input [3:0] nib;
        begin
            hex2ascii = (nib < 4'd10) ? (8'h30 + nib) : (8'h41 + (nib - 4'd10));
        end
    endfunction

    wire [7:0] ascii_byte = hex2ascii(cur_nib);

    assign m_axis_tvalid = act_valid;   // valid while we have an active word
    assign m_axis_tdata  = ascii_byte;

    // -------------------------
    // Single writer control block
    // -------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            act_valid   <= 1'b0;
            act_word    <= 32'd0;
            act_bidx    <= 2'd0;
            act_nib     <= 1'b0; // start with high nibble
            skid_valid  <= 1'b0;
            skid_word   <= 32'd0;
        end else begin
            // Load side
            if (s_axis_tvalid && s_axis_tready) begin
                if (!act_valid) begin
                    act_word   <= s_axis_tdata;
                    act_valid  <= 1'b1;
                    act_bidx   <= 2'd0;
                    act_nib    <= 1'b0; // high nibble first
                end else begin
                    // act_valid==1 implies skid must be free due to tready
                    skid_word  <= s_axis_tdata;
                    skid_valid <= 1'b1;
                end
            end

            // Send side
            if (m_axis_tvalid && m_axis_tready) begin
                if (act_nib == 1'b0) begin
                    // just sent high nibble -> low nibble next
                    act_nib <= 1'b1;
                end else begin
                    // low nibble sent -> advance to next byte
                    act_nib <= 1'b0;
                    if (act_bidx == 2'd3) begin
                        // finished 4 bytes -> pop word
                        if (skid_valid) begin
                            act_word   <= skid_word;
                            act_valid  <= 1'b1;
                            act_bidx   <= 2'd0;
                            act_nib    <= 1'b0;
                            skid_valid <= 1'b0;
                        end else begin
                            act_valid  <= 1'b0;
                            act_bidx   <= 2'd0;
                            act_nib    <= 1'b0;
                        end
                    end else begin
                        act_bidx <= act_bidx + 2'd1;
                    end
                end
            end
        end
    end

endmodule