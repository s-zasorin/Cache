module tb_configure_cache();

  import cache_pkg::*;
  
  logic [ADDR_WIDTH - 1:0] addr      ;
  logic [ADDR_WIDTH - 1:0] test_addr ;
  logic                    hit       ;
  logic                    clk       ;
  logic                    valid     ;
  logic                    miss      ;
  logic                    aresetn   ;
  logic [DATA_WIDTH - 1:0] read_data ;
  logic [DATA_WIDTH - 1:0] write_data;
  logic                    wr_en     ;

  initial begin
    clk = 1'b0;
    forever begin
      #5;
      clk <= ~clk;
    end
  end


  configure_cache DUT
  (
    .clk_i         (clk       ),
    .aresetn_i     (aresetn   ),
    .write_enable_i(wr_en     ),
    .write_data_i  (write_data),
    .addr_i        (addr      ),
    .hit_o         (hit       ),
    .valid_o       (valid     ),
    .miss_o        (miss      ),
    .read_data_o   (read_data )
  );

  initial begin
    aresetn <= 1'b0;
    @(posedge clk);
    aresetn    <= 1'b1;
    test_addr  <= $urandom;
    @(posedge clk);
    wr_en      <= 1'b1;
    repeat (4) begin
      addr       <= test_addr;
      write_data <= $urandom;
      @(posedge clk);
    end
    @(posedge clk);
    wr_en      <= 1'b0;
    repeat (2) @(posedge clk);
    $finish();
  end
endmodule