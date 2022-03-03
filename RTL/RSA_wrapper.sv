
import HardTest_params::*;

module RSA_wrapper(

   
      ///////// ARDUINO /////////
      inout       [15:0] ARDUINO_IO,
      inout              ARDUINO_RESET_N,

      ///////// FPGA /////////
      input              FPGA_CLK1_50,
      input              FPGA_CLK2_50,
      input              FPGA_CLK3_50,

      ///////// GPIO /////////
      inout       [35:0] GPIO_0,
      inout       [35:0] GPIO_1,

      ///////// KEY /////////
      input       [1:0]  KEY,

      ///////// LED /////////
      output      [7:0]  LED,

      ///////// SW /////////
      input       [3:0]  SW
);



      
      logic clk;
      logic reset_n;
      logic locked;


    (*preserve*) logic [7    :0] RSA_data_in;
    (*preserve*) logic [7    :0] RSA_data_out;
    (*preserve*) logic           RSA_valid;
    (*preserve*) logic           RSA_addr;
    (*preserve*) logic           RSA_write;
                 logic           RSA_phase;
                 logic           RSA_req;
                 logic           RSA_req_reg;


      /*source_probe u0 (
            .source     ({{RSA_data_in},{RSA_valid},{RSA_addr},{RSA_write}}),     //    sources.source
            .probe      (RSA_data_out),      //     probes.probe
            .source_clk (clk)  // source_clk.clk
      );

      /*pll pll_top (
            .refclk   (FPGA_CLK1_50),   //  refclk.clk
            .rst      (~KEY[0]),      //   reset.reset
            .outclk_0 (clk), // outclk0.clk
            .locked   (reset_n)    //  locked.export
      );*/
      assign reset_n = KEY[0];
      assign clk = FPGA_CLK1_50;
      
      /*always @(posedge clk) begin
            reset_n <= KEY[0];
      end*/

      typedef struct packed {
            bit [1:0]  nu_7_6;
            bit        done;
            bit        read_u;
            bit        load_n;
            bit        load_e;
            bit        load_x;
            bit        start;
      } control_reg_type;



      // AVMM

      logic        test_switch;

      // Register interface
      //control_reg_type control_reg;
      logic [31:0] data_reg;

      // Avalon stream
      
      logic [7:0] temp_reg;

      logic T_complete;
      logic TX_ready;
      logic TX_valid;
      logic TX_error;
      logic [7:0] TX_data;
      logic TX_req;
      logic TX_req_reg;
      logic TX_req_reg_1;
      
      logic RX_complete;
      logic RX_ready;
      logic RX_valid;
      logic RX_error;
      logic [7:0] RX_data;
      logic RX_wait_cycle;


      logic [3:0] cnt;
      assign LED[7:6] = 2'b11;
      assign TX_error = 1'b0;

      uart_stream uart0 (
            .clk_clk                 (clk),                 //                                clk.clk
            .reset_reset_n           (reset_n),           //                              reset.reset_n
            .rs232_0_from_uart_ready (RX_ready), // rs232_0_avalon_data_receive_source.ready
            .rs232_0_from_uart_data  (RX_data),  //                                   .data
            .rs232_0_from_uart_error (RX_error), //                                   .error
            .rs232_0_from_uart_valid (RX_valid), //                                   .valid
            .rs232_0_to_uart_data    (TX_data),    //  rs232_0_avalon_data_transmit_sink.data
            .rs232_0_to_uart_error   (TX_error),   //                                   .error
            .rs232_0_to_uart_valid   (TX_valid),   //                                   .valid
            .rs232_0_to_uart_ready   (TX_ready),   //                                   .ready
            .rs232_0_UART_RXD        (GPIO_0[0]),        //         rs232_0_external_interface.RXD
            .rs232_0_UART_TXD        (GPIO_0[1])         //                                   .TXD
      );
      
      always@(posedge clk or negedge reset_n) begin
            
            if(~reset_n) begin
                  TX_valid <= 1'b0;
                  TX_data <= 8'b0;
            end
            else begin
                  if(TX_ready && TX_req_reg) begin
                        TX_valid <= 1'b1;
                        TX_data <= RSA_data_out;
                  end
                  else begin
                        TX_valid <= 1'b0;
                        TX_data <= TX_data;
                  end
            end

      end

      logic temp_wait;

      always @(posedge clk or negedge reset_n) begin
            
            if(~reset_n) begin
                  RX_ready <= '0;
                  RSA_phase <= '0;
                  TX_req <= '0;
                  TX_req_reg <= '0;
                  RSA_data_in <= '0;
                  RSA_valid <= '0;
                  RSA_addr <= '0;
                  RSA_write <= '0;
            end
            else begin
                  TX_req_reg <= TX_req;
                  RX_ready <= 1'b1;
                  if(RX_valid) begin

                        if(~RSA_phase) begin   
                              RSA_addr <= RX_data[0];
                              RSA_write <= RX_data[1];
                              if(RX_data[1]) begin
                                    RSA_phase <= 1'b1;
                                    RSA_valid <= 1'b0;
                              end
                              else begin
                                    RSA_valid <= 1'b1;
                                    RSA_data_in <= '0;
                                    TX_req <= 1'b1;  
                                    RSA_phase <= 1'b0;    
                              end
                        end
                        else if(RSA_phase) begin
                              RSA_addr <= RSA_addr;
                              RSA_write <= RSA_write;
                              RSA_valid <= 1'b1;
                              RSA_data_in <= RX_data;
                              TX_req <= '0;
                              RSA_phase <= 1'b0;           
                        end   

                  end 
                  else begin
                        TX_req <= '0;
                        RSA_valid <= 1'b0;
                  end
            end

      end

      always @(posedge clk or negedge reset_n) begin
            
            if(~reset_n) begin
                  LED[3] <= 1'b0;
                  LED[4] <= 1'b0;
                  LED[5] <= 1'b0;
            end
            else begin
                  LED[3] <= LED[3];
                  LED[4] <= LED[4];
                  LED[5] <= LED[5];
                  if(RX_valid) begin
                        LED[3] <= 1'b1;
                        LED[4] <= 1'b1;
                        LED[5] <= 1'b1;
                  end         
            end

      end


      always @(posedge clk or negedge reset_n) begin
            if(~reset_n) begin
                  
                  LED[0] <= 1'b1;
                  LED[1] <= 1'b1;
                  LED[2] <= 1'b1;

            end
            else begin

                  LED[0] <= 1'b0;
                  LED[1] <= 1'b0;
                  LED[2] <= 1'b0;
            end
      end



      
      RSA #( 
        .DEVICE_FAMILY (RSA_DEVICE_FAMILY),
        .WORD_SIZE     (RSA_WORD_SIZE), 
        .INPUT_WIDTH   (RSA_DATA_WIDTH))
      RSA_Core (
            .clk(clk), 
            .reset_n(reset_n), 

            .data_in(RSA_data_in),
            .data_out(RSA_data_out),
            .addr(RSA_addr),
            .valid(RSA_valid),
            .write(RSA_write));




endmodule
