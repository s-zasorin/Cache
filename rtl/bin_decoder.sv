module bin_decoder #(
  parameter BIN_WIDTH    = -1,
  parameter ONEHOT_WIDTH = -1)
(
  input  logic [BIN_WIDTH    - 1:0] bin_i   ,
  output logic [ONEHOT_WIDTH - 1:0] onehot_o  
);

  always_comb begin
    onehot_o        = {ONEHOT_WIDTH{1'b0}};
    onehot_o[bin_i] = 1'b1;
  end

endmodule