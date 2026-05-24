module tb_configure_cache ();

  import cache_pkg::*;

  // Параметры для теста
  localparam TEST_SETS = SETS;
  localparam TEST_WAYS = WAYS;
  
  // Сигналы для подключения кэша
  logic                    clk_i;
  logic                    aresetn_i;
  
  // CPU Interface
  logic                    cpu_valid_i ;
  logic [ADDR_WIDTH - 1:0] cpu_addr_i  ;
  logic [4:0]              cpu_req_id_i;
  logic                    hit_o       ;
  logic                    cpu_ready_o ;
  logic                    valid_o     ;
  logic [4:0]              cpu_req_id_o;
  logic [DATA_WIDTH - 1:0] read_data_o ;
  
  // Memory Interface
  logic                    mem_req_o    ;
  logic [ADDR_WIDTH - 1:0] mem_addr_o   ;
  logic [ID_WIDTH   - 1:0] mem_id_o     ;
  logic [ID_WIDTH   - 1:0] mem_id_i     ;
  logic [DATA_WIDTH - 1:0] mem_data_i   ;
  logic                    mem_valid_i  ;
  logic                    mem_ack_i    ;

  logic [DATA_WIDTH - 1:0] external_memory [0:1023];
  logic [ADDR_WIDTH - 1:0] mem_save_addr           ;
  logic [ID_WIDTH   - 1:0] mem_save_id             ;
  
  cache_top DUT 
  (
    .clk_i       (clk_i       ),
    .aresetn_i   (aresetn_i   ),

    .cpu_valid_i (cpu_valid_i ),
    .cpu_addr_i  (cpu_addr_i  ),
    .cpu_req_id_i(cpu_req_id_i),

    .cpu_ready_o (cpu_ready_o ),
    .cpu_valid_o (valid_o     ),
    .cpu_req_id_o(cpu_req_id_o),
    .cpu_data_o  (read_data_o ),

    .mem_req_o   (mem_req_o   ),
    .mem_addr_o  (mem_addr_o  ),
    .mem_id_o    (mem_id_o    ),

    .mem_id_i    (mem_id_i    ),
    .mem_valid_i (mem_valid_i ),
    .mem_data_i  (mem_data_i  ),
    .mem_ack_i   (mem_ack_i   )
  );
  
  // Генерация тактового сигнала
  initial begin
    clk_i <= 1'b0;
    forever begin
      #5;
      clk_i <= ~clk_i;
    end
  end
  
  // Инициализация памяти
  initial begin
    for (int i = 0; i < 1024; i++) begin
      external_memory[i] = i * 16'h1000 + i;
    end
    $display("[MEMORY] Initialized 1024 locations with unique data");
  end
  
  task send_cpu_req(
    input logic [ADDR_WIDTH - 1:0] test_addr_i,
    input logic [ID_WIDTH   - 1:0] test_id_i
  );
    cpu_valid_i  <= 1'b1;
    cpu_addr_i   <= test_addr_i;
    cpu_req_id_i <= test_id_i;
    //@(posedge clk_i);
    //cpu_req_id_i <= 5'd2;
    @(posedge clk_i);
    cpu_valid_i <= 1'b0;
  endtask

  task wait_mem_ack();
    wait(mem_req_o);
    mem_ack_i     <= 1'b1;
    @(posedge clk_i);
    mem_ack_i     <= 1'b0;
    mem_save_addr <= mem_addr_o;
    mem_save_id   <= mem_id_o  ;
    repeat (2) @(posedge clk_i);
    mem_valid_i   <= 1'b1;
    mem_data_i    <= external_memory[mem_save_addr];
    mem_id_i      <= mem_save_id;
    @(posedge clk_i);
    mem_valid_i   <= 1'b0;
  endtask

  initial begin
    aresetn_i <= 1'b0;
    @(posedge clk_i);
    aresetn_i <= 1'b1;
    repeat (100) @(posedge clk_i);
    $finish();
  end

  initial begin
    repeat (10) @(posedge clk_i);
    send_cpu_req('d215, 'd1);
    //@(posedge clk_i);
    send_cpu_req('d315, 'd2);
    send_cpu_req('d83, 'd3);
    send_cpu_req('d121, 'd4);
    send_cpu_req('d221, 'd5);
    send_cpu_req('d387, 'd6);
    send_cpu_req('d566, 'd7);
    repeat (18) @(posedge clk_i);
    send_cpu_req('d215, 'd8);
    send_cpu_req('d315, 'd9);
    send_cpu_req('d83, 'd10);
    send_cpu_req('d121, 'd11);
    send_cpu_req('d221, 'd12);
    send_cpu_req('d387, 'd13);
    send_cpu_req('d566, 'd14);
    //@(posedge clk_i);
    //send_cpu_req('d56, 'd3);
    //repeat (10) @(posedge clk_i);
    //send_cpu_req('d215, 'd4);
    //send_cpu_req('d215, 'd6);
    //repeat (10) @(posedge clk_i);
    //send_cpu_req('d675, 'd5);
    //repeat (10) @(posedge clk_i);
    //send_cpu_req('d56, 'd7);
    //@(posedge clk_i);
    //send_cpu_req('d56);
  end

  initial begin
    mem_data_i  <= {DATA_WIDTH{1'b0}};
    cpu_valid_i <= 1'b0;
    mem_valid_i <= 1'b0;
    mem_id_i    <= 1'b0;
    mem_ack_i   <= 1'b0;
    repeat (15) @(posedge clk_i);
    wait_mem_ack();
    @(posedge clk_i);
    wait_mem_ack();
    @(posedge clk_i);
    wait_mem_ack();
  end
endmodule