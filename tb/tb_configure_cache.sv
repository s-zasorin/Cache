module tb_configure_cache ();

  import cache_pkg::*;

  // Сигналы для подключения кэша
  logic                    clk_i;
  logic                    aresetn_i;
  
  // CPU Interface
  logic                    cpu_valid_i;
  logic [ADDR_WIDTH - 1:0] cpu_addr_i;
  logic                    hit_o;
  logic                    cpu_ready_o;
  logic                    valid_o;
  logic [DATA_WIDTH - 1:0] read_data_o;
  
  // Memory Interface
  logic                    mem_req_o;
  logic                    mem_addr_o;
  logic [DATA_WIDTH - 1:0] mem_data_i;
  logic                    mem_ack_i;

  // Модель внешней памяти
  logic [DATA_WIDTH - 1:0] external_memory [0:255];
  logic [ADDR_WIDTH - 1:0] last_mem_request;
  int                      mem_response_delay = 2;  // Задержка ответа памяти в тактах

  // Статистика
  int hits = 0;
  int misses = 0;
  int total_accesses = 0;
  
  // Данные для тестирования PLRU
  logic [SET_WIDTH-1:0] test_set;
  logic [WAYS-1:0] expected_evict_order [$];
  
  // Инстанс кэша
  configure_cache u_cache 
  (
    .clk_i          (clk_i),
    .aresetn_i      (aresetn_i),
    .cpu_valid_i    (cpu_valid_i),
    .cpu_addr_i     (cpu_addr_i),
    .hit_o          (hit_o),
    .cpu_ready_o    (cpu_ready_o),
    .valid_o        (valid_o),
    .read_data_o    (read_data_o),
    .mem_req_o      (mem_req_o),
    .mem_addr_o     (mem_addr_o),
    .mem_data_i     (mem_data_i),
    .mem_ack_i      (mem_ack_i)
  );
  
  // Генерация тактового сигнала
  always #5 clk_i <= ~clk_i;  // 100 MHz
  
  // Инициализация внешней памяти
  initial begin
    for (int i = 0; i < 256; i++) begin
      external_memory[i] = i * 16'h1000 + i;  // Уникальные данные
    end
  end
  
  // Модель памяти
  always @(posedge clk_i) begin
    if (mem_req_o) begin
      last_mem_request = mem_addr_o;
      $display("[MEMORY] Request at address: 0x%0h", mem_addr_o);
      
      // Имитируем задержку ответа
      repeat (mem_response_delay) @(posedge clk_i);
      
      mem_data_i = external_memory[last_mem_request];
      mem_ack_i  = 1'b1;
      $display("[MEMORY] Response data: 0x%0h", mem_data_i);
      
      @(posedge clk_i);
      mem_ack_i = 1'b0;
    end
  end
  
  // Мониторинг статистики
  always @(posedge clk_i) begin
    if (cpu_valid_i && cpu_ready_o) begin
      total_accesses++;
      if (hit_o) begin
        hits++;
        $display("[HIT] Address: 0x%0h, Data: 0x%0h", cpu_addr_i, read_data_o);
      end else begin
        misses++;
        $display("[MISS] Address: 0x%0h", cpu_addr_i);
      end
    end
  end
  
  // Функция для отправки запроса к кэшу
  task send_read_request(input [ADDR_WIDTH-1:0] addr);
    $display("\n[TEST] Sending read request for address 0x%0h", addr);
    cpu_addr_i  <= addr;
    cpu_valid_i <= 1'b1;
    
    // Ждем готовности кэша
    wait (cpu_ready_o);
    @(posedge clk_i);
    cpu_valid_i <= 1'b0;
    
    // Ждем завершения операции (если промах, ждем заполнения)
    while (!cpu_ready_o && (u_cache.state_ff != WAIT_CPU_REQ)) begin
      @(posedge clk_i);
    end
  endtask
  
  // Функция для заполнения кэша последовательными адресами
  task fill_cache(input int start_addr, input int num_accesses);
    for (int i = 0; i < num_accesses; i++) begin
      send_read_request(start_addr + i * 4);
      #10;  // Небольшая задержка между запросами
    end
  endtask
  
  // Функция для доступа к адресам одного сета
  task access_set(input [SET_WIDTH-1:0] set, input int num_addresses);
    logic [ADDR_WIDTH-1:0] base_addr;
    base_addr <= {set, {ADDR_WIDTH-SET_WIDTH{1'b0}}};
    
    for (int i = 0; i < num_addresses; i++) begin
      send_read_request(base_addr + i * SETS * 4);  // Адреса в одном сете
      #10;
    end
  endtask
  
  // Мониторинг состояния кэша (можно добавить для отладки)
  task monitor_cache_state();
    $display("\n=== Cache State ===");
    $display("Hits: %0d, Misses: %0d, Hit Rate: %0.2f%%", 
             hits, misses, (total_accesses > 0) ? (hits * 100.0 / total_accesses) : 0);
    $display("==================\n");
  endtask
  
  // Основной тест
  initial begin
    // Инициализация сигналов
    clk_i       <= 1'b0;
    aresetn_i   <= 1'b0;
    cpu_valid_i <= 1'b0;
    cpu_addr_i  <= 0;
    mem_data_i  <= 0;
    mem_ack_i   <= 1'b0;
    
    // Сброс
    repeat (3) @(posedge clk_i);
    aresetn_i <= 1'b1;
    @(posedge clk_i);
    
    $display("\n=========================================");
    $display("Starting Cache Testbench");
    $display("Configuration: %0d sets, %0d ways", SETS, WAYS);
    $display("=========================================\n");
    
    // TEST 1: Заполнение кэша и проверка промахов/попаданий
    $display("\n=== TEST 1: Cache Fill ===");
    fill_cache(0, SETS * WAYS);  // Заполняем весь кэш
    
    #20;
    monitor_cache_state();
    
    // Должно быть 0 попаданий при заполнении
    if (hits == 0) $display("[PASS] No hits during cache fill");
    else $display("[FAIL] Unexpected hits during cache fill");
    
    // TEST 2: Проверка попаданий
    $display("\n=== TEST 2: Cache Hits ===");
    hits = 0; misses = 0; total_accesses = 0;
    
    // Повторно читаем те же адреса
    fill_cache(0, SETS * WAYS / 2);
    
    #20;
    monitor_cache_state();
    
    if (hits > 0) $display("[PASS] Cache hits working");
    else $display("[FAIL] No cache hits");
    
    // TEST 3: Тестирование PLRU вытеснения
    $display("\n=== TEST 3: PLRU Eviction Policy ===");
    hits = 0; misses = 0; total_accesses = 0;
    
    // Сначала заполняем определенный сет
    test_set = 0;
    $display("Filling set %0d", test_set);
    access_set(test_set, WAYS);  // Заполняем все пути в сете
    
    // Доступ к разным адресам для обновления PLRU
    $display("Accessing different addresses in set %0d to update PLRU", test_set);
    send_read_request({test_set, 12'b0, 2'b00});        // way 0
    #10;
    send_read_request({test_set, 12'b0, 2'b01});        // way 1  
    #10;
    send_read_request({test_set, 12'b0, 2'b10});        // way 2
    #10;
    send_read_request({test_set, 12'b0, 2'b00});        // way 0 again
    #10;
    send_read_request({test_set, 12'b0, 2'b01});        // way 1 again
    #10;
    
    // Теперь вызываем промах - должен вытесниться way 3 (если PLRU работает правильно)
    $display("Causing miss - should evict way %0d (least recently used)", WAYS-1);
    send_read_request({test_set, 12'b0, 2'b11});        // Новый адрес в том же сете
    
    #20;
    monitor_cache_state();
    
    // TEST 4: Проверка согласованности данных
    $display("\n=== TEST 4: Data Consistency ===");
    hits = 0; misses = 0; total_accesses = 0;
    
    // Читаем адрес, который должен быть в кэше
    send_read_request(0);
    #10;
    
    // Читаем адрес, который был вытеснен
    send_read_request({test_set, 12'b0, 2'b11});
    #10;
    
    monitor_cache_state();
    
    // TEST 6: Стресс-тест PLRU
    $display("\n=== TEST 6: PLRU Stress Test ===");
    hits = 0; misses = 0; total_accesses = 0;
    
    // Много разных адресов для активного вытеснения
    for (int i = 0; i < SETS * WAYS * 3; i++) begin
      send_read_request(i * 4);
      if (i % 10 == 0) #5;
    end
    
    #50;
    monitor_cache_state();
    
    // Финальный отчет
    $display("\n=========================================");
    $display("Test Summary");
    $display("=========================================");
    $display("Total accesses: %0d", total_accesses);
    $display("Final hit rate: %0.2f%%", (hits * 100.0 / total_accesses));
    $display("=========================================\n");
    
    #100;
    $finish;
  end
  
  // Дополнительная отладка - мониторинг состояния кэша
  initial begin
    $dumpfile("cache_tb.vcd");
    $dumpvars(0, tb_configure_cache);
  end
  
  // Мониторинг PLRU (если есть доступ к внутренним сигналам)
  // Для этого нужно добавить иерархический путь к сигналам кэша
  initial begin
    forever begin
      @(posedge clk_i);
      if (u_cache.mem_req_o) begin
        $display("[DEBUG] Memory request for address 0x%0h, evict_way: %0d", 
                 u_cache.mem_addr_o, u_cache.evict_way);
      end
    end
  end

endmodule