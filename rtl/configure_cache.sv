module configure_cache 
import cache_pkg::*;
(
  input  logic                    clk_i         ,
  input  logic                    aresetn_i     ,
  input  logic                    valid_i       ,
  input  logic [ADDR_WIDTH - 1:0] addr_i        ,
  input  logic                    write_enable_i,
  input  logic [DATA_WIDTH - 1:0] write_data_i  ,

  output logic                    hit_o         ,
  output logic                    ready_o       ,
  output logic                    valid_o       ,
  output logic [DATA_WIDTH - 1:0] read_data_o
);

  localparam STATUS_WIDTH = $bits(status_t)        ;

  logic [WAYS       - 1:0] hit_arr                 ;
  logic [WAYS       - 1:0] equal_tag_arr           ;
  logic [DATA_WIDTH - 1:0] read_data         [WAYS];
  logic [WAYS       - 1:0] valid_out               ;
  logic [WAYS       - 1:0] write_plru_enable       ;
  logic [WAYS       - 1:0] write_enable            ;
  logic [WIDTH_WAY  - 1:0] evict_way               ;
  logic [WAYS       - 1:0] empty_set               ;
  logic [WIDTH_WAY  - 1:0] write_way               ;
  logic [TAG_WIDTH  - 1:0] input_tag               ;
  logic [TAG_WIDTH  - 1:0] read_data_tag     [WAYS];
  logic [TAG_WIDTH  - 1:0] write_data_tag          ;
  logic                    write_enable_ff         ;
  logic                    handshake               ;
  logic [SET_WIDTH  - 1:0] set                     ;

  status_t                 read_data_status  [WAYS];

  assign input_tag = addr_i[ADDR_WIDTH - 1:SET_WIDTH];
  assign set       = addr_i[SET_WIDTH  - 1:0]        ;
  assign handshake = valid_i && ready_o              ;

  typedef enum logic [1:0] { 
    IDLE  = 2'b00,
    READ  = 2'b01,
    WRITE = 2'b10
  } cache_state_t;

  cache_state_t next, state_ff;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      write_enable_ff <= 1'b0;
    else if (handshake)
      write_enable_ff <= write_enable_i;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      write_data_tag <= {TAG_WIDTH{1'b0}};
    else if (handshake)
      write_data_tag <= input_tag;

  always_ff @(posedge clk_i or negedge aresetn_i)
    if (~aresetn_i)
      state_ff <= IDLE;
    else
      state_ff <= next;
  
  always_comb begin
    next = state_ff;

    case (state_ff)
      IDLE: if (handshake)       next = READ ;
      READ: if (write_enable_ff) next = WRITE;
            else                 next = READ ;
      WRITE:                     next = IDLE ;
    endcase
  end

  assign write_enable = (|hit_arr ? hit_arr : write_plru_enable) && (state_ff == READ && ~write_enable_ff);

  genvar i;

	generate
    for (i = 0; i < WAYS; i = i + 1) begin : gen_tag_ram
      single_port_ram #(.DATA_WIDTH(TAG_WIDTH), .RAM_DEPTH(SINGLE_DEPTH), .ADDR_WIDTH(SET_WIDTH)) i_tag_ram 
      (
        .clk_i              (clk_i           ),
        .wr_en_i            (write_enable[i] ),
        .addr_i             (set             ),
        .write_data_i       (write_data_tag  ),
        .read_data_o        (read_data_tag[i])
      );
    end
	endgenerate

	generate
    for (i = 0; i < WAYS; i = i + 1) begin : gen_data_ram
      single_port_ram #(.DATA_WIDTH(DATA_WIDTH), .RAM_DEPTH(SINGLE_DEPTH), .ADDR_WIDTH(SET_WIDTH)) i_data_ram 
      (
        .clk_i              (clk_i          ),
        .wr_en_i            (write_enable[i]),
        .addr_i             (set            ),
        .write_data_i       (write_data_i   ),
        .read_data_o        (read_data[i]   )
      );
    end
	endgenerate

	generate
    for (i = 0; i < WAYS; i = i + 1) begin : gen_status_ram
      single_port_ram #(.DATA_WIDTH(STATUS_WIDTH), .RAM_DEPTH(SINGLE_DEPTH), .ADDR_WIDTH(SET_WIDTH)) i_status_ram 
      (
        .clk_i              (clk_i              ),
        .wr_en_i            (write_enable[i]    ),
        .addr_i             (set                ),
        .write_data_i       (1'b1               ),
        .read_data_o        (read_data_status[i])
      );
    end
	endgenerate

  generate
    for (int i = 0; i < WAYS; i = i + 1) begin
      equal_tag_arr[i] = (input_tag == read_data_tag[i]);
    end
  endgenerate

  generate
    for (int i = 0; i < WAYS; i = i + 1) begin
      hit_arr[i] = equal_tag_arr[i] & read_data_status[i].valid;
    end
  endgenerate

  plru i_plru
  (
    .clk_i      (clk_i    ),
    .aresetn_i  (aresetn_i),
    .hit_i      (hit_arr  ),
    .evict_way_o(evict_way)
  );

  bin_decoder i_bin_dec_0
  (
    .bin_i   (evict_way        ),
    .onehot_o(write_plru_enable)
  );

  always_comb begin
    read_data_o = {DATA_WIDTH{1'b0}};

    for (int j = 0; j < WAYS; j = j + 1) begin
      read_data_o |= {{DATA_WIDTH}{hit_arr[i]}} & read_data[i];
    end
  end

  always_comb begin
    valid_o = 1'b0;

    for (int j = 0; j < WAYS; j = j + 1) begin
      valid_o |= valid_out[j] & hit[j] && (state_ff == READ) && ~write_enable_ff;
    end
  end

  assign hit_o   = |hit_arr && (state_ff == READ) && ~write_enable_ff;
  assign ready_o = (state_ff == IDLE);

endmodule