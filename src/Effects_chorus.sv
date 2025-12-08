module Effect_Chorus ( // try use M9K Block RAM
    input  logic         i_clk,
    input  logic         i_rst_n,
    input  logic         i_valid,
    input  logic         i_enable,
    input  [2:0]         i_level,
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output logic         o_valid
);

    localparam BUFFER_SIZE = 1024;
    logic signed [15:0] buffer [0:BUFFER_SIZE-1];
    
endmodule