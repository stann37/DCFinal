module Effect_Chorus (
    input  logic         i_clk,
    input  logic         i_rst_n,
    input  logic         i_valid,
    input  logic         i_enable,
    input  [2:0]         i_level,
    input  signed [15:0] i_data,

    input  signed [15:0] i_sram_rdata, // Data read FROM SRAM
    output logic  [19:0] o_sram_addr,  // Address request
    output logic         o_sram_we_n,  // 0=Write, 1=Read
    output signed [15:0] o_sram_wdata, // Data to write

    output signed [15:0] o_data,
    output logic         o_valid
);
    // we need 30 ms of delay buffer: 9600 samples
    localparam ADDR_START = 20'd0;
    localparam ADDR_END   = 20'd9599;

    
endmodule