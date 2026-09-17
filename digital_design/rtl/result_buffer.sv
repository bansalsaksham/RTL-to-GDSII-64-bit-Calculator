/*
* Module describing a 64-bit result buffer and the mux for controlling where
* in the buffer an adder's result is placed.
* 
* synchronous active high reset on posedge clk
* This module can and should be modified but the interface should not be changed.
*/
module result_buffer import calculator_pkg::*; (
    // DO NOT CHANGE ANY OF THESE PORTS
    input logic     clk_i,                          //clock signal
    input logic     rst_i,                          //reset signal
    input logic     [DATA_W-1 : 0] result_i,        //result from ALU
    input logic     loc_sel,                        //mux control signal
    output logic    [MEM_WORD_SIZE-1 : 0] buffer_o //64-bit output of buffer
);
    // You can make any modifications inside the module
    logic [MEM_WORD_SIZE-1 : 0] internal_buffer;
    assign buffer_o = internal_buffer;

    always_ff @(posedge clk_i) begin
        //TODO: implement synchronous reset
        //TODO: implement buffer write logic based on loc_sel
        if (rst_i) begin
            // Synchronous active high reset
            internal_buffer <= '0;
        end else begin
            // loc_sel uses the buffer_loc_t enum (LOWER=0, UPPER=1)
            if (loc_sel == LOWER) begin
                internal_buffer[31:0]  <= result_i;
                // We don't touch [63:32] so it stays the same
            end else begin
                internal_buffer[63:32] <= result_i;
                // We don't touch [31:0] so it stays the same
            end
        end

    end
endmodule