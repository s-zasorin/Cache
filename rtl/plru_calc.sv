module plru_calc
import cache_pkg::*;
#(parameter WIDTH_WAY  = $clog2(WAYS),
  parameter WIDTH_PLRU = WAYS - 1) (
  input   logic [WIDTH_PLRU - 1:0] plru_tree_i,
  output  logic [WIDTH_WAY  - 1:0] evict_way_o
);

  localparam BINARY_TREE_LEVELS = $clog2(WAYS);
  
  logic [BINARY_TREE_LEVELS - 1:0] way_index;
  logic [WIDTH_PLRU - 1:0] node_idx;

  always_comb begin
    way_index = '0;
    for (int lvl = 0; lvl < BINARY_TREE_LEVELS; lvl++) begin
      node_idx = ((1 << lvl) - 1) + (way_index >> (BINARY_TREE_LEVELS - lvl));
      way_index[BINARY_TREE_LEVELS - lvl - 1] = plru_tree_i[node_idx];
    end
    
    evict_way_o = way_index;
  end

endmodule