`timescale 1ns/1ps
module Triangle_generator (
    input                i_clk,
    input                i_rst_n,
    input                i_start,
    input         [2:0]  i_freq,
    output signed [15:0] o_tri
);

    localparam S_IDLE = 0;
    localparam S_GEN  = 1;

    logic signed [15:0] tri_data_r, tri_data_w;
    logic [14:0] cnt_r, cnt_w;
    logic [2:0] freq_r, freq_w;
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
                        3'd0: begin  // 1 Hz
                            step_w = 2;
                            cnt_max_w = 16000;
                        end
                        3'd1: begin  // 2 Hz
                            step_w = 4;
                            cnt_max_w = 8000;
                        end
                        3'd2: begin  // 3 Hz
                            step_w = 6;
                            cnt_max_w = 5333;
                        end
                        3'd3: begin // 4 Hz
                            step_w = 8;
                            cnt_max_w = 4000;
                        end
                        3'd4: begin  // 5 Hz
                            step_w = 10; 
                            cnt_max_w = 3200;
                        end
                        3'd5: begin  // 6 Hz
                            step_w = 12; 
                            cnt_max_w = 2666
                        end
                        3'd6: begin  // 7 Hz
                            step_w = 14; 
                            cnt_max_w = 2285;
                        end
                        3'd7: begin  // 8 Hz
                            step_w = 16; 
                            cnt_max_w = 2000;
                        end
                        default: begin 
                            step_w = 4;
                            cnt_max_w = 16000;
                        end
                    endcase
                end
            end 
            S_GEN: begin
                if (!i_start) begin
                    state_w = S_IDLE;
                    tri_data_w = 16'h7000;
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
            tri_data_r <= 16'sh7000;
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