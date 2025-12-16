`timescale 1ns/1ps

module tb_Triangle_generator;

    logic clk;
    logic rst_n;
    logic start;
    logic stop;
    logic [2:0] freq;
    logic [15:0] cnt;
    logic signed [31:0] tri_data;

    integer fd; // CSV file handle

    // Instantiate DUT
    Triangle_generator dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_start(start),
        .i_freq(freq),
        .o_tri(tri_data)
    );

    // Clock generation: 10ns
    always #5 clk = ~clk;

    initial begin
        $fsdbDumpfile("tri.fsdb");
        $fsdbDumpvars("+mda");
        $display("=== Triangle Generator Testbench ===");

        // open CSV file
        fd = $fopen("tri_output.csv", "w");
        $fwrite(fd, "time_ns,o_tri\n");

        // init
        clk   = 0;
        rst_n = 0;
        start = 0;
        freq  = 3'b011;
        cnt = 0;

        // reset
        #20;
        rst_n = 1;

        // start
        #20;
        start = 1;

        // Run and write waveform to CSV
        repeat (20000) begin
            @(posedge clk);
            $fwrite(fd, "%0t,%0d\n", $time, tri_data);
        end

        @(posedge clk);

        $fclose(fd);
        $display("=== Simulation finished ===");
        $finish;
    end

    initial begin
        wait(start == 1);
        forever @(posedge clk) cnt = cnt + 1;
    end

endmodule
