`timescale 1ns/1ps
module Triangle_generator (
    input                i_clk,
    input                i_rst_n,
    input                i_start,
    input                i_stop,
    input         [1:0]  i_freq,
    output signed [15:0] o_tri
);

    localparam S_IDLE = 0;
    localparam S_GEN  = 1;

    logic signed [15:0] tri_data_r, tri_data_w;
    logic [14:0] cnt_r, cnt_w;
    logic [1:0] freq_r, freq_w;
    logic pos_r, pos_w;
    logic state_r, state_w;

    logic [4:0] step_r, step_w;
    logic [15:0] cnt_max_r, cnt_max_w;

    assign o_tri = tri_data_r;

    always_comb begin
        tri_data_w = tri_data_r;
        freq_w = freq_r;
        state_w = state_r;
        pos_w = pos_r;
        cnt_w = cnt_r;
        step_w = step_r;
        cnt_max_w= cnt_max_r;
        case (state_r)
            S_IDLE: begin
                if (i_start) begin
                    freq_w = i_freq;
                    state_w = S_GEN;
                    case (i_freq)
                        2'b01: begin 
                            step_w = 4;
                            cnt_max_w = 16000;
                        end
                        2'b10: begin 
                            step_w = 8;
                            cnt_max_w = 8000;
                        end
                        2'b11: begin 
                            step_w = 16;
                            cnt_max_w = 4000;
                        end
                        default: begin 
                            step_w = 4;
                            cnt_max_w = 16000;
                        end
                    endcase
                end
            end 
            S_GEN: begin
                if (i_stop) begin
                    state_w = S_IDLE;
                    tri_data_w = 16'h7fff;
                    pos_w = 0;
                    cnt_w = 0;
                end
                else begin
                    if (cnt_r == cnt_max_r) begin
                        pos_w = !pos_r;
                        cnt_w = 0;
                    end
                    else begin
                        if (pos_r) tri_data_w = tri_data_r + step_r;
                        else tri_data_w = tri_data_r - step_r;
                        cnt_w = cnt_r + 1;
                    end
                end
            end 
        endcase
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tri_data_r <= 16'sh7fff;
            state_r <= S_IDLE;
            freq_r <= 0;
            pos_r <= 0;
            cnt_r <= 0;
            step_r <= 0;
            cnt_max_r <= 0;
        end
        else begin
            tri_data_r <= tri_data_w;
            state_r <= state_w;
            freq_r <= freq_w;
            pos_r <= pos_w;
            cnt_r <= cnt_w;
            step_r <= step_w;
            cnt_max_r <= cnt_max_w;
        end
    end
    
endmodule