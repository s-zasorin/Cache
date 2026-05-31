module hit_miss_detect #(
  parameter  ADDR_WIDTH = 32          ,
  parameter  WAYS       = 8           ,
  parameter  ID_WIDTH   = 4           ,
  parameter  SETS       = 8           ,
  localparam SET_WIDTH  = $clog2(SETS),
  parameter  TAG_WIDTH  = -1          ,
  parameter  PLRU_WIDTH = WAYS - 1
) (
  input  logic                    clk_i       ,
  input  logic                    aresetn_i   ,
  // CPU Interface
  input  logic [ADDR_WIDTH - 1:0] cpu_addr_i  ,
  input  logic [ID_WIDTH   - 1:0] cpu_req_id_i,
  input  logic                    cpu_valid_i ,

  // RX Command Queue Interface
  input  logic [ADDR_WIDTH - 1:0] cq_addr_i   ,
  input  logic                    cq_valid_i  ,

  // System Interface
  input  logic                    init_i      ,
  input  logic                    stall_i     ,
  input  logic [PLRU_WIDTH - 1:0] plru_tree_i ,
  input  logic [SET_WIDTH  - 1:0] init_cnt_i  ,
  output logic [WAYS       - 1:0] dr_we_o     ,

  output logic                    hit_o       ,
  output logic                    miss_o      ,
  output logic [SET_WIDTH  - 1:0] set_o       ,
  output logic [WAYS       - 1:0] hit_arr_o   ,
  output logic [ID_WIDTH   - 1:0] id_o        ,
  output logic [ADDR_WIDTH - 1:0] miss_addr_o ,
  output logic                    valid_o
);

  localparam WIDTH_WAY = $clog2(WAYS);

  logic [TAG_WIDTH  - 1:0] mem_write_tag       ;
  logic [TAG_WIDTH  - 1:0] cq_data_tag         ;
  logic [TAG_WIDTH  - 1:0] input_tag           ;
  logic [TAG_WIDTH  - 1:0] read_data_tag [WAYS];

  logic [SET_WIDTH  - 1:0] input_cpu_set;
  logic [SET_WIDTH  - 1:0] cq_set       ;
  logic [SET_WIDTH  - 1:0] cq_set_ff    ;

  logic [WIDTH_WAY  - 1:0] evict_way     ;
  logic [WAYS       - 1:0] we_tag_ram    ;
  logic [SET_WIDTH  - 1:0] addr_tag_ram  ;
  logic [SET_WIDTH  - 1:0] addr_state_ram;

  logic [WAYS       - 1:0] read_data_status       ;
  logic [WAYS       - 1:0] read_data_status_ff    ;
  logic [WAYS       - 1:0] write_data_state_ram   ;
  logic [WAYS       - 1:0] write_data_state_ram_ff;

  logic                    tag_mem_req;
  logic                    state_mem_req;
  logic                    we_state_ram;
  logic                    cq_valid_ff;
  logic                    cq_valid_edge;

  // Stage registers
  logic [ADDR_WIDTH - 1:0] cpu_addr_ff;
  logic [TAG_WIDTH  - 1:0] cpu_tag_ff ;
  logic [SET_WIDTH  - 1:0] cpu_set_ff ;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cq_valid_ff <= 1'b0;
    else
      cq_valid_ff <= cq_valid_i;

  assign cq_valid_edge = ~cq_valid_ff && cq_valid_i;

  assign mem_write_tag = cq_valid_edge ? cq_data_tag : input_tag;

  generate
    if (SETS == 1) begin
      assign cq_data_tag   = cq_addr_i ;
      assign input_tag     = cpu_addr_i;

      assign input_cpu_set = 1'b0;
      assign cq_set        = 1'b0;
    end
    else begin
      assign cq_data_tag   = cq_addr_i [ADDR_WIDTH - 1:SET_WIDTH];
      assign input_tag     = cpu_addr_i[ADDR_WIDTH - 1:SET_WIDTH];

      assign input_cpu_set = cpu_addr_i[SET_WIDTH - 1:0];
      assign cq_set        = cq_addr_i [SET_WIDTH - 1:0];
    end
  endgenerate

  assign we_state_ram  = init_i || cq_valid_edge;
  
  assign tag_mem_req   = (~stall_i && cpu_valid_i) || cq_valid_edge;

  assign state_mem_req = (~stall_i && cpu_valid_i) || (cq_valid_edge || init_i);

  assign dr_we_o = we_tag_ram;

  always_comb begin
    we_tag_ram = {WAYS{1'b0}};

    if (cq_valid_edge)
      we_tag_ram[evict_way] = 1'b1;
  end

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cq_set_ff <= {SET_WIDTH{1'b0}};
    else if (cq_valid_edge)
      cq_set_ff <= cq_set;

  always_comb begin
    addr_tag_ram = cq_set_ff;

    if (cpu_valid_i)
      addr_tag_ram = input_cpu_set;
    else if (cq_valid_edge)
      addr_tag_ram = cq_set;
  end

  always_comb begin
    addr_state_ram   = cq_set_ff;

    if (cpu_valid_i)
      addr_state_ram = input_cpu_set;
    else if (cq_valid_edge)
      addr_state_ram = cq_set;
    else if (init_i)
      addr_state_ram = init_cnt_i;
  end

  always_comb begin
    write_data_state_ram = read_data_status_ff;

    if (init_i)
      write_data_state_ram            = {WAYS{1'b0}};
    else if (cq_valid_edge)
      write_data_state_ram[evict_way] = 1'b1;
  end

  always_ff @(posedge clk_i)
    if (cq_valid_edge)
      write_data_state_ram_ff <= write_data_state_ram;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      read_data_status_ff <= {WAYS{1'b0}};
    else if (state_mem_req && ~we_state_ram)
      read_data_status_ff <= read_data_status;

  plru_calc i_plru_calc
  (
    .plru_tree_i(plru_tree_i),
    .evict_way_o(evict_way  )
  );

  generate
    for (genvar i = 0; i < WAYS; ++i) begin : g_tag_ram
      single_port_ram #(
        .DATA_WIDTH(TAG_WIDTH), 
        .RAM_DEPTH (SETS     ), 
        .ADDR_WIDTH(SET_WIDTH)
      ) i_tag_ram (
        .clk_i              (clk_i           ),
        .wr_en_i            (we_tag_ram[i]   ),
        .req_i              (tag_mem_req     ),
        .addr_i             (addr_tag_ram    ),
        .write_data_i       (mem_write_tag   ),
        .read_data_o        (read_data_tag[i])
      );
    end: g_tag_ram
	endgenerate

  single_port_ram #(
    .DATA_WIDTH(WAYS        ), 
    .RAM_DEPTH (SETS        ), 
    .ADDR_WIDTH(SET_WIDTH   )
    ) i_status_ram (
    .clk_i       (clk_i               ),
    .wr_en_i     (we_state_ram        ),
    .req_i       (state_mem_req       ),
    .addr_i      (addr_state_ram      ),
    .write_data_i(write_data_state_ram),
    .read_data_o (read_data_status    )
  );

  always_ff @(posedge clk_i)
    if (cpu_valid_i)
      cpu_addr_ff <= cpu_addr_i;
  
  always_ff @(posedge clk_i)
    if (~aresetn_i)
      valid_o <= 1'b0;
    else if (~stall_i)
      valid_o <= cpu_valid_i;

  always_ff @(posedge clk_i)
    if (cpu_valid_i)
      id_o <= cpu_req_id_i;

  generate
    if (SETS == 1) begin
      assign cpu_tag_ff = cpu_addr_ff;
      assign cpu_set_ff = 1'b0       ;
    end
    else begin
      assign cpu_tag_ff = cpu_addr_ff[ADDR_WIDTH - 1:SET_WIDTH];
      assign cpu_set_ff = cpu_addr_ff[SET_WIDTH  - 1:0]        ;
    end
  endgenerate

  generate
    for (genvar i = 0; i < WAYS; ++i) begin: g_hit_arr
      assign hit_arr_o[i] = (read_data_tag[i] == cpu_tag_ff) && read_data_status[i];
    end: g_hit_arr
  endgenerate

  assign hit_o       = |hit_arr_o && valid_o     ;
  assign miss_o      = ~hit_o && valid_o         ;
  assign miss_addr_o = miss_o ? cpu_addr_ff : 'b0;
  assign set_o       = cpu_set_ff                ;

endmodule