
module Adder#(
      parameter   DEVICE_FAMILY      =    "Cyclone V", 
      parameter   WIDTH              =    4,
      parameter   ADD_STAGES         =    4
      )
      (

      input                               clk,
      input                               reset_n,

      input [ADD_STAGES - 1:0]            add_stage_i,
      input                               subtract_i,
      input                               pre_shift_i,

      input [WIDTH - 1:0]                 operand_A_i,
      input [WIDTH - 1:0]                 operand_B_i,


      output logic [WIDTH - 1:0]          result_o
);




logic[WIDTH - 1:0] operand_A_reg;
logic[WIDTH - 1:0] operand_B_reg;

logic carry_in;
logic carry_out;

logic shift_msb;


logic [WIDTH - 1:0] u_shift_data_load;



always@(posedge clk) begin



      // Subtraction block, convert operand B to 2s negative, word by word
      // NOTE: only N (modulus) is ever subtracted and N is always odd -> first word of ~N is never 0xFF 
      // -> never need carry to 2nd word when adding 1 -> 1 needs to only be added to first word 

      if(subtract_i) begin // subtract
            if((add_stage_i[3] && ~add_stage_i[4])) begin // first word
                  operand_B_reg <= ~operand_B_i + 1'b1; // convert to 2s
            end
            else begin
                  operand_B_reg <= ~operand_B_i; // convert to 2s
            end
      end
      else if(subtract_i == 1'b0) begin // add
            operand_B_reg <= operand_B_i; 
      end

      // Must add 2B instead of B, right shift by one if pre_shift_i is high 
      shift_msb <= 1'b0;
      if(pre_shift_i) begin
            operand_A_reg <= {{operand_A_i[WIDTH-2:0]},{shift_msb}};
            shift_msb <= operand_A_i[WIDTH-1];
      end
      else begin
            operand_A_reg <= operand_A_i; // reg op A           
      end
      
      if(add_stage_i[4]) begin
            {carry_out, result_o} <= operand_A_reg + operand_B_reg + carry_in;
      end
      else begin
            result_o <= '0;
            carry_out <= '0;
      end

      if(~reset_n) begin
            result_o <= '0;
            carry_out <= '0;
            shift_msb <= 1'b0;
      end
end

always_comb begin
      if(~add_stage_i[4]) begin
            carry_in = '0;
      end
      else begin
            carry_in = carry_out;
      end
end

endmodule
