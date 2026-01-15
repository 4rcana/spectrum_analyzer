module Frame #(
    parameter integer N          = 2048,  // FFT frame length in COMPLEX samples
    parameter integer IN_W       = 32,    // incoming width (i2s = 32)
    parameter integer CH_W       = 24,    // per-channel width (L/R)
    parameter integer PACK_IM_RE = 1      // 1 = {IM,RE}, 0 = {RE,IM}
)(
    input  wire                 aclk,
    input  wire                 aresetn,

    input  wire [IN_W-1:0]      s_tdata,
    input  wire                 s_tvalid,
    output wire                 s_tready,
    input  wire                 s_tlast,

    output reg  [2*CH_W-1:0]    m_tdata,
    output reg                  m_tvalid,
    input  wire                 m_tready,
    output reg                  m_tlast
);

    reg  [CH_W-1:0]    left_sample;
    reg  [CH_W-1:0]    right_sample;
    reg                have_left;

    reg [10:0]         count;

    //--------------------------------------------------------------------
    // Upstream ready logic
    //--------------------------------------------------------------------
    assign s_tready = !m_tvalid || m_tready;

    //--------------------------------------------------------------------
    // Collect L and R into left_sample / right_sample
    //--------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            have_left  <= 0;
            m_tvalid   <= 0;
        end else begin
            // Accept input
            if (s_tvalid && s_tready) begin
                if (!s_tlast) begin
                    // LEFT sample
                    left_sample <= s_tdata[23:0];
                    have_left   <= 1;
                end else begin
                    // RIGHT sample completes the pair
                    right_sample <= s_tdata[23:0];
                    have_left    <= 0;
                    m_tvalid     <= 1; // output one complex sample
                end
            end

            // If we emitted a sample and downstream took it
            if (m_tvalid && m_tready) begin
                m_tvalid <= 0;

                // Increase frame counter
                if (count == N-1) begin
                    count  <= 0;
                    m_tlast <= 1;
                end else begin
                    count  <= count + 1;
                    m_tlast <= 0;
                end
            end

            // Prepare m_tdata when L+R is available
            if (m_tvalid && !m_tready) begin
                // keep old m_tdata
            end else if (m_tvalid == 0 && s_tvalid && s_tready && s_tlast) begin
                // Just stored right_sample in this cycle
                if (PACK_IM_RE) begin
                    m_tdata <= { right_sample, left_sample };   // {IM, RE}
                end else begin
                    m_tdata <= { left_sample, right_sample };   // {RE, IM}
                end
            end
        end
    end

endmodule
