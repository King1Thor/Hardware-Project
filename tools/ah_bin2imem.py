#!/usr/bin/env python3
# Convert a flat RV binary into a Verilog instruction ROM (ah_imem).
# (c) 2026 Ali Hussein, GPL-3.0.   usage: ah_bin2imem.py prog.bin out.v
import sys, struct
data = open(sys.argv[1],'rb').read()
if len(data)%4: data += b'\x00'*(4-len(data)%4)
words = [struct.unpack('<I', data[i:i+4])[0] for i in range(0,len(data),4)]
DEPTH = 1024
HDR = ('// ============================================================================\n'
 '//  AH-RISCV : instruction ROM generated from compiled C. (c) 2026 Ali Hussein.\n'
 '//  GPL-3.0.  Hardware signature: "AHUSSEIN".  Built by tools/ah_bin2imem.py.\n'
 '// ============================================================================\n')
out=[HDR,'module ah_imem (',
     '    input  [63:0] addr,',
     '    output [31:0] instr',
     ');',
     f'    reg [31:0] rom [0:{DEPTH-1}];',
     '    integer i;',
     '    initial begin',
     f'        for (i=0;i<{DEPTH};i=i+1) rom[i]=32\'h00000013;   // NOP',]
for i,w in enumerate(words):
    out.append(f"        rom[{i}]=32'h{w:08x};")
out += ['    end',
        f'    assign instr = rom[addr[{ (DEPTH-1).bit_length()+1 }:2]];',
        'endmodule','']
open(sys.argv[2],'w').write("\n".join(out))
print(f"{len(words)} instructions -> {sys.argv[2]}  (index bits addr[{(DEPTH-1).bit_length()+1}:2])")
