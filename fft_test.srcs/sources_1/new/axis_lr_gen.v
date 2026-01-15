`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 03:51:02 PM
// Design Name: 
// Module Name: axis_lr_gen
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


module axis_lr_gen#(
    parameter integer CH_W       = 24,      // per-channel width (signed)
    parameter integer PHASE_W    = 32,      // NCO phase accumulator width
    parameter integer N_FFT      = 1024,    // your FFT length
    parameter integer M_BIN      = 21,      // desired FFT bin (0..N_FFT-1)
    parameter integer AMP        = 100000,  // amplitude in LSBs of CH_W
    parameter integer LUT_ADDR_W = 10       // 10 -> 1024-entry ROM (cleaner than 256)
)(
    input  wire        aclk,
    input  wire        aresetn,
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast
);

    // =========================
    // NCO phase increment (bin-locked): PHASE_INC = 2^PHASE_W * M_BIN / N_FFT
    // Use 64-bit math to avoid overflow (e.g., 1<<32 wraps in 32-bit).
    // =========================
    localparam [63:0] TWO_POW     = (64'd1 << PHASE_W);
    localparam [63:0] INC_64      = (TWO_POW * M_BIN) / N_FFT;
    localparam [PHASE_W-1:0] PHASE_INC = INC_64[PHASE_W-1:0];

    // =========================
    // Phase accumulator + LR state
    // =========================
    reg [PHASE_W-1:0] phase_acc;
    reg               is_left;   // 1 = next beat is LEFT (Re), 0 = RIGHT (Im)

    // =========================
    // Sine ROM (simulation build)
    // Width = CH_W so we never slice out-of-range. Depth = 2^LUT_ADDR_W.
    // =========================
    localparam integer LUT_DEPTH = (1 << LUT_ADDR_W);

    reg signed [CH_W-1:0] sine_rom [0:LUT_DEPTH-1];
    integer i;
    initial begin
        // Populate ROM with scaled sine: sin(2*pi*i/LUT_DEPTH) * AMP
        for (i = 0; i < LUT_DEPTH; i = i + 1) begin
            sine_rom[i] = $rtoi($sin(6.283185307179586 * i / LUT_DEPTH) * AMP);
        end
    end

    // Address from MSBs of phase accumulator (Verilog-2001 slice [MSB:LSB])
    wire [LUT_ADDR_W-1:0] addr   = phase_acc[PHASE_W-1 -: LUT_ADDR_W]; // if your tool dislikes -:, expand to [PHASE_W-1:PHASE_W-LUT_ADDR_W]
    // If your simulator doesn't support [-:], replace the above with:
    // wire [LUT_ADDR_W-1:0] addr = phase_acc[PHASE_W-1 : PHASE_W-LUT_ADDR_W];

    // +90° offset for cosine: add LUT_DEPTH/4
    wire [LUT_ADDR_W-1:0] addr_q = (addr + (LUT_DEPTH >> 2)) & (LUT_DEPTH - 1);

    wire signed [CH_W-1:0] sin_q = sine_rom[addr];    // Im
    wire signed [CH_W-1:0] cos_q = sine_rom[addr_q];  // Re

    // Sign-extend channel width to 32-bit AXI word
    wire [31:0] re32 = {{(32-CH_W){cos_q[CH_W-1]}}, cos_q};
    wire [31:0] im32 = {{(32-CH_W){sin_q[CH_W-1]}}, sin_q};

    // In simulation, TREADY can float X; if so, treat X as 1 so we advance.
    wire ready_i = (m_axis_tready === 1'bx) ? 1'b1 : m_axis_tready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            phase_acc     <= {PHASE_W{1'b0}};
            is_left       <= 1'b1;
            m_axis_tdata  <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            // Always try to send in sim
            m_axis_tvalid <= 1'b1;

            if (m_axis_tvalid && ready_i) begin
                // Emit LEFT then RIGHT; advance phase once per complex sample (after RIGHT)
                if (is_left) begin
                    // LEFT = Real (cos)
                    m_axis_tdata <= re32;
                    m_axis_tlast <= 1'b0;
                    is_left      <= 1'b0;
                end else begin
                    // RIGHT = Imag (sin)  (for real-only test, set to 32'd0)
                    m_axis_tdata <= im32;        // change to 32'd0 for mono/real stimulus
                    m_axis_tlast <= 1'b1;
                    is_left      <= 1'b1;

                    // advance phase after completing the complex sample
                    phase_acc    <= phase_acc + PHASE_INC;
                end
            end
        end
    end

endmodule