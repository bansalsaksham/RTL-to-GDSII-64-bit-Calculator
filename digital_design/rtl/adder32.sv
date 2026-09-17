/*
* Module describing a 32-bit ripple carry adder, with no carry output or input.
*
* You can and should modify this file but do NOT change the interface.
*/
module adder32 import calculator_pkg::*; (
    // DO NOT MODIFY THE PORTs
    input logic [DATA_W - 1 : 0]    a_i, // First operand
    input logic [DATA_W - 1 : 0]    b_i, // Second operand
    input logic                     c_i, // Carry input
    output logic                    c_o, // Carry output
    output logic [DATA_W - 1 : 0]   sum_o // Sum output
);
    // You can modify anything below this line. You are required to use
    // full_adder.sv to build this module.
    
    //TODO: Declare any internal signals you need here.
    // Hint: You need an intermediary signal to handle the carry bits between adders.
    // Internal carry wire to chain the bits together
    // carry[0] is the input carry, carry[32] is the final output carry
    logic [DATA_W : 0] carry;
    // Assign the initial carry input to the start of our chain
    assign carry[0] = c_i;

    // TODO: use a generate block to chain together 32 full adders. 
    // generate block for building the large adder out of smaller, full adders
    generate
        genvar i;
        for (i = 0; i < DATA_W; i = i + 1) begin : gen_adder
            full_adder fa_inst (
                .a(a_i[i]),      // Changed from .a_i
                .b(b_i[i]),      // Changed from .b_i
                .cin(carry[i]),  // Changed from .c_i
                .s(sum_o[i]),    // Changed from .sum_o
                .cout(carry[i+1]) // Changed from .c_o
            );
        end
        // Hint: Think about looping w/ a module declaration
    endgenerate

    // Assign the final carry in the chain to the output port
    assign c_o = carry[DATA_W];

endmodule