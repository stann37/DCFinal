module VGA_Display (
    input  logic        i_clk_25mhz,    // VGA pixel clock
    input  logic        i_rst_n,
    input  logic        i_audio_clk,    // BCLK for audio samples
    input  logic        i_sample_valid, // New audio sample available
    input  signed [15:0] i_audio_data,  // Audio sample to display
    
    output logic [7:0]  o_VGA_R,
    output logic [7:0]  o_VGA_G,
    output logic [7:0]  o_VGA_B,
    output logic        o_VGA_HS,
    output logic        o_VGA_VS,
    output logic        o_VGA_BLANK_N,
    output logic        o_VGA_SYNC_N,
    output logic        o_VGA_CLK
);

    // VGA 640x480 @ 60Hz timing parameters
    localparam H_DISPLAY    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 800
    
    localparam V_DISPLAY    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 525
    
    // Waveform display area (centered, with margins)
    localparam WAVE_X_START = 40;
    localparam WAVE_X_END   = 600;  // 560 pixels wide
    localparam WAVE_Y_START = 100;
    localparam WAVE_Y_END   = 380;  // 280 pixels tall
    localparam WAVE_WIDTH   = WAVE_X_END - WAVE_X_START;  // 560
    localparam WAVE_HEIGHT  = WAVE_Y_END - WAVE_Y_START;  // 280
    localparam WAVE_CENTER  = WAVE_Y_START + (WAVE_HEIGHT / 2); // 240
    
    // VGA timing counters
    logic [9:0] h_count_r, h_count_w;
    logic [9:0] v_count_r, v_count_w;
    
    // Sync signals
    logic hsync, vsync;
    logic video_on;
    
    // Audio sample buffer - store 560 samples (one per horizontal pixel)
    logic signed [15:0] sample_buffer [0:WAVE_WIDTH-1];
    logic [9:0] write_addr_r, write_addr_w;
    
    // Cross clock domain for audio samples
    logic sample_valid_sync1, sample_valid_sync2;
    logic signed [15:0] audio_data_sync;
    
    assign o_VGA_CLK = i_clk_25mhz;
    assign o_VGA_SYNC_N = 1'b0;  // Not used in modern VGA
    
    //=======================================================================
    // VGA Timing Generator
    //=======================================================================
    always_comb begin
        // Horizontal counter
        if (h_count_r >= H_TOTAL - 1)
            h_count_w = 10'd0;
        else
            h_count_w = h_count_r + 10'd1;
        
        // Vertical counter
        if (h_count_r >= H_TOTAL - 1) begin
            if (v_count_r >= V_TOTAL - 1)
                v_count_w = 10'd0;
            else
                v_count_w = v_count_r + 10'd1;
        end else begin
            v_count_w = v_count_r;
        end
    end
    
    // Sync pulses (negative polarity for VGA standard)
    assign hsync = (h_count_r >= (H_DISPLAY + H_FRONT)) && 
                   (h_count_r < (H_DISPLAY + H_FRONT + H_SYNC));
    assign vsync = (v_count_r >= (V_DISPLAY + V_FRONT)) && 
                   (v_count_r < (V_DISPLAY + V_FRONT + V_SYNC));
    
    assign video_on = (h_count_r < H_DISPLAY) && (v_count_r < V_DISPLAY);
    
    assign o_VGA_HS = hsync;
    assign o_VGA_VS = vsync;
    assign o_VGA_BLANK_N = video_on;
    
    //=======================================================================
    // Clock Domain Crossing - Audio to VGA clock
    //=======================================================================
    always_ff @(posedge i_clk_25mhz or negedge i_rst_n) begin
        if (!i_rst_n) begin
            sample_valid_sync1 <= 1'b0;
            sample_valid_sync2 <= 1'b0;
            audio_data_sync <= 16'd0;
        end else begin
            sample_valid_sync1 <= i_sample_valid;
            sample_valid_sync2 <= sample_valid_sync1;
            if (i_sample_valid)
                audio_data_sync <= i_audio_data;
        end
    end
    
    wire sample_valid_edge = sample_valid_sync1 && !sample_valid_sync2;
    
    //=======================================================================
    // Sample Buffer Management
    //=======================================================================
    always_comb begin
        write_addr_w = write_addr_r;
        
        if (sample_valid_edge) begin
            if (write_addr_r >= WAVE_WIDTH - 1)
                write_addr_w = 10'd0;
            else
                write_addr_w = write_addr_r + 10'd1;
        end
    end
    
    // Write samples to buffer
    integer i;
    always_ff @(posedge i_clk_25mhz or negedge i_rst_n) begin
        if (!i_rst_n) begin
            write_addr_r <= 10'd0;
            for (i = 0; i < WAVE_WIDTH; i = i + 1) begin
                sample_buffer[i] <= 16'd0;
            end
        end else begin
            write_addr_r <= write_addr_w;
            if (sample_valid_edge) begin
                sample_buffer[write_addr_r] <= audio_data_sync;
            end
        end
    end
    
    //=======================================================================
    // Display Logic
    //=======================================================================
    logic in_wave_area;
    logic [9:0] wave_x;  // X position within waveform area (0 to WAVE_WIDTH-1)
    logic [9:0] wave_y;  // Y position within waveform area (0 to WAVE_HEIGHT-1)
    
    assign in_wave_area = (h_count_r >= WAVE_X_START) && (h_count_r < WAVE_X_END) &&
                          (v_count_r >= WAVE_Y_START) && (v_count_r < WAVE_Y_END);
    
    assign wave_x = h_count_r - WAVE_X_START;
    assign wave_y = v_count_r - WAVE_Y_START;
    
    // Read sample from buffer (with circular buffer offset)
    logic [9:0] read_addr;
    logic signed [15:0] current_sample;
    logic signed [9:0] sample_y_pos;  // Y position of sample (0 = top, WAVE_HEIGHT = bottom)
    
    assign read_addr = (wave_x + write_addr_r + 1) % WAVE_WIDTH;
    assign current_sample = sample_buffer[read_addr];
    
    // Map audio sample (-32768 to +32767) to screen Y position (0 to WAVE_HEIGHT)
    // Center line is at WAVE_HEIGHT/2
    // Scale: 32768 maps to WAVE_HEIGHT/2 pixels
    logic signed [31:0] scaled_sample;
    assign scaled_sample = (current_sample * WAVE_HEIGHT) / 32768;
    assign sample_y_pos = (WAVE_HEIGHT / 2) - scaled_sample[9:0];
    
    // Draw logic
    logic draw_waveform;
    logic draw_border;
    logic draw_grid;
    logic draw_center_line;
    
    // Waveform: draw if we're within 1 pixel of the sample line
    assign draw_waveform = in_wave_area && 
                          (wave_y >= (sample_y_pos - 1)) && 
                          (wave_y <= (sample_y_pos + 1));
    
    // Border around waveform area
    assign draw_border = ((h_count_r == WAVE_X_START - 1) || (h_count_r == WAVE_X_END)) &&
                        (v_count_r >= WAVE_Y_START - 1) && (v_count_r <= WAVE_Y_END) ||
                        ((v_count_r == WAVE_Y_START - 1) || (v_count_r == WAVE_Y_END)) &&
                        (h_count_r >= WAVE_X_START - 1) && (h_count_r <= WAVE_X_END);
    
    // Horizontal grid lines every 70 pixels (4 lines)
    assign draw_grid = in_wave_area && 
                      ((wave_y == 70) || (wave_y == 140) || (wave_y == 210)) &&
                      ((wave_x[2:0] == 3'd0));  // Dotted line
    
    // Center line (0V reference)
    assign draw_center_line = in_wave_area && 
                             (wave_y == (WAVE_HEIGHT / 2)) &&
                             ((wave_x[1:0] == 2'd0));  // Dotted line
    
    // Color assignment
    always_comb begin
        if (video_on) begin
            if (draw_waveform) begin
                // Bright green waveform
                o_VGA_R = 8'd0;
                o_VGA_G = 8'd255;
                o_VGA_B = 8'd0;
            end else if (draw_border) begin
                // White border
                o_VGA_R = 8'd255;
                o_VGA_G = 8'd255;
                o_VGA_B = 8'd255;
            end else if (draw_center_line) begin
                // Yellow center line
                o_VGA_R = 8'd255;
                o_VGA_G = 8'd255;
                o_VGA_B = 8'd0;
            end else if (draw_grid) begin
                // Dim gray grid
                o_VGA_R = 8'd64;
                o_VGA_G = 8'd64;
                o_VGA_B = 8'd64;
            end else if (in_wave_area) begin
                // Black background in waveform area
                o_VGA_R = 8'd0;
                o_VGA_G = 8'd0;
                o_VGA_B = 8'd0;
            end else begin
                // Dark blue background outside
                o_VGA_R = 8'd0;
                o_VGA_G = 8'd0;
                o_VGA_B = 8'd32;
            end
        end else begin
            // Blanking - all black
            o_VGA_R = 8'd0;
            o_VGA_G = 8'd0;
            o_VGA_B = 8'd0;
        end
    end
    
    //=======================================================================
    // Sequential Logic
    //=======================================================================
    always_ff @(posedge i_clk_25mhz or negedge i_rst_n) begin
        if (!i_rst_n) begin
            h_count_r <= 10'd0;
            v_count_r <= 10'd0;
        end else begin
            h_count_r <= h_count_w;
            v_count_r <= v_count_w;
        end
    end

endmodule