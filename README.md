# AH-RISCV - CPU

A **64-bit RISC-V CPU (RV64IMA)** designed from scratch in Verilog by
**Ali Hussein**, with a board wrapper and pin constraints for the Digilent
**Zybo Z7-10** (Zynq-7000) FPGA.

This package is the processor itself — the 5-stage pipeline and all of its
components — plus the FPGA integration. It does **not** include the larger SoC
(UART, timer, HDMI video, MMU); it is the CPU as a clean, self-contained core.

The design carries a hardware authorship signature (`ah_signature.v`) that reads
back `0x41485553_5345494E` ("AHUSSEIN") and survives into the synthesized
bitstream.

---

## What it implements

A synthesizable **RV64IMA + Zicsr** processor:

| Component | File | What it does |
|-----------|------|--------------|
| **Pipeline core** | `rtl/ah_core.v` | 5-stage (IF/ID/EX/MEM/WB) pipeline, top of the CPU |
| ALU | `rtl/ah_alu.v` | 64-bit arithmetic/logic, including the `*W` word ops |
| Decoder / control | `rtl/ah_control.v` | instruction decode and control signals |
| Register file | `rtl/ah_regfile.v` | 32 × 64-bit registers, `x0` hardwired to 0 |
| Immediate generator | `rtl/ah_imm_gen.v` | I/S/B/U/J immediate forms |
| Multiply / divide | `rtl/ah_muldiv.v` | sequential `MUL*`, `DIV*`, `REM*` (M extension) |
| Forwarding | `rtl/ah_forward.v` | EX/MEM/WB bypass network |
| Hazard unit | `rtl/ah_hazard.v` | load-use and control hazard stalls/flushes |
| CSR / traps | `rtl/ah_csr.v` | machine-mode CSRs, `ecall`/`ebreak`, exceptions |
| Instruction memory | `rtl/ah_imem.v` | registered instruction ROM (holds the demo program) |
| Data memory | `rtl/ah_dmem.v` | byte/half/word/double loads & stores |
| Signature | `rtl/ah_signature.v` | hardware authorship register |

Implemented instruction set: full **RV64I** (integer ALU + immediates, all
load/store widths, branches, `JAL`/`JALR`, `LUI`/`AUIPC`, the `*W` word ops), the
**M** extension (multiply/divide), and the **A** extension (`LR`/`SC` + the `AMO*`
family), with **Zicsr** and machine-mode trap handling.

---

## Pipeline at a glance

```
   IF  ──►  ID  ──►  EX  ──►  MEM  ──►  WB
   PC      decode    ALU      load/      reg
   imem    regfile   mul/div  store      write-back
            imm-gen   AMO/LR-SC
              ▲          ▲
   ah_hazard ─┘  ah_forward (bypass)     ah_csr (traps)
```

Hazards are resolved by forwarding where possible and by a one-cycle stall for the
load-use case; taken branches and jumps flush the wrongly-fetched instruction.

---

## Simulate (Icarus Verilog)

Whole-CPU self-check — runs the program in `rtl/ah_imem.v` and verifies the result:

```bash
iverilog -g2012 -I rtl -o run sim/ah_core_tb.v rtl/*.v
vvp run
```

Expected:

```
ah_core: halted at pc=0x20 after 37 cycles; x4=13, x6=15
hardware signature = 0x414855535345494e ("AHUSSEIN")
AH-RISCV CORE: ALL TESTS PASSED
```

Multiply/divide unit self-check:

```bash
iverilog -g2012 -I rtl -o mt sim/ah_muldiv_tb.v rtl/ah_muldiv.v
vvp mt          # MULDIV: ALL TESTS PASSED
```

---

## On the FPGA (Vivado, Zybo Z7-10)

The board wrapper `fpga/ah_top.v` runs the core on the board and maps it to the
LEDs / switches / buttons, with a slow clock and a single-step mode so you can
watch it execute.

```
Controls
  sw[0] : run mode   0 = auto-run (slow clock)   1 = single-step (BTN0)
  sw[1] : speed      0 = ~2 Hz                    1 = ~12 Hz
  sw[2] : LED show   0 = PC index                 1 = a register (low nibble)
  sw[3] : register   0 = x6 (sum = 15)            1 = x4 (value = 13)
  btn[3]: reset      btn[0]: single-step
Outputs
  led[3:0] : selected value   led6_g : heartbeat   led6_b : halted
```

To build: create a Vivado project for `xc7z010clg400-1`, add `rtl/*.v` and
`fpga/*.v`, set the top module to `ah_top`, add the constraints file
`fpga/ah_zybo.xdc`, then generate the bitstream and program the board.

---

## Changing the program

The demo program lives in `rtl/ah_imem.v` as a small ROM (one 32-bit word per
instruction). The source is `sw/demo.S`. To change it, edit the assembly and
re-encode, e.g. with the included encoder `tools/ah_asm.py`, or assemble with a
`riscv64-unknown-elf` toolchain and copy the resulting words into `rom[...]`.
`sw/m_demo.c` and `sw/a_demo.c` are small C exercises for the M and A extensions.

---

## Files

```
rtl/    the CPU: pipeline core + ALU, regfile, decoder, imm-gen, mul/div,
        forwarding, hazard unit, CSRs, instruction/data memory, signature
fpga/   board wrapper (ah_top), slow/single-step clock, button debounce,
        and the Zybo Z7-10 pin constraints (ah_zybo.xdc)
sim/    self-checking testbenches (whole-CPU and mul/div)
sw/     demo program (demo.S) + small C exercises + crt0/linker
tools/  ah_asm.py — a tiny RV64I instruction encoder
```

## License

GPL-3.0 - see project LICENSE. Reuse is welcome but **must** keep attribution and
stay open-source. The hardware signature in `ah_signature.v` is part of the design.

## Author

**Ali Hussein** - 2026 · [github.com/King1Thor/Hardware-Project](https://github.com/King1Thor/Hardware-Project/)
