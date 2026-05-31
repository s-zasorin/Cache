module plru_refill 
import cache_pkg::*;
#(parameter WIDTH_WAY  = $clog2(WAYS),
  parameter WIDTH_PLRU = WAYS - 1) (
  input   logic [WIDTH_PLRU - 1:0] plru_tree_i,
  input   logic [WAYS       - 1:0] hit_i      ,
  output  logic [WIDTH_PLRU - 1:0] plru_tree_o
);

  localparam LEVELS = $clog2(WAYS);

  logic [WIDTH_WAY - 1:0] hit_way_num;
  logic [WIDTH_WAY - 1:0] offset;
  logic [LEVELS    - 1:0] update_base_id;
  onehot_decoder #(
    .ONE_HOT_WIDTH(WAYS)
  ) i_onehot (
    .onehot_i(hit_i      ),
    .bin_o   (hit_way_num)
  );

  always_comb begin
    plru_tree_o = plru_tree_i;

    for (int lvl = LEVELS - 1; lvl >= 0; lvl = lvl - 1) begin
      update_base_id  = ('b1 << lvl) - 1'b1;
      offset = (hit_way_num >> (LEVELS - lvl));
      plru_tree_o[update_base_id + offset] = ~plru_tree_i[update_base_id + offset];
    end
  end

endmodule