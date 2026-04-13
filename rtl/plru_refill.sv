module plru_refill 
import cache_pkg::*;
#(parameter WIDTH_WAY  = $clog2(WAYS),
  parameter WIDTH_PLRU = WAYS - 1) (
  input   logic                    clk_i      ,
  input   logic                    aresetn_i  ,
  input   logic                    valid_i    ,
  input   logic [WIDTH_PLRU - 1:0] plru_tree_i,
  input   logic [WAYS       - 1:0] hit_i      ,
  output  logic                    valid_o    ,
  output  logic [WIDTH_WAY  - 1:0] evict_way_o,
  output  logic [WIDTH_PLRU - 1:0] plru_tree_o
);

  localparam BINARY_TREE_LEVELS = $clog2(WAYS)      ;
  localparam WIDTH_PTR_PLRU     = $clog2(WIDTH_PLRU);

  logic [WIDTH_PLRU         - 1:0] plru_tree_ff  ;
  logic [WIDTH_PTR_PLRU     - 1:0] update_base_id;
  logic [WIDTH_PTR_PLRU     - 1:0] evict_base_id ;
  logic [BINARY_TREE_LEVELS - 2:0] offset        ;
  logic [WIDTH_WAY          - 1:0] num_of_way    ;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      plru_tree_ff <= {WIDTH_PLRU{1'b0}};
    else if (valid_i)
      plru_tree_ff <= plru_tree_i;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      valid_o <= 1'b0;
    else
      valid_o <= valid_i;

  onehot_decoder i_onehot
  (
    .onehot_i(hit_i     ),
    .bin_o   (num_of_way)
  );

  always_comb begin
    update_base_id = {WIDTH_PTR_PLRU{1'b0}};
    offset         = {(BINARY_TREE_LEVELS - 1){1'b0}};

    for (int i = 0; i < WAYS; i = i + 1) begin
      if (hit_i[i]) begin
        for (int lvl = BINARY_TREE_LEVELS - 1; lvl >= 0; lvl = lvl - 1) begin
          update_base_id  = ('b1 << lvl) - 1'b1;
          offset = (num_of_way >> lvl) & ((1 << (WIDTH_WAY - lvl)) - 1);
          plru_tree_o[update_base_id + offset] = ~plru_tree_ff;
        end
      end
    end
  end

endmodule