module SignExtender(BusImm, Instr, Ctrl); 
    output [63:0] BusImm; 
    input [25:0] Instr; 
    input [2:0] Ctrl; 

    reg [63:0] result;

    always @ (*)
    begin
        // assign output, BusImm
        case(Ctrl)
            3'b000: // I-type, 12-bit immediate
            begin
                result = {52'b0, Instr[21:10]};
            end
            3'b001: // D-type, 9-bit address offset
            begin
                result = {{55{Instr[20]}}, Instr[20:12]};
            end
            3'b010: // B-type, 26-bit branch address
            begin
                result = {{36{Instr[25]}}, Instr[25:0], 2'b0};
            end
            3'b011: // CB-type, 19-bit branch address
            begin
                result = {{43{Instr[23]}}, Instr[23:5], 2'b0};
            end
            3'b100: // IM-type, 16-bit immediate
            begin
                case(Instr[22:21])
                    2'b00: // shift 2^0
                        result = {48'b0, Instr[20:5]};
                    2'b01: // shift 2^16
                        result = {32'b0, Instr[20:5], 16'b0};
                    2'b10: // shift 2^32
                        result = {16'b0, Instr[20:5], 32'b0};
                    2'b11: // shift 2^48
                        result = {Instr[20:5], 48'b0};
                endcase
            end
        endcase
    end
    assign BusImm = result;
endmodule
