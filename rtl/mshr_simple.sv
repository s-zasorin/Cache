module mshr_simple 
import cache_pkg::id_t;
#(
  parameter ID_WIDTH   = 3,
  parameter ADDR_WIDTH = 32
) (
  input  logic                    clk_i          ,
  input  logic                    aresetn_i      ,

  input  logic [ID_WIDTH   - 1:0] miss_id_i      ,
  input  logic [ADDR_WIDTH - 1:0] miss_addr_i    ,
  input  logic                    miss_valid_i   ,

  input  logic                    mem_handshake_i,
  input  logic                    send_id_en_i   ,

  output logic                    stall_o        ,
  output logic                    almost_empty_o ,
  output logic [ID_WIDTH   - 1:0] id_o           ,
  output logic                    valid_o
);

  logic [ADDR_WIDTH - 1:0] mshr_reg    ;
  logic                    mshr_valid  ;
  logic                    push_fifo   ;
  logic                    compare_addr;

  id_t                     temp_out_id ;
  id_t                     temp_in_id  ;

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

  assign push_fifo = miss_valid_i && (~mshr_valid) || miss_valid_i && mshr_valid && compare_addr;

  assign temp_in_id = miss_id_i;

  show_ahead_fifo #(
    .struct_t  (id_t),
    .FIFO_DEPTH(8   )
  ) i_id_fifo (
    .aclk_i        (clk_i         ),
    .aresetn_i     (aresetn_i     ),

    .s_tdata_i     (temp_in_id    ),
    .s_tvalid_i    (push_fifo     ),
    .s_tready_o    (              ),

    .m_tdata_o     (temp_out_id   ),
    .m_tvalid_o    (valid_o       ),
    .m_tready_i    (send_id_en_i  ),

    .almost_empty_o(almost_empty_o)
  );

  assign id_o    = temp_out_id.id;
  assign stall_o = miss_valid_i && mshr_valid && ~compare_addr;

endmodule