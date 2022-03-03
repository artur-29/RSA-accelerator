package HardTest_params;
    
    localparam   RSA_DATA_WIDTH        =     1024; // k
    localparam   RSA_WORD_SIZE         =     32;
    localparam   UART_WORD_SIZE        =     8;
    localparam   UART_WORDS            =     RSA_WORD_SIZE/UART_WORD_SIZE;
    localparam   RSA_DEVICE_FAMILY     =     "Cyclone V";

endpackage