module magnitude2 (
    input  wire         alck,
    input  wire         aresetn,

    input  wire         i_axis_tvalid,
    output wire         i_axis_tready,
    input  wire [31:0]  i_axis_tdata,
    input  wire         i_axis_tlast,

    output wire         o_axis_tvalid,
    input  wire         o_axis_tready,
    output wire [33:0]  o_axis_tdata,
    output wire         o_axis_tlast
);

    reg  [33:0] sum;
    reg         valid_reg;
    reg         tlast_reg;

    // Interpret FFT output halves as signed two's complement
    wire signed [15:0] im_s = i_axis_tdata[31:16];
    wire signed [15:0] re_s = i_axis_tdata[15:0];

    // Signed multiply; square is non-negative
    wire [31:0] re_sq = $signed(re_s) * $signed(re_s);
    wire [31:0] im_sq = $signed(im_s) * $signed(im_s);

    // Widen before add (keep full precision comfortably)
    wire [33:0] sum_next = {2'b0, re_sq} + {2'b0, im_sq};

    assign i_axis_tready = !valid_reg || o_axis_tready;
    assign o_axis_tvalid = valid_reg;
    assign o_axis_tdata  = sum;
    assign o_axis_tlast  = tlast_reg;

    always @(posedge alck or negedge aresetn) begin
        if (!aresetn) begin
            sum       <= 34'd0;
            valid_reg <= 1'b0;
            tlast_reg <= 1'b0;
        end else begin
            if (i_axis_tvalid && i_axis_tready) begin
                sum       <= sum_next;
                valid_reg <= 1'b1;
                tlast_reg <= i_axis_tlast;
            end else if (o_axis_tready && valid_reg) begin
                valid_reg <= 1'b0;
                tlast_reg <= 1'b0;
            end
        end
    end
endmodule
