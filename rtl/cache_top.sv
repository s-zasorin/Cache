module cache_top
import cache_pkg::*;
(
  input   logic                    clk_i         ,
  input   logic                    aresetn_i     ,

  // CPU Interface
  input   logic                    cpu_valid_i   ,
  input   logic [ADDR_WIDTH - 1:0] cpu_addr_i    ,
  input   logic [ID_WIDTH   - 1:0] cpu_req_id_i  ,

  output  logic                    cpu_ready_o   ,
  output  logic                    cpu_valid_o   ,
  output  logic [ID_WIDTH   - 1:0] cpu_req_id_o  ,
  output  logic [DATA_WIDTH - 1:0] cpu_data_o    ,

  // Memory Interface
  output  logic                    mem_req_o     ,
  output  logic [ADDR_WIDTH - 1:0] mem_addr_o    ,
  output  logic [ID_WIDTH   - 1:0] mem_id_o      ,

  input   logic [DATA_WIDTH - 1:0] mem_data_i    ,
  input   logic [ID_WIDTH   - 1:0] mem_id_i      ,
  input   logic                    mem_valid_i   ,
  input   logic                    mem_ack_i    
);

  // Local parameters
  localparam COMMON_FIFO_DEPTH   = 8                   ;
  localparam HMD_FIFO_DATA_WIDTH = SET_WIDTH + ID_WIDTH;

  localparam CREDIT_NUM          = COMMON_FIFO_DEPTH ; 
  localparam CREDIT_CNT_WIDTH    = $clog2(CREDIT_NUM);

  localparam MSHR_DEPTH          = 4;
  localparam MSHR_ADDR_WIDTH     = $clog2(MSHR_DEPTH);

  localparam DR_INPUT_WIDTH      = HMD_FIFO_DATA_WIDTH;
  localparam DR_ID_WIDTH         = ID_WIDTH;
  localparam DR_OUTPUT_WIDTH     = DATA_WIDTH + ID_WIDTH;

  localparam PLRU_WIDTH          = WAYS - 1;
  // Local declarations Hit-Miss Detect
  logic                             hmd_hit         ;
  logic                             hmd_miss        ;
  logic                             hmd_valid_miss  ;
  logic [ADDR_WIDTH - 1:0]          hmd_addr        ;
  logic [ID_WIDTH   - 1:0]          hmd_id          ;
  logic [SET_WIDTH  - 1:0]          hmd_set         ;
  logic [WAYS       - 1:0]          hmd_hit_arr     ;
  logic                             hmd_valid_in    ;
  logic                             hmd_valid_out   ;
  logic [WAYS       - 1:0]          hmd_we_dr_out   ;

  logic                             hmd_fifo_s_valid;
  logic                             hmd_fifo_s_ready;
  hmd_fifo_t                        hmd_fifo_s_data ;

  logic                             hmd_fifo_m_valid;
  logic                             hmd_fifo_m_ready;
  hmd_fifo_t                        hmd_fifo_m_data ;

  // Local declarations Data Read Stage
  logic                             dr_fifo_s_valid;
  logic                             dr_fifo_s_ready;
  dr_fifo_t                         dr_fifo_s_data ;

  logic                             dr_fifo_m_valid;
  logic                             dr_fifo_m_ready;
  dr_fifo_t                         dr_fifo_m_data ;

  rx_command_queue_line_t           dr_ram_data_read;  
  logic                             dr_valid        ;
  logic                             dr_ready        ;

  // Local declarations Credit Counter
  logic [CREDIT_CNT_WIDTH    - 1:0] credit_cnt ;
  logic                             credit_decr;
  logic                             credit_incr;

  logic [PLRU_WIDTH          - 1:0] plru_tree  ;

  // Local declarations TX Command Queue
  logic                   tx_cq_s_valid;
  logic                   tx_cq_s_ready;
  tx_command_queue_line_t tx_cq_s_data ;

  logic                   tx_cq_m_valid;
  logic                   tx_cq_m_ready;
  tx_command_queue_line_t tx_cq_m_data ;

  // Local declarations RX Command Queue
  logic                   rx_cq_s_valid;
  logic                   rx_cq_s_ready;
  rx_command_queue_line_t rx_cq_s_data ;

  logic                   rx_cq_m_valid;
  logic                   rx_cq_m_ready;
  rx_command_queue_line_t rx_cq_m_data ;

  // Local declarations MSHR
  logic                   mshr_send_req      ;
  logic                   mshr_full          ;
  logic [ADDR_WIDTH -1:0] mshr_read_miss_addr;

  // Local declarations FSM
  logic                   init          ;
  logic                   work          ;
  logic                   fsm_write_back;
  logic [SET_WIDTH - 1:0] init_cnt_ff   ;

  // Local deneral declarations
  logic                   global_stall;


  assign global_stall = fsm_write_back || mshr_full;

  assign hmd_valid_in = cpu_valid_i && cpu_ready_o;

  hit_miss_detect #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .WAYS      (WAYS      ),
    .ID_WIDTH  (ID_WIDTH  ),
    .SETS      (SETS      ),
    .TAG_WIDTH (TAG_WIDTH )
  ) i_hmd (
    .clk_i       (clk_i                  ),
    .aresetn_i   (aresetn_i              ),

    .cpu_addr_i  (cpu_addr_i             ),
    .cpu_req_id_i(cpu_req_id_i           ),
    .cpu_valid_i (hmd_valid_in           ),

    .init_i      (init                   ),
    .init_cnt_i  (init_cnt_ff            ),
    .plru_tree_i (plru_tree              ),
    .dr_we_o     (hmd_we_dr_out          ),

    .cq_addr_i   (mshr_read_miss_addr    ),
    .cq_valid_i  (rx_cq_m_valid          ),

    .hit_o       (hmd_hit                ),
    .miss_o      (hmd_miss               ),
    .id_o        (hmd_fifo_s_data.id     ),
    .set_o       (hmd_fifo_s_data.set    ),
    .hit_arr_o   (hmd_fifo_s_data.hit_arr),
    .miss_addr_o (hmd_addr               ),
    .valid_o     (hmd_valid_out          )
  );

  assign hmd_id         = hmd_fifo_s_data.id;
  assign hmd_valid_miss = hmd_miss && hmd_valid_out;

  assign credit_incr    = hmd_fifo_m_ready && hmd_fifo_m_valid;
  assign credit_decr    = hmd_fifo_s_valid && hmd_fifo_s_ready;

  credit_cnt #(
    .CNT_WIDTH (CREDIT_CNT_WIDTH),
    .CREDIT_NUM(CREDIT_NUM      )
  ) i_crd_cnt (
    .clk_i    (clk_i      ),
    .aresetn_i(aresetn_i  ),
    .incr_i   (credit_incr),
    .decr_i   (credit_decr),
    .cnt_o    (credit_cnt )
  );

  assign hmd_fifo_s_valid = hmd_valid_out && hmd_hit;


  fifo #(
    .struct_t(hmd_fifo_t       ),
    .DEPTH   (COMMON_FIFO_DEPTH)
  ) i_hm_detect_fifo (
    .clk_i     (clk_i           ),
    .arstn_i   (aresetn_i       ),

    .s_tvalid_i(hmd_fifo_s_valid),
    .s_tready_o(hmd_fifo_s_ready),
    .s_tdata_i (hmd_fifo_s_data ),

    .m_tvalid_o(hmd_fifo_m_valid), 
    .m_tready_i(hmd_fifo_m_ready), 
    .m_tdata_o (hmd_fifo_m_data )
  );

  mshr #(
    .DEPTH(MSHR_DEPTH)
  ) i_mshr (
    .clk_i          (clk_i                 ),
    .aresetn_i      (aresetn_i             ),

    .init_i         (init                  ),
    .target_id_i    (rx_cq_m_data.req_id   ),
    .enable_i       (hmd_valid_miss && work),
    .write_id_i     (hmd_id                ),
    .init_cnt_i     (init_cnt_ff           ),
    .write_data_i   (hmd_addr              ),

    .full_o         (mshr_full             ),
    .read_hit_data_o(mshr_read_miss_addr   ),
    .push_cq_o      (mshr_send_req         )
  );

  assign hmd_fifo_m_ready = dr_ready && global_stall;

  cache_data_read #(
    .SETS           (SETS                   ),
    .DATA_WIDTH     (DATA_WIDTH             ),
    .WAYS           (WAYS                   ),
    .ID_WIDTH       (ID_WIDTH               ),
    .slave_struct_t (hmd_fifo_t             ),
    .master_struct_t(rx_command_queue_line_t)
  ) i_dr (
    .clk_i         (clk_i                ),
    .aresetn_i     (aresetn_i            ),

    .s_data_i      (hmd_fifo_m_data      ),
    .s_valid_i     (hmd_fifo_m_valid     ),
    .s_ready_o     (dr_ready             ),

    .cq_data_i     (rx_cq_m_data.mem_data),
    .cq_addr_i     (mshr_read_miss_addr  ),
    .cq_valid_i    (rx_cq_m_valid        ),

    .init_i        (init                 ),
    .init_cnt_i    (init_cnt_ff          ),
    .plru_tree_o   (plru_tree            ),
    .write_enable_i(hmd_we_dr_out        ),

    .m_data_o      (dr_ram_data_read     ),
    .m_valid_o     (dr_valid             )
  );

  assign dr_fifo_s_valid      = dr_valid;
  assign dr_fifo_s_data.data  = dr_ram_data_read.mem_data;
  assign dr_fifo_s_data.id    = dr_ram_data_read.req_id;

  fifo #(
    .struct_t(dr_fifo_t),
    .DEPTH   (4)
  ) i_dr_fifo (
    .clk_i     (clk_i          ),
    .arstn_i   (aresetn_i      ),

    .s_tvalid_i(dr_fifo_s_valid),
    .s_tready_o(dr_fifo_s_ready),
    .s_tdata_i (dr_fifo_s_data ),

    .m_tvalid_o(dr_fifo_m_valid),
    .m_tready_i(dr_fifo_m_ready),
    .m_tdata_o (dr_fifo_m_data )
  );

  assign dr_fifo_m_ready = ~rx_cq_m_valid;

  // TX Command Queue
  assign tx_cq_s_valid          = mshr_send_req;
  assign tx_cq_s_data.miss_addr = hmd_addr     ;
  assign tx_cq_s_data.req_id    = hmd_id       ;

  show_ahead_fifo #(
    .struct_t(tx_command_queue_line_t),
    .DEPTH   (SETS                   )
  ) i_tx_command_queue (
    .aclk_i    (clk_i         ),
    .aresetn_i (aresetn_i     ),

    .s_tvalid_i(tx_cq_s_valid ),
    .s_tready_o(tx_cq_s_ready ),
    .s_tdata_i (tx_cq_s_data  ),

    .m_tvalid_o(tx_cq_m_valid ),
    .m_tready_i(tx_cq_m_ready ),
    .m_tdata_o (tx_cq_m_data  )
  );

  assign mem_req_o     = tx_cq_m_valid         ;
  assign mem_addr_o    = tx_cq_m_data.miss_addr;
  assign mem_id_o      = tx_cq_m_data.req_id   ;
  assign tx_cq_m_ready = mem_ack_i             ;

  assign rx_cq_s_valid         = mem_valid_i   ;
  assign rx_cq_s_data.mem_data = mem_data_i    ;
  assign rx_cq_s_data.req_id   = mem_id_i      ;
  assign rx_cq_m_ready         = fsm_write_back;
  // RX Command Queue
  show_ahead_fifo #(
    .struct_t(rx_command_queue_line_t),
    .DEPTH   (SETS                   )
  ) i_rx_command_queue (
    .aclk_i    (clk_i        ),
    .aresetn_i (aresetn_i    ),

    .s_tvalid_i(rx_cq_s_valid),
    .s_tready_o(rx_cq_s_ready),
    .s_tdata_i (rx_cq_s_data ),

    .m_tvalid_o(rx_cq_m_valid),
    .m_tready_i(rx_cq_m_ready),
    .m_tdata_o (rx_cq_m_data )
  );

  cache_fsm i_fsm
  (
    .clk_i        (clk_i         ),
    .aresetn_i    (aresetn_i     ),

    .rx_cq_valid_i(rx_cq_m_valid ),
    .init_o       (init          ),
    .work_o       (work          ),
    .init_cnt_o   (init_cnt_ff   ),
    .write_back_o (fsm_write_back)
  );

  // Write-Back
  assign cpu_ready_o  = ~global_stall && (credit_cnt != 0);

  assign cpu_valid_o  = global_stall ? rx_cq_m_valid         : dr_fifo_m_valid    ;
  assign cpu_req_id_o = global_stall ? rx_cq_m_data.req_id   : dr_fifo_m_data.id  ;
  assign cpu_data_o   = global_stall ? rx_cq_m_data.mem_data : dr_fifo_m_data.data;

endmodule