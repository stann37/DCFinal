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

    logic signed [8:0] bass_gain; // Q4.4 Fixed Point
    logic signed [8:0] treb_gain;

    always_comb begin
        case (i_level_treble)
            3'd0: treb_gain = 9'b00000_0100; // 0.25 
            3'd1: treb_gain = 9'b00000_1000; // 0.50
            3'd2: treb_gain = 9'b00000_1100; // 0.75
            3'd3: treb_gain = 9'b00001_0000; // 1.0
            3'd4: treb_gain = 9'b00001_0100; // 1.25
            3'd5: treb_gain = 9'b00001_1000; // 1.50
            3'd6: treb_gain = 9'b00001_1100; // 1.75
            3'd7: treb_gain = 9'b00010_0000; // 2.0
        endcase
        case (i_level_bass)
            3'd0: bass_gain = 9'b00000_0100; // 0.25 
            3'd1: bass_gain = 9'b00000_1000; // 0.50
            3'd2: bass_gain = 9'b00000_1100; // 0.75
            3'd3: bass_gain = 9'b00001_0000; // 1.0
            3'd4: bass_gain = 9'b00001_0100; // 1.25
            3'd5: bass_gain = 9'b00001_1000; // 1.50
            3'd6: bass_gain = 9'b00001_1100; // 1.75
            3'd7: bass_gain = 9'b00010_0000; // 2.0
        endcase
    end

    logic signed [15:0] lp_bass_reg; 
    logic signed [15:0] lp_wide_reg;
    logic signed [15:0] diff_bass;
    logic signed [15:0] diff_wide;

    logic signed [15:0] comp_bass;
    logic signed [15:0] comp_mid;
    logic signed [15:0] comp_treb;

    logic signed [15:0] next_wide;

    always_comb begin
        diff_bass = i_data - lp_bass_reg;
        comp_bass = lp_bass_reg + (diff_bass >>> 4); // ignore treb, mid

        diff_wide = i_data - lp_wide_reg;
        next_wide = lp_wide_reg + (diff_wide >>> 1); // ignore treb

        comp_mid  = next_wide - comp_bass;

        comp_treb = i_data - next_wide;
    end

    logic signed [24:0] bass_out;
    logic signed [24:0] mid_out;
    logic signed [24:0] treb_out;
    logic signed [24:0] summed_result;

    always_comb begin
        bass_out = comp_bass * bass_gain;
        treb_out = comp_treb * treb_gain;
        mid_out  = comp_mid <<< 4;
        summed_result = bass_out + mid_out + treb_out;
    end


    logic signed [24:0] final_shifted;
    logic signed [15:0] saturated_out;

    assign final_shifted = summed_result >>> 4;

    always_comb begin
        if (final_shifted > 25'd32767) 
            saturated_out = 16'd32767;
        else if (final_shifted < -25'd32768)
            saturated_out = -16'd32768;
        else
            saturated_out = final_shifted[15:0];
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            lp_bass_reg <= 16'd0;
            lp_wide_reg <= 16'd0;
            o_data      <= 16'd0;
            o_valid     <= 1'b0;
        end else begin
            o_valid <= i_valid;

            if (i_valid) begin
                lp_bass_reg <= comp_bass;
                lp_wide_reg <= lp_wide_reg + (diff_wide >>> 1); 

                o_data <= saturated_out;
            end
        end
    end
endmodule