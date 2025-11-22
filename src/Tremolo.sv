module tremolo (
    input                i_clk,
    input                i_rst_n,
    input  signed [15:0] i_signal,
    input                i_sel,
    input                i_start,
    input         [1:0]  i_rate,  // 00 = 1, 01 = 2, 10 = 3, 11 = 4
    input         [1:0]  i_depth, // 00 = 0%, 01 = 25%, 10 = 50%, 11 = 100%
    output signed [15:0] o_signal
);

    localparam S_IDLE = 0;
    localparam S_SEL  = 1;
    localparam S_RUN  = 2;

    reg [1:0] state_r, state_w;
    reg [1:0] rate_r, rate_w;
    reg [1:0] depth_r, depth_w;

    // TODO: output = input × (1 - depth/2 + depth/2 × LFO_waveform)
    // TODO: LFO_waveform 

    always_comb begin
        state_w = state_r;
        case (state_r)
            S_IDLE: begin
                if (i_sel) begin
                    state_w = S_SEL;
                end
            end 
            S_SEL: begin
                if (i_start) begin
                    state_w = S_RUN;
                end
                else if (!i_sel) begin
                    state_w = S_IDLE;
                end
                else begin
                    rate_w = i_rate;
                    depth_w = i_depth;
                end
            end 
            S_RUN: begin
                
            end
        endcase
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state_r <= S_IDLE;
            rate_r <= 0;
            depth_r <= 0;
        end
        else begin
            state_r <= state_w;
            rate_r <= rate_w;
            depth_r <= depth_w;
        end
    end

    
endmodule