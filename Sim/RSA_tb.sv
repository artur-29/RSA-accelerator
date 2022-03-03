

import ModProd_pkg::*;
import RSA_pkg::*;
`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
module RSA_tb#(
      )
      (
);


    localparam   CLK_FREQ_GHZ             =     0.250; //GHz
    localparam   CLK_FREQ                 =     250000000; //Hz
    localparam   CLK_PERIOD               =     1/CLK_FREQ;
    localparam   CLK_PERIOD_NS            =     1/CLK_FREQ_GHZ;

    localparam   TEST_ITERATIONS          =     100;
    localparam   LAT_TIMEOUT              =     20000;
    localparam   READY_TIMEOUT            =     20000;

    localparam   DUT_DATA_WIDTH           =     32; // k
    localparam   DUT_WORD_SIZE            =     8;
    localparam   DUT_DATA_PADDING         =     DUT_WORD_SIZE;
    localparam   DUT_MAX_DATA_WIDTH       =     DUT_DATA_WIDTH+DUT_DATA_PADDING; // k +    
    localparam   DUT_EXP_WIDTH            =     DUT_DATA_WIDTH;
    localparam   DUT_DEVICE_FAMILY        =     "Cyclone V";

    localparam   TB_WORD_SIZE             =     32;
    localparam   int TB_WORDS             =     ((DUT_DATA_WIDTH-1)/TB_WORD_SIZE) + 1;
    

    logic                              clk;
    logic                              reset_n;

    // Test data
    logic [DUT_MAX_DATA_WIDTH - 1:0]   init_x = '0;
    logic [DUT_MAX_DATA_WIDTH - 1:0]   init_e = '0;
    logic [DUT_MAX_DATA_WIDTH - 1:0]   init_n = '0;
    logic [DUT_MAX_DATA_WIDTH - 1:0]   init_r = '0;



    logic [DUT_MAX_DATA_WIDTH - 1:0]   upper_range = 0;
    int                                break_chance = 0;


    logic [DUT_MAX_DATA_WIDTH - 1:0]   model_result;
    logic [DUT_MAX_DATA_WIDTH - 1:0]   dut_result;


    // DUT IO
    control_reg_type                   test_ctrl_reg;
    logic [7:0]                        dut_data_in;
    logic [7:0]                        dut_data_out;
    logic                              dut_addr;
    logic                              dut_write;
    logic                              dut_valid;



    RSA #( 
        .DEVICE_FAMILY (DUT_DEVICE_FAMILY),
        .WORD_SIZE     (DUT_WORD_SIZE), 
        .INPUT_WIDTH   (DUT_DATA_WIDTH)
        )
    DUT (   
        .clk (clk),
        .reset_n (reset_n),
        .data_in (dut_data_in),
        .data_out (dut_data_out),
        .addr (dut_addr),
        .write (dut_write),
        .valid (dut_valid)
        );
    

    // Test stats
    int total_fails = 0;
    int internal_fails = 0;
    longint test_latency = 0;
    longint avg_latency = 0;
    real avg_latency_s = 0;
    longint worst_latency = 0;
    longint best_latency = (2**63)-1;
    real avg_throughput = 0;
    real test_thru = 0;
    real avg_throughput1 = 0; 
    real bit_period = 0;


initial begin
    $timeformat(-9, 2, "ns");
    
    init_r = {{1'b1},{DUT_DATA_WIDTH{1'b0}}}; // r = 2^k, constant
    clk = 0;
    reset_n = 1'b0;


    #50 reset_n = 1'b1;


    // Randomized X(plaintext), E(exponent) and N (modulus), with half of test cases having all words non-zero
    // First 3 iterations are corner cases
    for(int test_iter = 0; test_iter < TEST_ITERATIONS + 5; test_iter++) begin
            
    $display("\n\n\n");
    $display("Iteration: %d", test_iter);
    $display("Time: %t", $realtime);
    

    $display("Data_width: %d, tb_words:%d", DUT_DATA_WIDTH, TB_WORDS);
    init_x = '0;
    init_e = '0;
    init_n = '0;


    //Initialize n
    //$display("\nInit_x");
    upper_range = 2**(DUT_DATA_WIDTH-2)-1;

    if(test_iter > 3) begin
        for(int i = 0; i < TB_WORDS; i++) begin
            

            break_chance = $urandom_range(TB_WORDS, 0);
            //$display("I: %d, break_chance: %d", i, break_chance);

            if(i > 0 && (break_chance == TB_WORDS) && test_iter > TEST_ITERATIONS/2 + 4) // One in TB_WORDS chance that randomization stops at current word
                break;

            if(upper_range == '0) begin
                init_n[i*TB_WORD_SIZE+:TB_WORD_SIZE] = '0;
            end
            else if(upper_range < {TB_WORD_SIZE{1'b1}}) begin // last slice
                init_n[i*TB_WORD_SIZE+:TB_WORD_SIZE] = $urandom_range(upper_range, 1); //ensure is odd
            end  
            else begin
                init_n[i*TB_WORD_SIZE+:TB_WORD_SIZE] = $urandom(); //ensure is odd
            end

            //$display("Hex:%x\nupper_range:%x\n", init_n[i*TB_WORD_SIZE+:TB_WORD_SIZE], upper_range);
            upper_range = upper_range >> TB_WORD_SIZE;

        end
    end
    else if(test_iter == 0) begin
        init_n = upper_range;
    end 
    else if(test_iter == 1) begin
        init_n = 1;
    end
    else if(test_iter == 2) begin
        init_n = 2;
    end
    else if(test_iter == 3) begin
        init_n = {{1'b1},{DUT_DATA_WIDTH-3{1'b0}}};
    end

    //init_n = 32'h000c8eb895;
    if(init_n%2 == 0) begin
        init_n = init_n + 1;
    end 

 

    //Initialize x
    //$display("\nInit_x");

    upper_range = init_n - 1;

    if(test_iter > 3) begin
        for(int i = 0; i < TB_WORDS; i++) begin
            

            break_chance = $urandom_range(TB_WORDS, 0);
            //$display("I: %d, break_chance: %d", i, break_chance);

            if(i > 0 && (break_chance == TB_WORDS) && test_iter > TEST_ITERATIONS/2 + 4) // One in TB_WORDS chance that randomization stops at current word
                break;

            if(upper_range == '0) begin
                init_x[i*TB_WORD_SIZE+:TB_WORD_SIZE] = '0;
            end
            else if(upper_range < {TB_WORD_SIZE{1'b1}}) begin // last slice
                init_x[i*TB_WORD_SIZE+:TB_WORD_SIZE] = $urandom_range(upper_range, 1); //ensure is odd
            end  
            else begin
                init_x[i*TB_WORD_SIZE+:TB_WORD_SIZE] = $urandom(); //ensure is odd
            end
            
            //$display("Hex:%x\nupper_range:%x\n", init_x[i*TB_WORD_SIZE+:TB_WORD_SIZE], upper_range);
            upper_range = upper_range >> TB_WORD_SIZE;

        end
    end
    else if(test_iter == 0) begin
        init_x = upper_range;
    end 
    else if(test_iter == 1) begin
        init_x = 0;
    end
    else if(test_iter == 2) begin
        init_x = 1;
    end
    else if(test_iter == 3) begin
        init_x = {{1'b1},{DUT_DATA_WIDTH-4{1'b0}}};
    end

    //init_x = 32'h0001e9adce;


    //Initialize e
    //$display("\nInit_e");

    upper_range = 2**(DUT_DATA_WIDTH-2)-1;

    if(test_iter > 3) begin
        for(int i = 0; i < TB_WORDS; i++) begin
            

            break_chance = $urandom_range(TB_WORDS, 0);
            //$display("I: %d, break_chance: %d", i, break_chance);
            
            if(i > 0 && (break_chance == TB_WORDS) && test_iter > TEST_ITERATIONS/2 + 4) // One in TB_WORDS chance that randomization stops at current word
                break;
            
            if(upper_range == '0) begin
                init_e[i*TB_WORD_SIZE+:TB_WORD_SIZE] = '0;
            end        
            else if(upper_range < {TB_WORD_SIZE{1'b1}}) begin // last slice
                init_e[i*TB_WORD_SIZE+:TB_WORD_SIZE] = $urandom_range(upper_range, 1); //ensure is odd
            end  
            else begin
                init_e[i*TB_WORD_SIZE+:TB_WORD_SIZE] = $urandom(); //ensure is odd
            end
            
            //$display("Hex:%x\nupper_range:%x\n", init_e[i*TB_WORD_SIZE+:TB_WORD_SIZE], upper_range);
            upper_range = upper_range >> TB_WORD_SIZE;

        end
    end
    else if(test_iter == 0) begin
        init_e = upper_range;
    end 
    else if(test_iter == 1) begin
        init_e = 1;
    end
    else if(test_iter == 2) begin
        init_e = 2;
    end
    else if(test_iter == 3) begin
        init_e = {{1'b1},{DUT_DATA_WIDTH-3{1'b0}}};
    end

    //init_e = 32'h001a5891d7;

    $display("Dec.\nX:%d\nE:%d\nN:%d\nR:%d\n\n", init_x, init_e, init_n, init_r);
    $display("Hex.\nX:%x\nE:%x\nN:%x\nR:%x\n\n", init_x, init_e, init_n, init_r);

    if(init_x < init_n && init_n < 2**(DUT_DATA_WIDTH-2) && init_x < 2**(DUT_DATA_WIDTH-2) && init_e < 2**(DUT_DATA_WIDTH-2)) begin
        $display("Randomization correct \n");
    end
    else begin
        $stop;
    end

    init_x = {{DUT_DATA_PADDING{1'b0}},init_x};
    init_e = {{DUT_DATA_PADDING{1'b0}},init_e};
    init_n = {{DUT_DATA_PADDING{1'b0}},init_n};

    RSA_DUT(init_x, init_e, init_n, init_r, dut_result, test_latency);

    if(test_latency > worst_latency) begin
        worst_latency = test_latency;
    end
    if (test_latency < best_latency) begin
        best_latency = test_latency;
    end
    avg_latency = avg_latency + test_latency;

    model_result = RSA_MODEL(init_x, init_e, init_n);

    $display("Dec.\ndut_result:%d\nmodel_result:%d\n\n", dut_result, model_result);
    $display("Dec.\ndut_result:%x\nmodel_result:%x\n\n", dut_result, model_result);

    if(dut_result == model_result) begin
        $display("SUCCESS: Result correct");
        //$stop;
    end
    else begin
        $display("FAILED: dut_result != model_result");
        total_fails++;
        $stop;
    end
    $display("  test_latency = %d\n\n", test_latency);


    end
    avg_latency = avg_latency/TEST_ITERATIONS;

    avg_latency_s = real'(real'(avg_latency)/real'(CLK_FREQ));
    avg_throughput = real'(real'(DUT_DATA_WIDTH)/real'(avg_latency_s));
    //avg_throughput = real'(DUT_DATA_WIDTH)/(real'(avg_latency)*real'(CLK_PERIOD));   
    avg_throughput1 = real'(DUT_DATA_WIDTH/avg_latency_s);

    $display("All tests finished. Total_fails: %d, worst_latency: %d, best_latency: %d, avg_latency: %d, avg_latency_s: %f, avg_throughput: %f, avg_throughput: %f", total_fails, worst_latency, best_latency, avg_latency, avg_latency_s, avg_throughput, avg_throughput1);
    $stop;
end




always 
begin
    clk = 1'b1; 
    #CLK_PERIOD_NS; 

    clk = 1'b0;
    #CLK_PERIOD_NS; 
end

task load_data;
    input logic [DUT_MAX_DATA_WIDTH - 1:0] test_x, test_e, test_n;
    begin
 
        $display("Loading data ...\n");
        $display("Dec.\nX:%d\nE:%d\nN:%d\n\n", test_x, test_e, test_n);
        $display("Hex.\nX:%x\nE:%x\nN:%x\n\n", test_x, test_e, test_n);

        test_ctrl_reg = '0;
        dut_data_in = '0;
        dut_addr = '0;
        dut_valid = '0;
        dut_write = '0;
        @(posedge clk)
        // Load_x
        test_ctrl_reg = '0;
        test_ctrl_reg.load_x = 1'b1;
        dut_addr = 1'b0;
        dut_write = 1'b1;
        dut_valid = 1'b1;
        dut_data_in = test_ctrl_reg;
        @(posedge clk);

        $display("Load x\n");
        for(int i = 0; i < (DUT_MAX_DATA_WIDTH/DUT_WORD_SIZE); i++) begin
            dut_addr = 1'b1;
            dut_write = 1'b1;
            dut_valid = 1'b1;
            dut_data_in = test_x[i*DUT_WORD_SIZE+:DUT_WORD_SIZE];
            $display("Data in: %x\n", dut_data_in);
            @(posedge clk);
        end
        
        // Load e
        test_ctrl_reg = '0;
        test_ctrl_reg.load_e = 1'b1;
        dut_addr = 1'b0;
        dut_write = 1'b1;
        dut_valid = 1'b1;
        dut_data_in = test_ctrl_reg;
        @(posedge clk);


        $display("Load e\n");
        for(int i = 0; i < (DUT_MAX_DATA_WIDTH/DUT_WORD_SIZE); i++) begin
            dut_addr = 1'b1;
            dut_write = 1'b1;
            dut_valid = 1'b1;
            dut_data_in = test_e[i*DUT_WORD_SIZE+:DUT_WORD_SIZE];
            $display("Data in: %x\n", dut_data_in);
            @(posedge clk);
        end

        // Load n
        test_ctrl_reg = '0;
        test_ctrl_reg.load_n = 1'b1;
        dut_addr = 1'b0;
        dut_write = 1'b1;
        dut_valid = 1'b1;
        dut_data_in = test_ctrl_reg;
        @(posedge clk);

        $display("Load n\n");
        for(int i = 0; i < (DUT_MAX_DATA_WIDTH/DUT_WORD_SIZE); i++) begin
            dut_addr = 1'b1;
            dut_write = 1'b1;
            dut_valid = 1'b1;
            dut_data_in = test_n[i*DUT_WORD_SIZE+:DUT_WORD_SIZE];
            $display("Data in: %x\n", dut_data_in);
            @(posedge clk);
        end      

        // Start  
        test_ctrl_reg = '0;
        test_ctrl_reg.start = 1'b1;
        dut_addr = '0;
        dut_valid = '1;
        dut_write = '1;
        dut_data_in = test_ctrl_reg;
        @(posedge clk);
        test_ctrl_reg = '0;
        dut_data_in = '0;
        dut_addr = '0;
        dut_valid = '0;
        dut_write = '0;
        @(posedge clk);
    end
endtask


task poll_ready;
    output integer latency;
    begin
 
        latency = 0;

        $display("Polling ready ...\n");
        test_ctrl_reg = '0;
        dut_data_in = '0;
        dut_addr = '0;
        dut_valid = '0;
        dut_write = '0;
        @(posedge clk)
        
        // Read ctrl
        dut_addr = 1'b0;
        dut_write = 1'b0;
        dut_valid = 1'b1;
        @(posedge clk);

        test_ctrl_reg = dut_data_out;
        $display("Data in: %x\n", dut_data_out);
        @(posedge clk);

        while(test_ctrl_reg.ready != 1'b1) begin
            
            latency++;

            test_ctrl_reg = '0;
            dut_data_in = '0;
            dut_addr = '0;
            dut_valid = '0;
            dut_write = '0;
            @(posedge clk);
            
            // Read ctrl
            dut_addr = 1'b0;
            dut_write = 1'b0;
            dut_valid = 1'b1;
            @(posedge clk);

            test_ctrl_reg = dut_data_out;
            //$display("Data in: %x\n", dut_data_out);
            @(posedge clk);
        end
        
    end
endtask

task read_back;
    output logic [DUT_MAX_DATA_WIDTH - 1:0] out_u;    
    begin
 
        logic [7:0] data;
        $display("Reading U ...\n");
 
        test_ctrl_reg = '0;
        dut_data_in = '0;
        dut_addr = '0;
        dut_valid = '0;
        dut_write = '0;
        @(posedge clk)
        
        // set flag read_u
        test_ctrl_reg = '0;
        test_ctrl_reg.read_u = 1'b1;
        dut_addr = 1'b0;
        dut_write = 1'b1;
        dut_valid = 1'b1;
        dut_data_in = test_ctrl_reg;

        @(posedge clk)
        test_ctrl_reg = '0;
        dut_data_in = '0;
        dut_addr = '0;
        dut_valid = '0;
        dut_write = '0;
        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);


        for(int i = 0; i < (DUT_MAX_DATA_WIDTH/DUT_WORD_SIZE); i++) begin

            // Read data_reg
            dut_addr = 1'b1;
            dut_write = 1'b0;
            dut_valid = 1'b1;
            @(posedge clk);    

            dut_valid = '0;
            #(CLK_PERIOD_NS/2)
            
            data = dut_data_out;
            $display("Data received: %x\n", dut_data_out);
            out_u[i*DUT_WORD_SIZE+:DUT_WORD_SIZE] = dut_data_out;
            $display("Hex.\nU:%x\n", out_u);
            @(posedge clk);

        end
        
    end
endtask




function logic [DUT_MAX_DATA_WIDTH*3 - 1:0] RSA_MODEL (logic [DUT_MAX_DATA_WIDTH*3 - 1:0] x_in, e_in, n_in);
    logic [DUT_MAX_DATA_WIDTH*3 - 1:0] P_test, Z_test;

    $display("Starting model routine ...\n");
    P_test = 1;
    Z_test = x_in;
    for(int i = 0; i < DUT_EXP_WIDTH; i++) begin
        if(e_in[i]) begin
            P_test = (P_test*Z_test)%n_in;
        end
        Z_test = (Z_test*Z_test)%n_in;
    end
    
    $display("Model routine complete\n");
    return P_test;
endfunction


task RSA_DUT;
    input logic [DUT_MAX_DATA_WIDTH - 1:0] test_x, test_e, test_n, test_r;
    output logic [DUT_MAX_DATA_WIDTH - 1:0] out_u; output longint latency;  
    begin

        logic [DUT_MAX_DATA_WIDTH - 1:0] x, e, n, r, u;
        automatic integer MP_fails = 0;

        x = test_x;
        e = test_e;
        n = test_n;
        r = test_r;
    
        $display("Starting DUT routine ...\n");
        $display("Dec.\nX:%d\nE:%d\nN:%d\n\n", x, e, n);
        $display("Hex.\nX:%x\nE:%x\nN:%x\n\n", x, e, n);


        load_data(x, e, n);

        // Uncomment to enable debug routines
        //Exp_verify(x, e, n, r);

        poll_ready(latency);
        read_back(u);
        $display("Hex.\nU:%x\n", u);

        //wait(ready == 1'b1);
        $display("DUT routine complete\n");
        out_u = u;
    
    end
endtask

task measure_latency;
    output integer latency;
    begin
        latency = 0;

        while(DUT.ready == 0) begin
            @(posedge clk)
            latency++;
        end
    end
endtask

task wait_cycles;
    input integer cycles;
    begin
        for(int i = 0; i < cycles; i++) begin
            @(posedge clk);
        end
    end
endtask

 
// Debug tasks
function longint unsigned MontProd (longint unsigned a_bar_in, b_bar_in, n_in, r_in, n_dash_in);
    automatic longint unsigned t, m, res_a, res_b;
    $display("ModProd task in. A: %x, B:%x, N:%x, R:%x", a_bar_in, b_bar_in, n_in, r_in);

    //$display("a_bar:%x, b_bar:%x, r:%x, n:%x, n_dash:%x", a_bar_in, b_bar_in, r_in, n_in, n_dash_in);    
    t = a_bar_in*b_bar_in;
    m = (t*n_dash_in)%r_in;
    res_a = t+m*n_in;
    res_b = res_a/r_in;
    $display("t:%x, m:%x, res_a:%x, res_b:%x", t, m, res_a, res_b);    
    if(res_b >= n_in)
        return res_b-n_in;
    else
        return res_b;
endfunction


task Exp_verify;
    input logic [DUT_MAX_DATA_WIDTH*3 - 1:0] x, e, n, r;
    begin

        int test_P, test_Z;

        automatic integer conversion_fails = 0;
        $display("\n\n");

        wait(DUT.this_state == init_P);
        $display("Time: %t", $realtime);
        $display("Init_P");

        Convert_verify(1, n, r, conversion_fails, test_P);
        wait(DUT.this_state == init_Z);
        $display("Time: %t", $realtime);
        $display("Init_Z");

        Convert_verify(x, n, r, conversion_fails, test_Z);

        for(int i = 0; i < DUT_EXP_WIDTH; i++) begin
            
            $display("\n\n\n");
            $display("Iteration: %d", i);
            $display("Test_P: %x, Test_Z:%x", test_P, test_Z);

            wait(DUT.this_state == inc_exp);
            $display("e_j: %d", DUT.e_j);

            if(DUT.e_j != e[i]) begin // check exponent bit
                $display("Error: exp bit incorrect");
                $stop;
            end
            else if(DUT.e_j == e[i]) begin
                $display("Exp correct");
                //$stop;
            end

            if(DUT.e_j == 1) begin                

                $display("\n\n");
                wait(DUT.this_state == mult);
                $display("Test_P: %x, Test_Z:%x", test_P, test_Z);
                $display("Time: %t", $realtime);
                $display("Mult");
                $display("MultCore expected in. A: %x, B:%x, N:%x, R:%x", test_P, test_Z, n, r);
                ModProd_verify(test_P, test_Z, n, internal_fails);

                wait(DUT.ModProd_ready);
                #(CLK_PERIOD/4);

                $display("Time: %t", $realtime);
                $display("u_output: %x", DUT.MultCore.sum_u);

                test_P = DUT.MultCore.sum_u;
            end
            
            $display("\n\n");
            wait(DUT.this_state == square);
            $display("Time: %t", $realtime);
            $display("Square");
            $display("MultCore expected in. A: %x, B:%x, N:%x, R:%x", test_Z, test_Z, n, r);
            ModProd_verify(test_Z, test_Z, n, internal_fails);

            wait(DUT.ModProd_ready);
            #(CLK_PERIOD/4);
            $display("Time: %t", $realtime);

            $display("u_output: %x", DUT.MultCore.sum_u);
            test_Z = DUT.MultCore.sum_u;

            wait(DUT.this_state == inc_exp);
            $display("Test_P: %x, Test_Z:%x", test_P, test_Z);
        end
    end
endtask

task Convert_verify;
    input logic [DUT_MAX_DATA_WIDTH*3 - 1:0] in, n, r;
    output integer fail, result;
    begin
        logic [DUT_MAX_DATA_WIDTH*3 - 1:0] temp;
        logic [DUT_MAX_DATA_WIDTH*3 - 1:0] temp1;
        logic [DUT_MAX_DATA_WIDTH*3 - 1:0] prev_sum;


        $display("in:%x, r:%x, n:%x,", in, r, n);

        temp = in;
        prev_sum = '0;


        for(int i = 0; i < DUT_DATA_WIDTH; i++) begin
            
            $display("\nI: %d", i);

            wait(DUT.MultCore.this_state == MP_shift_l);
            #(CLK_PERIOD_NS/4);
            $display("Time: %t", $realtime);
            $display("Temp unshifted: %x, DUT.MultCore.sum_u: %x", temp, DUT.MultCore.sum_u);
            
            temp = temp << 1;
            wait(DUT.MultCore.this_state == MP_store_u);
            #(CLK_PERIOD_NS/4);
            $display("Time: %t", $realtime);
            $display("Temp shifted: %x, DUT.MultCore.sum_u: %x", temp, DUT.MultCore.sum_u);
            while(temp > n) begin
                temp = temp - n;
            end    
            $display("temp_subtracted: %x", temp);
        end

        //temp1 = (in*r)%n;
        wait(DUT.MultCore.this_state == MP_sub_N_mem);
        wait(DUT.MultCore.this_state == MP_store_u);
        #(CLK_PERIOD_NS/4);
        $display("expecte value: %x, DUT.MultCore.sum_u: %x", temp, DUT.MultCore.sum_u);

        if(DUT.MultCore.sum_u != temp) begin
            $display("Time: %t, Error: incorrect conversion to montgomery domain", $realtime);
            $stop;
        end          
        result = temp;
    end
endtask

task ModProd_verify;
    input logic [DUT_MAX_DATA_WIDTH - 1:0] internal_a, internal_b, internal_n;
    output integer fail;
    begin

    ModProd_state                      cur_op;
    logic [DUT_MAX_DATA_WIDTH - 1:0]   prev_u;

        cur_op = MP_shift_r;
        prev_u = '0;
        fail = 0;

            for(int i = 0; i < DUT_DATA_WIDTH; i++) begin
               


                wait(DUT.MultCore.this_state == MP_inc_iter);
                #(CLK_PERIOD_NS/4);
                $display("Time: %t", $realtime);


                $display("a: %x, a bit expected:%x, a bit:%x", internal_a, internal_a[i], DUT.MultCore.a_j);
                if(DUT.MultCore.a_j != internal_a[i]) begin // check exponent bit
                    $display("Error: a bit incorrect");
                    $stop;
                end
                else if(DUT.MultCore.a_j == internal_a[i]) begin
                    $display("a bit correct");
                    //$stop;
                end

                $display("Prev u: %x, cur_op: %0s", prev_u, cur_op.name());
                if(cur_op == MP_add_B) begin
                    $display("B: %x, 2*B: %x, true_sum: %x, obs_sum: %x", internal_b, 2*internal_b, (2*internal_b+prev_u)/2, DUT.MultCore.sum_u);
                    if(DUT.MultCore.sum_u != (prev_u + 2*internal_b)/2) begin
                        $display("Error: wrong sum adding B");
                        fail = 1;
                        $stop;
                    end
                end
                else if(cur_op == MP_add_BN) begin
                    $display("B+N: %x, true_sum: %x, obs_sum: %x", 2*internal_b+internal_n, (2*internal_b+internal_n+prev_u)/2, DUT.MultCore.sum_u);
                    if(DUT.MultCore.sum_u != (prev_u + 2*internal_b+internal_n)/2) begin
                        $display("Error: wrong sum adding B+N");
                        fail = 1;
                        $stop;
                    end
                end
                else if(cur_op == MP_add_N) begin
                    $display("N: %x, true_sum: %x, obs_sum: %x", internal_n, (internal_n+prev_u)/2, DUT.MultCore.sum_u);
                    if(DUT.MultCore.sum_u != (prev_u + internal_n)/2) begin
                        $display("Error: wrong sum adding N");
                        fail = 1;
                        $stop;
                    end
                end
                else if(cur_op == MP_shift_r) begin
                   $display("true_sum: %x, obs_sum: %x", prev_u/2, DUT.MultCore.sum_u);
                    if(DUT.MultCore.sum_u != prev_u/2) begin
                        $display("Error: wrong sum shifting");
                        fail = 1;
                        $stop;
                    end            
                end
                    
                $write("Next op:");
                if(~DUT.MultCore.a_j && ~DUT.MultCore.u_0 && DUT.MultCore.next_state == MP_shift_r) begin
                    $display("Single MP_shift_r");
                end
                else if(DUT.MultCore.a_j && ~DUT.MultCore.u_0 && DUT.MultCore.next_state == MP_add_B) begin 
                    $display("Add B");
                end 
                else if(DUT.MultCore.a_j && DUT.MultCore.u_0 && DUT.MultCore.next_state == MP_add_BN) begin
                    $display("Add B+N");
                end
                else if(~DUT.MultCore.a_j && DUT.MultCore.u_0 && DUT.MultCore.next_state == MP_add_N) begin
                    $display("Add N");
                end
                else begin
                    $display("Error: wrong state transition");
                        fail = 1;
                    $stop;            
                end
                cur_op = DUT.MultCore.next_state;
                prev_u = DUT.MultCore.sum_u;

                @(posedge clk);
                #(CLK_PERIOD_NS/4);
                $display("\n\n");


            end
    end
endtask


endmodule
