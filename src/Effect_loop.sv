module Effect_Loop (
    input  logic         i_clk,
    input  logic         i_rst_n,
    input  logic         i_valid,
    input  logic         i_enable,
    input  [2:0]         i_level,
    input  signed [15:0] i_data,
    input  logic         i_key_1,
    input  signed [15:0] i_sram_rdata, // Data read FROM SRAM
    output logic  [19:0] o_sram_addr,  // Address request
    output logic         o_sram_we_n,  // 0=Write, 1=Read
    output signed [15:0] o_sram_wdata, // Data to write

    output signed [15:0] o_data,
    output logic         o_valid
);

    // work flow: write new sample, read old sample, process with current, output

    logic [19:0] write_ptr;
    logic [19:0] read_ptr;

    localparam MAX_BUFFER  = 20'd672000; // 640000 + 32000 from delay 
    localparam START_PTR   = 20'd32000;

    logic        mix_output_r, mix_output_w;  // decide output 
    logic [19:0] loop_ptr;                    // ptr for loop boundary
    logic [19:0] delay_sample_w = loop_ptr - START_PTR;  // loop length

    always_comb begin
        case (i_level)
            3'd0:  begin
                input_scale = 0;
                sram_scale  = 8;
            end
            3'd1:  begin
                input_scale = 1;
                sram_scale  = 7;
            end
            3'd2:  begin
                input_scale = 2;
                sram_scale  = 6;
            end
            3'd3:  begin
                input_scale = 3;
                sram_scale  = 5;
            end
            3'd4:  begin
                input_scale = 4;
                sram_scale  = 4;
            end
            3'd5:  begin
                input_scale = 5;
                sram_scale  = 3;
            end
            3'd6:  begin
                input_scale = 6;
                sram_scale  = 2;
            end
            3'd7:  begin
                input_scale = 7;
                sram_scale  = 1;
            end
        endcase
    end

    always_comb begin
        mix_output_w = (i_key_1) ? ((mix_output_r == 2) ? 0 : mix_output_r + 1) : mix_output_r;
    end

    // mix_output_r: 0 : IDLE, 1 : play input + create loop, 2: play input + play loop

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            mix_output_r <= 0;
        end else begin
            mix_output_r <= mix_output_w;
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            write_ptr <= START_PTR;
            loop_ptr  <= START_PTR;
        end else begin
            if (i_valid) begin
                if (mix_output_r == 1) begin
                    if (loop_ptr >= MAX_BUFFER - 1) 
                        loop_ptr <= START_PTR;
                    else 
                        loop_ptr <= loop_ptr + 1;
                end

                if ((write_ptr >= MAX_BUFFER - 1) || (write_ptr >= loop_ptr)) 
                    write_ptr <= START_PTR;
                else 
                    write_ptr <= write_ptr + 1;
            end
            else begin
                loop_ptr <= loop_ptr;
                write_ptr <= write_ptr;
            end
        end
    end

    // TODO: switch to variable delay after debugging
    assign read_ptr = (write_ptr >= delay_sample_w) ? (write_ptr - delay_sample_w) : (MAX_BUFFER + write_ptr - delay_sample_w);

    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_WRITE = 3'd1;
    localparam [2:0] S_READ_REQ = 3'd2;
    localparam [2:0] S_READ_LATCH = 3'd3;
    localparam [2:0] S_MIX = 3'd4;

    logic [2:0] state;

    logic signed [15:0] captured_input; // Store input stable
    logic signed [15:0] delayed_sample; // Store SRAM data
    logic        [2:0]  input_scale, sram_scale;
    logic signed [19:0] scaled_input = captured_input * input_scale;
    logic signed [19:0] scaled_sram  = delayed_sample * sram_scale;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= S_IDLE;
            o_valid <= 0;
            o_data <= 0;
            captured_input <= 0;
            delayed_sample <= 0;
        end
        else begin
            o_valid <= 0; // default
            case (state)
                S_IDLE: begin
                    if (i_valid) begin
                        captured_input <= i_data; // Latch input audio
                        state <= S_WRITE;
                    end
                end
                S_WRITE: begin
                    // Wait 1 cycle for write to finish
                    state <= S_READ_REQ;
                end
                S_READ_REQ: begin
                    // Wait 1 cycle for address setup
                    state <= S_READ_LATCH;
                end
                S_READ_LATCH: begin
                    delayed_sample <= i_sram_rdata; 
                    state <= S_MIX;
                end
                S_MIX: begin
                    if (i_enable && (mix_output_r == 2)) begin
                        o_data <= (shifted_input >>> 3) + (shifted_sram >>> 3);
                        // TODO: error here
                    end else begin
                        o_data <= captured_input;
                    end
                    o_valid <= 1;
                    state <= S_IDLE;
                end
            endcase
        end  
    end

    always_comb begin
        o_sram_addr  = 20'd0;
        o_sram_we_n  = 1'b1; // read 
        o_sram_wdata = 16'd0;

        case (state)
            S_WRITE: begin
                o_sram_addr  = write_ptr;
                o_sram_wdata = captured_input;
                o_sram_we_n  = 1'b0; // Active Low WRITE
            end

            S_READ_REQ, S_READ_LATCH: begin
                o_sram_addr  = read_ptr;
                o_sram_we_n  = 1'b1; // READ
            end
            
            // S_IDLE, S_MIX: Do nothing (bus released by Top.sv anyway)
        endcase
    end
endmodule