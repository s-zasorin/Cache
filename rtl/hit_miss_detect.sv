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

  logic [TAG_WIDTH  - 1:0] read_data_tag [WAYS];

  logic [SET_WIDTH  - 1:0] input_cpu_set;

  logic [WIDTH_WAY  - 1:0] evict_way           ;
  logic [WAYS       - 1:0] we_tag_ram          ;
  logic [SET_WIDTH  - 1:0] addr_tag_ram        ;
  logic [SET_WIDTH  - 1:0] write_addr_state_ram;
  logic [SET_WIDTH  - 1:0] read_addr_state_ram ;
  logic [SET_WIDTH  - 1:0] addr_state_ram_ff   ;

  logic [WAYS       - 1:0] read_data_status       ;
  logic [WAYS       - 1:0] read_data_status_ff    ;
  logic [WAYS       - 1:0] write_data_state_ram   ;
  logic [WAYS       - 1:0] write_data_state_ram_ff;

  logic                    cq_valid_ff    ;
  logic [ADDR_WIDTH - 1:0] cq_addr_ff     ;
  logic [SET_WIDTH  - 1:0] cq_set         ;
  logic [SET_WIDTH  - 1:0] cq_set_ff      ;
  logic [TAG_WIDTH  - 1:0] cq_data_tag    ;
  logic [TAG_WIDTH  - 1:0] cq_data_tag_ff ;
  logic                    tag_mem_req    ;
  logic                    state_mem_req  ;
  logic                    we_state_ram   ;
  logic                    rd_en_state_ram;
  logic [WIDTH_WAY  - 1:0] evict_way_ff   ;
  logic                    init_ff        ;
  // Stage registers
  logic [1:0]              cpu_valid_ff      ;
  logic [ID_WIDTH   - 1:0] cpu_req_id_ff[1:0];
  logic [ADDR_WIDTH - 1:0] cpu_addr_ff  [1:0];
  logic [TAG_WIDTH  - 1:0] cpu_tag_ff   [1:0];
  logic [SET_WIDTH  - 1:0] cpu_set_ff   [1:0];

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cq_valid_ff <= 1'b0;
    else
      cq_valid_ff <= cq_valid_i;

  always_ff @(posedge clk_i)
    if (cq_valid_i)
      cq_addr_ff <= cq_addr_i;

  always_ff @(posedge clk_i)
      if (cpu_valid_i)
    cpu_addr_ff[0] <= cpu_addr_i;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cpu_valid_ff <= 2'b00;
    else if (~stall_i) begin
      cpu_valid_ff[0] <= cpu_valid_i;
      cpu_valid_ff[1] <= cpu_valid_ff[0];
    end

  always_ff @(posedge clk_i)
    if (cpu_valid_i)
      cpu_req_id_ff[0] <= cpu_req_id_i;

  always_ff @(posedge clk_i)
    init_ff <= init_i;

  generate
    if (SETS == 1) begin
      assign cq_data_tag   = cq_addr_i ;
      assign cpu_tag_ff[0] = cpu_addr_ff[0];

      assign cpu_set_ff[0] = 1'b0;
      assign cq_set        = 1'b0;
    end
    else begin
      assign cq_data_tag   = cq_addr_i     [ADDR_WIDTH - 1:SET_WIDTH];
      assign cpu_tag_ff[0] = cpu_addr_ff[0][ADDR_WIDTH - 1:SET_WIDTH];

      assign cpu_set_ff[0] = cpu_addr_ff[0][SET_WIDTH - 1:0];
      assign cq_set        = cq_addr_i     [SET_WIDTH - 1:0];
    end
  endgenerate

  assign we_state_ram    = init_i          || cq_valid_ff;
  assign rd_en_state_ram = cpu_valid_ff[0] || cq_valid_i;

  assign tag_mem_req     = cpu_valid_ff[0] || cq_valid_ff;

  assign state_mem_req   = cpu_valid_ff[0] || (init_i || cq_valid_ff || cq_valid_i);

  always_comb begin
    dr_we_o = {WAYS{1'b0}};

    if (cq_valid_i   )
      dr_we_o[evict_way] = 1'b1;
  end

  always_comb begin
    we_tag_ram = {WAYS{1'b0}};

    if (cq_valid_ff   )
      we_tag_ram[evict_way] = 1'b1;
  end

  always_ff @(posedge clk_i)
    if (cq_valid_i)
      evict_way_ff <= evict_way;

  always_ff @(posedge clk_i)
    if (cq_valid_i)
      cq_data_tag_ff <= cq_data_tag;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      cq_set_ff <= {SET_WIDTH{1'b0}};
    else if (cq_valid_i   )
      cq_set_ff <= cq_set;

  always_comb begin
    addr_tag_ram = cq_set_ff;

    if (cpu_valid_ff[0])
      addr_tag_ram = cpu_set_ff[0];
    else if (cq_valid_i   )
      addr_tag_ram = cq_set;
  end

  always_comb begin
    write_addr_state_ram   = cq_set_ff;
    if (init_i)
      write_addr_state_ram = init_cnt_i;
    else if (cq_valid_ff   )
      write_addr_state_ram = cq_set_ff;
  end

  always_comb begin
    read_addr_state_ram   = cq_set;

    if (cpu_valid_ff[0])
      read_addr_state_ram = cpu_set_ff[0];
    else if (cq_valid_i   )
      read_addr_state_ram = cq_set;
  end

  always_comb begin
    write_data_state_ram = read_data_status;

    if (init_i)
      write_data_state_ram               = {WAYS{1'b0}};
    else if (cq_valid_ff)
      write_data_state_ram[evict_way_ff] = 1'b1;
  end

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      write_data_state_ram_ff <= {WAYS{1'b0}};
    else if (init_i)
      write_data_state_ram_ff <= {WAYS{1'b0}};
    else if (cq_valid_i)
      write_data_state_ram_ff <= write_data_state_ram;

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
        .clk_i       (clk_i           ),
        .wr_en_i     (we_tag_ram[i]   ),
        .req_i       (tag_mem_req     ),
        .addr_i      (addr_tag_ram    ),
        .write_data_i(cq_data_tag_ff  ),
        .read_data_o (read_data_tag[i])
      );
    end: g_tag_ram
	endgenerate

  //single_port_ram #(
  //  .DATA_WIDTH(WAYS        ), 
  //  .RAM_DEPTH (SETS        ), 
  //  .ADDR_WIDTH(SET_WIDTH   )
  //  ) i_status_ram (
  //  .clk_i       (clk_i                                ),
  //  .wr_en_i     (we_state_ram                         ),
  //  .req_i       (state_mem_req || (init_ff && ~init_i)),
  //  .addr_i      (init_i ? addr_state_ram : addr_state_ram_ff),
  //  .write_data_i(write_data_state_ram_ff              ),
  //  .read_data_o (read_data_status                     )
  //);

  dual_port_ram #(
    .DATA_WIDTH(WAYS     ),
    .RAM_DEPTH (SETS     ),
    .ADDR_WIDTH(SET_WIDTH)
  ) i_status_ram (
    .clk_i    (clk_i               ),
    .wr_addr_i(write_addr_state_ram),
    .data_i   (write_data_state_ram),
    .wr_en_i  (we_state_ram        ),
    .rd_en_i  (rd_en_state_ram     ),
    .rd_addr_i(read_addr_state_ram ),
    .data_o   (read_data_status    )
  );

  always_ff @(posedge clk_i)
    if (cpu_valid_ff[0])
      cpu_addr_ff[1] <= cpu_addr_ff[0];

  always_ff @(posedge clk_i)
    if (cpu_valid_ff[0])
      cpu_req_id_ff[1] <= cpu_req_id_ff[0];

  generate
    if (SETS == 1) begin
      assign cpu_tag_ff[1] = cpu_addr_ff[1];
      assign cpu_set_ff[1] = 1'b0          ;
    end
    else begin
      assign cpu_tag_ff[1] = cpu_addr_ff[1][ADDR_WIDTH - 1:SET_WIDTH];
      assign cpu_set_ff[1] = cpu_addr_ff[1][SET_WIDTH  - 1:0]        ;
    end
  endgenerate

  generate
    for (genvar i = 0; i < WAYS; ++i) begin: g_hit_arr
      assign hit_arr_o[i] = (read_data_tag[i] == cpu_tag_ff[1]) && read_data_status[i];
    end: g_hit_arr
  endgenerate

  assign valid_o     = cpu_valid_ff[1]              ;
  assign hit_o       = |hit_arr_o && valid_o        ;
  assign miss_o      = ~hit_o && valid_o            ;
  assign miss_addr_o = miss_o ? cpu_addr_ff[1] : 'b0;
  assign set_o       = cpu_set_ff[1]                ;
  assign id_o        = cpu_req_id_ff[1]             ;

endmodule