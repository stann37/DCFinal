module Effect_Compressor (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,              // "New Sample" Strobe
    input  i_enable,             // Switch[1]
    input  [2:0] i_level,        // Controls Compression Amount (0-7)
    input  signed [15:0] i_data, // Audio In
    output signed [15:0] o_data, // Audio Out
    output logic o_valid         // Delayed Strobe
);

    // --- Output Registers ---
    logic signed [15:0] data_out_r;
    logic valid_r;
    assign o_data  = data_out_r;
    assign o_valid = valid_r;

    // ============================================================
    // 1. ENVELOPE DETECTOR (Same as Gate)
    // ============================================================
    logic signed [15:0] abs_data;
    assign abs_data = (i_data[15]) ? -i_data : i_data;

    logic signed [15:0] env_r, env_next;
    logic signed [15:0] env_diff;
    assign env_diff = abs_data - env_r;

    // Fast smoothing for envelope (approx 2ms)
    always_comb env_next = env_r + (env_diff >>> 7);

    // ============================================================
    // 2. COMPRESSION PARAMETERS (Based on i_level)
    // ============================================================
    // Threshold: Signal must be louder than this to trigger compression
    // Target Gain Min: The lowest the gain is allowed to drop (Heavy vs Light)
    // Makeup Gain: Fixed boost to make up for the volume we lost
    
    logic signed [15:0] threshold;
    logic [15:0] target_gain_min; // Q0.16 format
    logic [15:0] makeup_gain;     // Q4.12 format (allows gain > 1.0)

    always_comb begin
        case (i_level)
            // Light Compression (Vocals/Acoustic)
            3'd0: begin threshold = 16'd20000; target_gain_min = 16'hE000; makeup_gain = 16'h1100; end // ~1.06x
            3'd1: begin threshold = 16'd16000; target_gain_min = 16'hC000; makeup_gain = 16'h1200; end // ~1.12x
            3'd2: begin threshold = 16'd12000; target_gain_min = 16'hA000; makeup_gain = 16'h1400; end // ~1.25x
            
            // Medium Compression (Rock Guitar/Bass)
            3'd3: begin threshold = 16'd8000;  target_gain_min = 16'h8000; makeup_gain = 16'h1800; end // ~1.5x
            3'd4: begin threshold = 16'd6000;  target_gain_min = 16'h6000; makeup_gain = 16'h1C00; end // ~1.75x
            3'd5: begin threshold = 16'd4000;  target_gain_min = 16'h5000; makeup_gain = 16'h2000; end // ~2.0x
            
            // Heavy Limiting (Metal/Solo)
            3'd6: begin threshold = 16'd3000;  target_gain_min = 16'h4000; makeup_gain = 16'h2800; end // ~2.5x
            3'd7: begin threshold = 16'd2000;  target_gain_min = 16'h3000; makeup_gain = 16'h3000; end // ~3.0x
        endcase
    end

    // ============================================================
    // 3. GAIN CALCULATION
    // ============================================================
    logic [15:0] current_gain_r, next_gain;
    logic [15:0] target_gain;

    // Attack/Release Constants
    // Attack (Gain Reduction): Fast but not instant (prevents clicking)
    localparam ATTACK_SHIFT = 6; 
    // Release (Gain Recovery): Slow recovery
    localparam RELEASE_SHIFT = 9;

    always_comb begin
        if (!i_enable) begin
            next_gain = 16'hFFFF; // Bypass: Gain = 1.0
        end else begin
            // A. Determine Target Gain
            if (env_r > threshold) begin
                // We are ABOVE threshold -> Reduce Gain
                // Simple linear mapping: As Env goes up, Target Gain goes down
                // (This avoids complex division)
                target_gain = target_gain_min; 
            end else begin
                // We are BELOW threshold -> Gain should recover to 1.0
                target_gain = 16'hFFFF;
            end

            // B. Smoothly move Current Gain towards Target Gain
            if (current_gain_r > target_gain) begin
                // COMPRESSING (Attack phase): Drop gain downwards
                // Gain = Gain - (Difference / Speed)
                next_gain = current_gain_r - ((current_gain_r - target_gain) >>> ATTACK_SHIFT);
            end else begin
                // RECOVERING (Release phase): Rise gain upwards
                next_gain = current_gain_r + ((target_gain - current_gain_r) >>> RELEASE_SHIFT);
            end
        end
    end

    // ============================================================
    // 4. SEQUENTIAL LOGIC
    // ============================================================
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            valid_r        <= 1'b0;
            data_out_r     <= 16'd0;
            env_r          <= 16'd0;
            current_gain_r <= 16'hFFFF; // Start at 1.0
        end else begin
            // 1. Pipeline Valid
            valid_r <= i_valid;

            if (i_valid) begin
                // 2. Update State
                env_r          <= env_next;
                current_gain_r <= next_gain;

                if (i_enable) begin
                    // 3. Apply Compression Gain (Reduction)
                    // Result = Input * Current_Gain (Q16.16)
                    logic signed [31:0] compressed_signal;
                    compressed_signal = (i_data * current_gain_r) >>> 16;

                    // 4. Apply Makeup Gain (Boost)
                    // Makeup Gain is Q4.12 format. 
                    // Example: 16'h2000 = 2.0. 
                    // We multiply and then shift right by 12.
                    logic signed [31:0] final_signal;
                    final_signal = (compressed_signal * makeup_gain) >>> 12;

                    // 5. Hard Limiter (Saturation) to prevent overflow clipping
                    if (final_signal > 32'd32767)       data_out_r <= 16'd32767;
                    else if (final_signal < -32'd32768) data_out_r <= -16'd32768;
                    else                                data_out_r <= final_signal[15:0];

                end else begin
                    // BYPASS
                    data_out_r <= i_data;
                end
            end
        end
    end

endmodule