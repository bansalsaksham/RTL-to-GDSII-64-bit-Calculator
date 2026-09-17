
/*
* Module describing a single-bit full adder. 
* The full adder can be chained to create multi-bit adders. 
*
* This module can be modified but the interface must remain the same.
*/
module full_adder (
    // DO NOT CHANGE THESE PORTS
    input logic a,
    input logic b,
    input logic cin,
    output logic s,
    output logic cout
);

    // Sum logic: A XOR B XOR Cin
    assign s = a ^ b ^ cin;

    // Carry-out logic: AB + BCin + ACin
    assign cout = (a & b) | (b & cin) | (a & cin);
    
endmodule
