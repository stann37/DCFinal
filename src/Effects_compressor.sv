module Effect_Compressor (
    input  logic             i_clk,
    input  logic             i_rst_n,
    input  logic             i_valid,   // Sync pulse from previous stage
    input  logic             i_enable,  // Switch to enable/bypass
    input  logic [2:0]       i_level,   // 0 (Light) to 7 (Heavy)
    input  signed [15:0]     i_data,    // Input Audio
    output logic signed [15:0] o_data,  // Output Audio
    output logic             o_valid    // Sync pulse to next stage
);

    logic signed [15:0] abs_data;
    assign abs_data = (i_data[15]) ? -i_data : i_data;

    logic signed [15:0] threshold;
    logic [3:0]         makeup_shift; // Simple bit-shift for gain (0 to 15)

    always_comb begin
        case (i_level)
            // Lvl   Threshold (Lower = More Compression)   Makeup Gain (Shift)
            3'd0: begin threshold = 16'd28000;              makeup_shift = 4'd0; end // ~1.0x
            3'd1: begin threshold = 16'd24000;              makeup_shift = 4'd0; end // ~1.0x
            3'd2: begin threshold = 16'd20000;              makeup_shift = 4'd0; end // ~1.0x
            3'd3: begin threshold = 16'd16000;              makeup_shift = 4'd1; end // ~2.0x
            3'd4: begin threshold = 16'd12000;              makeup_shift = 4'd1; end // ~2.0x
            3'd5: begin threshold = 16'd8000;               makeup_shift = 4'd2; end // ~4.0x
            3'd6: begin threshold = 16'd4000;               makeup_shift = 4'd2; end // ~4.0x
            3'd7: begin threshold = 16'd2000;               makeup_shift = 4'd3; end // ~8.0x
            default: begin threshold = 16'd28000;           makeup_shift = 4'd0; end
        endcase
    end

    // 3. Compression Logic
    logic signed [15:0] compressed_abs;
    logic signed [15:0] diff;
    logic signed [15:0] gain_adjusted;
    
    always_comb begin
        if (abs_data > threshold) begin
            // SIGNAL IS LOUD: Compress it
            diff = abs_data - threshold;
            
            // "Ratio" is 4:1. We divide the excess by 4 (shift right 2)
            // Formula: Output = Threshold + (Excess / Ratio)
            compressed_abs = threshold + (diff >>> 2); 
        end else begin
            // SIGNAL IS QUIET: Pass it linearly
            compressed_abs = abs_data;
        end
    end

    // 4. Output Register & Gain Application
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_data  <= 16'd0;
            o_valid <= 1'b0;
        end else begin
            o_valid <= i_valid; // Pass the sync pulse down the chain

            if (i_valid) begin
                if (i_enable) begin
                    // Apply Makeup Gain (Sustain)
                    // We prevent overflow by checking MSB before shifting, 
                    // but for simplicity here we rely on the compressor squashing enough 
                    // headroom to allow the shift.
                
                    gain_adjusted = compressed_abs <<< makeup_shift;

                    // Restore the original Sign
                    if (i_data[15]) // Was originally negative
                        o_data <= -gain_adjusted;
                    else            // Was originally positive
                        o_data <= gain_adjusted;
                        
                end else begin
                    // BYPASS
                    o_data <= i_data;
                end
            end
        end
    end

endmodule