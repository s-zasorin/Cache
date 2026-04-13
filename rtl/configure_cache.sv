module configure_cache 
import cache_pkg::*;
(
  input   logic                    clk_i         ,
  input   logic                    aresetn_i     ,

  // CPU Interface (Read-Only)
  input   logic                    cpu_valid_i   ,
  input   logic [ADDR_WIDTH - 1:0] cpu_addr_i    ,
  output  logic                    hit_o         ,
  output  logic                    cpu_ready_o   ,
  output  logic                    valid_o       ,
  output  logic [DATA_WIDTH - 1:0] read_data_o   ,

  // Memory Interface
  output  logic                    mem_req_o     ,
  output  logic [ADDR_WIDTH - 1:0] mem_addr_o    ,
  input   logic [DATA_WIDTH - 1:0] mem_data_i    ,
  input   logic                    mem_ack_i    

);

  localparam WIDTH_PLRU          = WAYS - 1           ;
  localparam STATUS_WIDTH        = WAYS               ;
  localparam PLRU_RAM_LINE_WIDTH = WAYS + WIDTH_PLRU  ;

  logic [WAYS       - 1:0] hit_arr                    ;
  logic                    hit_ff                     ;
  logic [WAYS       - 1:0] equal_tag_arr              ;
  logic [DATA_WIDTH - 1:0] read_data            [WAYS];
  logic [WIDTH_WAY  - 1:0] evict_way                  ;
  logic [TAG_WIDTH  - 1:0] input_tag                  ;
  logic [TAG_WIDTH  - 1:0] read_data_tag        [WAYS];
  logic                    mem_write_handshake        ;
  logic                    cpu_read_handshake         ;
  logic [SET_WIDTH  - 1:0] set                        ;
  logic [SET_WIDTH  - 1:0] set_ff                     ;
  logic [ADDR_WIDTH - 1:0] addr_ff                    ;
  logic [WIDTH_PLRU - 1:0] plru_ram             [SETS];
  logic [SET_WIDTH  - 1:0] state_ram_write_addr       ;
  logic [SET_WIDTH  - 1:0] init_state_ram_cnt_ff      ;
  logic [WAYS       - 1:0] write_data_state_ram       ;
  logic [SET_WIDTH  - 1:0] addr_for_ram               ;
  logic                    write_enable_state_ram     ;
  logic                    plru_wr_en                 ;
  logic [WIDTH_PLRU - 1:0] plru_tree_ram              ;
  logic [WIDTH_PLRU - 1:0] plru_tree_ram_out_arr[SETS];
  logic [WIDTH_PLRU - 1:0] plru_tree_ram_out          ;
  logic [SETS       - 1:0] plru_calc_en               ;
  logic [SETS       - 1:0] plru_calc_valid_out_arr    ;
  logic                    plru_calc_valid_out        ;
  logic [WAYS       - 1:0] write_enable               ;

  logic [WAYS       - 1:0] read_data_status           ;
  cache_state_t next, state_ff;

  assign input_tag              = cpu_addr_i[ADDR_WIDTH - 1:SET_WIDTH]                                     ;
  assign set                    = (SETS == 1) ? 1'b0 : cpu_addr_i[SET_WIDTH  - 1:0]                        ;
  assign cpu_read_handshake     = cpu_valid_i && cpu_ready_o                                               ;
  assign mem_write_handshake    = mem_req_o && mem_ack_i                                                   ;
  assign write_enable_state_ram = (state_ff == INIT) || ((state_ff == WAIT_ACK_MEM) && mem_write_handshake);

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      addr_ff <= {{ADDR_WIDTH{1'b0}}};
    else if (cpu_read_handshake)
      addr_ff <= cpu_addr_i;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      init_state_ram_cnt_ff <= {SET_WIDTH{1'b0}};
    else if (state_ff == INIT)
      init_state_ram_cnt_ff <= init_state_ram_cnt_ff + 'b1;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      state_ff <= IDLE;
    else
      state_ff <= next;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      set_ff <= {SET_WIDTH{1'b0}};
    else if (cpu_read_handshake)
      set_ff <= set;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      hit_ff <= 1'b0;
    else
      hit_ff <= hit_o;

  always_comb begin
    write_enable = 'b0;
    if (mem_write_handshake && state_ff == WAIT_ACK_MEM)
      write_enable[evict_way] = 1'b1;
  end

  always_comb begin
    next = state_ff;

    case (state_ff)
      IDLE        :                                             next = INIT        ;
      INIT        : if      (init_state_ram_cnt_ff == SETS - 1) next = WAIT_CPU_REQ;
      WAIT_CPU_REQ: if      (cpu_read_handshake               ) next = PLRU_RECALC ;
      PLRU_RECALC : if      (plru_calc_valid_out && hit_o     ) next = WAIT_CPU_REQ;
                    else if (plru_calc_valid_out && ~hit_o    ) next = WAIT_ACK_MEM;
      WAIT_ACK_MEM: if      (mem_write_handshake              ) next = WAIT_CPU_REQ;
    endcase
  end

  always_comb begin
    state_ram_write_addr = 'b0;
    if (state_ff == INIT)
      state_ram_write_addr = init_state_ram_cnt_ff;
    else if (state_ff == WAIT_ACK_MEM)
      state_ram_write_addr = set;
  end

  always_comb begin
    addr_for_ram = {SETS{1'b0}};
    if (state_ff == WAIT_CPU_REQ)
      addr_for_ram = set;
    else if (state_ff == WAIT_ACK_MEM)
      addr_for_ram = evict_way;
  end

  always_comb begin
    write_data_state_ram = {WAYS{1'b0}};

    if (state_ff == INIT)
      write_data_state_ram = {WAYS{1'b0}};
    else if ((state_ff == WAIT_ACK_MEM) && mem_write_handshake)
      write_data_state_ram[evict_way] = 1'b1;

  end
  genvar i;

	generate
    for (i = 0; i < WAYS; i = i + 1) begin : gen_tag_ram
      single_port_ram #(
        .DATA_WIDTH(TAG_WIDTH   ), 
        .RAM_DEPTH (SINGLE_DEPTH), 
        .ADDR_WIDTH(SET_WIDTH   )
      ) i_tag_ram (
        .clk_i              (clk_i           ),
        .wr_en_i            (write_enable[i] ),
        .addr_i             (addr_for_ram    ),
        .write_data_i       (input_tag       ),
        .read_data_o        (read_data_tag[i])
      );
    end
	endgenerate

	generate
    for (i = 0; i < WAYS; i = i + 1) begin : gen_data_ram
      single_port_ram #(
        .DATA_WIDTH(DATA_WIDTH  ), 
        .RAM_DEPTH (SINGLE_DEPTH), 
        .ADDR_WIDTH(SET_WIDTH   )
      ) i_data_ram (
        .clk_i       (clk_i          ),
        .wr_en_i     (write_enable[i]),
        .addr_i      (addr_for_ram   ),
        .write_data_i(mem_data_i     ),
        .read_data_o (read_data   [i])
      );
    end
	endgenerate

  single_port_ram #(
    .DATA_WIDTH(WAYS        ), 
    .RAM_DEPTH (SETS        ), 
    .ADDR_WIDTH(SET_WIDTH   )
    ) i_status_ram (
    .clk_i       (clk_i                 ),
    .wr_en_i     (write_enable_state_ram),
    .addr_i      (state_ram_write_addr  ),
    .write_data_i(write_data_state_ram  ),
    .read_data_o (read_data_status      )
  );

  assign plru_wr_en = (state_ff == PLRU_RECALC) && plru_calc_valid_out;

  single_port_ram #(
    .DATA_WIDTH(WIDTH_PLRU), 
    .RAM_DEPTH (SETS      ), 
    .ADDR_WIDTH(SET_WIDTH )
  ) i_plru_ram (
    .clk_i       (clk_i            ),
    .wr_en_i     (plru_wr_en       ),
    .addr_i      (set              ),
    .write_data_i(plru_tree_ram_out),
    .read_data_o (plru_tree_ram    )
  );

  bin_decoder #(
    .BIN_WIDTH   (SET_WIDTH),
    .ONEHOT_WIDTH(SETS     )
  ) i_dec_plru_calc_en (
    .bin_i   (set_ff       ),
    .onehot_o(plru_calc_en )
  );

  genvar k;
  generate
    for (k = 0; k < SETS; k = k + 1) begin
      plru_refill #(
        .WIDTH_WAY (WIDTH_WAY ), 
        .WIDTH_PLRU(WIDTH_PLRU)
      ) i_plru (    
        .clk_i      (clk_i                     ),
        .aresetn_i  (aresetn_i                 ),
        .plru_tree_i(plru_tree_ram             ),
        .valid_i    (plru_calc_en           [k]),
        .hit_i      (hit_arr                   ),
        .valid_o    (plru_calc_valid_out_arr[k]),
        .plru_tree_o(plru_tree_ram_out_arr  [k])
      );
    end
  endgenerate

  always_comb begin
    for (int i = 0; i < SETS; i = i + 1) begin
      plru_tree_ram_out |= plru_tree_ram_out_arr[i] & {WIDTH_PLRU{plru_calc_valid_out_arr[i]}};
    end
  end

  plru_calc #(
    .WIDTH_WAY (WIDTH_WAY ),
    .WIDTH_PLRU(WIDTH_PLRU)
  ) i_plru_calc (
    .plru_tree_i(plru_tree_ram),
    .evict_way_o(evict_way    )
  );

  assign plru_calc_valid_out = |plru_calc_valid_out_arr;

  always_comb begin
    for (int j = 0; j < WAYS; j = j + 1) begin
      equal_tag_arr[j] = (input_tag == read_data_tag[j]) && read_data_status[j];
    end
  end

  always_comb begin
    for (int j = 0; j < WAYS; j = j + 1) begin
      hit_arr[j] = equal_tag_arr[j] & read_data_status[j];
    end
  end

  always_comb begin
    read_data_o = {DATA_WIDTH{1'b0}};

    for (int j = 0; j < WAYS; j = j + 1) begin
      read_data_o |= {{DATA_WIDTH}{hit_arr[j]}} & read_data[j];
    end
  end

  always_comb begin
    valid_o = 1'b0;

    for (int j = 0; j < WAYS; j = j + 1) begin
      valid_o |= hit_arr[j] && (state_ff == WAIT_ACK_MEM);
    end
  end

  assign hit_o       = |hit_arr && (state_ff == PLRU_RECALC);
  assign mem_req_o   = (state_ff == WAIT_ACK_MEM)           ;
  assign mem_addr_o  = addr_ff                              ;

  assign cpu_ready_o = (state_ff == WAIT_CPU_REQ);
endmodule