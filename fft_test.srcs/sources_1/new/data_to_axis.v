`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 13:10:06
// Design Name: 
// Module Name: data_to_axis
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


module data_to_axis#(
    parameter DATA_WIDTH = 16,
    parameter PACKET_SIZE = 1024  
)(
    input  wire                    clk,     
    input  wire                    rstn,
    input  wire [11:0]             ADC_Data,        
    output reg  [DATA_WIDTH-1:0]   m_axis_tdata,
    output reg                     m_axis_tvalid,
    output reg                     m_axis_tlast,
    input  wire                    m_axis_tready
);
    localparam CNT_WIDTH = $clog2(PACKET_SIZE);
    reg [CNT_WIDTH-1:0] sample_count;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            m_axis_tdata  <= {DATA_WIDTH{1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            sample_count  <= {CNT_WIDTH{1'b0}};
        end
        else begin
            if(~m_axis_tready)begin
                sample_count <= {CNT_WIDTH{1'b0}};
                m_axis_tlast <= 1'b0;
            end
            else if (!m_axis_tvalid || m_axis_tready) begin
                m_axis_tdata  <= { {4{~ADC_Data[11]}}, (ADC_Data ^ 12'h800) };
                m_axis_tvalid <= 1'b1;
                if (m_axis_tvalid && m_axis_tready) begin
                    if (sample_count == (PACKET_SIZE - 2)) begin
                        m_axis_tlast <= 1'b1;
                        sample_count <= {CNT_WIDTH{1'b0}};
                    end else begin
                        sample_count <= sample_count + 1;
                        m_axis_tlast <= 1'b0;
                    end
                end
            end
        end
    end
endmodule