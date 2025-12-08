module Effect_EQ (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,              // Trigger IN
    input  i_enable,
    input  [2:0] i_level_treble,
    input  [2:0] i_level_bass,
    input  signed [15:0] i_data,
    output logic signed [15:0] o_data,
    output logic o_valid         // Trigger OUT
);

    logic signed [8:0] bass_gain; // Q4.4 Fixed Point
    logic signed [8:0] treb_gain;

    always_comb begin
        case (i_level_treble)
            3'd0: treb_gain = 9'b00000_0000; // 0.0 (Total Cut)
            3'd1: treb_gain = 9'b00000_0100; // 0.25
            3'd2: treb_gain = 9'b00000_1000; // 0.50
            3'd3: treb_gain = 9'b00000_1100; // 0.75
            3'd4: treb_gain = 9'b00001_0000; // 1.0 (Flat)
            3'd5: treb_gain = 9'b00001_1000; // 1.50
            3'd6: treb_gain = 9'b00010_0000; // 2.00
            3'd7: treb_gain = 9'b00011_0000; // 3.00
        endcase
        case (i_level_bass)
            3'd0: bass_gain = 9'b00000_0000; // 0.0 (Total Cut)
            3'd1: bass_gain = 9'b00000_0100; // 0.25
            3'd2: bass_gain = 9'b00000_1000; // 0.50
            3'd3: bass_gain = 9'b00000_1100; // 0.75
            3'd4: bass_gain = 9'b00001_0000; // 1.0 (Flat)
            3'd5: bass_gain = 9'b00001_1000; // 1.50
            3'd6: bass_gain = 9'b00010_0000; // 2.00
            3'd7: bass_gain = 9'b00011_0000; // 3.00
        endcase
    end

    // 2nd Order Filter Registers (Stage 1 and Stage 2)
    logic signed [15:0] lp_bass_s1; 
    logic signed [15:0] lp_bass_s2; 
    
    logic signed [15:0] lp_wide_s1;
    logic signed [15:0] lp_wide_s2;

    // Filter Intermediates
    logic signed [15:0] w_bass_s1, w_bass_s2;
    logic signed [15:0] w_wide_s1, w_wide_s2;

    logic signed [15:0] comp_bass;
    logic signed [15:0] comp_mid;
    logic signed [15:0] comp_treb;

    always_comb begin
        // --- Bass Filter Chain (Narrow) ---
        // Alpha ~ 1/16 (>>> 4)
        w_bass_s1 = lp_bass_s1 + ((i_data - lp_bass_s1) >>> 4);
        w_bass_s2 = lp_bass_s2 + ((w_bass_s1 - lp_bass_s2) >>> 4);
        
        comp_bass = w_bass_s2; // Pure Bass

        // --- Wide Filter Chain (Bass + Mid) ---
        // Alpha ~ 1/2 (>>> 1)
        w_wide_s1 = lp_wide_s1 + ((i_data - lp_wide_s1) >>> 1);
        w_wide_s2 = lp_wide_s2 + ((w_wide_s1 - lp_wide_s2) >>> 1);

        // --- Band Separation ---
        // Mids = (Bass+Mids) - Bass
        // Treble = Input - (Bass+Mids)
        comp_mid  = w_wide_s2 - comp_bass;
        comp_treb = i_data - w_wide_s2;
    end

    logic signed [24:0] bass_out;
    logic signed [24:0] mid_out;
    logic signed [24:0] treb_out;
    logic signed [24:0] summed_result;

    always_comb begin
        bass_out = comp_bass * bass_gain;
        treb_out = comp_treb * treb_gain;
        mid_out  = comp_mid <<< 4; // Unity gain for Mids (matches Q4.4)
        
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
            lp_bass_s1 <= 16'd0;
            lp_bass_s2 <= 16'd0;
            lp_wide_s1 <= 16'd0;
            lp_wide_s2 <= 16'd0;
            o_data     <= 16'd0;
            o_valid    <= 1'b0;
        end else begin
            o_valid <= i_valid;
            lp_bass_s1 <= w_bass_s1;
            lp_bass_s2 <= w_bass_s2;
            lp_wide_s1 <= w_wide_s1;
            lp_wide_s2 <= w_wide_s2;
            if (i_valid) begin
                o_data <= saturated_out;
            end 
            else begin
                o_data <= o_data; 
            end
        end
    end
endmodule