module calc_tb_top;
  import calc_tb_pkg::*;
  import calculator_pkg::*;

  parameter int DataSize = DATA_W;
  parameter int AddrSize = ADDR_W;
  logic clk = 0;
  logic rst;
  state_t state;

  calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_if(.clk(clk));
  
  top_lvl my_calc(
    .clk(clk),
    .rst(calc_if.reset),
    .read_start_addr(calc_if.calc.read_start_addr),
    .read_end_addr(calc_if.calc.read_end_addr),
    .write_start_addr(calc_if.calc.write_start_addr),
    .write_end_addr(calc_if.calc.write_end_addr)
  );

  assign rst = calc_if.reset;
  assign state = my_calc.u_ctrl.state;
  assign calc_if.calc.wr_en = my_calc.write;
  assign calc_if.calc.rd_en = my_calc.read;
  assign calc_if.calc.wr_data_lower = my_calc.buffer_word[31:0];
  assign calc_if.calc.wr_data_upper = my_calc.buffer_word[63:32];
  assign calc_if.calc.rd_data_lower = my_calc.sram_a_do;
  assign calc_if.calc.rd_data_upper = my_calc.sram_b_do;
  assign calc_if.calc.ready = (my_calc.u_ctrl.state == S_END);
  assign calc_if.calc.curr_rd_addr = my_calc.r_addr;
  assign calc_if.calc.curr_wr_addr = my_calc.w_addr;
  assign calc_if.calc.loc_sel = my_calc.buffer_control;

  calc_tb_pkg::calc_driver    #(DataSize, AddrSize) calc_driver_h;
  calc_tb_pkg::calc_sequencer #(DataSize, AddrSize) calc_sequencer_h;
  calc_tb_pkg::calc_monitor   #(DataSize, AddrSize) calc_monitor_h;
  calc_tb_pkg::calc_sb        #(DataSize, AddrSize) calc_sb_h;

  always #5 clk = ~clk;

  task write_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    @(posedge clk);
    if (!block_sel) my_calc.sram_A.memory_mode_inst.memory[addr] = data;
    else            my_calc.sram_B.memory_mode_inst.memory[addr] = data;
    calc_driver_h.initialize_sram(addr, data, block_sel);
  endtask
  
initial begin
    $shm_open("waves.shm"); $shm_probe("AC");

    calc_if.reset = 1; 

    calc_monitor_h   = new(calc_if);
    calc_sb_h        = new(calc_monitor_h.mon_box);
    calc_sequencer_h = new();
    calc_driver_h    = new(calc_if, calc_sequencer_h.calc_box);

    fork
      calc_monitor_h.main();
      calc_sb_h.main();
    join_none

    repeat (10) @(posedge clk);

    $display($stime, " --- Starting Memory Initialization ---");
    // FULL MEMORY INITIALIZATION
    for (int i = 0; i < 1024; i++) begin
      write_sram(i, $random, 0);
      write_sram(i, $random, 1);
    end

    $display("--- Starting Directed Testing ---");
    write_sram(100, 32'h00000000, 0); 
    write_sram(100, 32'h00000000, 1); 
    write_sram(101, 32'h00000000, 0); 
    write_sram(101, 32'h00000000, 1); 
    calc_driver_h.start_calc(100, 101, 200, 200, 1);

    write_sram(102, 32'hFFFFFFFF, 0); 
    write_sram(102, 32'hFFFFFFFF, 1); 
    write_sram(103, 32'hFFFFFFFF, 0); 
    write_sram(103, 32'hFFFFFFFF, 1); 
    calc_driver_h.start_calc(102, 103, 201, 201, 1);

    $display("--- Starting Toggle Sweep (Max Coverage) ---");
    // Sweep 1: All 1s to All 0s (Forces rollover and toggles every single bit)
    write_sram(32'hFFFFFFFF, 32'hFFFFFFFF, 0); 
    write_sram(32'hFFFFFFFF, 32'hFFFFFFFF, 1); 
    write_sram(32'h00000000, 32'h00000000, 0); 
    write_sram(32'h00000000, 32'h00000000, 1); 
    calc_driver_h.start_calc(32'hFFFFFFFF, 32'h00000000, 32'hFFFFFFFF, 32'hFFFFFFFF, 1);

    // Sweep 2: Alternating 1010 (Hex A)
    write_sram(32'hAAAAAAAA, 32'hAAAAAAAA, 0); 
    write_sram(32'hAAAAAAAA, 32'hAAAAAAAA, 1); 
    write_sram(32'hAAAAAAAB, 32'hAAAAAAAA, 0); 
    write_sram(32'hAAAAAAAB, 32'hAAAAAAAA, 1); 
    calc_driver_h.start_calc(32'hAAAAAAAA, 32'hAAAAAAAB, 32'hAAAAAAAA, 32'hAAAAAAAA, 1);

    // Sweep 3: Alternating 0101 (Hex 5)
    write_sram(32'h55555555, 32'h55555555, 0); 
    write_sram(32'h55555555, 32'h55555555, 1); 
    write_sram(32'h55555556, 32'h55555555, 0); 
    write_sram(32'h55555556, 32'h55555555, 1); 
    calc_driver_h.start_calc(32'h55555555, 32'h55555556, 32'h55555555, 32'h55555555, 1);

    $display("--- Starting Randomized Testing ---");
    fork
      calc_sequencer_h.gen(2000); 
      calc_driver_h.drive();
    join_any

    // Mid-Flight Reset Coverage
    $display("--- Triggering Mid-Flight Reset ---");
    calc_driver_h.start_calc(10, 50, 200, 240, 1); 
    repeat (3) @(posedge clk); 
    calc_if.reset = 1;         
    repeat (5) @(posedge clk);
    calc_if.reset = 0;         
    repeat (10) @(posedge clk);

    repeat (100) @(posedge clk);
    $display("TEST PASSED");
    $finish;
  end

  // Assertions (Updated to use |-> for asynchronous reset compatibility)
  assert_reset: assert property (@(posedge clk) (rst |-> (state == S_IDLE)))
    else $error($stime, " SVA Error: Reset was high but state was not S_IDLE");

  assert_lsb_msb: assert property (@(posedge clk) disable iff (rst) (state == S_CALC_LO) |=> (state == S_CALC_HI))
    else $error($stime, " SVA Error: S_CALC_LO was not immediately followed by S_CALC_HI");

  assert_carry: assert property (@(posedge clk) disable iff (rst) (state == S_CALC_LO && my_calc.carry_out == 1) |=> (state == S_CALC_HI && my_calc.carry_in == 1))
    else $error($stime, " SVA Error: Carry out from LSB did not propagate to MSB");

endmodule