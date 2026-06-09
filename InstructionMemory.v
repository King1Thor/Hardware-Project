`timescale 1ns / 1ps
/*
 * Module: InstructionMemory
 *
 * Implements read-only instruction memory
 * 
 */
module InstructionMemory(Data, Address);
   parameter T_rd = 20;
   parameter MemSize = 40;
   
   output [31:0] Data;
   input [63:0]  Address;
   reg [31:0] 	 Data;
   
   /*
    * ECEN 350 Processor Test Functions
    * Texas A&M University
    */
   
   always @ (Address) begin
      #4;
      case(Address)

	/* Test Program 1:
	 * Program loads constants from the data memory. Uses these constants to test
	 * the following instructions: LDUR, ORR, AND, CBZ, ADD, SUB, STUR and B.
	 * 
	 * Assembly code for test:
	 * 
	 * 0: LDUR X9, [XZR, 0x0]    //Load 1 into x9
	 * 4: LDUR x11, [XZR, 0x8]   //Load a into x11
	 * 8: LDUR X11, [XZR, 0x11]  //Load 5 into x11
	 * C: LDUR X12, [XZR, 0x18]  //Load big constant into x12
	 * 10: LDUR X13, [XZR, 0x20]  //load a 0 into X13
	 * 
	 * 14: ORR x11, x11, X11  //Create mask of 0xf
	 * 18: AND X12, X12, x11  //Mask off low order bits of big constant
	 *
	 * loop:
	 * 1C: CBZ X12, end  //while X12 is not 0
	 * 20: ADD X13, X13, X9  //Increment counter in X13
	 * 24: SUB X12, X12, X9  //Decrement remainder of big constant in X12
	 * 28: B loop  //Repeat till X12 is 0
	 * 2C: STUR X13, [XZR, 0x20]  //store back the counter value into the memory location 0x20
	 */
	

	63'h000: Data = 32'hF84003E9;
	63'h004: Data = 32'hF84083EA;
	63'h008: Data = 32'hF84103EB;
	63'h00c: Data = 32'hF84183EC;
	63'h010: Data = 32'hF84203ED;
	63'h014: Data = 32'hAA0B014A;
	63'h018: Data = 32'h8A0A018C;
	63'h01c: Data = 32'hB400008C;
	63'h020: Data = 32'h8B0901AD;
	63'h024: Data = 32'hCB09018C;
	63'h028: Data = 32'h17FFFFFD;
	63'h02c: Data = 32'hF80203ED;
	63'h030: Data = 32'hF84203ED;  //One last load to place stored value on memdbus for test checking.

	/* Add code for your tests here */

	63'h034: Data = 32'b10010001000000000000001111101001; // 34: ADDI X9, XZR, 0x0  // load a 0 into X9

	63'h038: Data = 32'b11010010111000100100011010001011; // 38: MOVZ x11, 0x1234, LSL 48 // (x11 = 0x1234 * 2^48)
	63'h03c: Data = 32'b10001011000010010000000101101001; // 3c: ADD X9, x11, X9 // add result of MOVZ in x11 to x9

	63'h040: Data = 32'b11010010110010101100111100001011; // 40: MOVZ x11, 0x5678, LSL 32 // (x11 = 0x5678 * 2^32)
	63'h044: Data = 32'b10001011000010010000000101101001; // 44: ADD X9, x11, X9 // add result of MOVZ in x11 to x9

	63'h048: Data = 32'b11010010101100110101011110001011; // 48: MOVZ x11, 0x9abc, LSL 16 // (x11 = 0x9abc * 2^16)
	63'h04c: Data = 32'b10001011000010010000000101101001; // 4c: ADD X9, x11, X9 // add result of MOVZ in x11 to x9

	63'h050: Data = 32'b11010010100110111101111000001011; // 50: MOVZ x11, 0xdef0, LSL 0 // (x11 = 0xdef0 * 2^0)
	63'h054: Data = 32'b10001011000010010000000101101001; // 54: ADD X9, x11, X9 // add result of MOVZ in x11 to x9
			
	63'h058: Data = 32'b11111000000000011100001111101001; // 58: STUR X9, [XZR, 0x28] // store constant in memory
	63'h05c: Data = 32'b11111000010000011100001111101010; // 5c: LDUR X10, [XZR, 0x28] // Load constant into x10
	default: Data = 32'hXXXXXXXX;
      endcase
   end
endmodule
