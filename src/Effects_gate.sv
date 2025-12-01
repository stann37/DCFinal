module Effect_Gate (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,              // Trigger IN
    input  i_enable,
    input  [2:0] i_level,
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output logic o_valid         // Trigger OUT
);

    logic signed [15:0] data_out_r;
    assign o_data = data_out_r;

    logic valid_r;
    assign o_valid = valid_r;

    logic signed [15:0] abs_data;
    assign abs_data = (i_data[15]) ? -i_data : i_data; 

    logic signed [15:0] threshold;
    always_comb begin
        case (i_level)
            3'd0: threshold = 16'd0;
            3'd1: threshold = 16'd300;
            3'd2: threshold = 16'd600;
            3'd3: threshold = 16'd1200;
            3'd4: threshold = 16'd2400;
            3'd5: threshold = 16'd4000;
            3'd6: threshold = 16'd8000;
            3'd7: threshold = 16'd15000;
            default: threshold = 16'd0;
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            data_out_r <= 16'd0;
            valid_r    <= 1'b0;
        end else begin
            valid_r <= i_valid;
            
            if (i_valid) begin
                if (i_enable) begin
                    // GATE LOGIC
                    if (abs_data < threshold) 
                        data_out_r <= 16'd0; // Mute
                    else 
                        data_out_r <= i_data; // Pass through
                end else begin
                    // BYPASS
                    data_out_r <= i_data;
                end
            end
        end
    end

endmodule

// with decay factor
module Effect_Gate_1 (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,
    input  i_enable,
    input  [2:0] i_level,
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output logic o_valid
);

    logic signed [15:0] data_out_r;
    assign o_data = data_out_r;

    logic valid_r; 
    assign o_valid = valid_r;

    localparam [15:0] FIXED_DECAY_MULTIPLIER = 16'hFFFC;

    logic signed [15:0] abs_data;
    assign abs_data = (i_data[15]) ? -i_data : i_data; 
    
    logic [15:0] decay_factor_r, decay_factor_w; 
    
    logic signed [15:0] threshold;
    always_comb begin
        case (i_level)
            3'd0: threshold = 16'd0;     // Always open
            3'd1: threshold = 16'd300;
            3'd2: threshold = 16'd600;
            3'd3: threshold = 16'd1200;
            3'd4: threshold = 16'd2400;
            3'd5: threshold = 16'd4000;
            3'd6: threshold = 16'd8000;
            3'd7: threshold = 16'd15000; // Most sensitive (cuts most background noise)
            default: threshold = 16'd0;
        endcase
    end

    always_comb begin
        decay_factor_w = decay_factor_r;
        
        if (i_enable) begin
            if (abs_data >= threshold) begin
                decay_factor_w = 16'hFFFF; // 1.0 gain
            end else begin
                // BELOW THRESHOLD: Decay the current factor (Smooth Release)
                // decay_factor_w = decay_factor_r * FIXED_DECAY_MULTIPLIER
                decay_factor_w = (decay_factor_r * FIXED_DECAY_MULTIPLIER) >>> 16;
            end
        end else begin
            decay_factor_w = 16'hFFFF;
        end
    end

    // --- 3. Sequential Logic: Update Data and Factors ---
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            data_out_r     <= 16'd0;
            valid_r        <= 1'b0;
            decay_factor_r <= 16'hFFFF; // Start fully open (1.0 gain)
        end else begin
            valid_r <= i_valid;
            
            if (i_valid) begin
                decay_factor_r <= decay_factor_w;

                if (i_enable) begin
                    data_out_r <= (i_data * decay_factor_r) >>> 16;
                end else begin
                    data_out_r <= i_data;
                end
            end
        end
    end

endmodule

// with attack and release dynamics
module Effect_Gate_2 (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,              // "New Sample" Strobe
    input  i_enable,             // Switch[0]
    input  [2:0] i_level,        // Controls Threshold (0-7)
    input  signed [15:0] i_data, // Audio In
    output signed [15:0] o_data, // Audio Out
    output logic o_valid         // Delayed "New Sample" Strobe
);

    // --- Output Registers ---
    logic signed [15:0] data_out_r;
    logic valid_r;
    assign o_data  = data_out_r;
    assign o_valid = valid_r;

    // ============================================================
    // 1. ABSOLUTE VALUE (Magnitude)
    // ============================================================
    logic signed [15:0] abs_data;
    assign abs_data = (i_data[15]) ? -i_data : i_data;

    // ============================================================
    // 2. ENVELOPE DETECTOR (Leaky Integrator)
    // ============================================================
    // This creates a smooth "average" of the volume.
    // Logic: New_Env = Old_Env + alpha * (Input - Old_Env)
    // We implement alpha as a bit shift (>>> 7 divides by 128) for efficiency.
    logic signed [15:0] env_r;
    logic signed [15:0] env_next;
    
    // Difference between current absolute level and stored envelope
    logic signed [15:0] env_diff;
    assign env_diff = abs_data - env_r;

    always_comb begin
        // Update envelope: Move existing envelope slightly towards the current input magnitude
        // Using >>> 7 (divide by 128) creates a fast smoothing filter (~2-3ms response)
        env_next = env_r + (env_diff >>> 7);
    end

    // ============================================================
    // 3. THRESHOLD MAPPING
    // ============================================================
    // Determines the level at which the gate opens
    logic signed [15:0] threshold;
    always_comb begin
        case (i_level)
            3'd0: threshold = 16'd0;     // Always open
            3'd1: threshold = 16'd200;
            3'd2: threshold = 16'd500;
            3'd3: threshold = 16'd1000;
            3'd4: threshold = 16'd2500;
            3'd5: threshold = 16'd4500;
            3'd6: threshold = 16'd8000;
            3'd7: threshold = 16'd14000; 
            default: threshold = 16'd0;
        endcase
    end

    // ============================================================
    // 4. GAIN DYNAMICS (Attack & Release)
    // ============================================================
    // Tracks current gain (0.0 to 1.0) in Q0.16 format.
    // 16'hFFFF represents Gain = 1.0 (Fully Open)
    // 16'h0000 represents Gain = 0.0 (Fully Closed)
    logic [15:0] gain_r, gain_next;
    
    // Release Constant: How fast it fades out. (0.9995 per sample)
    localparam [15:0] RELEASE_COEFF = 16'hFFEF; 
    
    // Attack Shift: Controls how fast it opens. 
    // >>> 5 is fairly fast attack. >>> 8 would be slower "fade in".
    localparam integer ATTACK_SHIFT = 5;

    always_comb begin
        if (!i_enable) begin
            gain_next = 16'hFFFF; // Bypass: Locked at 1.0
        end else begin
            if (env_r >= threshold) begin
                // --- ATTACK PHASE (Opening) ---
                // If Envelope is loud, ramp gain towards 1.0
                // Formula: Gain += (Target - Current) / Speed
                if (gain_r < 16'hFFFF)
                    gain_next = gain_r + ((16'hFFFF - gain_r) >>> ATTACK_SHIFT);
                else
                    gain_next = 16'hFFFF; // Clamped at max
            end else begin
                // --- RELEASE PHASE (Closing) ---
                // If Envelope is quiet, multiply gain by decay factor
                // Formula: Gain = Gain * Release_Coeff
                gain_next = (gain_r * RELEASE_COEFF) >>> 16;
            end
        end
    end

    // ============================================================
    // 5. SEQUENTIAL LOGIC
    // ============================================================
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            valid_r    <= 1'b0;
            data_out_r <= 16'd0;
            env_r      <= 16'd0;
            gain_r     <= 16'hFFFF; // Start open
        end else begin
            // 1. Pipeline Valid Signal
            valid_r <= i_valid;

            // 2. Process DSP only on "Data Valid" pulse
            if (i_valid) begin
                // Update State
                env_r  <= env_next;
                gain_r <= gain_next;

                // Final Output Calculation
                if (i_enable) begin
                    // Apply the dynamic gain to the audio input
                    // (Input * Gain) >>> 16 to adjust for Q-format
                    data_out_r <= (i_data * gain_r) >>> 16;
                end else begin
                    data_out_r <= i_data;
                end
            end
        end
    end

endmodule