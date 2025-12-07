module Effect_EQ (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,              // Trigger IN
    input  i_enable,
    input  [2:0] i_level_treble,
    input  [2:0] i_level_bass,
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output logic o_valid         // Trigger OUT
);

endmodule