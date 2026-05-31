module mshr
import cache_pkg::*;
#(
  parameter  DEPTH           = 4            ,
  localparam MSHR_ADDR_WIDTH = $clog2(DEPTH)
) (
  input  logic                            clk_i                 ,
  input  logic                            aresetn_i             ,

  input  logic                            init_i                ,
  input  logic [ID_WIDTH           - 1:0] target_id_i           ,
  input  logic                            enable_i              ,
  input  logic [ID_WIDTH           - 1:0] write_id_i            ,
  input  logic [MSHR_ADDR_WIDTH    - 1:0] init_cnt_i            ,
  input  logic [ADDR_WIDTH         - 1:0] write_data_i          ,

  output logic                            full_o                ,
  output logic [ADDR_WIDTH         - 1:0] read_hit_data_o       ,
  output logic                            push_cq_o    
);

  localparam WIDTH_ADDR_LINE_ID = $clog2(ID_MAX_NUM);

  mshr_line_t ram [DEPTH - 1:0];

  logic [DEPTH              - 1:0] hit_arr         ;
  logic [DEPTH              - 1:0] id_hit_arr      ;
  logic                            hit             ;
  logic                            write_enable    ;
  logic [MSHR_ADDR_WIDTH    - 1:0] num_id_hit_field;
  logic [MSHR_ADDR_WIDTH    - 1:0] write_addr      ;
  logic [MSHR_ADDR_WIDTH    - 1:0] mshr_work_cnt   ;
  logic                            hit_id          ;
  logic [DEPTH              - 1:0] full_arr        ;

  cnt #(
    .CNT_WIDTH(MSHR_ADDR_WIDTH)
  ) i_mshr_cnt (
    .clk_i    (clk_i        ),
    .aresetn_i(aresetn_i    ),
    .enable_i (enable_i     ),

    .cnt_o    (mshr_work_cnt)
  );

  always_comb begin
    if (init_i)
      write_addr = init_cnt_i;
    else
      write_addr = mshr_work_cnt;
  end

  assign write_enable = enable_i && ~hit && ~full_o && ~init_i;

  always_ff @(posedge clk_i)
    if (init_i)
      ram[write_addr].valid        <= 1'b0;
    else if (hit_id)
      ram[num_id_hit_field].valid  <= 1'b0;
    else if (write_enable) begin
      ram[write_addr].miss_addr <= write_data_i;
      ram[write_addr].valid     <= 1'b1        ;
      ram[write_addr].req_id    <= write_id_i  ;
    end

  generate
    for (genvar i = 0; i < DEPTH; ++i) begin
      assign hit_arr[i] = (ram[i].miss_addr == write_addr) && ram[i].valid;
    end
  endgenerate

  generate
    for (genvar i = 0; i < DEPTH; ++i) begin
      assign id_hit_arr[i] = (ram[i].req_id == target_id_i) && ram[i].valid;
    end
  endgenerate

  onehot_decoder #(
    .ONE_HOT_WIDTH(DEPTH)
  ) i_one_hot_dec (
    .onehot_i(id_hit_arr      ),
    .bin_o   (num_id_hit_field)
  );

  generate
    for (genvar i = 0; i < DEPTH; ++i) begin
      assign full_arr[i] = ram[i].valid;
    end
  endgenerate

  assign read_hit_data_o = ram[num_id_hit_field].miss_addr;
  assign hit_id          = |id_hit_arr                    ;
  assign hit             = |hit_arr                       ;
  assign push_cq_o       = enable_i && ~hit               ;
  assign full_o          = &full_arr                      ;

endmodule