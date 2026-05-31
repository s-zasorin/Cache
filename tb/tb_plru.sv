module tb_plru ();

  import cache_pkg::*;

  localparam WIDTH_WAY  = $clog2(WAYS);
  localparam WIDTH_PLRU = WAYS - 1;

  logic [WIDTH_PLRU - 1:0] plru_tree_i;
  logic [WAYS       - 1:0] hit_i      ;
  logic [WIDTH_PLRU - 1:0] plru_tree_o;
  logic [WIDTH_WAY  - 1:0] evict_way_o;

  plru_refill DUT (
    .plru_tree_i(plru_tree_i),
    .hit_i      (hit_i      ),
    .plru_tree_o(plru_tree_o)
  );

  plru_calc i_calc (
    .plru_tree_i(plru_tree_o),
    .evict_way_o(evict_way_o)
  );

  initial begin
    plru_tree_i = 3'b000;
    hit_i       = 4'b0001;
    #10;
    $finish();
  end
endmodule