class calc_sb #(int DataSize, int AddrSize);

  int mem_a [2**AddrSize];
  int mem_b [2**AddrSize];
  
  bit [DataSize:0] golden_lower_data;
  bit [DataSize:0] golden_upper_data;
  bit carry_lower;
  bit second_read;

  mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box;

  function new(mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box);
    this.sb_box = sb_box;
    golden_lower_data = 0;
    golden_upper_data = 0;
    carry_lower = 0;
    second_read = 0;
  endfunction

  task main();
    calc_seq_item #(DataSize, AddrSize) trans;
    forever begin
      sb_box.get(trans);
      // Implement the scoreboard's core functionality.
      // The scoreboard's task is to verify the DUT's behavior by comparing the
      // data received from the monitor against a golden reference model.
      // Use `$display` to log successful transactions and `$error` to report mismatches.
      // If a mismatch occurs, use `$finish` to terminate the simulation.
      //-----------
      // RESET
      //-----------
      if (trans.reset) begin
        // On reset transaction, clear scoreboard state
        golden_lower_data = 0;
        golden_upper_data = 0;
        carry_lower = 0;
        second_read = 0;
      //------------
      // INITIALIZE
      //------------
      // TODO: For initialization, update the scoreboard's local memory (`mem_a` and `mem_b`) to match the DUT's initial SRAM state.
      end else if (trans.initialize) begin
        // Update local scoreboard memory based on location select
        if (trans.loc_sel == 0) begin
          mem_a[trans.curr_wr_addr] = trans.lower_data;
        end else begin
          mem_b[trans.curr_wr_addr] = trans.upper_data;
        end
        $display($stime, " SB: Initialized memory %s at address 0x%0x", (trans.loc_sel == 0) ? "A" : "B", trans.curr_wr_addr);
      
      //------------
      // WRITE
      //------------
      //TODO: For write operations, compare the DUT's output to the data calculated by the golden model in the scoreboard.
      end else if (trans.rdn_wr) begin
        // Compare lower 32 bits
        if (trans.lower_data !== golden_lower_data[DataSize-1:0]) begin
          $error($stime, " SB Error: Lower data mismatch! Expected: 0x%0x, Got: 0x%0x at address 0x%0x", golden_lower_data[DataSize-1:0], trans.lower_data, trans.curr_wr_addr);
          $finish;
        end
        
        // Compare upper 32 bits
        if (trans.upper_data !== golden_upper_data[DataSize-1:0]) begin
          $error($stime, " SB Error: Upper data mismatch! Expected: 0x%0x, Got: 0x%0x at address 0x%0x", golden_upper_data[DataSize-1:0], trans.upper_data, trans.curr_wr_addr);
          $finish;
        end

        // If it matches perfectly, update the local memory with the new sum
        mem_a[trans.curr_wr_addr] = trans.lower_data;
        mem_b[trans.curr_wr_addr] = trans.upper_data;
        $display($stime, " SB: Write matched! Addr: 0x%0x, Lower: 0x%0x, Upper: 0x%0x", trans.curr_wr_addr, trans.lower_data, trans.upper_data);
      
      //------------
      // READ
      //------------
      //TODO: For read operations, compare the data from the SRAM in the DUT to the data stored in the scoreboard's memory.
      //       Think about how to account for the two sequential reads in the DUT for the single write operation. The values
      //       from both read operations need to be used to compare against the calculated values in the DUT when they are written
      //       to SRAM. The second_read, carry_lower, golden_lower_data, and golden_upper_data signals can be used for this purpose.
      end else begin
        // 1. Verify that the read data matches the scoreboard's internal memory state
        if (trans.lower_data !== mem_a[trans.curr_rd_addr]) begin
           $error($stime, " SB Error: SRAM A Read mismatch! Expected: 0x%0x, Got: 0x%0x at addr 0x%0x", mem_a[trans.curr_rd_addr], trans.lower_data, trans.curr_rd_addr);
           $finish;
        end
        if (trans.upper_data !== mem_b[trans.curr_rd_addr]) begin
           $error($stime, " SB Error: SRAM B Read mismatch! Expected: 0x%0x, Got: 0x%0x at addr 0x%0x", mem_b[trans.curr_rd_addr], trans.upper_data, trans.curr_rd_addr);
           $finish;
        end

        // 2. Calculate the Golden Model logic across the two read cycles
        if (!second_read) begin
          // First read cycle: store Operand 1
          golden_lower_data = trans.lower_data;
          golden_upper_data = trans.upper_data;
          second_read = 1;
        end else begin
          // Second read cycle: perform addition (Operand 1 + Operand 2)
          golden_lower_data = golden_lower_data + trans.lower_data;
          
          // Extract the carry out (bit 32) from the lower addition
          carry_lower = golden_lower_data[DataSize]; 
          
          // Add the upper operands + the carry from the lower calculation
          golden_upper_data = golden_upper_data + trans.upper_data + carry_lower;
          
          // Reset the cycle tracker for the next calculation
          second_read = 0; 
        end
        
        $display($stime, " SB: Read verified against memory model at address 0x%0x", trans.curr_rd_addr);
      
      end
    end
  endtask

endclass : calc_sb
