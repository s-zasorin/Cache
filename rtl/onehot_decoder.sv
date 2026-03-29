module onehot_decoder 
import cache_pkg::*;
#(parameter BIN_WIDTH = $clog2(WAYS))
(
  input  logic [WAYS      - 1:0] onehot_i,
  output logic [BIN_WIDTH - 1:0] bin_o 
);

  always_comb begin
    bin_o = {BIN_WIDTH{1'b0}};
    for (int i = 0; i < WAYS; i = i + 1) begin
      if (onehot_i[i])
        bin_o = i;
    end
  end

endmodule