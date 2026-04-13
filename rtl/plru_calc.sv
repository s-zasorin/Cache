module plru_calc
import cache_pkg::*;
#(parameter WIDTH_WAY  = $clog2(WAYS),
  parameter WIDTH_PLRU = WAYS - 1) (
  input   logic [WIDTH_PLRU - 1:0] plru_tree_i,
  output  logic [WIDTH_WAY  - 1:0] evict_way_o
);

  localparam BINARY_TREE_LEVELS = $clog2(WAYS)      ;
  localparam WIDTH_PTR_PLRU     = $clog2(WIDTH_PLRU);

  logic [WIDTH_PTR_PLRU     - 1:0] evict_base_id ;

  always_comb begin
    evict_base_id   = {WIDTH_PTR_PLRU{1'b0}};
    evict_way_o[0]  = plru_tree_i[0];
    for (int lvl = 1; lvl < BINARY_TREE_LEVELS; lvl = lvl + 1) begin
      evict_base_id    = ('b1 << lvl) - 1'b1;
      evict_way_o[lvl] = evict_way_o[lvl - 1] ? plru_tree_i[evict_base_id + 1'b1] : plru_tree_i[evict_base_id];
    end
  end

endmodule