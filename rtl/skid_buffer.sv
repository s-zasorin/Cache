module skid_buffer #(parameter DATA_WIDTH = 32) (
  input logic                     clk_i,
  input logic                     aresetn_i,

  // Upstream
  input  logic                    up_valid_i,
  input  logic [DATA_WIDTH - 1:0] up_data_i ,
  output logic                    up_ready_o,

  // Downstream
  input  logic                    dwn_ready_i,
  output logic [DATA_WIDTH - 1:0] dwn_data_o ,
  output logic                    dwn_valid_o
);

  logic                    wr_buf_en       ;
  logic [DATA_WIDTH - 1:0] dat_buf         ;
  logic                    val_buf         ;

  always_ff @(posedge clk_i)
    if (up_ready_o && ~dwn_ready_i)
      dat_buf <= up_data_i;

  assign dwn_data_o  = up_ready_o ? up_data_i  : dat_buf;
  assign dwn_valid_o = up_ready_o ? up_valid_i : val_buf ;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i) begin
      val_buf     <= 1'b0;
      up_ready_o  <= 1'b1;
    end 
    else begin
      if (up_ready_o && ~dwn_ready_i)
        val_buf <= up_valid_i;      
      up_ready_o <= dwn_ready_i;
    end

endmodule