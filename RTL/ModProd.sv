
import ModProd_pkg::*;
module ModProd#(
      parameter   DEVICE_FAMILY     =     "Cyclone V",
      parameter   MEM_ADDR_WIDTH    =     32,   
      parameter   WORD_SIZE         =     4, 
      parameter   DATA_WIDTH        =     1024,
      parameter   ITERATIONS        =     1027
      )
      (


      input                             clk,
      input                             reset_n,

      input  [1                 :0]     op, // 00 = montgomery multiply, 10 final reduction, 11 convert to montgomery domain

      input  [MEM_ADDR_WIDTH - 1:0]     addr_A_i,
      input  [MEM_ADDR_WIDTH - 1:0]     addr_B_i,
      input  [MEM_ADDR_WIDTH - 1:0]     addr_N_i,
      input  [MEM_ADDR_WIDTH - 1:0]     addr_BN_i,
      input  [MEM_ADDR_WIDTH - 1:0]     addr_U_i,

      // General memory
      input [WORD_SIZE - 1:0]                   mem1_out_i,
      input [WORD_SIZE - 1:0]                   mem2_out_i,
      output logic [WORD_SIZE - 1:0]            mem1_in_o,
      output logic [WORD_SIZE - 1:0]            mem2_in_o,
      output logic                              mem1_write_o,
      output logic                              mem2_write_o,
      output logic [MEM_ADDR_WIDTH - 1:0] addr1_o,
      output logic [MEM_ADDR_WIDTH - 1:0] addr2_o,

      input                             start_i,
      output logic                      ready_o


);

localparam ADD_STAGES = 6;
localparam WORDS = DATA_WIDTH/WORD_SIZE;

ModProd_state this_state, next_state;
//Inputs
logic start;
logic next_word;
logic a_j;
logic u_0;
logic u_s;
logic next_iter;
logic next_iter_1;
logic load_done;

//Outputs
logic reset_data_n;
logic ready;
logic [1:0] op_a_sel;
logic [1:0] op_b_sel; 
logic add_start;
logic [ADD_STAGES - 1:0] add_stage;
logic inc_ic;
logic reset_carry;
logic shift_u;
logic u_mem_mux;
logic load_entries;
logic load_entries_1;
logic clear_u_reg;
logic init_a;
logic subtract;
logic shift_dir;

logic [MEM_ADDR_WIDTH - 1:0] addr1;
logic [MEM_ADDR_WIDTH - 1:0] addr1_next;
logic [MEM_ADDR_WIDTH - 1:0] addr2;
logic [MEM_ADDR_WIDTH - 1:0] addr2_next;

assign addr1_next = addr1 + 1'b1;
assign addr2_next = addr2 + 1'b1;

// Adder

logic[WORD_SIZE - 1:0] operand_A;
logic[WORD_SIZE - 1:0] operand_B;
logic[DATA_WIDTH - 1:0] sum_u;
logic[WORD_SIZE - 1:0] u_partial_in;
logic[WORD_SIZE - 1:0] u_partial_out;

// A and B processing signals
logic a_in;
logic load_a;
logic fetch_a;
logic b_shift;


assign addr1_o = addr1;
assign addr2_o = addr2;

always_ff @(posedge clk) begin
      if(~reset_n) begin
            start <= '0;
            ready_o <= '0;
      end else begin
            start <= start_i;
            ready_o <= ready;
      end
end


//=======================================================
//  FSM
//=======================================================
always_comb begin : next_state_logic
      next_state = MP_hold;
      case(this_state)
            MP_hold:  begin
                  if(start) begin
                        if(op == 2'b00) begin
                              next_state = MP_preprocess;
                        end
                        else if(op == 2'b10) begin
                              next_state = MP_sub_N_mem;
                        end
                        else if(op == 2'b11) begin
                              next_state = MP_clear_u;
                        end
                  end
                  else begin
                        next_state = MP_hold;
                  end
            end
            MP_preprocess: begin
                  if(~next_word) begin
                        next_state = MP_preprocess_store;
                  end
                  else begin
                        next_state = MP_preprocess;                        
                  end
            end
            MP_preprocess_store: begin
                  if(load_done && op == 2'b00)
                        next_state = MP_clear_u;
                  else if(load_done && op == 2'b10) begin
                        next_state = MP_hold;
                  end
                  else if(load_done && op == 2'b11) begin
                        next_state = MP_sub_N_mem;
                  end
                  else begin
                        next_state = MP_preprocess_store;                        
                  end
            end
            MP_clear_u: begin
                  if(op == 2'b00) begin
                        next_state = MP_inc_iter;
                  end
                  else if(op == 2'b11) begin
                        next_state = MP_add_BN;
                  end
            end
            MP_inc_iter: begin
                  if(op == 2'b00) begin
                        if(next_iter) begin
                              if(a_j && u_0) begin
                                    next_state = MP_add_BN;
                              end
                              else if(a_j) begin
                                    next_state = MP_add_B;
                              end
                              else if(u_0) begin
                                    next_state = MP_add_N;
                              end
                              else begin
                                    next_state = MP_shift_r;
                              end
                        end
                        else if(~next_iter) begin
                              next_state = MP_store_u;
                        end
                  end
                  else if(op == 2'b11) begin
                        if(next_iter_1) begin
                              next_state = MP_shift_l;
                        end
                        else if(~next_iter_1) begin
                              next_state = MP_store_u;
                        end
                  end      

            end
            MP_add_B: begin 
                  if(~next_word) begin
                        next_state = MP_shift_r;
                  end
                  else begin
                        next_state = MP_add_B;
                  end
            end
            MP_add_BN: begin 
                  if(op == 2'b00) begin
                        if(~next_word) begin
                              next_state = MP_shift_r;
                        end
                        else begin
                              next_state = MP_add_BN;
                        end
                  end
                  else if(op == 2'b11) begin
                        if(~next_word) begin
                              next_state = MP_inc_iter;
                        end
                        else begin
                              next_state = MP_add_BN;
                        end                        
                  end
            end
            MP_add_N: begin 
                  if(~next_word) begin
                        next_state = MP_shift_r;
                  end
                  else begin
                        next_state = MP_add_N;
                  end
            end
            MP_sub_N_mem: begin 
                  if(~next_word && u_s) begin
                        if(op == 2'b10) begin
                              next_state = MP_hold;
                        end
                        if(op == 2'b11) begin
                              next_state = MP_clear_u;
                        end
                  end
                  else if(~next_word && ~u_s) begin
                        if(op == 2'b10) begin
                              next_state = MP_store_u;
                        end
                        if(op == 2'b11) begin
                              next_state = MP_inc_iter;
                        end                  
                  end
                  else begin
                        next_state = MP_sub_N_mem;
                  end                    
            end
            MP_shift_l: begin
                  next_state = MP_store_u;
            end
            MP_shift_r: begin
                  next_state = MP_inc_iter;
            end
            MP_store_u: begin
                  if(load_done) begin
                        if(op == 2'b00 || op == 2'b10) begin
                              next_state = MP_hold;
                        end
                        else if(op == 2'b11 && next_iter) begin
                              next_state = MP_sub_N_mem;
                        end
                        else if(op == 2'b11 && ~next_iter) begin
                              next_state = MP_hold;
                        end
                  end
                  else begin
                        next_state = MP_store_u;
                  end
            end
      endcase
end

always_comb begin
      reset_data_n = 1'b1;
      ready = '0;
      op_a_sel = '0; 
      add_start = '0;
      inc_ic = '0;
      reset_carry = '0;
      shift_u = '0;
      u_mem_mux = '0;
      load_entries = '0;
      clear_u_reg = '0;
      init_a = '0;
      b_shift ='0;
      subtract = '0;
      shift_dir = '0; 

      case(this_state)
            MP_hold: begin
                  ready = 1'b1;
                  reset_data_n = 1'b0;
                  reset_carry = '1; // reset carry, replacement for global reset functionality
            end

            MP_preprocess: begin 
                  op_a_sel = 2'b00;
                  u_mem_mux = 1'b1;
                  add_start = 1'b1;
                  b_shift = 1'b1;
            end
            MP_preprocess_store: begin 
                  load_entries = 1'b1;
                  u_mem_mux = 1'b1;
                  init_a = 1'b1;
            end
            MP_clear_u: begin 
                  clear_u_reg = 1'b1;
            end
            MP_inc_iter: begin 
                  reset_carry = 1'b1;
                  inc_ic = 1'b1;
            end
            MP_add_B: begin 
                  op_a_sel = 2'b00;
                  add_start = 1'b1;
                  b_shift = 1'b1;
            end
            MP_add_BN: begin 
                  op_a_sel = 2'b01;
                  add_start = 1'b1;
            end
            MP_add_N: begin 
                  op_a_sel = 2'b10;
                  add_start = 1'b1;
            end
            MP_sub_N_mem: begin 
                  op_a_sel = 2'b00;
                  add_start = 1'b1;
                  u_mem_mux = 1'b1;
                  subtract = 1'b1;
            end
            MP_shift_l: begin
                  shift_u = 1'b1;
                  shift_dir = 1'b1;
            end
            MP_shift_r: begin
                  shift_u = 1'b1;
                  shift_dir = 1'b0;
            end
            MP_store_u: begin 
                  load_entries = 1'b1;
                  u_mem_mux = 1'b0;
            end
      endcase
end

always_ff@(posedge clk) begin
      if(~reset_n)
            this_state <= MP_hold;
      else
            this_state <= next_state;
end

//=======================================================
//  Counters
//=======================================================
logic [$clog2(WORDS) - 1:0] word_counter;
logic [WORDS - 1:0] word_counter_one_hot;
logic [WORDS - 1:0] word_counter_one_hot_1;
logic [WORDS - 1:0] u_shift_select;
logic [WORD_SIZE - 1:0] u_shift_data_load;

always @(posedge clk) begin
      
      if(add_stage[3] && word_counter < WORDS-1) begin
                  word_counter <= word_counter + 1'b1;                  
      end
      else begin
            word_counter <= '0;
      end

      if(~reset_data_n) begin
            word_counter <= '0;
      end
end


always @(posedge clk) begin
      if(add_stage[5]) begin
            u_shift_select[0] <= 1'b0;
            for(int i = 0; i < WORDS - 1; i++) begin
                  u_shift_select[i+1] <= u_shift_select[i];
            end
      end
      else begin
            u_shift_select <= {{(WORDS-1){1'b0}},1'b1};
      end
      
      next_word <= ~u_shift_select[WORDS-2];

      if(~reset_data_n) begin
            u_shift_select <= {{(WORDS-1){1'b0}},1'b1};
            next_word <= 1'b1;
      end
end


logic [$clog2(ITERATIONS) - 1:0] iter_counter;

always @(posedge clk) begin
      
      fetch_a <= 1'b0;
      load_a <= 1'b0;

      if(inc_ic) begin
            iter_counter <= iter_counter + 1'b1;
            if(iter_counter == (ITERATIONS - 1)) begin // Runs 32 iterations
                  next_iter <= 1'b0;
            end
            if(iter_counter == (ITERATIONS - 2)) begin // Runs 32 iterations
                  next_iter_1 <= 1'b0;
            end
            
            if(iter_counter[$clog2(WORD_SIZE) - 1:0] == {{($clog2(WORD_SIZE)-2){1'b1}},{1'b0},{1'b0}}) begin
                  fetch_a <= 1'b1;
            end
            else if(iter_counter[$clog2(WORD_SIZE) - 1:0] == {{($clog2(WORD_SIZE)-1){1'b1}},{1'b1}}) begin
                  load_a <= 1'b1;
            end
      end
      if(~reset_data_n) begin
            iter_counter <= '0;
            next_iter <= 1'b1;
            next_iter_1 <= 1'b1;
      end
end


//=======================================================
//  Adding logic
//=======================================================
// Add stages
// 0 - write memory address
// 1 - addresses loaded
// 2 -
// 3 - memory data arrives, data is reged (and inverted), first word of u is reged, word_counter incremented
// 4 - first add occurs
// 5 - first result arrives, increment u_shift_select, u_shift_select = 1
// 6 - second result arrives, u_shift_select = 2
// WORDS + 4 - last result arrives, next_word goes low 
// WORDS + 5 - last result stored in sum, safe to shift on next cycle

Adder#(
      .DEVICE_FAMILY(DEVICE_FAMILY), 
      .WIDTH(WORD_SIZE), 
      .ADD_STAGES(ADD_STAGES))
      add_1(
      .clk(clk),
      .reset_n(reset_n),
      .add_stage_i(add_stage),
      .subtract_i(subtract),
      .pre_shift_i(b_shift),
      .operand_A_i(operand_A),
      .operand_B_i(operand_B),
      .result_o(u_partial_out)
);

assign add_stage[0] = add_start;
    
genvar j;
generate            
for(j = 1; j < ADD_STAGES; j++) begin: generate_add_stages
      always @(posedge clk) begin
            if(add_stage[0]) begin
                  add_stage[j] <= add_stage[j-1];
            end
            else begin
                  add_stage[j] <= '0;
            end
            if(~reset_data_n) begin
                  add_stage[j] <= '0;
            end
      end
end
endgenerate


always_comb begin
      if(u_mem_mux) begin
            operand_B = mem2_out_i;
      end
      else begin
            operand_B = u_partial_in;
      end

      if(add_stage[0]) begin
            u_shift_data_load = u_partial_out;            
      end
      else begin
            u_shift_data_load = '0;
      end
end

assign operand_A = mem1_out_i;

assign u_0 = sum_u[0]; // first bit of final result
assign u_partial_in = sum_u[word_counter*WORD_SIZE+:WORD_SIZE]; // word select of U
assign u_s = u_partial_out[WORD_SIZE - 1]; // sign of final result, use final bit of each partial result
                                           // NOTE: currently only evaluated when u_partial_out contains final word,
                                           // at any other cycle does represent sign of the result

//=======================================================
//  Shift Registers
//=======================================================

// A data shift reg
lpm_shiftreg #(
      .lpm_width(WORD_SIZE),
      .lpm_direction("RIGHT"))
      a_shift_reg(
      .data(mem2_out_i),
      .clock(clk),
      .enable(inc_ic||load_a||init_a),
      .shiftin(1'b0),
      .load(load_a||init_a),
      .aclr(),
      .aset(),
      .sclr(),
      .sset(),
      .q(), 
      .shiftout(a_j)
);



      logic [WORDS - 1:0] inter_shift_out;
      logic [WORDS - 1:0] inter_shift_in;      

      // Generate one shift register per word in data width
      // Connect shift registers together using inter_shift_in and inter_shift_out
      // Bidirectional shift registers, inter_shift_in and out are muxed to switch direction
      genvar i;
      generate
        for (i=0; i < WORDS; i++) begin : generate_u_shift_regs
            if (i == 0) begin
                  always_comb begin 
                        if(shift_dir) begin
                              inter_shift_in[0] = 0;
                        end
                        else begin                        
                              inter_shift_in[0] = inter_shift_out[1];
                        end   
                  end      
            end
            else if (i == WORDS - 1) begin
                  always_comb begin 
                        if(shift_dir) begin
                              inter_shift_in[WORDS - 1] = inter_shift_out[WORDS - 1 -1];      
                        end
                        else begin                        
                              inter_shift_in[WORDS - 1] = 0;
                        end   
                  end
            end
            else begin
                  always_comb begin 
                        if(shift_dir) begin
                              inter_shift_in[i] = inter_shift_out[i-1];      
                        end
                        else begin                        
                              inter_shift_in[i] = inter_shift_out[i+1];
                        end   
                  end
            end

            bidir_shift_reg #(
            .WIDTH(WORD_SIZE))
            u_shift_reg(
            .data_in(u_shift_data_load),
            .dir(shift_dir),
            .clock(clk),
            .reset_n(reset_n),
            .enable(clear_u_reg||shift_u||(u_shift_select[i] && add_stage[0] && add_stage[5])),
            .shift_in(inter_shift_in[i]),
            .load(clear_u_reg||(u_shift_select[i] && add_stage[0] && add_stage[5])),
            //aclr, aset
            //sclr, sset                          : INPUT = GND,
            .q_out(sum_u[i*WORD_SIZE+:WORD_SIZE]),
            .shift_out(inter_shift_out[i])      

            );

      end
      endgenerate


//=======================================================
//  Memory Mux
//=======================================================
always_ff @(posedge clk) begin: memory_mux
      
      mem1_write_o <= '0;
      mem2_write_o <= '0;            
      load_done <= 1'b0;

      load_entries_1 <= load_entries;

      // Load preprocessed B+N into memory
      if(load_entries && ~load_entries_1 && u_mem_mux) begin
            addr1 <= addr_BN_i - 1;
      end
      else if(load_entries && u_mem_mux) begin
            addr1 <= addr1_next;
            mem1_write_o <= 1'b1;
            mem1_in_o <= sum_u[WORD_SIZE*(addr1_next-addr_BN_i)+:WORD_SIZE];
            if(addr1_next > (addr_BN_i+WORDS - 3)) begin
                  load_done <= 1'b1;
            end
      end
      
      // Load final value u into memory
      if(load_entries && ~load_entries_1 && ~u_mem_mux) begin
            addr1 <= addr_U_i - 1;
      end
      else if(load_entries && ~u_mem_mux) begin
            addr1 <= addr1_next;
            mem1_write_o <= 1'b1;
            mem1_in_o <= sum_u[WORD_SIZE*(addr1_next-addr_U_i)+:WORD_SIZE];
            if(addr1_next > (addr_U_i+WORDS - 3)) begin
                  load_done <= 1'b1;
            end
      end

      // Load operand A
      if(add_stage[0] && ~add_stage[1]) begin
            if(op_a_sel == 2'b00)
                  addr1 <= addr_B_i;
            else if(op_a_sel == 2'b01)
                  addr1 <= addr_BN_i;
            else if(op_a_sel == 2'b10)
                  addr1 <= addr_N_i;
      end      
      else if(add_stage[0] && addr1_next != ({MEM_ADDR_WIDTH{1'b1}}+1)) begin
            addr1 <= addr1_next;
      end

      // Load operand B if preprocessing
      if(u_mem_mux && add_stage[0] && ~add_stage[1]) begin
            addr2 <= addr_N_i;
      end      
      else if(u_mem_mux && add_stage[0] && addr2_next != ({MEM_ADDR_WIDTH{1'b1}}+1)) begin
            addr2 <= addr2_next;
      end
      
      // Continously fetch A if not preprocessing
      if(init_a) begin
            addr2 <= addr_A_i;
      end      
      else if(fetch_a && addr2_next != ({MEM_ADDR_WIDTH{1'b1}}+1)) begin
            addr2 <= addr2_next;
      end


      if(~reset_data_n) begin
            load_done <= 1'b0;
            addr2 <= {MEM_ADDR_WIDTH{1'b1}};
            addr2 <= {MEM_ADDR_WIDTH{1'b1}};
            mem1_write_o <= '0;
            mem2_write_o <= '0;
            mem1_in_o <= '0;
            mem2_in_o <= '0;
      end

end

endmodule
