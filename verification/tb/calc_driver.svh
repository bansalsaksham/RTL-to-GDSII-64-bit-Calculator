class calc_driver #(int DataSize, int AddrSize);

  mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box;
  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif,
      mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box);
    this.calcVif = calcVif;
    this.drv_box = drv_box;
  endfunction

  task reset_task();
    // Drive reset ACTIVE (High) 
    calcVif.cb.reset <= 1; 
    repeat(10) @(calcVif.cb); 
    
    // De-assert reset (Low)
    calcVif.cb.reset <= 0; 
    repeat(2) @(calcVif.cb);
  endtask

  virtual task initialize_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    // FIX 2: Drive raw interface signals to bypass clocking block hiding
    calcVif.initialize <= 1;
    calcVif.initialize_loc_sel <= block_sel;
    calcVif.initialize_addr <= addr;
    calcVif.initialize_data <= data;
    
    $display($stime, " [DRIVER] Init SRAM block %0d at Addr 0x%h with Data 0x%h", block_sel, addr, data);
    
    @(calcVif.cb); // Wait one clock cycle
    calcVif.initialize <= 0;
  endtask : initialize_sram

  virtual task start_calc(input logic [AddrSize-1:0] read_start_addr, input logic [AddrSize-1:0] read_end_addr,
      input logic [AddrSize-1:0] write_start_addr, input logic [AddrSize-1:0] write_end_addr,
      input bit direct = 1);
    
    int delay;
    calc_seq_item #(DataSize, AddrSize) trans;

    calcVif.cb.read_start_addr <= read_start_addr;
    calcVif.cb.read_end_addr <= read_end_addr;
    calcVif.cb.write_start_addr <= write_start_addr;
    calcVif.cb.write_end_addr <= write_end_addr;

    $display($stime, " [DRIVER] Starting Calc: Read 0x%h to 0x%h | Write 0x%h to 0x%h", 
             read_start_addr, read_end_addr, write_start_addr, write_end_addr);
    
    // Trigger design out of IDLE
    reset_task();
    
    // Wait for the calculation to finish
    @(calcVif.cb iff (calcVif.cb.ready === 1'b1));

    if (!direct) begin 
      if (drv_box.try_peek(trans)) begin
        delay = $urandom_range(0, 5); 
        repeat (delay) @(calcVif.cb);
      end
    end
  endtask : start_calc

  virtual task drive();
    calc_seq_item #(DataSize, AddrSize) trans;
    reset_task(); 
    
    while (drv_box.try_get(trans)) begin
      start_calc(trans.read_start_addr, trans.read_end_addr, 
                 trans.write_start_addr, trans.write_end_addr, 0);
    end
  endtask : drive

endclass : calc_driver