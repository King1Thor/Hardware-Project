#!/usr/bin/env python3
# Generate ah_imem.v: a synchronous instruction BRAM (64 KB = 16384 words).
# (c) 2026 Ali Hussein, GPL-3.0.  usage: ah_mkimem.py out.v prog.bin
import sys, struct
WORDS=16384
data=open(sys.argv[2],'rb').read()
if len(data)%4: data+=b'\x00'*(4-len(data)%4)
words=[struct.unpack('<I',data[i:i+4])[0] for i in range(0,len(data),4)]
H='''// =============================================================================
//  AH-RISCV : synchronous instruction memory (64 KB BRAM). (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".  Generated.
//  Registered read: the instruction for `addr` appears on `instr` next cycle.
// ============================================================================='''
L=[H,'module ah_imem (',
   '    input         clk,',
   '    input  [63:0] addr,',
   '    output reg [31:0] instr',
   ');',
   f'    reg [31:0] rom [0:{WORDS-1}];',
   '    integer i;',
   '    initial begin',
   f'        for (i=0;i<{WORDS};i=i+1) rom[i]=32\'h00000013;  // NOP fill']
for i,w in enumerate(words):
    if w!=0x00000013: L.append(f"        rom[{i}]=32'h{w:08x};")
L+=['    end',
    '    always @(posedge clk) instr <= rom[addr[15:2]];',
    'endmodule','']
open(sys.argv[1],'w').write("\n".join(L))
print(f"{sys.argv[1]}: {WORDS} words, {len(words)} program words loaded")
