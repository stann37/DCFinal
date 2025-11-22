module Top(
    input i_rst_n,
	input i_clk,
	input i_key_0,
	input i_key_1,
	input i_key_2,

    // AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,

    // I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT

    // LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	// output  [8:0] o_ledg
	// output [17:0] o_ledr

);

parameter S_I2C = 0; // defalut state upon resetting, I2C then go to S_PLAY
parameter S_PLAY = 1;
parameter S_SET = 2;
parameter S_RECD_LOOP = 3;
parameter S_PLAY_LOOP = 4;

logic [2:0] state_w, state_r;
logic [2:0] state_gate_r, state_gate_w;
logic [2:0] state_comp_r, state_comp_w;
logic {2:0} state_dist_r, state_dist_w;
logic {2:0} state_EQb_r, state_EQb_w;
logic {2:0} state_EQt_r, state_EQt_w;
logic {2:0} state_trem_r, state_trem_w;
logic [2:0] state_chor_r, state_chor_w;
logic [2:0] state_delay_r, state_delay_w;

// I2C
logic I2C_finish;
logic i2c_oen, i2c_sdat;
assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(1'b1),	// inside I2C module, start I2C when !i_rst_n 
	.o_finished(I2C_finish),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
);


// state transition
always_comb begin
	state_w = state_r;
	case (state_r)
		S_I2C: begin
			if (I2C_finish) begin
				state_w = S_PLAY;
			end
		end
		S_PLAY: begin
			if (i_key_2) begin
				state_w = S_SET;
			end
			else if (i_key_1) begin
				state_w = S_RECD_LOOP;
			end
		end
		S_SET: begin
			if (i_key_2) begin
				state_w = S_PLAY;
			end
		end
		S_RECD_LOOP: begin
			if (i_key_1) begin
				state_w = S_PLAY_LOOP;
			end
		end
		S_PLAY_LOOP: begin

		end
	endcase
end

// reset logic
always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r <= S_I2C; // start from I2C initialization
	end
	else begin
		state_r <= state_w;
	end
end

endmodule