#params
add wave sim:/ModProd_tb/DUT/DEVICE_FAMILY
add wave sim:/ModProd_tb/DUT/MEM_ADDR_WIDTH
add wave sim:/ModProd_tb/DUT/WORD_SIZE
add wave sim:/ModProd_tb/DUT/DATA_WIDTH
add wave sim:/ModProd_tb/DUT/MEMORY_WORDS
add wave sim:/ModProd_tb/DUT/EXP_WIDTH
#sigs
add wave sim:/ModProd_tb/DUT/*
#add wave sim:/ModProd_tb/DUT/{sum_u[255:0]}
#add wave sim:/ModProd_tb/DUT/{sum_u[511:256]}
#add wave sim:/ModProd_tb/DUT/{sum_u[767:512]}
#add wave sim:/ModProd_tb/DUT/{sum_u[1023:768]}
#add wave sim:/ModProd_tb/DUT/a_shift_0/*
#add wave sim:/ModProd_tb/DUT/a_shift_1/*
#add wave sim:/ModProd_tb/DUT/a_shift_2/*
#add wave sim:/ModProd_tb/DUT/a_shift_3/*
add wave sim:/ModProd_tb/DUT/main_ram/*
#add wave sim:/ModProd_tb/DUT/main_ram/altsyncram_component/*

add wave sim:/ModProd_tb/DUT/MultCore/*
#add wave sim:/ModProd_tb/DUT/MultCore/b_shift_reg/*
add wave sim:/ModProd_tb/DUT/MultCore/a_shift_reg/*
add wave sim:/ModProd_tb/DUT/MultCore/generate_u_shift_regs[0]/u_shift_reg/*
add wave sim:/ModProd_tb/DUT/MultCore/generate_u_shift_regs[1]/u_shift_reg/*
add wave sim:/ModProd_tb/DUT/MultCore/generate_u_shift_regs[2]/u_shift_reg/*