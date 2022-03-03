package RSA_pkg;

	typedef enum int unsigned { reset = 0, hold = 1, reload_mem = 2, init_P = 4, init_Z = 8, square = 16, mult = 32, inc_exp = 64, convert_P = 128, reduce = 256, init_P_wait = 512, init_Z_wait = 1024, square_wait = 2048, mult_wait = 4096, convert_P_wait = 8192, reduce_wait = 16384 } RSA_state;
    
    typedef struct packed {
          bit [1:0]  nu_7_6;
          bit        ready;
          bit        read_u;
          bit        load_n;
          bit        load_e;
          bit        load_x;
          bit        start;
    } control_reg_type;

endpackage
