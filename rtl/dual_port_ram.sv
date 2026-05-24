module dual_port_ram #( parameter  DATA_WIDTH = 8,
                        parameter  RAM_DEPTH  = 8,
                        parameter  ADDR_WIDTH = $clog2(RAM_DEPTH))
(
  input  logic                    clk_i    ,
  input  logic [ADDR_WIDTH - 1:0] wr_addr_i,
  input  logic [DATA_WIDTH - 1:0] data_i   ,
  input  logic                    wr_en_i  ,
  input  logic                    rd_en_i  ,
  input  logic [ADDR_WIDTH - 1:0] rd_addr_i,
  output logic [DATA_WIDTH - 1:0] data_o
);
  
  logic [DATA_WIDTH - 1:0] ram [RAM_DEPTH - 1:0];
  logic [DATA_WIDTH - 1:0] data_ff;

  always_ff @(posedge clk_i)
    if (wr_en_i)
      ram[wr_addr_i] <= data_i;
  
  always_ff @(posedge clk_i)
    if (rd_en_i)
      data_ff <= ram[rd_addr_i];
  
  assign data_o = data_ff;

endmodule