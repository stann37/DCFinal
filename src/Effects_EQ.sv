module Effect_EQ_gemini (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_valid,            // Input Valid
    input  wire        i_enable,           // Bypass (1 = EQ Active)
    input  wire [2:0]  i_level_treble,     // 0=Mute, 4=Flat, 7=Boost
    input  wire [2:0]  i_level_bass,
    input  wire signed [15:0] i_data,
    output logic signed [15:0] o_data,
    output logic       o_valid
);

    // ========================================================================
    // 1. PARAMETERS & COEFFICIENTS (Q2.14 Fixed Point)
    // ========================================================================
    // 1.0 (Unity) = 16384
    
    // Filter 1: Wide Low Pass (2.5 kHz)
    localparam signed [15:0] W_B0 =  16'd725; 
    localparam signed [15:0] W_B1 =  16'd1451;
    localparam signed [15:0] W_B2 =  16'd725;
    localparam signed [15:0] W_A1 = -16'd21700;
    localparam signed [15:0] W_A2 =  16'd8267;

    // Filter 2: Bass Low Pass (400 Hz)
    localparam signed [15:0] B_B0 =  16'd24; 
    localparam signed [15:0] B_B1 =  16'd48;
    localparam signed [15:0] B_B2 =  16'd24;
    localparam signed [15:0] B_A1 = -16'd30948;
    localparam signed [15:0] B_A2 =  16'd14669;

    localparam signed [8:0] GAIN_MID = 9'd16; // 1.0 in Q4.4

    // ========================================================================
    // 2. INTERNAL SIGNALS & REGISTERS
    // ========================================================================

    // -- Gain Decodes --
    logic signed [8:0] gain_treble;
    logic signed [8:0] gain_bass;

    // -- Filter 1 (Wide) States --
    // 40-bit accumulators to prevent overflow during IIR feedback
    logic signed [39:0] w1_wide, w2_wide; 
    logic signed [39:0] w1_wide_next, w2_wide_next;
    logic signed [39:0] y_calc_wide;
    logic signed [15:0] out_wide;

    // -- Filter 2 (Bass) States --
    logic signed [39:0] w1_bass, w2_bass;
    logic signed [39:0] w1_bass_next, w2_bass_next;
    logic signed [39:0] y_calc_bass;
    logic signed [15:0] out_bass;

    // -- Pipeline Alignment Registers --
    logic signed [15:0] p_data_d1;     // Input delayed by 1 cycle
    logic signed [15:0] p_data_d2;     // Input delayed by 2 cycles
    logic signed [15:0] p_wide_d1;     // Wide LPF output delayed by 1 cycle
    
    // -- Valid Pipeline --
    logic [2:0] valid_pipe;

    // -- Summation & Output --
    logic signed [15:0] band_bass, band_mid, band_treb;
    logic signed [24:0] sum_mixed;     // 16bit + 9bit gain = 25 bits
    logic signed [24:0] sum_shifted;
    logic signed [15:0] out_saturated;

    // ========================================================================
    // 3. COMBINATIONAL LOGIC (Math & Next State Calculation)
    // ========================================================================

    always_comb begin
        // --- A. Decode Gains ---
        case (i_level_treble)
            3'd0: gain_treble = 9'd0;
            3'd1: gain_treble = 9'd4;
            3'd2: gain_treble = 9'd8;
            3'd3: gain_treble = 9'd12;
            3'd4: gain_treble = 9'd16;
            3'd5: gain_treble = 9'd24;
            3'd6: gain_treble = 9'd32;
            3'd7: gain_treble = 9'd48;
            default: gain_treble = 9'd16;
        endcase

        case (i_level_bass)
            3'd0: gain_bass = 9'd0;
            3'd1: gain_bass = 9'd4;
            3'd2: gain_bass = 9'd8;
            3'd3: gain_bass = 9'd12;
            3'd4: gain_bass = 9'd16;
            3'd5: gain_bass = 9'd24;
            3'd6: gain_bass = 9'd32;
            3'd7: gain_bass = 9'd48;
            default: gain_bass = 9'd16;
        endcase

        // --- B. Filter 1 Math (Wide LPF) ---
        // y[n] = b0*x + w1
        y_calc_wide = (i_data * W_B0) + w1_wide;
        
        // Next w1 = b1*x - a1*y + w2
        // Note: y_calc_wide >>> 14 converts Q17.14 back to Q17.0 Integer
        w1_wide_next = (i_data * W_B1) - ((y_calc_wide >>> 14) * W_A1) + w2_wide;
        
        // Next w2 = b2*x - a2*y
        w2_wide_next = (i_data * W_B2) - ((y_calc_wide >>> 14) * W_A2);

        // --- C. Filter 2 Math (Bass LPF) ---
        // Input to this filter is 'out_wide' (Registered Output of Filter 1)
        y_calc_bass = (out_wide * B_B0) + w1_bass;
        
        w1_bass_next = (out_wide * B_B1) - ((y_calc_bass >>> 14) * B_A1) + w2_bass;
        w2_bass_next = (out_wide * B_B2) - ((y_calc_bass >>> 14) * B_A2);

        // --- D. Band Separation ---
        // These use the delayed pipeline registers to ensure phase coherence
        // Bass = Output of Bass Filter
        // Mid  = (Wide Filter Output) - (Bass Filter Output)
        // Treb = (Original Input)     - (Wide Filter Output)
        
        band_bass = out_bass;
        band_mid  = p_wide_d1 - out_bass;
        band_treb = p_data_d2 - p_wide_d1;

        // --- E. Gain & Sum ---
        sum_mixed = (band_bass * gain_bass) + 
                    (band_mid  * GAIN_MID)  + 
                    (band_treb * gain_treble);
        
        sum_shifted = sum_mixed >>> 4; // Remove Q4.4 gain factor

        // --- F. Saturation ---
        if (sum_shifted > 25'd32767)       out_saturated = 16'd32767;
        else if (sum_shifted < -25'd32768) out_saturated = -16'd32768;
        else                               out_saturated = sum_shifted[15:0];
    end

    // ========================================================================
    // 4. SEQUENTIAL LOGIC (Registers & State Updates)
    // ========================================================================

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            w1_wide    <= '0;
            w2_wide    <= '0;
            out_wide   <= '0;
            
            w1_bass    <= '0;
            w2_bass    <= '0;
            out_bass   <= '0;
            
            p_data_d1  <= '0;
            p_data_d2  <= '0;
            p_wide_d1  <= '0;
            
            o_data     <= '0;
            valid_pipe <= '0;
            o_valid    <= 1'b0;
        end else begin
            
            // Valid signal shift register
            valid_pipe <= {valid_pipe[1:0], i_valid};
            o_valid    <= valid_pipe[1]; // Output valid after 3-stage pipe

            // --- Stage 1 Update (Triggered by i_valid) ---
            if (i_valid) begin
                if (i_enable) begin
                    w1_wide  <= w1_wide_next;
                    w2_wide  <= w2_wide_next;
                    out_wide <= y_calc_wide[29:14]; // Take Integer part
                end else begin
                    // In bypass, maintain flow but don't filter
                    out_wide <= i_data; 
                end
                // Always capture input for delay line
                p_data_d1 <= i_data;
            end

            // --- Stage 2 Update (Triggered by Stage 1 Valid) ---
            if (valid_pipe[0]) begin
                if (i_enable) begin
                    w1_bass  <= w1_bass_next;
                    w2_bass  <= w2_bass_next;
                    out_bass <= y_calc_bass[29:14];
                end else begin
                    out_bass <= out_wide; // Bypass
                end
                // Pipeline alignments
                p_wide_d1 <= out_wide; // Delay Wide output by 1
                p_data_d2 <= p_data_d1; // Delay Input by 1 more (Total 2)
            end

            // --- Stage 3 Update (Triggered by Stage 2 Valid) ---
            if (valid_pipe[1]) begin
                if (i_enable) begin
                    o_data <= out_saturated;
                end else begin
                    o_data <= p_data_d2; // Total Bypass (Pass delayed input)
                end
            end
        end
    end

endmodule