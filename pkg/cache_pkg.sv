package cache_pkg;

  localparam ADDR_WIDTH  = 32;
  localparam DATA_WIDTH  = 32;
  localparam SETS        = 8;
  localparam WAYS        = 4;

  localparam WIDTH_WAY    = $clog2(WAYS)           ;
  localparam SINGLE_DEPTH = SETS / WAYS            ;
  localparam SET_WIDTH    = $clog2(SETS)           ;
  localparam TAG_WIDTH    = ADDR_WIDTH - SET_WIDTH ;

  typedef struct packed {
    logic valid;
  } status_t;

  typedef struct packed {
    logic [DATA_WIDTH - 1:0] data  ;
    logic [TAG_WIDTH  - 1:0] tag   ;
    status_t                 status;
  } cache_line_t;

  typedef enum logic [2:0] { 
    IDLE         = 3'b000,
    INIT         = 3'b001,
    WAIT_CPU_REQ = 3'b010,
    PLRU_RECALC  = 3'b011,
    WAIT_ACK_MEM = 3'b100
  } cache_state_t;

endpackage : cache_pkg