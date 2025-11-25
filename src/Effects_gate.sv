module Effect_Gate (
    input  i_clk,             // Audio Bit Clock (BCLK)
    input  i_rst_n,
    input  i_valid,           // "New Sample" Strobe
    input  i_enable,          // Switch[0]: Is the effect ON?
    input  [2:0] i_level,     // FSM Parameter (0-7)
    input  signed [15:0] i_data, // Input Audio
    output signed [15:0] o_data  // Output Audio
);

    logic signed [15:0] data_out_r;
    assign o_data = data_out_r;

    // 1. Calculate Absolute Value (Magnitude)
    // We need this because -500 is just as "loud" as +500
    logic signed [15:0] abs_data;
    assign abs_data = (i_data < 0) ? -i_data : i_data;

    // 2. Determine Threshold based on i_level (0-7)
    logic signed [15:0] threshold;
    always_comb begin
        case (i_level)
            3'd0: threshold = 16'd100;   // Very low threshold
            3'd1: threshold = 16'd300;
            3'd2: threshold = 16'd600;
            3'd3: threshold = 16'd1200;
            3'd4: threshold = 16'd2400;
            3'd5: threshold = 16'd4000;
            3'd6: threshold = 16'd8000;
            3'd7: threshold = 16'd15000; // Very aggressive (cuts loud sounds)
            default: threshold = 16'd100;
        endcase
    end

    // 3. Process Data
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            data_out_r <= 16'd0;
        end else if (i_valid) begin
            if (i_enable) begin
                // GATE LOGIC: If signal is weaker than threshold, mute it.
                if (abs_data < threshold) 
                    data_out_r <= 16'd0; 
                else 
                    data_out_r <= i_data;
            end else begin
                // BYPASS: Just pass input to output
                data_out_r <= i_data;
            end
        end
    end

endmodule