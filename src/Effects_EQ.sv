module Effect_EQ (
    input  logic       i_clk,
    input  logic       i_rst_n,
    input  logic       i_valid,
    input  logic       i_enable,
    input  logic [2:0] i_level_treble,
    input  logic [2:0] i_level_bass,
    input  logic signed [15:0] i_data,
    output logic signed [15:0] o_data,
    output logic       o_valid
);

    // LUT for Q4.28 format biquad coefficients
    // y[n] = a0*x[n] + a1*x[n-1] + a2*x[n-2] – b1*y[n-1] – b2*y[n-2]

    logic signed [31:0] bass_a0, bass_a1, bass_a2, bass_b1, bass_b2; // 250 Hz
    logic signed [31:0] treb_a0, treb_a1, treb_a2, treb_b1, treb_b2; // 2500 Hz

    always_comb begin
        case (i_level_bass)
            3'd0: begin // -12dB
                bass_a0 = 32'd259330623; bass_a1 = -32'd500665367; bass_a2 = 32'd241938545; bass_b1 = -32'd499765381; bass_b2 = 32'd233733699;
            end
            3'd1: begin // -9dB
                bass_a0 = 
            end
            3'd2: begin // -6dB

            end
            3'd3: begin // -3dB

            end
            3'd4: begin // 0dB

            end
            3'd5: begin // +3dB

            end
            3'd6: begin // +6dB

            end
            3'd7: begin // +9dB

            end
        endcase

        case (i_level_treble)
            3'd0: begin // -12dB
                
            end
            3'd1: begin // -9dB

            end
            3'd2: begin // -6dB

            end
            3'd3: begin // -3dB

            end
            3'd4: begin // 0dB

            end
            3'd5: begin // +3dB

            end
            3'd6: begin // +6dB

            end
            3'd7: begin // +9dB

            end
        endcase
    end


endmodule


module Biquad_Filter (
    input logic i_clk,
    input logic i_rst_n,
    input logic i_valid,
    input logic signed [15:0] i_data,

    input  logic signed [31:0] i_b0,
    input  logic signed [31:0] i_b1,
    input  logic signed [31:0] i_b2,
    input  logic signed [31:0] i_a1,
    input  logic signed [31:0] i_a2,

    output logic signed [15:0] o_data,
    output logic o_valid
);

endmodule