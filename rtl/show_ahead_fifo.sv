module show_ahead_fifo #(parameter type struct_t = logic,
                        parameter  FIFO_DEPTH    = 16) (

  input  logic    aclk_i    ,
  input  logic    aresetn_i ,   

  // Slave Interface
  input  struct_t s_tdata_i ,
  input  logic    s_tvalid_i,
  output logic    s_tready_o,

  // Master Interface
  output struct_t m_tdata_o ,
  output logic    m_tvalid_o,
  input  logic    m_tready_i

);

  localparam int unsigned DATA_WIDTH = $bits(struct_t);

  localparam ONE_RAM_DEPTH           = FIFO_DEPTH / 2;
  localparam PTR_WIDTH               = $clog2(ONE_RAM_DEPTH);

  logic [PTR_WIDTH     :0] wr_ptr         ;
  logic [PTR_WIDTH     :0] rd_ptr         ;
  struct_t                 data_ram_out   ;
  struct_t                 head_reg       ;

  logic                    full           ;
  logic                    empty          ;
  logic                    bypass_en      ; // управляет мультиплексором на выходном порте
  logic                    m_handshake    ;
  logic                    s_handshake    ;
  logic                    enable_head_reg; // разрешение на запись в head register
  logic                    almost_empty   ; // почти пуст по первому порту
  logic                    wr_en          ; // запись в RAM память
  logic                    rd_en          ; // чтение из RAM памяти

  assign full            = wr_ptr[PTR_WIDTH - 1:0] == rd_ptr[PTR_WIDTH - 1:0] && (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);
  assign empty           = wr_ptr[PTR_WIDTH - 1:0] == rd_ptr[PTR_WIDTH - 1:0] && (wr_ptr[PTR_WIDTH] == rd_ptr[PTR_WIDTH]);

  assign almost_empty    = empty && bypass_en || (wr_ptr == rd_ptr + 'b1);

  assign m_handshake     = m_tvalid_o && m_tready_i;
  assign s_handshake     = s_tvalid_i  && s_tready_o ;

  assign s_tready_o      = ~full;
  assign m_tvalid_o      = ~empty || bypass_en;

  assign enable_head_reg = s_handshake && (empty || m_handshake && almost_empty);

  assign wr_en           = s_handshake && ~enable_head_reg;

  assign rd_en           = m_handshake;

  dual_port_ram #(
    .DATA_WIDTH(DATA_WIDTH    ),
    .RAM_DEPTH (ONE_RAM_DEPTH ),
    .ADDR_WIDTH(PTR_WIDTH     )
  ) i_ram (
    .clk_i    (aclk_i      ),
    .wr_addr_i(wr_ptr      ),
    .data_i   (s_tdata_i   ),
    .wr_en_i  (wr_en       ),
    .rd_en_i  (rd_en       ),
    .rd_addr_i(rd_ptr + 'b1),
    .data_o   (data_ram_out)
  );

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i) begin
      wr_ptr <= {PTR_WIDTH{1'b0}};
    end
    else if (s_handshake) begin
      wr_ptr <= wr_ptr + 'b1;
    end

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      rd_ptr <= {PTR_WIDTH{1'b0}};
    else if (m_handshake)
      rd_ptr <= rd_ptr + 'b1;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      head_reg <= {DATA_WIDTH{1'b0}};
    else if (enable_head_reg)
      head_reg <= s_tdata_i;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      bypass_en <= 1'b0;
    else if (enable_head_reg)
      bypass_en <= 1'b1;
    else if (m_handshake)
      bypass_en <= 1'b0;

  assign m_tdata_o = bypass_en ? head_reg : data_ram_out;

endmodule