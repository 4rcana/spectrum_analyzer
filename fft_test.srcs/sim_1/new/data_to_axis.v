`timescale 1ns / 1ps

module tb_data_to_axis;

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter PACKET_SIZE = 1024;
    parameter CLK_PERIOD = 10;

    // Signals
    reg                    clk;
    reg                    rstn;
    reg  [11:0]            ADC_Data;
    wire [DATA_WIDTH-1:0]  m_axis_tdata;
    wire                   m_axis_tvalid;
    wire                   m_axis_tlast;
    reg                    m_axis_tready;

    // DUT
    data_to_axis #(
        .DATA_WIDTH(DATA_WIDTH),
        .PACKET_SIZE(PACKET_SIZE)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .ADC_Data(ADC_Data),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tready(m_axis_tready)
    );

    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Stimulus
    initial begin
        rstn = 0;
        ADC_Data = 12'h000;
        m_axis_tready = 0;
        
        #(CLK_PERIOD*5);
        rstn = 1;
        
        #(CLK_PERIOD*2);
        m_axis_tready = 1;
        
        repeat(PACKET_SIZE * 3) begin
            ADC_Data = ADC_Data + 1;
            @(posedge clk);
        end
        
        #(CLK_PERIOD*10);
        $finish;
    end

    // Waveform
    initial begin
        $dumpfile("tb_data_to_axis.vcd");
        $dumpvars(0, tb_data_to_axis);
    end

endmodule