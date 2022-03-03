	set path_to_quartus /home/artur/intelFPGA/21.1/quartus
	
	vlib lpm_ver
	vlib altera_mf_ver	
	vlib altera_prim_ver	
	vlib sgate_ver
	vlib altgxb_ver
	vlib cyclone_ver

	vmap lpm_ver lpm_ver
	vmap altera_mf_ver altera_mf_ver
	vmap sgate_ver sgate_ver
	vmap altgxb_ver altgxb_ver	
	vmap cyclone_ver cyclone_ver	
	vmap altera_prim_ver altera_prim_ver

	vlog -O5 -work altera_mf_ver $path_to_quartus/eda/sim_lib/altera_mf.v
	vlog -O5 -work lpm_ver $path_to_quartus/eda/sim_lib/220model.v
	vlog -O5 -work sgate_ver $path_to_quartus/eda/sim_lib/sgate.v
	vlog -O5 -work cyclone_ver $path_to_quartus/eda/sim_lib/cyclonev_atoms.v
	vlog -O5 -work altera_prim_ver $path_to_quartus/eda/sim_lib/altera_primitives.v

	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/ModProd_pkg.sv}
	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/RSA_pkg.sv}
	#vlog -work work -sv {/home/artur/Documents/RSA-accelerator/src/Sim/ModProd_tb.sv}
	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/Sim/RSA_tb.sv}
	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/ModProd.sv}
	#vlog -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/ModProd_v1.sv}
	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/RSA.sv}
	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/Adder.sv}
	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/memory/bidir_shift_reg.sv}
	vlog -O5 -work work -sv {/home/artur/Documents/RSA-accelerator/src/RTL/memory/int_ram.sv}

	vopt +acc work.RSA_tb -L lpm_ver -L altera_mf_ver -L sgate_ver -L altera_prim_ver -o dbugver
    
	
	vsim -sv_seed 4 dbugver
	do wave1.do

	run 1ps
	mem load -filltype value -filldata "8'h01" -startaddress 5 -endaddress 5 RSA_tb/DUT/main_ram/altsyncram_component/m_default/altsyncram_inst/mem_data
	mem load -filltype value -filldata "8'h01" -startaddress 30 -endaddress 30 RSA_tb/DUT/main_ram/altsyncram_component/m_default/altsyncram_inst/mem_data
	#mem load -filltype value -filldata "8'h17 8'h39 8'h8E 8'h1F 8'h00" -startaddress 35 -endaddress 39 RSA_tb/DUT/main_ram/altsyncram_component/m_default/altsyncram_inst/mem_data
	#mem load -filltype value -filldata "8'he9 8'h49 8'h8c 8'h1a 8'h00" -startaddress 35 -endaddress 39 RSA_tb/DUT/main_ram/altsyncram_component/m_default/altsyncram_inst/mem_data
	#mem load -filltype value -filldata "8'h00 8'h00 8'h00 8'h00 8'h01" -startaddress 35 -endaddress 39 RSA_tb/DUT/main_ram/altsyncram_component/m_default/altsyncram_inst/mem_data
	#mem load -filltype value -filldata "8'h30 8'hAE 8'hB3 8'h00 8'h00" -startaddress 35 -endaddress 39 RSA_tb/DUT/main_ram/altsyncram_component/m_default/altsyncram_inst/mem_data

	run -all
