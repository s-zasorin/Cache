module plru_wrapper 
import cache_pkg::*;
# (
  localparam PLRU_WIDTH = (WAYS == 1) ? WAYS : WAYS - 1
) (
  input  logic                    clk_i      ,
  input  logic                    aresetn_i  ,

  input  logic                    init_i     ,
  input  logic                    valid_i    ,
  output logic                    ready_o    ,

  input  logic [WAYS       - 1:0] hit_i      ,
  input  logic [SET_WIDTH  - 1:0] set_i      ,
  output logic [PLRU_WIDTH - 1:0] plru_tree_o 
);

  logic [PLRU_WIDTH - 1:0] write_data;
  logic [PLRU_WIDTH - 1:0] write_plru_tree;
  logic                    write_enable;
  logic                    valid_ff;
  logic                    handshake;
  logic [WAYS       - 1:0] hit_ff;
  logic [2:0]              shift;
  logic [PLRU_WIDTH - 1:0] read_plru;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      shift <= 3'b1;
    else if (handshake)
      shift <= {1'b1, shift[2:1]};
    else if (~ready_o)
      shift <= (shift >> 1);

  assign write_data   = init_i ? {PLRU_WIDTH{1'b0}} : write_plru_tree;
  assign write_enable = init_i ? 1'b1 : shift[1];
  assign handshake    = ready_o && valid_i;
  assign ready_o      = shift[0];

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      hit_ff <= {WAYS{1'b0}};
    else if (handshake)
      hit_ff <= hit_i;

  single_port_ram #(
    .DATA_WIDTH(PLRU_WIDTH),
    .RAM_DEPTH (SETS      )
  ) i_plru_ram (
    .clk_i       (clk_i       ),
    .wr_en_i     (write_enable),
    .req_i       (1'b1        ),
    .addr_i      (set_i       ),
    .write_data_i(write_data  ),
    .read_data_o (read_plru   )
  );

  assign plru_tree_o = write_plru_tree;

endmodule