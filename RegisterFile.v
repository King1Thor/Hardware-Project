module RegisterFile(BusA, BusB, BusW, RA, RB, RW, RegWr, Clk);
    // Buses A, B, and W are 64 bits wide
    output [63:0] BusA; // // The contents of register RA
    output [63:0] BusB; // The contents of register RB
    input [63:0] BusW; // What is written to register RW
    input [4:0] RA, RB, RW; // Specify which registers to use
    input RegWr;
    input Clk;
    reg [63:0] registers [31:0]; // 32, 64-bit registers
    
    initial registers[31] = 64'b0; // initialize register 31 to 0
    
    assign #2 BusA = registers[RA]; // BusA reads register RA
    assign #2 BusB = registers[RB]; // BusB reads register RB

    always @ (negedge Clk) begin // check every negative clock edge
        if(RegWr && RW != 31) // ensure that register 31 is not overwritten
            registers[RW] <= #3 BusW; // data on Bus W is stored in the register specified by Rw
    end
endmodule
