`timescale 1ns/1ps

module tb_Frame;

  localparam N         = 8;    // shorter for sim
  localparam IN_W      = 32;
  localparam CH_W      = 24;
  localparam PACK_IM_RE= 1;

  reg aclk;
  reg aresetn;

  // Clock generation
  initial begin
    aclk = 0;
    forever #5 aclk = ~aclk;  // 100 MHz
  end

  // Reset
  initial begin
    aresetn = 0;
    #30;
    aresetn = 1;
  end

  // ------------------------------------------------------------
  // DUT interface signals
  // ------------------------------------------------------------
  reg  [IN_W-1:0] s_tdata;
  reg              s_tvalid;
  wire             s_tready;
  reg              s_tlast;

  wire [2*CH_W-1:0] m_tdata;
  wire               m_tvalid;
  reg                m_tready;
  wire               m_tlast;

  // ------------------------------------------------------------
  // DUT
  // ------------------------------------------------------------
  Frame #(
    .N          (N),
    .IN_W       (IN_W),
    .CH_W       (CH_W),
    .PACK_IM_RE (PACK_IM_RE)
  ) dut (
    .aclk     (aclk),
    .aresetn  (aresetn),
    .s_tdata  (s_tdata),
    .s_tvalid (s_tvalid),
    .s_tready (s_tready),
    .s_tlast  (s_tlast),
    .m_tdata  (m_tdata),
    .m_tvalid (m_tvalid),
    .m_tready (m_tready),
    .m_tlast  (m_tlast)
  );

  // ------------------------------------------------------------
  // Simple L/R generator
  // ------------------------------------------------------------
  reg  [31:0] k;
  reg         is_left;

  initial begin
    s_tvalid = 0;
    s_tdata  = 0;
    s_tlast  = 0;
    is_left  = 1;
    k        = 0;
    m_tready = 1'b1;  // always ready for now
  end

  always @(posedge aclk) begin
    if (!aresetn) begin
      s_tvalid <= 0;
      s_tdata  <= 0;
      s_tlast  <= 0;
      is_left  <= 1;
      k        <= 0;
    end else begin
      s_tvalid <= 1'b1; // always try to send

      if (s_tvalid && s_tready) begin
        if (is_left) begin
          s_tdata <= k[23:0];
          s_tlast <= 1'b0;  // LEFT beat
          is_left <= 1'b0;
        end else begin
          s_tdata <= k + 32'd1000;  // RIGHT beat
          s_tlast <= 1'b1;
          is_left <= 1'b1;
          k       <= k + 1;
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Run duration
  // ------------------------------------------------------------
  initial begin
    #2000;
    $finish;
  end

endmodule