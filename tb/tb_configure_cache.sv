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
  logic [DATA_WIDTH - 1:0] cpu_data_o  ;
  
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
    .cpu_data_o  (cpu_data_o  ),

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

    @(posedge clk_i);
    cpu_valid_i <= 1'b0;
  endtask

  task wait_mem_ack();
    wait(mem_req_o);
    mem_ack_i     <= 1'b1;
    mem_data_i    <= external_memory[mem_addr_o];
    mem_id_i      <= mem_id_o;
    @(posedge clk_i);
    mem_ack_i     <= 1'b0;
  endtask

  initial begin
    aresetn_i <= 1'b0;
    @(posedge clk_i);
    aresetn_i <= 1'b1;
    repeat (500) @(posedge clk_i);
    $finish();
  end

  initial begin
    repeat (20) @(posedge clk_i);
    send_cpu_req('d215, 'd1);
    send_cpu_req('d215, 'd2);
    send_cpu_req('d215, 'd3);
    repeat (20) @(posedge clk_i);
    send_cpu_req('d315, 'd4);
    send_cpu_req('d315, 'd5);
    send_cpu_req('d315, 'd6);
    send_cpu_req('d315, 'd7);
    send_cpu_req('d315, 'd8);
    send_cpu_req('d315, 'd9);
    //repeat (9) @(posedge clk_i);
    //send_cpu_req('d83 , 'd10);
    //repeat (9) @(posedge clk_i);
    //send_cpu_req('d580, 'd11);
    //repeat (8) @(posedge clk_i);
    //send_cpu_req('d121, 'd4);
    //repeat (11) @(posedge clk_i);
    //send_cpu_req('d221, 'd5);
    //repeat (13) @(posedge clk_i);
    //send_cpu_req('d387, 'd6);
    //repeat (9) @(posedge clk_i);
    //send_cpu_req('d566, 'd7);
    //repeat (9) @(posedge clk_i);
    //send_cpu_req('d289, 'd8);
    repeat (9) @(posedge clk_i);
    send_cpu_req('d300, 'd10);
    repeat (9) @(posedge clk_i);
    send_cpu_req('d387, 'd11);
    send_cpu_req('d387, 'd12);
    send_cpu_req('d387, 'd13);
    send_cpu_req('d387, 'd14);
    send_cpu_req('d387, 'd15);
    send_cpu_req('d387, 'd16);
    send_cpu_req('d387, 'd17);
    send_cpu_req('d387, 'd18);
    repeat (20) @(posedge clk_i);
    send_cpu_req('d904, 'd45);
    send_cpu_req('d904, 'd46);
    repeat (45) @(posedge clk_i);
    send_cpu_req('d215, 'd19);
    send_cpu_req('d315, 'd20);
    //send_cpu_req('d121, 'd14);
    //send_cpu_req('d221, 'd15);
    //send_cpu_req('d387, 'd16);
    //send_cpu_req('d566, 'd17);
    //send_cpu_req('d289, 'd18);
    //send_cpu_req('d300, 'd19);
    //send_cpu_req('d452, 'd20);
    //send_cpu_req('d904, 'd21);
    send_cpu_req('d300, 'd21);
    send_cpu_req('d387, 'd22);
    //send_cpu_req('d221, 'd12);
    send_cpu_req('d387, 'd23);
    send_cpu_req('d315, 'd24);
    send_cpu_req('d904, 'd25);
    send_cpu_req('d904, 'd26);
    //send_cpu_req('d566, 'd14);
    //@(posedge clk_i);
    //send_cpu_req('d56, 'd3);
    //repeat (10) @(posedge clk_i);
    //send_cpu_req('d215, 'd4);
    //send_cpu_req('d215, 'd6);
    //repeat (10) @(posedge clk_i);
    //send_cpu_req('d675, 'd19);
    //send_cpu_req('d675, 'd20);
    //send_cpu_req('d675, 'd21);
    //send_cpu_req('d675, 'd22);
    //send_cpu_req('d675, 'd23);
    //send_cpu_req('d675, 'd24);
    //send_cpu_req('d675, 'd25);
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
    repeat (30) @(posedge clk_i);
    wait_mem_ack();
    repeat (20) @(posedge clk_i);
    wait_mem_ack();
    repeat (10) @(posedge clk_i);
    wait_mem_ack();
    repeat (20) @(posedge clk_i);
    wait_mem_ack();
    repeat (20) @(posedge clk_i);
    wait_mem_ack();
    //repeat (11) @(posedge clk_i);
    //wait_mem_ack();
    //repeat (11) @(posedge clk_i);
    //wait_mem_ack();
    //repeat (11) @(posedge clk_i);
    //wait_mem_ack();
    //repeat (11) @(posedge clk_i);
    //wait_mem_ack();
    //repeat (30) @(posedge clk_i);
    //wait_mem_ack();
    //repeat (30) @(posedge clk_i);
    //wait_mem_ack();
  end
endmodule