class calc_monitor #(int DataSize, int AddrSize);
  logic written = 0;
  logic pending_read;
  logic [AddrSize-1:0] pending_rd_addr;
  calc_seq_item #(DataSize, AddrSize) initialization_trans;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) mon_box;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif);
    this.calcVif = calcVif;
    this.mon_box = new();
  endfunction

  task main();
    logic prev_reset = 0; // FIX 1: Track reset edge
    
    forever begin
      @(calcVif.cb);

      // FIX 1: Only send reset transaction ONCE when it goes high, stop the spam!
      if (calcVif.reset && !prev_reset) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        written = 0;
        pending_read = 0;
        trans.reset = 1'b1;
        mon_box.put(trans);
      end
      prev_reset = calcVif.reset;

      if (calcVif.cb.rd_en && calcVif.cb.wr_en) begin
        $error($stime, " Mon: Error rd_en and wr_en both asserted at the same time\n");
      end
 
      if (pending_read) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        trans.rdn_wr = 0; // Read
        trans.curr_rd_addr = pending_rd_addr;
        trans.lower_data = calcVif.cb.rd_data_lower; 
        trans.upper_data = calcVif.cb.rd_data_upper;

        $display($stime, " Mon: Read from Addr: 0x%0x, Data A: 0x%0x, Data B: 0x%0x",
          trans.curr_rd_addr, trans.lower_data, trans.upper_data);
        mon_box.put(trans);
        pending_read = 0;
      end

      if (calcVif.cb.wr_en || calcVif.cb.rd_en) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        trans.rdn_wr = calcVif.cb.wr_en; 
        trans.curr_wr_addr = calcVif.cb.curr_wr_addr;
        trans.curr_rd_addr = calcVif.cb.curr_rd_addr;

        if (trans.rdn_wr) begin // Write
          trans.lower_data = calcVif.cb.wr_data_lower;
          trans.upper_data = calcVif.cb.wr_data_upper;
          
          if (!written) begin
            written = 1;
            $display($stime, " Mon: Write to Addr: 0x%0x, Data A: 0x%0x, Data B: 0x%0x",
                trans.curr_wr_addr, trans.lower_data, trans.upper_data);
            mon_box.put(trans);
          end
        end else begin // Read
          written = 0;
          pending_read = 1;
          pending_rd_addr = trans.curr_rd_addr;
        end
      end

      // FIX 2: Check RAW interface signals, bypassing the clocking block
      if (calcVif.initialize) begin
        initialization_trans = new();
        initialization_trans.initialize = 1;
        initialization_trans.loc_sel = calcVif.initialize_loc_sel;
        initialization_trans.curr_wr_addr = calcVif.initialize_addr;

        if (initialization_trans.loc_sel == 0) begin
            initialization_trans.lower_data = calcVif.initialize_data;
        end else begin
            initialization_trans.upper_data = calcVif.initialize_data;
        end

        $display($stime, " Mon: Initialize SRAM; Write to SRAM %s, Addr: 0x%0x, Data: 0x%0x", 
                 !calcVif.initialize_loc_sel ? "A" : "B", calcVif.initialize_addr, calcVif.initialize_data);
        mon_box.put(initialization_trans);
      end
    end
  endtask : main

endclass : calc_monitor