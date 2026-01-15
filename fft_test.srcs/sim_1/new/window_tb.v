
`timescale 1ns / 1ps
module window_tb;

    reg         aclk=1'b1;
    reg         aresetn=1'b0;
    reg         s_axis_tvalid=1'b0;
    wire        s_axis_tready;
    reg [15:0]  s_axis_tdata=16'b0;
    reg         s_axis_tlast=1'b0;
    wire        m_axis_tvalid;
    reg         m_axis_tready=1'b0;
    wire        m_axis_tdata;
    wire        m_axis_tlast;

    axis_window_real2cplx window_tb (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tlast(m_axis_tlast)
    );

    always #5 aclk = ~aclk;

    initial begin
        #50;
        aresetn=1'b1;
        #50
        m_axis_tready=1'b1;
        s_axis_tvalid=1'b1;
        s_axis_tdata=16'h60;
        #50
         s_axis_tvalid=1'b0;
        #50
        s_axis_tvalid=1'b1;
        s_axis_tdata=16'h70;
        
        
    end

endmodule