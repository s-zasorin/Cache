module fifo #(
  parameter type struct_t = logic, 
  parameter      DEPTH    = 10)(
  input  logic     clk_i     ,
  input  logic     arstn_i   ,

  // Slave interface
  input  logic     s_tvalid_i,
  output logic     s_tready_o,
  input  struct_t  s_tdata_i , 

// Master interface
  output logic     m_tvalid_o,
  input  logic     m_tready_i,
  output struct_t  m_tdata_o
);

  localparam WIDTH_PTR = $clog2(DEPTH);
  localparam MAX_PTR   = WIDTH_PTR' (DEPTH - 1);


  logic [WIDTH_PTR:0] wr_ptr           ;
  logic [WIDTH_PTR:0] rd_ptr           ;
  logic               wr_ptr_odd_circle;
  logic               rd_ptr_odd_circle;
  logic               equal_ptrs       ;
  logic               same_circle      ;

  logic               empty            ;
  logic               full             ;

  logic               push             ;
  logic               pop              ;
  struct_t            ram [DEPTH]      ;

  assign empty       = equal_ptrs & same_circle;
  assign full        = equal_ptrs & ~same_circle;

  assign s_tready_o  = ~full;
  assign m_tvalid_o  = ~empty;

  assign push        = s_tvalid_i && s_tready_o;
  assign pop         = m_tready_i && m_tvalid_o;

  assign equal_ptrs  = (wr_ptr == rd_ptr);
  assign same_circle = (wr_ptr_odd_circle == rd_ptr_odd_circle);

  always_ff @ (posedge clk_i or negedge arstn_i)
    if (~arstn_i) begin
      wr_ptr <= '0;
      wr_ptr_odd_circle <= 1'b0;
    end
    else if (push) begin
      if (wr_ptr == MAX_PTR) begin
        wr_ptr <= '0;
        wr_ptr_odd_circle <= ~ wr_ptr_odd_circle;
      end
      else
        wr_ptr <= wr_ptr + 1'b1;
    end

  always_ff @ (posedge clk_i or negedge arstn_i)
    if (~arstn_i) begin
      rd_ptr <= '0;
      rd_ptr_odd_circle <= 1'b0;
    end
    else if (pop)
    begin
      if (rd_ptr == MAX_PTR) begin
        rd_ptr <= '0;
        rd_ptr_odd_circle <= ~ rd_ptr_odd_circle;
      end
      else
        rd_ptr <= rd_ptr + 1'b1;
    end


  always_ff @ (posedge clk_i)
    if (push)
      ram [wr_ptr] <= s_tdata_i;

  assign m_tdata_o = ram [rd_ptr];

endmodule