`timescale 1ns/1ps

module tremolo_tb;

    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Tremolo inputs
    logic valid;
    logic enable;
    logic [2:0] freq;
    logic signed [15:0] data_in;
    
    // Tremolo outputs
    logic signed [15:0] data_out;
    logic valid_out;
    
    // File handle for CSV output
    integer file;
    
    // Test parameters
    localparam CLK_PERIOD = 20;  // 50 MHz clock (20ns period)
    localparam SAMPLE_RATE = 32000;  // 32 kHz audio sampling
    localparam SAMPLES_TO_CAPTURE = 128000;  // 4 seconds at 32kHz
    
    // Instantiate the DUT
    tremolo dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_valid(valid),
        .i_enable(enable),
        .i_freq(freq),
        .i_data(data_in),
        .o_data(data_out),
        .o_valid(valid_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        valid = 0;
        enable = 0;
        freq = 3'd2;  // 3 Hz tremolo for testing
        data_in = 0;
        
        // Open CSV file
        file = $fopen("tremolo_output.csv", "w");
        $fdisplay(file, "sample,input,output,tri_wave");
        
        // Reset sequence
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        // Enable tremolo
        enable = 1;
        
        // Generate ramp input and capture output
        for (int i = 0; i < SAMPLES_TO_CAPTURE; i++) begin
            // Generate ramp input: y = x
            // Scale to fit within 16-bit signed range
            // Ramp from -32768 to +32767 over the entire capture period
            data_in = -16'sh8000 + ((i * 32'h10000) / SAMPLES_TO_CAPTURE);
            
            valid = 1;
            
            // Wait for one clock cycle
            @(posedge clk);
            
            // Write to CSV file
            if (valid_out) begin
                $fdisplay(file, "%0d,%0d,%0d,%0d", i, data_in, data_out, dut.tri_data_w);
            end
            
            // Print progress every 10000 samples
            if (i % 10000 == 0) begin
                $display("Progress: %0d/%0d samples", i, SAMPLES_TO_CAPTURE);
            end
        end
        
        // Test with tremolo disabled
        $display("\nTesting with tremolo disabled...");
        enable = 0;
        
        for (int i = 0; i < 1000; i++) begin
            data_in = -16'sh8000 + ((i * 32'h10000) / 1000);
            @(posedge clk);
        end
        
        // Close file and end simulation
        $fclose(file);
        $display("\nSimulation complete! Output saved to tremolo_output.csv");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * SAMPLES_TO_CAPTURE * 2);
        $display("ERROR: Simulation timeout!");
        $fclose(file);
        $finish;
    end
    
endmodule