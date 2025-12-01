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

module Effect_Gate_1 (
    input  i_clk,
    input  i_rst_n,
    input  i_valid,              // Trigger IN from previous stage (or ADC)
    input  i_enable,             // Switch[0]
    input  [2:0] i_level,        // Parameter (0-7) to control Threshold
    input  signed [15:0] i_data,
    output signed [15:0] o_data,
    output logic o_valid         // Trigger OUT to next stage
);

    logic signed [15:0] data_out_r;
    assign o_data = data_out_r;

    // --- Pipelining Registers ---
    logic valid_r; 
    assign o_valid = valid_r;

    // --- Fixed Release Factor (Q0.16) ---
    // This value determines how fast the gate closes when the signal is quiet.
    // 16'hFFFF = 1.0 (no decay, hard gate). 16'hFFFC is a very slow, smooth fade.
    localparam [15:0] FIXED_DECAY_MULTIPLIER = 16'hFFFC;

    // --- Dynamic Registers for DSP ---
    logic signed [15:0] abs_data;
    // Calculate Absolute Value (Magnitude)
    assign abs_data = (i_data[15]) ? -i_data : i_data; 
    
    // Tracks the current gain (0.0 to 1.0) applied to the input signal (Q0.16 format)
    logic [15:0] decay_factor_r, decay_factor_w; 
    
    // --- 1. Threshold Mapping (Controlled by i_level) ---
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

    // --- 2. Combinatorial Decay Factor Logic ---
    always_comb begin
        decay_factor_w = decay_factor_r;
        
        if (i_enable) begin
            if (abs_data >= threshold) begin
                // ABOVE THRESHOLD: Snap open instantly (Attack = 0)
                decay_factor_w = 16'hFFFF; // 1.0 gain
            end else begin
                // BELOW THRESHOLD: Decay the current factor (Smooth Release)
                // decay_factor_w = decay_factor_r * FIXED_DECAY_MULTIPLIER
                decay_factor_w = (decay_factor_r * FIXED_DECAY_MULTIPLIER) >>> 16;
            end
        end else begin
            // BYPASS: Keep the factor at 1.0 to pass signal through unmodified
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
            // 1. Pipeline the valid signal
            valid_r <= i_valid;
            
            if (i_valid) begin
                // 2. Update the decay factor register
                decay_factor_r <= decay_factor_w;

                if (i_enable) begin
                    // 3. Apply the current gain (decay_factor_r) to the input audio
                    // Output = Input * Current Gain (Q16.16 math, shift right by 16)
                    data_out_r <= (i_data * decay_factor_r) >>> 16;
                end else begin
                    // BYPASS
                    data_out_r <= i_data;
                end
            end
        end
    end

endmodule