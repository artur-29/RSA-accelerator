
import RSA_pkg::*;
module RSA#(
      parameter   DEVICE_FAMILY     =     "Cyclone V",
      parameter   WORD_SIZE         =     4, 
      parameter   INPUT_WIDTH       =     1024,
      parameter DATA_WIDTH          =     INPUT_WIDTH + WORD_SIZE

      )
      (

      input                             clk,
      input                             reset_n,

      input [7:0]                       data_in,
      output logic [7:0]                data_out,
      input                             addr,
      input                             valid,
      input                             write

);
localparam ITERATIONS        =     INPUT_WIDTH + 1;
localparam EXP_WIDTH         =     INPUT_WIDTH;
localparam R                 =     {{1'b1},{INPUT_WIDTH{1'b0}}}; // r = 2^k

localparam MEM_LATENCY = 3; // cycles to for correct result to arrive from memory
localparam MODPROD_READY_LATENCY = 3; // cycles to for correct result to arrive from memory
localparam OPERAND_WORDS = (DATA_WIDTH/WORD_SIZE); // words for each variable
localparam MEMORY_WORDS = OPERAND_WORDS*8; // 8 variables
localparam MEM_ADDR_WIDTH = $clog2(MEMORY_WORDS);

//=======================================================
//  FSM
//=======================================================
//

typedef struct packed {
      bit [1:0]  nu_7_6;
      bit        ready;
      bit        read_u;
      bit        load_n;
      bit        load_e;
      bit        load_x;
      bit        start;
} control_reg_type;

// Register interface
control_reg_type control_reg;
logic [7:0] load_reg;
logic [7:0] result_reg;
logic new_data;
logic data_read;

RSA_state this_state, next_state;
//Inputs
logic start;
logic ModProd_ready;
logic ModProd_ready_inter;
logic e_j;
logic next_iter;
logic ModProd_wait;
logic ModProd_cont;
logic init_mem_done;

//Outputs
logic reset_data_n;
logic ready;
logic load_x;
logic load_e;
logic load_n;
logic read_u;
logic load_x_reg;
logic load_e_reg;
logic load_n_reg;
logic read_u_reg;
logic ModProd_start;
logic ModProd_start_reg;
logic ModProd_start_in;
logic [1:0] ModProd_op;
logic inc_ic;
logic init_mem;
logic init_mem_reg;

// Memory
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_BN = 0; //0-4
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_P = (DATA_WIDTH/WORD_SIZE); // 5-9
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_Z = (DATA_WIDTH/WORD_SIZE)*2; // 10-14
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_X = (DATA_WIDTH/WORD_SIZE)*3;  //14-19
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_E = (DATA_WIDTH/WORD_SIZE)*4;  // 20 -24
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_N = (DATA_WIDTH/WORD_SIZE)*5; // 25-29
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_const1 = (DATA_WIDTH/WORD_SIZE)*6; // 30 - 34
localparam logic [MEM_ADDR_WIDTH - 1:0] addr_R2 = (DATA_WIDTH/WORD_SIZE)*7; // 35 -39

logic [MEM_ADDR_WIDTH - 1:0] ModProd_addr_A = 0;  
logic [MEM_ADDR_WIDTH - 1:0] ModProd_addr_B = 0;  
logic [MEM_ADDR_WIDTH - 1:0] ModProd_addr_BN = 0;  
logic [MEM_ADDR_WIDTH - 1:0] ModProd_addr_N = 0;
logic [MEM_ADDR_WIDTH - 1:0] ModProd_addr_U = 0;    

logic data_init_0;
logic data_init_1;
logic data_init_2;

logic [WORD_SIZE - 1:0] mem1_out;
logic [WORD_SIZE - 1:0] mem2_out;
logic [WORD_SIZE - 1:0] mem1_in;
logic [WORD_SIZE - 1:0] mem2_in;
logic mem1_write;
logic mem2_write;
logic [MEM_ADDR_WIDTH - 1:0] addr1_in;
logic [MEM_ADDR_WIDTH - 1:0] addr2_in;


logic [MEM_ADDR_WIDTH - 1:0] addr1_RSA;
logic [MEM_ADDR_WIDTH - 1:0] addr2_RSA;
logic [MEM_ADDR_WIDTH - 1:0] addr1_next_RSA;
logic [MEM_ADDR_WIDTH - 1:0] addr2_next_RSA;
logic [WORD_SIZE - 1:0] mem1_out_RSA;
logic [WORD_SIZE - 1:0] mem2_out_RSA;
logic [WORD_SIZE - 1:0] mem1_in_RSA;
logic [WORD_SIZE - 1:0] mem2_in_RSA;
logic mem1_write_RSA;
logic mem2_write_RSA;

assign addr1_next_RSA = addr1_RSA + 1'b1;
assign addr2_next_RSA = addr2_RSA + 1'b1;

logic [MEM_ADDR_WIDTH - 1:0] addr1_ModProd;
logic [MEM_ADDR_WIDTH - 1:0] addr2_ModProd;
logic [WORD_SIZE - 1:0] mem1_out_ModProd;
logic [WORD_SIZE - 1:0] mem2_out_ModProd;
logic [WORD_SIZE - 1:0] mem1_in_ModProd;
logic [WORD_SIZE - 1:0] mem2_in_ModProd;
logic mem1_write_ModProd;
logic mem2_write_ModProd;

logic [WORD_SIZE - 1:0] e_in;
logic next_e;
logic next_e_reg;
logic [MEM_LATENCY + 2: 0] fetch_e;

// Wait 3 cycles, before using true value of ModProd_ready
// Allows for propagation due to ModProd FSM
logic [2:0] ModProd_wait_cnt;
always @(posedge clk) begin
      
      if(ModProd_cont == 1'b1) begin
            ModProd_cont <= 1'b0;
            ModProd_wait_cnt <= '0;
      end
      else if(ModProd_wait_cnt > MODPROD_READY_LATENCY) begin
            ModProd_cont <= 1'b1;
      end
      else if(ModProd_wait) begin
            ModProd_wait_cnt <= ModProd_wait_cnt + 1'b1;
      end

      if(~reset_data_n) begin
            ModProd_wait_cnt <= '0;
            ModProd_cont <= '0;
      end

end

//=======================================================
//  IO Registers
//=======================================================
assign load_x = control_reg.load_x;
assign load_e = control_reg.load_e;
assign load_n = control_reg.load_n;
assign read_u = control_reg.read_u;

always @(posedge clk) begin

      new_data <= 1'b0;
      data_read <= 1'b0;

      if(~write && valid && ready) begin
            if(addr) begin
                  data_out <= result_reg;
                  data_read <= 1'b1;
            end
            else if(~addr) begin
                  data_out <= control_reg;
                  data_read <= 1'b0;
            end            
      end
      else if(write && valid && ready) begin
            if(addr) begin
                  load_reg <= data_in;
                  new_data <= 1'b1;
            end
            else if(~addr) begin
                  control_reg <= data_in;
                  new_data <= 1'b0;
            end
      end

      start <= 1'b0;
      if(control_reg.start) begin
            start <= 1'b1;
            control_reg.start <= 1'b0;
      end

      control_reg.ready <= ready;

      if(~reset_n) begin
            load_reg <= '0;
            control_reg <= '0;
            start <= '0;
      end
end

//=======================================================
//  FSM
//=======================================================
always_comb begin : next_state_logic
      next_state = this_state;
      case(this_state)   
            hold:  begin
                  if(start) begin
                        next_state = reload_mem;      
                  end
                  else begin
                        next_state = hold;
                  end
            end
            reset:  begin
                  next_state = hold;
            end         
            reload_mem:  begin
                  if(init_mem_done) begin
                        next_state = init_P;      
                  end
                  else begin
                        next_state = reload_mem;
                  end
            end
            init_P: begin
                  if(ModProd_cont) begin
                        next_state = init_P_wait;
                  end
                  else begin
                        next_state = init_P;                        
                  end
            end
            init_P_wait: begin
                  if(ModProd_ready) begin
                        next_state = init_Z;
                  end
                  else begin
                        next_state = init_P_wait;                        
                  end
            end
            init_Z: begin
                  if(ModProd_cont) begin
                        next_state = init_Z_wait;
                  end
                  else begin
                        next_state = init_Z;                        
                  end
            end
            init_Z_wait: begin
                  if(ModProd_ready) begin
                        next_state = inc_exp;
                  end
                  else if(~ModProd_ready) begin
                        next_state = init_Z_wait;
                  end
            end
            square: begin
                  if(ModProd_cont) begin
                        next_state = square_wait;
                  end
                  else begin
                        next_state = square;                        
                  end
            end
            square_wait: begin
                  if(ModProd_ready) begin
                        next_state = inc_exp;
                  end
                  else if(~ModProd_ready) begin
                        next_state = square_wait;
                  end
            end
            mult: begin 
                 if(ModProd_cont) begin
                        next_state = mult_wait;
                  end
                  else begin
                        next_state = mult;
                  end
            end
            mult_wait: begin 
                 if(ModProd_ready) begin
                        next_state = square;
                  end
                  else if(~ModProd_ready) begin
                        next_state = mult_wait;
                  end
            end
            inc_exp: begin 
                  if(next_iter) begin
                        if(e_j) begin
                              next_state = mult;
                        end
                        else if(~e_j) begin
                              next_state = square;
                        end
                  end
                  else if(~next_iter) begin
                        next_state = convert_P;
                  end
            end
            convert_P: begin 
                  if(ModProd_cont) begin
                        next_state = convert_P_wait;
                  end
                  else begin
                        next_state = convert_P;                        
                  end
            end
            convert_P_wait: begin 
                  if(ModProd_ready) begin
                        next_state = reduce;
                  end
                  else begin
                        next_state = convert_P_wait;                        
                  end
            end
            reduce: begin 
                  if(ModProd_cont) begin
                        next_state = reduce_wait;
                  end
                  else begin
                        next_state = reduce;                        
                  end
            end
            reduce_wait: begin
                  if(ModProd_ready) begin
                        next_state = reset;
                  end
                  else begin
                        next_state = reduce_wait;                        
                  end
            end
      endcase
end

always_comb begin
      reset_data_n = 1'b1;
      ready = '0;
      inc_ic = '0;
      ModProd_start = '0;
      ModProd_addr_A = '0;  
      ModProd_addr_B = '0;  
      ModProd_addr_BN = '0;  
      ModProd_addr_N = '0;
      ModProd_addr_U = '0;
      inc_ic = '0;
      ModProd_wait = '0;
      ModProd_op = '0;
      init_mem = '0;

      case(this_state)
            reset: begin
                  reset_data_n = 1'b0;
            end
            hold: begin
                  ready = 1'b1;
            end
            reload_mem: begin
                  init_mem = 1'b1;
            end
            init_P: begin
                  ModProd_wait = 1'b1;
                  ModProd_start = 1'b1;
                  ModProd_op = 2'b11;
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_P;  
                  ModProd_addr_BN = addr_P;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            init_P_wait: begin
                  ModProd_op = 2'b11;
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_P;  
                  ModProd_addr_BN = addr_P;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            init_Z: begin
                  ModProd_wait = 1'b1;
                  ModProd_start = 1'b1;
                  ModProd_op = 2'b11;
                  ModProd_addr_A = addr_Z;  
                  ModProd_addr_B = addr_Z;  
                  ModProd_addr_BN = addr_Z;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_Z;
            end
            init_Z_wait: begin
                  ModProd_op = 2'b11;
                  ModProd_addr_A = addr_Z;  
                  ModProd_addr_B = addr_Z;  
                  ModProd_addr_BN = addr_Z;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_Z;
            end
            square: begin
                  ModProd_wait = 1'b1;
                  ModProd_start = 1'b1;
                  ModProd_addr_A = addr_Z;  
                  ModProd_addr_B = addr_Z;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_Z;
            end
            square_wait: begin
                  ModProd_addr_A = addr_Z;  
                  ModProd_addr_B = addr_Z;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_Z;
            end
            mult: begin
                  ModProd_wait = 1'b1; 
                  ModProd_start = 1'b1;
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_Z;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            mult_wait: begin
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_Z;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            convert_P: begin
                  ModProd_wait = 1'b1; 
                  ModProd_start = 1'b1;
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_const1;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            convert_P_wait: begin
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_const1;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            reduce: begin 
                  ModProd_wait = 1'b1; 
                  ModProd_start = 1'b1;
                  ModProd_op = 2'b10;
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_P;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            reduce_wait: begin 
                  ModProd_op = 2'b10;
                  ModProd_addr_A = addr_P;  
                  ModProd_addr_B = addr_P;  
                  ModProd_addr_BN = addr_BN;  
                  ModProd_addr_N = addr_N;
                  ModProd_addr_U = addr_P;
            end
            inc_exp: begin 
                  inc_ic = 1'b1;
            end
      endcase
end

always_ff@(posedge clk) begin
      if(~reset_n)
            this_state <= reset;
      else
            this_state <= next_state;
end



//=======================================================
//  Multiplier + Data path
//=======================================================

      ModProd #( 
        .DEVICE_FAMILY (DEVICE_FAMILY),
        .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH),   
        .WORD_SIZE     (WORD_SIZE), 
        .DATA_WIDTH    (DATA_WIDTH),
        .ITERATIONS    (ITERATIONS))
      MultCore (
            .clk                    (clk), 
            .reset_n                (reset_n), 

            .op                     (ModProd_op),

            .addr_A_i               (ModProd_addr_A),
            .addr_B_i               (ModProd_addr_B),
            .addr_BN_i              (ModProd_addr_BN),
            .addr_N_i               (ModProd_addr_N),
            .addr_U_i               (ModProd_addr_U),
            
            // General memory
            .mem1_out_i             (mem1_out_ModProd),
            .mem2_out_i             (mem2_out_ModProd),
            .mem1_in_o              (mem1_in_ModProd),
            .mem2_in_o              (mem2_in_ModProd),
            .mem1_write_o           (mem1_write_ModProd),
            .mem2_write_o           (mem2_write_ModProd),
            .addr1_o                (addr1_ModProd),
            .addr2_o                (addr2_ModProd),

            .start_i                (ModProd_start), 
            .ready_o                (ModProd_ready)
      );


logic [$clog2(DATA_WIDTH) - 1:0] iter_counter;

always @(posedge clk) begin

      fetch_e <= '0;
      for(int i = 0; i < MEM_LATENCY + 2; i++) begin
            fetch_e[i+1] <= fetch_e[i];
            fetch_e[0] <= 1'b0;
      end
      if(inc_ic) begin      
            next_iter <= 1'b1;
            iter_counter <= iter_counter + 1'b1;
            if(iter_counter > (EXP_WIDTH - 2))
                  next_iter <= 1'b0;

            if(iter_counter[$clog2(WORD_SIZE) - 1:0] == {($clog2(WORD_SIZE)){1'b1}}) begin
                  fetch_e[0] <= 1'b1;
            end
      end
      if(~reset_data_n) begin
            iter_counter <= '0;
            next_iter <= 1'b1;
            next_e <= '0;
            fetch_e <= '0;
      end
end

// Exp shift
lpm_shiftreg #(
      .lpm_width(WORD_SIZE),
      .lpm_direction("RIGHT"))
      exp_shift_0(
      .data(e_in),
      .clock(clk),
      .enable(inc_ic||(fetch_e[MEM_LATENCY + 1])||ready),
      .shiftin(1'b0),
      .load((fetch_e[MEM_LATENCY + 1])||ready),
      .aclr(),
      .aset(),
      .sclr(),
      .sset(),
      .q(),
      .shiftout(e_j)
);


//=======================================================
//  Memory Management
//=======================================================
always_comb begin

      if((ready || init_mem_reg) && addr1_RSA < MEMORY_WORDS) begin
            addr1_in = addr1_RSA;
      end
      else if(~(ready || init_mem_reg) && addr1_ModProd < MEMORY_WORDS) begin
            addr1_in = addr1_ModProd;                 
      end
      else begin
            addr1_in = {MEM_ADDR_WIDTH{1'b0}};
      end
         
end

always_comb begin

      if((fetch_e[1] || ready || init_mem_reg) && addr2_RSA < MEMORY_WORDS) begin
            addr2_in = addr2_RSA;
      end
      else if(~(fetch_e[1] || ready || init_mem_reg) && addr2_ModProd < MEMORY_WORDS) begin
            addr2_in = addr2_ModProd;                 
      end
      else begin
            addr2_in = {MEM_ADDR_WIDTH{1'b0}};
      end

end

always_comb begin

      if(ready || init_mem_reg || (fetch_e[MEM_LATENCY])) begin
            mem1_out_RSA = mem1_out;
            mem2_out_RSA = mem2_out;
            mem1_out_ModProd = '0;
            mem2_out_ModProd = '0;
            mem1_in    = mem1_in_RSA;    
            mem2_in    = mem2_in_RSA;
            mem1_write = mem1_write_RSA;
            mem2_write = mem2_write_RSA;
      end
      else begin
            mem1_out_ModProd = mem1_out;
            mem2_out_ModProd = mem2_out;
            mem1_out_RSA = '0;
            mem2_out_RSA = '0;
            mem1_in    = mem1_in_ModProd;    
            mem2_in    = mem2_in_ModProd;
            mem1_write = mem1_write_ModProd;
            mem2_write = mem2_write_ModProd;
      end

end

      int_ram #(
      .MEM_WIDTH(WORD_SIZE),
      .MEM_WORDS(MEMORY_WORDS)
      )main_ram(
      .address_1 (addr1_in),
      .address_2 (addr2_in),
      .clk (clk),
      .data_1(mem1_in),
      .data_2(mem2_in),
      .rden_1(1'b1),
      .rden_2(1'b1),
      .wren_1(mem1_write),
      .wren_2(mem2_write),
      .q_1(mem1_out),
      .q_2(mem2_out));

logic addr1_load;
logic [4:0] addr1_index;
logic addr1_incr;
logic addr1_incr_2;
logic [MEM_ADDR_WIDTH - 1:0] data_cnt;

logic addr2_load;
logic [3:0] addr2_index;
logic addr2_incr;
logic addr2_incr_2;
logic [MEM_ADDR_WIDTH - 1:0] addr2_cnt;

logic read_back_switch;

// Addr1 loaded in 4 cases:
// when ready, user data x, e, n can be loaded. assume user doesn't assert at same time
// init_mem only asserted ready is low, user doesn't pass data on ready low

assign addr1_load = (load_x && ~load_x_reg) || (load_e && ~load_e_reg) || (load_n && ~load_n_reg) ||  (read_u && ~read_u_reg) || (init_mem && ~init_mem_reg);
assign addr1_index = {(load_x && ~load_x_reg), (load_n && ~load_n_reg), (load_e && ~load_e_reg), (read_u && ~read_u_reg), (init_mem && ~init_mem_reg)};

assign addr1_incr = ~addr1_load && (new_data) || (init_mem_reg) && (data_cnt < OPERAND_WORDS);
assign addr1_incr_2 = ~addr1_load && (data_read || data_init_2) && ~read_back_switch && data_cnt < (OPERAND_WORDS/2 + 1);

assign addr2_load = (init_mem && ~init_mem_reg) || (read_u && ~read_u_reg) || (~init_mem && init_mem_reg) || (~read_u && read_u_reg);
assign addr2_index = {(read_u && ~read_u_reg), (init_mem && ~init_mem_reg), (~read_u && read_u_reg), (~init_mem && init_mem_reg)};

assign addr2_incr = ~addr2_load && (init_mem_reg) || (fetch_e[0]) && addr2_cnt < (OPERAND_WORDS);
assign addr2_incr_2 = ~addr2_load && (data_read || data_init_2) && read_back_switch  && addr2_cnt < (OPERAND_WORDS/2);

always_ff @(posedge clk) begin
     
      next_e_reg <= next_e;
      load_x_reg <= load_x;
      load_e_reg <= load_e;
      load_n_reg <= load_n;
      read_u_reg <= read_u;
      init_mem_reg <= init_mem; 

      mem1_write_RSA <= '0;
      mem2_write_RSA <= '0;            
      data_init_0 <= '0;
      data_init_1 <= data_init_0;
      data_init_2 <= data_init_1;

      // Memory 1 load
      if(addr1_load) begin
            case(addr1_index)
                  5'h0: addr1_RSA <= addr1_RSA;
                  5'h10: addr1_RSA <= addr_Z - 1;
                  5'h8: addr1_RSA <= addr_N - 1;
                  5'h4: addr1_RSA <= addr_E - 1;
                  5'h2: addr1_RSA <= addr_P; 
                  5'h1: addr1_RSA <= addr_const1 - 1;
            endcase
            data_cnt <= '0;
      end
      // Memory 1 count
      else if(addr1_incr) begin
            data_cnt <= data_cnt + 1'b1;
            addr1_RSA <= addr1_next_RSA;
      end
      else if(addr1_incr_2) begin
            data_cnt <= data_cnt + 1'b1;
            addr1_RSA <= addr1_next_RSA + 1;
      end
      else begin
            data_cnt <= data_cnt;
            addr1_RSA <= addr1_RSA;
      end


      // Memory 1 data in
      if(data_cnt < OPERAND_WORDS && new_data) begin
            mem1_in_RSA <= load_reg;
            mem1_write_RSA <= 1'b1;
      end
      else if(data_cnt == 0 && init_mem_reg) begin
            mem1_in_RSA <= {{(WORD_SIZE-1){1'b0}},{1'b1}};
            mem1_write_RSA <= 1'b1;
      end 
      else if(data_cnt < (OPERAND_WORDS) && init_mem_reg) begin
            mem1_in_RSA <= '0;
            mem1_write_RSA <= 1'b1;
      end    
      else begin
            mem1_in_RSA <= '0;
            mem1_write_RSA <= '0;
      end



      // Ext signals
      if(read_u && ~read_u_reg) begin
            data_init_0 <= 1'b1;
      end
      else begin
            data_init_0 <= 1'b0;
      end

      if(init_mem_reg && (data_cnt > (OPERAND_WORDS - 3))) begin
            init_mem_done <= 1'b1;
      end
      else begin
            init_mem_done <= 1'b0;
      end

      if(data_read || data_init_2) begin
            read_back_switch <= ~read_back_switch;
      end
      else begin
            read_back_switch <= read_back_switch;
      end


      // Memory 2 load
      if(addr2_load) begin
            case(addr2_index)
                  4'h0: addr2_RSA <= addr2_RSA;
                  4'h8: addr2_RSA <= addr_P + 1;
                  4'h4: addr2_RSA <= addr_P - 1;
                  4'h2: addr2_RSA <= addr_E;
                  4'h1: addr2_RSA <= addr_E; 
            endcase
            addr2_cnt <= '0;
      end

      // Memory 1 count
      else if(addr2_incr) begin
            addr2_cnt <= addr2_cnt + 1'b1;
            addr2_RSA <= addr2_next_RSA;
      end
      else if(addr2_incr_2) begin
            addr2_cnt <= addr2_cnt + 1'b1;
            addr2_RSA <= addr2_next_RSA + 1;
      end
      else begin
            addr2_cnt <= addr2_cnt;
            addr2_RSA <= addr2_RSA;
      end

      // Memory 2 data in
      if(addr2_cnt == 0 && init_mem_reg) begin
            mem2_in_RSA <= {{(WORD_SIZE-1){1'b0}},{1'b1}};
            mem2_write_RSA <= 1'b1;
      end 
      else if(addr2_cnt < (OPERAND_WORDS) && init_mem_reg) begin
            mem2_in_RSA <= '0;
            mem2_write_RSA <= 1'b1;
      end    
      else begin
            mem2_in_RSA <= '0;
            mem2_write_RSA <= '0;
      end

      // Memory data out
      if(|fetch_e || ready) begin
            e_in <= mem2_out_RSA;            
      end
      else begin
            e_in <= e_in;
      end

      // Memory data out
      if(read_u && (data_read || data_init_2)) begin
            if(~read_back_switch) begin
                  result_reg <= mem1_out_RSA;
            end
            else begin
                  result_reg <= mem2_out_RSA;
            end
      end
      else begin
            result_reg <= result_reg;
      end

      if(~reset_data_n) begin    
            addr1_RSA <= {MEM_ADDR_WIDTH{1'b1}};
            addr2_RSA <= addr_E;
            mem1_write_RSA <= '0;
            mem2_write_RSA <= '0;
            mem1_in_RSA <= '0;
            mem2_in_RSA <= '0;
            data_cnt <= '0;
            addr2_cnt <= '0;
            result_reg <= '0;
            e_in <= '0;
            init_mem_reg <= '0;
            init_mem_done <= '0;
            read_back_switch <= '0;
      end
end


endmodule
