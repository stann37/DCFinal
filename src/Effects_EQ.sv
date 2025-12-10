module Effect_EQ (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_valid,
    input  wire        i_enable,
    input  wire [2:0]  i_level_treble,     // 0=Mute, 4=Flat, 7=Boost
    input  wire [2:0]  i_level_bass,
    input  wire signed [15:0] i_data,
    output logic signed [15:0] o_data,
    output logic       o_valid
);

endmodule