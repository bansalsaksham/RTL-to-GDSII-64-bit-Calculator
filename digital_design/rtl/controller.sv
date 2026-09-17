/* * Controller module for DD onboarding.
 */
module controller import calculator_pkg::*;(
    input  logic              clk_i,
    input  logic              rst_i,
  
    // Memory Access
    input  logic [ADDR_W-1:0] read_start_addr,
    input  logic [ADDR_W-1:0] read_end_addr,
    input  logic [ADDR_W-1:0] write_start_addr,
    input  logic [ADDR_W-1:0] write_end_addr,
  
    // Memory Controls
    output logic                         write,
    output logic                         read,
    output logic [ADDR_W-1:0]            w_addr,
    output logic [MEM_WORD_SIZE-1:0]     w_data,
    output logic [ADDR_W-1:0]            r_addr,
    input  logic [MEM_WORD_SIZE-1:0]     r_data,

    // Buffer Control (1 = upper, 0 = lower)
    output logic buffer_control,
  
    // These go into adder
    output logic [DATA_W-1:0] op_a,
    output logic [DATA_W-1:0] op_b,

    // Carry input for adder
    output logic carry_in,    // Carry input to adder
    input  logic carry_out,   // Carry output from adder
    
    // What is being stored in the buffer
    input  logic [MEM_WORD_SIZE-1:0] buff_result
); 

    // ------------------------------------------------------------------
    // RESTORED: Cycle Counter (Required by Testbench)
    // ------------------------------------------------------------------
    logic [31:0] cycle_count;
    always_ff @(posedge clk_i) begin
        if (rst_i)
            cycle_count <= 32'd0;
        else
            cycle_count <= cycle_count + 1'b1;
    end

    // ------------------------------------------------------------------
    // FSM Logic
    // ------------------------------------------------------------------
    
    logic [MEM_WORD_SIZE-1:0] op_a_reg;

    state_t state, next;
    logic [ADDR_W-1:0] r_ptr, w_ptr;
    logic carry_reg; 
    logic [7:0] write_count; 

    // State Transition
    always_ff @(posedge clk_i) begin
        if (rst_i) state <= S_IDLE;
        else       state <= next;
    end

    // Next State Logic
    always_comb begin
        next = state;
        case (state)
            S_IDLE:      next = S_READ_LO; 
            S_READ_LO:   next = S_READ_HI; 
            S_READ_HI:   next = S_CALC_LO;
            S_CALC_LO:   next = S_CALC_HI;
            S_CALC_HI:   next = S_WRITE;
            S_WRITE:     next = S_INCREMENT;
            S_INCREMENT: next = (write_count == 8'd127) ? S_END : S_READ_LO;
            S_END:       next = S_END;
            default:     next = S_IDLE;
        endcase
    end

    // Sequential Logic (Datapath Control)
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            r_ptr <= read_start_addr;
            w_ptr <= write_start_addr;
            write_count <= 8'd0;
            carry_reg <= 1'b0;
            op_a_reg <= '0;
        end else begin
            case (state)
                S_READ_HI: begin 
                    op_a_reg <= r_data; 
                end
                S_CALC_LO: begin
                    carry_reg <= carry_out; 
                end
                S_INCREMENT: begin
                    r_ptr <= r_ptr + 2; 
                    w_ptr <= w_ptr + 1;
                    write_count <= write_count + 1'b1;
                end
            endcase
        end
    end

    // Combinational Output Logic
    always_comb begin
        read = 1'b0;
        write = 1'b0; 
        w_addr = w_ptr;
        w_data = buff_result;
        r_addr = r_ptr;
        buffer_control = 0;
        op_a = '0;
        op_b = '0;
        carry_in = 0;

        case (state)
            S_READ_LO: begin 
                read = 1'b1;
                r_addr = r_ptr; 
            end
            S_READ_HI: begin 
                read = 1'b1;
                r_addr = r_ptr + 1; 
            end
            S_CALC_LO: begin
                r_addr = r_ptr + 1;    // <--- ADD THIS LINE
                op_a = op_a_reg[31:0];
                op_b = r_data[31:0];   
                buffer_control = 0;    
                carry_in = 0;
            end
            S_CALC_HI: begin
                op_a = op_a_reg[63:32];
                op_b = r_data[63:32];
                buffer_control = 1;    
                carry_in = carry_reg;  
            end
            S_WRITE: begin
                write = 1'b1; 
            end
        endcase
    end
endmodule