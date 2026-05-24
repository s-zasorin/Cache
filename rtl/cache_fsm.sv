module cache_fsm 
import cache_pkg::SETS;
import cache_pkg::SET_WIDTH;
(
  input  logic                   clk_i        ,
  input  logic                   aresetn_i    ,
  input  logic                   rx_cq_valid_i,

  output logic [SET_WIDTH - 1:0] init_cnt_o   ,
  output logic                   work_o       ,
  output logic                   init_o       ,
  output logic                   write_back_o
);


  typedef enum logic [2:0] { 
    IDLE       = 3'b000,
    INIT       = 3'b001,
    WORK       = 3'b010,
    WRITE_BACK = 3'b011
  } cache_state_t;

  cache_state_t state_ff, next;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      state_ff <= IDLE;
    else
      state_ff <= next;

  always_comb begin
    next = state_ff;

    case (state_ff)
      IDLE      :                             next = INIT      ;
      INIT      : if (init_cnt_o == SETS - 1) next = WORK      ;
      WORK      : if (rx_cq_valid_i)          next = WRITE_BACK;
      WRITE_BACK: if (~rx_cq_valid_i)         next = WORK      ;
    endcase
  end

  assign init_o       = (state_ff == INIT);
  assign work_o       = (state_ff == WORK);
  assign write_back_o = ~work_o           ;
  cnt #(
    .CNT_WIDTH(SET_WIDTH)
  ) i_init_cnt (
    .clk_i    (clk_i      ),
    .aresetn_i(aresetn_i  ),
    .enable_i (init_o     ),

    .cnt_o    (init_cnt_o )
  );

endmodule