module single_port_ram 
  #(parameter DATA_WIDTH = 32,
    parameter RAM_DEPTH  = 8 ,
    parameter ADDR_WIDTH = $clog2(RAM_DEPTH))
(
  input  logic                           clk_i       ,
  input  logic                           wr_en_i     ,
  input  logic        [ADDR_WIDTH - 1:0] addr_i      ,
  input  logic        [DATA_WIDTH - 1:0] write_data_i,

  output logic        [DATA_WIDTH - 1:0] read_data_o
);

  logic [DATA_WIDTH - 1:0]   ram          [RAM_DEPTH];
  logic [DATA_WIDTH - 1:0]   read_data_ff            ;

  always_ff @(posedge clk_i)
    if (wr_en)
      ram[set]   <= write_data_i;
    read_data_ff <= ram[set];

  assign read_data_o = read_data_ff ;

endmodule