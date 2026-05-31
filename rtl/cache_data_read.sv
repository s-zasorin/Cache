module cache_data_read #(
  parameter      DATA_WIDTH      = -1          ,
  parameter      ID_WIDTH        = -1          ,
  parameter      WAYS            = -1          ,
  parameter      SETS            = -1          ,
  localparam     SET_WIDTH       = $clog2(SETS),
  localparam     PLRU_WIDTH      = WAYS - 1    ,
  parameter type slave_struct_t  = logic       ,
  parameter type master_struct_t = logic
) (
  input  logic                    clk_i         ,
  input  logic                    aresetn_i     ,

  // Slave Interface
  input  slave_struct_t           s_data_i      ,
  input  logic                    s_valid_i     ,
  output logic                    s_ready_o     ,

  // Command Queue Slave Interface
  input  logic [DATA_WIDTH - 1:0] cq_data_i     ,
  input  logic [SET_WIDTH  - 1:0] cq_addr_i     ,
  input  logic                    cq_valid_i    ,

  // System Interface
  input  logic [WAYS       - 1:0] write_enable_i,
  input  logic                    stall_i       ,
  input  logic                    init_i        ,
  input  logic [SET_WIDTH  - 1:0] init_cnt_i    ,
  output logic [PLRU_WIDTH - 1:0] plru_tree_o   ,

  // Master Interface
  output master_struct_t          m_data_o      ,
  output logic                    m_valid_o  
);

  logic                       s_handshake          ;
  logic                       data_mem_req         ;
  logic [WAYS          - 1:0] write_enable         ;
  logic                       s_valid_ff           ;
  logic [SET_WIDTH     - 1:0] s_set                ;
  logic [ID_WIDTH      - 1:0] s_id                 ;
  logic [SET_WIDTH     - 1:0] work_addr_plru       ;
  logic [SET_WIDTH     - 1:0] addr_data_ram        ;
  logic [DATA_WIDTH    - 1:0] read_data_ram [WAYS] ;
  logic [DATA_WIDTH    - 1:0] read_data_ff         ;
  logic [ID_WIDTH      - 1:0] s_id_ff              ;    
  logic [WAYS          - 1:0] hit_arr              ;
  logic [WAYS          - 1:0] hit_arr_ff           ;
  logic [DATA_WIDTH    - 1:0] select_read_data     ;
  logic [SET_WIDTH     - 1:0] set_ff               ;
  logic [WAYS          - 1:0] update_vector        ;
  logic [PLRU_WIDTH    - 1:0] plru_ram      [SETS] ;
  logic                       plru_we              ;
  logic [PLRU_WIDTH    - 1:0] plru_tree_refilled   ;  
  logic [PLRU_WIDTH    - 1:0] plru_tree_read       ;
  logic [PLRU_WIDTH    - 1:0] plru_tree_read_ff    ;
  logic [SET_WIDTH     - 1:0] work_addr_plru_ff    ;
  logic                       plru_we_ff           ;

  assign plru_we      = cq_valid_i || s_handshake ;
  assign hit_arr      = s_data_i.hit_arr;
  assign s_set        = s_data_i.set;
  assign s_id         = s_data_i.id;
  assign s_handshake  = s_valid_i && s_ready_o;
  assign data_mem_req = s_handshake || cq_valid_i;
  assign s_ready_o    = ~stall_i;

  always_comb begin
    update_vector = {WAYS{1'b0}};
    if (cq_valid_i)
      update_vector = write_enable_i;
    else if (s_handshake)
      update_vector = hit_arr;
  end

  always_comb begin
    work_addr_plru = {SET_WIDTH{1'b0}};
    if (init_i)
      work_addr_plru = init_cnt_i;
    if (s_handshake)
      work_addr_plru = s_set;
    else if (cq_valid_i)
      work_addr_plru = cq_addr_i;
  end

  always_comb begin
    addr_data_ram = {SET_WIDTH{1'b0}};

    if (s_handshake)
      addr_data_ram = s_set;
    else if (cq_valid_i)
      addr_data_ram = cq_addr_i;
  end

  always_ff @(posedge clk_i)
    work_addr_plru_ff <= work_addr_plru;

  always_ff @(posedge clk_i)
    plru_we_ff <= plru_we;

  always_comb begin
    select_read_data = 'b0;
    for (int j = 0; j < WAYS; ++j) begin
      select_read_data |= read_data_ram[j] & {DATA_WIDTH{hit_arr_ff[j]}};
    end
  end

  generate
    for (genvar i = 0; i < WAYS; ++i) begin: g_data_ram
      single_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_DEPTH (SETS      )
      ) i_data_ram (
        .clk_i       (clk_i            ),
        .wr_en_i     (write_enable_i[i]),
        .req_i       (data_mem_req     ),
        .addr_i      (addr_data_ram    ),
        .write_data_i(cq_data_i        ),
        .read_data_o (read_data_ram[i] )
      );
    end: g_data_ram
  endgenerate

  assign plru_tree_read = plru_ram[work_addr_plru_ff];

  plru_refill i_refill
  (
    .plru_tree_i(plru_tree_read    ),
    .hit_i      (update_vector     ),
    .plru_tree_o(plru_tree_refilled)
  );

  always_ff @(posedge clk_i)
    if (init_i)
      plru_ram[init_cnt_i] <= {PLRU_WIDTH{1'b0}};
    else if (plru_we)
      plru_ram[work_addr_plru] <= plru_tree_refilled;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      s_valid_ff <= 1'b0;
    else
      s_valid_ff <= s_handshake;
  
  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      hit_arr_ff <= {WAYS{1'b0}};
    else if (s_handshake)
      hit_arr_ff <= hit_arr;

  always_ff @(posedge clk_i)
    if (s_handshake)
      s_id_ff <= s_id;

  always_ff @(posedge clk_i)
    if (s_handshake)
      set_ff <= s_set;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      plru_tree_read_ff <= 'b0;
    else if (plru_we_ff)
      plru_tree_read_ff <= plru_tree_read;

  assign m_data_o.mem_data = select_read_data ;
  assign m_data_o.req_id   = s_id_ff          ;
  assign m_valid_o         = s_valid_ff       ;
  assign plru_tree_o       = plru_tree_read_ff;

endmodule