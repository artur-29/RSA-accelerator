#params
add wave sim:/RSA_tb/DUT/DEVICE_FAMILY
add wave sim:/RSA_tb/DUT/WORD_SIZE
add wave sim:/RSA_tb/DUT/DATA_WIDTH
add wave sim:/RSA_tb/DUT/ITERATIONS
add wave sim:/RSA_tb/DUT/EXP_WIDTH
add wave sim:/RSA_tb/DUT/addr_BN  
add wave sim:/RSA_tb/DUT/addr_P 
add wave sim:/RSA_tb/DUT/addr_Z 
add wave sim:/RSA_tb/DUT/addr_X 
add wave sim:/RSA_tb/DUT/addr_E 
add wave sim:/RSA_tb/DUT/addr_N
add wave sim:/RSA_tb/DUT/addr_R2 
add wave sim:/RSA_tb/DUT/addr_const1 
#sigs
add wave sim:/RSA_tb/*

add wave sim:/RSA_tb/DUT/*
add wave sim:/RSA_tb/DUT/exp_shift_0/*
add wave sim:/RSA_tb/DUT/main_ram/*

add wave sim:/RSA_tb/DUT/MultCore/*
add wave sim:/RSA_tb/DUT/MultCore/add_1/*
add wave sim:/RSA_tb/DUT/MultCore/a_shift_reg/*
add wave sim:/RSA_tb/DUT/MultCore/generate_u_shift_regs[0]/u_shift_reg/*
add wave sim:/RSA_tb/DUT/MultCore/generate_u_shift_regs[1]/u_shift_reg/*
add wave sim:/RSA_tb/DUT/MultCore/generate_u_shift_regs[2]/u_shift_reg/*
add wave sim:/RSA_tb/DUT/MultCore/generate_u_shift_regs[3]/u_shift_reg/*
add wave sim:/RSA_tb/DUT/MultCore/generate_u_shift_regs[4]/u_shift_reg/*