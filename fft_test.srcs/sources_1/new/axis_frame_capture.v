`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2025 01:52:01 PM
// Design Name: 
// Module Name: axis_frame_capture
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


// axis_frame_capture.v - SIMULATION-ONLY file capture of one (or many) FFT frames.
// Writes one magnitude per line; writes "FRAME_END" at TLAST.

module axis_frame_capture#(
    parameter integer DATA_W           = 32,
    parameter integer FRAMES_TO_CAPTURE= 1,           // capture this many frames, then optional $stop
    parameter        FILENAME          = "fft_mag_capture.txt",
    parameter        STOP_WHEN_DONE    = 1            // 1 -> call $stop after last frame
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    // AXIS input
    input  wire [DATA_W-1:0]     s_tdata,
    input  wire                  s_tvalid,
    output wire                  s_tready,
    input  wire                  s_tlast
);

    // Always ready (no backpressure) for sim convenience
    assign s_tready = 1'b1;

    integer f;
    integer line_cnt;
    integer frame_cnt;
    reg     file_open;

    initial begin
        line_cnt  = 0;
        frame_cnt = 0;
        file_open = 1'b0;

        f = $fopen(FILENAME, "w");
        if (f == 0) begin
            $display("[%0t] ERROR axis_frame_capture_v2001: cannot open %s", $time, FILENAME);
        end else begin
            file_open = 1'b1;
            $display("[%0t] axis_frame_capture_v2001: opened %s", $time, FILENAME);
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            // keep file open; just reset counters
            line_cnt  <= 0;
            frame_cnt <= 0;
        end else if (file_open) begin
            if (s_tvalid) begin
                // write one magnitude per valid beat
                $fwrite(f, "%0d\n", s_tdata);
                line_cnt <= line_cnt + 1;
                // optional console echo for debug
                // $display("[%0t] CAP: %0d", $time, s_tdata);

                if (s_tlast) begin
                    frame_cnt <= frame_cnt + 1;
                    $fwrite(f, "FRAME_END\n");
                    $display("[%0t] axis_frame_capture_v2001: frame %0d done, %0d lines written",
                             $time, frame_cnt, line_cnt);
                    line_cnt <= 0;

                    if (frame_cnt >= FRAMES_TO_CAPTURE) begin
                        // close file and optionally stop sim
                        $fclose(f);
                        file_open <= 1'b0;
                        $display("[%0t] axis_frame_capture_v2001: closed %s (captured %0d frame(s))",
                                 $time, FILENAME, frame_cnt);
                        if (STOP_WHEN_DONE) begin
                            $display("[%0t] axis_frame_capture_v2001: calling $stop", $time);
                            $stop;
                        end
                    end
                end
            end
        end
    end

    // Safety timeout so you get a message if nothing shows up
    initial begin
        #1000000; // 1 ms sim time (adjust)
        if (file_open && frame_cnt == 0)
            $display("[%0t] WARNING axis_frame_capture_v2001: no data captured yet. Check reset/valid/last.", $time);
    end

endmodule

