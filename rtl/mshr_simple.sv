module mshr_simple 
import cache_pkg::id_t;
#(
  parameter ID_WIDTH      = 3 ,
  parameter ADDR_WIDTH    = 32,
  parameter NUM_MISS_ADDR = 1
) (
  input  logic                    clk_i          ,
  input  logic                    aresetn_i      ,

  input  logic [ID_WIDTH   - 1:0] miss_id_i      ,
  input  logic [ADDR_WIDTH - 1:0] miss_addr_i    ,
  input  logic                    miss_valid_i   ,

  input  logic                    mem_handshake_i,
  input  logic                    send_id_en_i   ,
  input  logic                    init_i         ,

  output logic                    stall_o        ,
  output logic                    almost_empty_o ,
  output logic [ID_WIDTH   - 1:0] id_o           ,
  output logic                    valid_o
);

  localparam FILL_CNT_WIDTH = $clog2(NUM_MISS_ADDR);

  logic [ADDR_WIDTH     - 1:0] mshr_reg    ;
  logic                        mshr_valid  ;
  logic                        compare_addr;

  id_t                         temp_out_id ;
  id_t                         temp_in_id  ;

  mshr_line_t                  ram [NUM_MISS_ADDR];


  logic                        mshr_full   ;
  logic                        mshr_en     ;
  logic [NUM_MISS_ADDR  - 1:0] mshr_wr_en  ;
  logic [NUM_MISS_ADDR  - 1:0] mshr_hit    ;

  // Fifo's interface
  logic [NUM_MISS_ADDR  - 1:0] fifo_m_valid;
  logic [NUM_MISS_ADDR  - 1:0] fifo_push   ;
  logic [NUM_MISS_ADDR  - 1:0] fifo_s_ready;

  assign mshr_en      = miss_valid_i && ~mshr_full;
  assign compare_addr = (miss_addr_i == mshr_reg);

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      mshr_valid <= 1'b0;
    else if (miss_valid_i)
      mshr_valid <= 1'b1;
    else if (mem_handshake_i)
      mshr_valid <= 1'b0;

  always_ff @(posedge clk_i)
    if (miss_valid_i)
      mshr_reg <= miss_addr_i;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      mshr_wr_en <= {{(NUM_MISS_ADDR - 1){1'b0}}, 1'b1};
    else if (mshr_en)
      mshr_wr_en <= {mshr_wr_en[NUM_MISS_ADDR - 2:0], 1'b0};

  generate
    for (genvar i = 0; i < NUM_MISS_ADDR; ++i) begin: g_mshr_miss_addr
      always_ff @(posedge clk_i)
        if (mshr_en && mshr_wr_en[i])
          ram[i].miss_addr <= miss_addr_i;
    end: g_mshr_miss_addr
  endgenerate

  generate
    for (genvar i = 0; i < NUM_MISS_ADDR; ++i) begin: g_mshr_valid
      always_ff @(posedge clk_i)
        if (init_i)
          ram[i].valid <= 1'b0;
        else if (mshr_en && mshr_wr_en[i])
          ram[i].valid <= 1'b1;
    end: g_mshr_valid
  endgenerate

  always_comb begin
    mshr_hit = {NUM_MISS_ADDR{1'b0}};

    for (genvar i = 0; i < NUM_MISS_ADDR; ++i) begin: g_mshr_hit
      assign mshr_hit[i] == (ram[i].miss_addr == miss_addr_i) && ram[i].valid;
    end: g_mshr_hit
  end

  always_comb begin
    fifo_push = {NUM_MISS_ADDR{1'b0}};
  end

  assign temp_in_id = miss_id_i;

  generate
    for (genvar i = 0; i < NUM_MISS_ADDR; ++i) begin: g_id_fifo
      show_ahead_fifo #(
        .struct_t  (id_t),
        .FIFO_DEPTH(8   )
      ) i_id_fifo (
        .aclk_i        (clk_i         ),
        .aresetn_i     (aresetn_i     ),

        .s_tdata_i     (temp_in_id     ),
        .s_tvalid_i    (fifo_push      ),
        .s_tready_o    (fifo_s_ready[i]),

        .m_tdata_o     (temp_out_id   ),
        .m_tvalid_o    (valid_o       ),
        .m_tready_i    (send_id_en_i  ),

        .almost_empty_o(almost_empty_o)
      );
    end: g_id_fifo
  endgenerate

  assign id_o    = temp_out_id.id;
  assign stall_o = miss_valid_i && mshr_valid && ~compare_addr;

endmodule