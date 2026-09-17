/*
 * This package defines common parameters used across various modules in the design to ensure consistency and ease of maintenance. 
 * It includes parameters for data width, memory word size, and address width (defined by size of SRAM).
 *
 * You can and should modify this file to add additional states as needed.
 */
`define functional
package calculator_pkg;
    //parameter for size of data (adder size)
    parameter DATA_W = 32;

    //parameter for size of memory word
    parameter MEM_WORD_SIZE = 64;

    parameter ADDR_W = 10   ;

    // TODO: Declare additional state(s) as needed
    // DO NOT REMOVE S_IDLE AND S_END STATES
    // typedef enum logic [3:0] {S_IDLE, S_READ, S_END} state_t;
    // typedef enum logic {LOWER, UPPER} buffer_loc_t;
    typedef enum logic [3:0] {
        S_IDLE,      // Wait for start/reset release
        S_READ_LO,   // Read lower 32 bits of operands
        S_CALC_LO,   // Add lower bits, store in result_buffer[31:0]
        S_READ_HI,   // Read upper 32 bits of operands
        S_CALC_HI,   // Add upper bits + carry, store in result_buffer[63:32]
        S_WRITE,     // Write the full 64-bit result to SRAM
        S_INCREMENT, // Update addresses and check if we are at 128 writes
        S_END        // Done with all operations
    } state_t;

    typedef enum logic {LOWER, UPPER} buffer_loc_t;

endpackage