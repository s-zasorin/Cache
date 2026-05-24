module credit_cnt #(
  parameter     CNT_WIDTH  = 4,
  parameter int CREDIT_NUM = 4
) (
  input  logic                   clk_i    ,
  input  logic                   aresetn_i,

  input  logic                   incr_i   ,
  input  logic                   decr_i   ,

  output logic [CNT_WIDTH - 1:0] cnt_o
);

  logic [CNT_WIDTH - 1:0] cnt_ff;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cnt_ff <= (CREDIT_NUM - 1);
    else if (decr_i)
      cnt_ff <= cnt_ff - 'b1;
    else if (incr_i)
      cnt_ff <= cnt_ff + 'b1;

  assign cnt_o = cnt_ff;

endmodule