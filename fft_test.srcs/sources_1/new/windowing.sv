module axis_window_real2cplx #(
    parameter int N            = 1024,                 // window/FFT length
    parameter int DATA_W       = 16,                   // real sample width
    parameter int COEF_W       = 16,                   // coefficient width (Q1.(COEF_W-1), e.g. Q15)
    parameter bit USE_S_TLAST  = 1'b0,                 // 1: trust s_axis_tlast to reset idx, pass it through
                                                     // 0: generate tlast every N samples
    parameter string COEF_FILE = "window.mem"
)(
    input  logic                      aclk,
    input  logic                      aresetn,

    // AXI4-Stream input (real)
    input  logic                      s_axis_tvalid,
    output logic                      s_axis_tready,
    input  logic [DATA_W-1:0]         s_axis_tdata,
    input  logic                      s_axis_tlast,

    // AXI4-Stream output (complex: {imag, real})
    output logic                      m_axis_tvalid,
    input  logic                      m_axis_tready,
    output logic [2*DATA_W-1:0]       m_axis_tdata,
    output logic                      m_axis_tlast
);

    // -----------------------------
    // Coefficient ROM (window values 0..1 in Q format)
    // -----------------------------
    logic [COEF_W-1:0] coef_rom [0:N-1];
    initial $readmemh(COEF_FILE, coef_rom);

    // index width
    localparam int IDX_W = (N <= 2) ? 1 : $clog2(N);

    logic [IDX_W-1:0] idx;

    // -----------------------------
    // One-stage skid buffer regs (holds one sample when downstream stalls)
    // -----------------------------
    logic                    v_reg;
    logic                    last_reg;
    logic signed [DATA_W-1:0] x_reg;
    logic [COEF_W-1:0]        w_reg;

    wire in_fire  = s_axis_tvalid && s_axis_tready;
    wire out_fire = m_axis_tvalid && m_axis_tready;

    // ready when buffer empty OR downstream ready to accept current output
    assign s_axis_tready = (!v_reg) || m_axis_tready;

    assign m_axis_tvalid = v_reg;
    assign m_axis_tlast  = last_reg;

    // -----------------------------
    // Multiply + rounding + scaling
    // w is Q1.(COEF_W-1), so shift right by (COEF_W-1)
    // -----------------------------
    localparam int SHIFT = (COEF_W-1);

    // extend coef by 1 bit to keep it positive in signed math
    logic signed [COEF_W:0] w_s;

    logic signed [DATA_W+COEF_W:0] prod;
    logic signed [DATA_W+COEF_W:0] prod_rnd;
    logic signed [DATA_W-1:0]      y_re;

    always_comb begin
        w_s = $signed({1'b0, w_reg});          // 0 .. ~1.0 in signed form

        prod = x_reg * w_s;

        // rounding before shift (if SHIFT>=1)
        if (SHIFT >= 1)
            prod_rnd = prod + (1 <<< (SHIFT-1));
        else
            prod_rnd = prod;

        y_re = prod_rnd >>> SHIFT;

        // output complex: imag=0, real=windowed sample
        m_axis_tdata = { {DATA_W{1'b0}}, y_re };
    end

    // -----------------------------
    // Control: latch input, update idx, generate/pass tlast
    // -----------------------------
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            v_reg    <= 1'b0;
            last_reg <= 1'b0;
            x_reg    <= '0;
            w_reg    <= '0;
            idx      <= '0;
        end else begin
            // if output consumed and no new input replaces it, clear valid
            if (out_fire && !in_fire)
                v_reg <= 1'b0;

            // accept new input (either buffer empty, or downstream ready)
            if (in_fire) begin
                x_reg <= $signed(s_axis_tdata);
                w_reg <= coef_rom[idx];
                v_reg <= 1'b1;

                if (USE_S_TLAST) begin
                    last_reg <= s_axis_tlast;

                    // reset idx on incoming frame end
                    if (s_axis_tlast)
                        idx <= '0;
                    else if (idx == N-1)
                        idx <= '0;      // safety wrap
                    else
                        idx <= idx + 1'b1;

                end else begin
                    last_reg <= (idx == N-1);

                    if (idx == N-1)
                        idx <= '0;
                    else
                        idx <= idx + 1'b1;
                end
            end
        end
    end

endmodule
