module bin_decoder
import cache_pkg::*;
#(parameter BIN_WIDTH = $clog2(WAYS))
(
  input  logic [BIN_WIDTH - 1:0] bin_i,
  output logic [WAYS      - 1:0] onehot_o  
);

  always_comb begin
    onehot_o        = {WAYS{1'b0}};
    onehot_o[bin_i] = 1'b1;
  end

endmodule