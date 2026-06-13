module cache_fsm 
import cache_pkg::SETS;
import cache_pkg::SET_WIDTH;
(
  input  logic                   clk_i              ,
  input  logic                   aresetn_i          ,
  input  logic                   mem_handshake_i    ,
  input  logic                   mshr_almost_empty_i,
  input  logic                   mshr_en_i          ,

  output logic [SET_WIDTH - 1:0] init_cnt_o         ,
  output logic                   work_o             ,
  output logic                   init_o             ,
  output logic                   mem_send_o
);

  logic [2:0] mem_op_done;

  typedef enum logic [2:0] { 
    IDLE               = 3'b000,
    INIT               = 3'b001,
    WORK               = 3'b010,
    SEND_DATA_FROM_MEM = 3'b011
  } cache_state_t;

  cache_state_t state_ff, next;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      state_ff <= IDLE;
    else
      state_ff <= next;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      mem_op_done    <= 3'b000;
    else if (mem_send_o    )
      mem_op_done    <= 3'b001;
    else if (mem_op_done[0])
      mem_op_done    <= 3'b010;
    else if (mem_op_done[1])
      mem_op_done    <= 3'b100;
    else if (mem_op_done[2])
      mem_op_done    <= 3'b000;
  
  always_comb begin
    next = state_ff;

    case (state_ff)
      IDLE              :                                            next = INIT              ;
      INIT              : if (init_cnt_o == SETS - 1)                next = WORK              ;
      WORK              : if (mshr_en_i)                             next = SEND_DATA_FROM_MEM;
      SEND_DATA_FROM_MEM: if (mshr_almost_empty_i || mem_op_done[2]) next = WORK              ;
    endcase
  end

  assign init_o       = (state_ff == INIT);
  assign work_o       = (state_ff == WORK);
  assign mem_send_o   = (state_ff == SEND_DATA_FROM_MEM);

  cnt #(
    .CNT_WIDTH(SET_WIDTH)
  ) i_init_cnt (
    .clk_i    (clk_i      ),
    .aresetn_i(aresetn_i  ),
    .enable_i (init_o     ),

    .cnt_o    (init_cnt_o )
  );

endmodule