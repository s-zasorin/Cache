package cache_pkg;

  localparam ADDR_WIDTH  = 32;
  localparam DATA_WIDTH  = 32;
  localparam SETS        = 8;
  localparam WAYS        = 4;

  localparam WIDTH_WAY    = (WAYS == 1) ? WAYS : $clog2(WAYS);
  localparam SINGLE_DEPTH = SETS;
  localparam SET_WIDTH    = $clog2(SETS)                     ;
  localparam TAG_WIDTH    = ADDR_WIDTH - SET_WIDTH           ;
  localparam ID_WIDTH     = 5;
  localparam ID_MAX_NUM   = 2;

  typedef struct packed {
    logic valid;
  } status_t;

  typedef struct packed {
    logic [ID_WIDTH - 1:0] id;
  } id_t;

  typedef struct packed {
    logic [DATA_WIDTH - 1:0] data  ;
    logic [TAG_WIDTH  - 1:0] tag   ;
    status_t                 status;
  } cache_line_t;

  typedef struct packed {
    logic [ADDR_WIDTH - 1:0] miss_addr;
    logic                    valid    ;
  } mshr_line_t;

  typedef struct packed {
    logic [ADDR_WIDTH - 1:0] miss_addr;
    logic [ID_WIDTH   - 1:0] req_id   ;
  } tx_command_queue_line_t;

  typedef struct packed {
    logic [DATA_WIDTH - 1:0] mem_data;
    logic [ID_WIDTH   - 1:0] req_id  ;
  } rx_command_queue_line_t;

  typedef struct packed {
    logic [SET_WIDTH - 1:0] set;
    logic [ID_WIDTH  - 1:0] id ;
    logic [WAYS      - 1:0] hit_arr;
  } hmd_fifo_t;

  typedef struct packed {
    logic [DATA_WIDTH - 1:0] data;
    logic [ID_WIDTH   - 1:0] id;
  } dr_fifo_t;

endpackage : cache_pkg