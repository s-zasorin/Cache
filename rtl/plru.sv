module plru 
import cache_pkg::*;
#(parameter WIDTH_WAY = $clog2(WAYS)) (
  input   logic                   clk_i      ,
  input   logic                   aresetn_i  ,
  input   logic [WAYS      - 1:0] hit_i      ,
  output  logic [WIDTH_WAY - 1:0] evict_way_o
);

  localparam BINARY_TREE_LEVELS = $clog2(WAYS)      ;
  localparam WIDTH_PLRU         = WAYS - 1          ;
  localparam WIDTH_PTR_PLRU     = $clog2(WIDTH_PLRU);

  logic [WIDTH_PLRU         - 1:0] plru_tree     ;
  logic [WIDTH_PLRU         - 1:0] plru_tree_ff  ;
  logic [WIDTH_PTR_PLRU     - 1:0] update_base_id;
  logic [WIDTH_PTR_PLRU     - 1:0] evict_base_id ;
  logic [BINARY_TREE_LEVELS - 2:0] offset        ;
  logic [WIDTH_WAY          - 1:0] num_of_way    ;

  onehot_decoder i_onehot
  (
    .onehot_i(hit_i     ),
    .bin_o   (num_of_way)
  );

  always_comb begin
    update_base_id = {WIDTH_PTR_PLRU{1'b0}};
    offset         = {(BINARY_TREE_LEVELS - 1){1'b0}};
    plru_tree      = {WIDTH_PLRU{1'b0}};

    for (int i = 0; i < WAYS; i = i + 1) begin
      if (hit_i[i]) begin
        for (int lvl = BINARY_TREE_LEVELS - 1; lvl >= 0; lvl = lvl - 1) begin
          update_base_id  = ('b1 << lvl) - 1'b1;
          offset = (num_of_way >> lvl) & ((1 << (WIDTH_WAY - lvl)) - 1);
          plru_tree[update_base_id + offset] = ~plru_tree_ff;
        end
      end
    end
  end

  always_comb begin
    evict_base_id   = {WIDTH_PTR_PLRU{1'b0}};
    evict_way_o[0]  = plru_tree_ff[0];
    for (int lvl = 1; lvl < BINARY_TREE_LEVELS; lvl = lvl + 1) begin
      evict_base_id    = ('b1 << lvl) - 1'b1;
      evict_way_o[lvl] = evict_way_o[lvl - 1] ? plru_tree_ff[evict_base_id + 1'b1] : plru_tree_ff[evict_base_id];
    end
  end

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      plru_tree_ff <= {WIDTH_PLRU{1'b0}};
    else
      plru_tree_ff <= plru_tree;

endmodule