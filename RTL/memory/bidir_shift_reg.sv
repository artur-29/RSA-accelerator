module bidir_shift_reg#(
	parameter WIDTH = 8
	) (

	input clock,
	input reset_n,
	input enable,
	input load,
	input dir, // 0 = right, 1 = left
	input [WIDTH - 1:0] data_in,
	input shift_in,
	output logic shift_out,
	output logic [WIDTH - 1:0] q_out);

always @(posedge clock) begin

	if(enable) begin
		if(load) begin
			q_out <= data_in;
		end
		else begin
			if(dir) begin
				q_out <= {q_out[WIDTH - 2:0], shift_in};
			end
			else begin
				q_out <= {shift_in, q_out[WIDTH - 1:1]};
			end
		end
	end
	else begin
		q_out <= q_out;
	end

	if(~reset_n) begin
		q_out <= '0;
	end
end

always_comb
	
	if(dir) begin
		shift_out = q_out[WIDTH - 1];
	end	
	else begin
		shift_out = q_out[0];
	end
endmodule