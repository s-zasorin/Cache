module onehot_decoder #(
  parameter  ONE_HOT_WIDTH = 8,
  localparam BIN_WIDTH     = $clog2(ONE_HOT_WIDTH))
(
  input  logic [ONE_HOT_WIDTH - 1:0] onehot_i,
  output logic [BIN_WIDTH     - 1:0] bin_o 
);

  always_comb begin
    bin_o = {BIN_WIDTH{1'b0}};
    for (int i = 0; i < ONE_HOT_WIDTH; i = i + 1) begin
      if (onehot_i[i])
        bin_o = i;
    end
  end

endmodule