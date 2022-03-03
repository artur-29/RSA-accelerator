package ModProd_pkg;
	typedef enum int unsigned { MP_hold = 0, MP_load = 1, MP_preprocess = 2, MP_preprocess_store = 4, MP_clear_u = 8, MP_inc_iter = 16, MP_add_B = 32, MP_add_BN = 64, MP_add_N = 128, MP_shift_l = 256, MP_store_u = 512, MP_shift_r = 1024, MP_sub_N_mem = 2048 } ModProd_state;
endpackage