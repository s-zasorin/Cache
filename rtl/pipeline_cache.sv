module pipeline_cache 
import cache_pkg::*;
(
  input   logic                    clk_i         ,
  input   logic                    aresetn_i     ,

  // CPU Interface
  input   logic                    cpu_valid_i   ,
  input   logic [ADDR_WIDTH - 1:0] cpu_addr_i    ,
  input   logic [4:0]              cpu_req_id_i  ,

  output  logic                    cpu_ready_o   ,
  output  logic                    cpu_valid_o   ,
  output  logic [4:0]              cpu_req_id_o  ,
  output  logic [DATA_WIDTH - 1:0] cpu_data_o    ,

  // Memory Interface
  output  logic                    mem_req_o     ,
  output  logic [ADDR_WIDTH - 1:0] mem_addr_o    ,
  output  logic [ID_WIDTH   - 1:0] mem_id_o      ,

  input   logic [DATA_WIDTH - 1:0] mem_data_i    ,
  input   logic                    mem_valid_i   ,
  input   logic [ID_WIDTH   - 1:0] mem_id_i      ,
  input   logic                    mem_ack_i    
);

  localparam PLRU_WIDTH          = (WAYS == 1) ? WAYS : WAYS - 1;
  localparam MSHR_DEPTH          = SETS                         ;
  localparam MSHR_ADDR_WIDTH     = $clog2(MSHR_DEPTH)           ;
  localparam COMMAND_QUEUE_WIDTH = ADDR_WIDTH + ID_WIDTH        ;
  localparam WIDTH_ADDR_LINE_ID  = $clog2(ID_MAX_NUM)           ;

  // Global declarations

  logic                         cpu_req               ;
  logic [1:0]                   cpu_req_ff            ;
  logic [ADDR_WIDTH      - 1:0] cpu_addr_ff      [1:0];

  logic [4:0]                   cpu_req_id_ff    [3:0];
  logic [SET_WIDTH       - 1:0] init_state_ram_cnt_ff ;
  logic [TAG_WIDTH       - 1:0] mem_write_tag         ;
  logic [WAYS            - 1:0] hit_arr               ;
  logic [SET_WIDTH       - 1:0] set_ff           [3:0];

  logic [SET_WIDTH       - 1:0] addr_ram              ;
  logic                         hit                   ;
  logic                         stall                 ;
  logic [1:0]                   mem_op_done_ff        ;
  logic                         mem_handshake         ;

  logic                      ready_send_cpu_data_rx_cq;
  // FSM

  logic init;
  cache_state_t state_ff, next;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      state_ff <= 'b0;
    else
      state_ff <= next;

  assign stall       = (state_ff == WAIT_REFILL_FROM_MEM) || (~hit && cpu_req_ff[1]);
  assign cpu_ready_o = (state_ff == CPU_WORK) && ~stall  ;
  assign mem_req_o   = (state_ff == WAIT_REFILL_FROM_MEM) && ~(|mem_op_done_ff);
  assign init        = (state_ff == INIT                );

  always_comb begin
    next = state_ff;

    case (state_ff)
      IDLE              :                                          next = INIT;
      INIT              : if (init_state_ram_cnt_ff == (SETS - 1)) next = CPU_WORK;
      CPU_WORK          : if (ready_send_cpu_data_rx_cq)           next = SEND_DATA_FROM_MEM;
      SEND_DATA_FROM_MEM: 
    endcase
  end

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      mem_op_done_ff <= 2'b0;
    else if (state_ff == WAIT_REFILL_FROM_MEM) begin
      mem_op_done_ff[0] <= mem_handshake;
      mem_op_done_ff[1] <= mem_op_done_ff[0];
    end

  // Stage 1

  assign tag                 = cpu_addr_ff[0][ADDR_WIDTH - 1:SET_WIDTH];
  assign cpu_req             = cpu_valid_i && cpu_ready_o;
  assign set_ff[0]           = cpu_addr_ff[0][SET_WIDTH  - 1:0]        ;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      init_state_ram_cnt_ff <= {SET_WIDTH{1'b0}};
    else if (state_ff == INIT)
      init_state_ram_cnt_ff <= init_state_ram_cnt_ff + 'b1;

  always_ff @(posedge clk_i)
    if (cpu_req && ~stall)
      cpu_addr_ff[0] <= cpu_addr_i;
  
  always_ff @(posedge clk_i)
    if (cpu_req && ~stall)
      cpu_req_id_ff[0] <= cpu_req_id_i;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cpu_req_ff[0] <= 1'b0;
    else if (~stall)
      cpu_req_ff[0] <= cpu_req;

  // Stage 2

  logic [TAG_WIDTH  - 1:0] compare_tag         ;
  logic [TAG_WIDTH  - 1:0] read_data_tag [WAYS];
  logic [WAYS       - 1:0] write_enable        ;
  logic [WAYS       - 1:0] write_data_state_ram;
  logic                    we_state_ram        ;
  logic [SET_WIDTH  - 1:0] addr_state_ram      ;
  logic [WAYS       - 1:0] read_data_status    ;
  logic [WIDTH_WAY  - 1:0] evict_way           ;
  logic                    tag_mem_req         ;
  logic                    state_mem_req       ;
  logic [PLRU_WIDTH - 1:0] plru_tree_ff        ;

  plru_calc i_plru_calc
  (
    .plru_tree_i(plru_tree_ff),
    .evict_way_o(evict_way   )
  );

  assign we_state_ram  = |write_enable || (state_ff == INIT);
  assign compare_tag   = cpu_addr_ff[1][ADDR_WIDTH - 1:SET_WIDTH];
  assign mem_addr_o    = cpu_addr_ff[1];
  assign mem_write_tag = mem_addr_o[ADDR_WIDTH - 1:SET_WIDTH];

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cpu_req_ff[1] <= 1'b0;
    else
      cpu_req_ff[1] <= cpu_req_ff[0];

  always_ff @(posedge clk_i)
    if (cpu_req_ff[0])
      set_ff[1] <= set_ff[0];

  always_ff @(posedge clk_i)
    if (cpu_req_ff[0])
      cpu_addr_ff[1] <= cpu_addr_ff[0];

  always_ff @(posedge clk_i)
    if (cpu_req_ff[0])
      cpu_req_id_ff[1] <= cpu_req_id_ff[0];
  
  always_comb begin
    tag_mem_req = 1'b0;

    if (state_ff == CPU_WORK)
      tag_mem_req = cpu_req_ff[0];
    else if (state_ff == WAIT_REFILL_FROM_MEM)
      tag_mem_req = mem_op_done_ff[0];
  end

  always_comb begin
    state_mem_req = 1'b0;

    if (state_ff == INIT)
      state_mem_req = 1'b1;
    else if (state_ff == CPU_WORK)
      state_mem_req = cpu_req_ff[0];
    else if (state_ff == WAIT_REFILL_FROM_MEM)
      state_mem_req = mem_op_done_ff[0];
  end

  always_comb begin
    write_enable = {WAYS{1'b0}};

    if (stall)
      write_enable[evict_way] = 1'b1; 
  end

  always_comb begin
    if (cpu_valid_o && stall)
      addr_ram = set_ff[3];
    else
      addr_ram = set_ff[0];
  end

  always_comb begin
    if (state_ff == WAIT_REFILL_FROM_MEM)
      addr_state_ram = set_ff[3];
    else
      addr_state_ram = init_state_ram_cnt_ff;
  end

  always_comb begin
    write_data_state_ram = read_data_status;

    if (state_ff == INIT)
      write_data_state_ram = {WAYS{1'b0}};
    else if (state_ff == WAIT_REFILL_FROM_MEM)
      write_data_state_ram[evict_way] = 1'b1;
  end



  assign hit = |hit_arr;

  // Stage 3

  logic [DATA_WIDTH - 1:0] read_data_ram [WAYS]  ;
  logic [DATA_WIDTH - 1:0] select_read_data      ;
  logic [SET_WIDTH  - 1:0] addr_data_ram         ;
  logic                    plru_ready            ;
  logic                    valid_ram_data_out    ;
  logic                    valid_ram_data_out_ff ;

  logic [SET_WIDTH  - 1:0] set_skid              ;
  logic                    set_skid_ready        ;
  logic                    set_skid_valid        ;
  logic                    set_skid_dwn_handshake;

  logic [SET_WIDTH  - 1:0] cpu_req_id_skid       ;
  logic                    cpu_req_id_skid_ready ;
  logic                    cpu_req_id_skid_valid ;
  logic                    cpu_req_id_skid_dwn_handshake;

  logic [WAYS       - 1:0] hit_arr_skid          ;
  logic                    hit_arr_skid_valid    ;
  logic                    hit_arr_skid_ready    ;
  logic [WAYS       - 1:0] hit_arr_ff            ;
  logic                    hit_arr_skid_handshake;

  logic                    hit_skid              ;
  logic                    hit_skid_valid        ;
  logic                    hit_skid_ready        ;

  logic                    valid_ram_data_skid   ;
  logic                    valid_ram_skid_valid  ;
  logic                    valid_ram_skid_ready  ;
  logic                    valid_ram_skid_dwn_handshake;

  logic                    data_mem_req;
  logic                    plru_mem_req;

  logic [PLRU_WIDTH - 1:0] plru_tree;
  logic [SET_WIDTH  - 1:0] addr_plru_wrapper;

  assign set_skid_dwn_handshake        = plru_ready && set_skid_valid       ;
  assign cpu_req_id_skid_dwn_handshake = plru_ready && cpu_req_id_skid_valid;
  assign hit_arr_skid_dwn_handshake    = plru_ready && hit_arr_skid_valid   ;
  assign valid_ram_skid_dwn_handshake  = plru_ready && valid_ram_skid_valid ;
  assign valid_ram_data_out            = hit        && cpu_req_ff[1]        ;

  always_comb begin
    if (stall && cpu_valid_o)
      addr_data_ram = set_ff[3];
    else
      addr_data_ram = set_skid;
  end

  always_comb begin
    data_mem_req = 1'b0;
    if (state_ff == CPU_WORK)
      data_mem_req = valid_ram_data_out;
    else if (state_ff == WAIT_REFILL_FROM_MEM)
      data_mem_req = mem_op_done_ff[0];
  end

  skid_buffer #(
    .DATA_WIDTH(SET_WIDTH)
  ) i_skid_set (
    .clk_i      (clk_i         ),
    .aresetn_i  (aresetn_i     ),

    .up_valid_i (cpu_req_ff[1] ),
    .up_data_i  (set_ff[1]     ),
    .up_ready_o (set_skid_ready),

    .dwn_ready_i(plru_ready    ),
    .dwn_data_o (set_skid      ),
    .dwn_valid_o(set_skid_valid)
  );

  skid_buffer #(
    .DATA_WIDTH(5)
  ) i_skid_req_id (
    .clk_i      (clk_i                ),
    .aresetn_i  (aresetn_i            ),

    .up_valid_i (cpu_req_ff[1]        ),
    .up_data_i  (cpu_req_id_ff[1]     ),
    .up_ready_o (cpu_req_id_skid_ready),

    .dwn_ready_i(plru_ready           ),
    .dwn_data_o (cpu_req_id_skid      ),
    .dwn_valid_o(cpu_req_id_skid_valid)
  );

  always_ff @(posedge clk_i)
    if (set_skid_dwn_handshake)
      set_ff[2] <= set_skid;

  always_ff @(posedge clk_i)
    if (cpu_req_id_skid_dwn_handshake)
      cpu_req_id_ff[2] <= cpu_req_id_skid;

  skid_buffer #(
    .DATA_WIDTH(WAYS)
  ) i_skid_hit_arr (
    .clk_i      (clk_i             ),
    .aresetn_i  (aresetn_i         ),

    .up_valid_i (cpu_req_ff[1]     ),
    .up_data_i  (hit_arr           ),
    .up_ready_o (hit_arr_skid_ready),

    .dwn_ready_i(plru_ready        ),
    .dwn_data_o (hit_arr_skid      ),
    .dwn_valid_o(hit_arr_skid_valid)
  );

  always_ff @(posedge clk_i)
    if (hit_arr_skid_dwn_handshake)
      hit_arr_ff <= hit_arr_skid;

  always_comb begin
    for (int j = 0; j < WAYS; ++j) begin
      select_read_data |= read_data_ram[j] & {DATA_WIDTH{hit_arr_ff[j]}};
    end
  end

  always_comb begin
    if (state_ff == INIT)
      addr_plru_wrapper = init_state_ram_cnt_ff;
    else if (state_ff == CPU_WORK)
      addr_plru_wrapper = set_skid;
    else
      addr_plru_wrapper = set_ff[3];
  end

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      valid_ram_data_out_ff <= 1'b0;
    else if (valid_ram_skid_dwn_handshake)
      valid_ram_data_out_ff <= valid_ram_data_out;

// TX Command Queue

  logic                   tx_cq_s_tready;
  tx_command_queue_line_t tx_cq_s_tdata ;

  tx_command_queue_line_t tx_cq_m_tdata ;

  assign tx_cq_s_tdata.miss_addr = cpu_addr_ff  [1];
  assign tx_cq_s_tdata.req_id    = cpu_req_id_ff[1];

  show_ahead_fifo #(
    .struct_t(tx_command_queue_line_t)
    .DEPTH   (SETS                   )
  ) i_tx_command_queue (
    .aclk_i    (clk_i         ),
    .aresetn_i (aresetn_i     ),

    .s_tvalid_i(mshr_in_fly   ),
    .s_tready_o(tx_cq_s_tready),
    .s_tdata_i (tx_cq_s_tdata ),

    .m_tvalid_o(mem_req_o     ),
    .m_tready_i(mem_ack_i     ),
    .m_tdata_o (tx_cq_m_tdata )
  );

  assign mem_addr_o = cq_m_tdata.mem_addr_o;
  assign mem_id_o   = cq_m_tdata.req_id    ;

// RX Command Queue

  logic                    rx_cq_s_tready;
  logic [DATA_WIDTH - 1:0] rx_cq_data    ;
  logic [ID_WIDTH   - 1:0] rx_cq_id      ;
  rx_command_queue_line_t  rx_cq_s_tdata ;

  rx_command_queue_line_t  rx_cq_m_tdata ;
  logic                    rx_cq_m_valid ;

  assign rx_cq_s_tdata.mem_data  = mem_data_i;
  assign rx_cq_s_tdata.req_id    = mem_id_i  ;

  show_ahead_fifo #(
    .struct_t(rx_command_queue_line_t)
    .DEPTH   (SETS                   )
  ) i_rx_command_queue (
    .aclk_i    (clk_i         ),
    .aresetn_i (aresetn_i     ),

    .s_tvalid_i(mem_valid_i   ),
    .s_tready_o(rx_cq_s_tready),
    .s_tdata_i (rx_cq_s_tdata ),

    .m_tvalid_o(rx_cq_m_valid ),
    .m_tready_i(mem_ack_i     ),
    .m_tdata_o (rx_cq_m_tdata )
  );

  assign rx_cq_data = rx_cq_m_tdata.mem_data;
  assign rx_cq_id   = rx_cq_m_tdata.req_id  ;

  // MSHR

  logic [MSHR_ADDR_WIDTH    - 1:0] mshr_addr               ;
  logic                            mshr_enable             ;
  logic [ADDR_WIDTH         - 1:0] mshr_write_data         ;
  logic                            mshr_in_fly             ;
  logic                            mshr_req_id             ;
  logic [MSHR_ADDR_WIDTH    - 1:0] mshr_addr_work_cnt_ff   ;
  logic [MSHR_ADDR_WIDTH    - 1:0] mshr_addr_cnt_init_ff   ;
  logic                            mshr_hit_id             ;
  logic [ID_WIDTH           - 1:0] mshr_id_arr [ID_MAX_NUM];
  logic [WIDTH_ADDR_LINE_ID - 1:0] mshr_num_miss_id        ;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      mshr_addr_cnt_init_ff <= {MSHR_ADDR_WIDTH{1'b0}};
    else if (state_ff == INIT)
      mshr_addr_cnt_init_ff <= mshr_addr_cnt_init_ff + 'b1;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      mshr_addr_work_cnt_ff <= {MSHR_ADDR_WIDTH{1'b0}};
    else if (mshr_enable)
      mshr_addr_work_cnt_ff <= mshr_addr_work_cnt_ff + 'b1;

  assign mshr_enable = cpu_req_ff[1] && ~hit;

  always_comb begin
    if (state_ff == INIT)
      mshr_addr = mshr_addr_cnt_init_ff;
    else
      mshr_addr = mshr_addr_work_cnt_ff;
  end

  mshr #(
    .DEPTH(4)
  ) i_mshr (
    .clk_i       (clk_i           ),
    .aresetn_i   (aresetn_i       ),

    .init_i      (init            ),
    .target_id_i (rx_cq_id        ),
    .enable_i    (mshr_enable     ),
    .write_id_i  (cpu_req_id_ff[1]),
    .write_addr_i(mshr_addr       ),
    .write_data_i(mshr_write_data ),

    .cnt_id_o    (mshr_num_miss_id),
    .hit_id_o    (mshr_hit_id     ),
    .read_id_o   (mshr_id_arr     ),
    .in_fly_o    (mshr_in_fly     )
  );

  assign ready_transmit_cpu_data_rx_cq = mshr_hit_id && rx_cq_m_valid;
// Stage 4

  logic [DATA_WIDTH - 1:0] data_mux          ;
  logic                    valid_data_summary;

  assign mem_handshake      = mem_ack_i && mem_req_o                       ;
  assign data_mux           = mem_handshake ? mem_data_i : select_read_data;
  assign valid_data_summary = valid_ram_data_out_ff || mem_handshake       ;

  always_ff @(posedge clk_i)
    if (valid_data_summary)
      set_ff[3] <= set_ff[2];

  always_ff @(posedge clk_i)
    if (valid_data_summary)
      cpu_req_id_ff[3] <= cpu_req_id_ff[2];

  always_ff @(posedge clk_i)
    cpu_valid_o <= valid_data_summary;

  always_ff @(posedge clk_i)
    if (valid_data_summary)
      cpu_data_o <= data_mux;
  
  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      plru_tree_ff <= {PLRU_WIDTH{1'b0}};
    else if (mem_handshake)
      plru_tree_ff <= plru_tree;

  assign cpu_req_id_o = cpu_req_id_ff[3];

endmodule