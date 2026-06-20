# AH-RISCV — a 64-bit RISC-V CPU, from gates toward Linux

A 64-bit RISC-V processor built from scratch in Verilog and run on a real FPGA,
then grown — one verified step at a time — into a system capable of running an
operating system. Every layer a kernel needs is added by hand: the pipeline, the
extensions, the interrupt and timer hardware, privilege modes, and an MMU. The
guiding goal is a **staircase to Linux**, where each rung is a self-contained,
tested milestone.

> **Target board:** Digilent Zybo Z7-10 (Xilinx Zynq-7000, `xc7z010clg400-1`)
> **Toolchain:** Verilog (Icarus + Yosys), `riscv64-unknown-elf-gcc`, Xilinx Vivado
> **ISA:** RV64IMA + Zicsr, machine / supervisor / user privilege, Sv39 paging (in progress)
> **Author:** Ali Hussein · **License:** GPL-3.0

---

## The staircase to Linux

| # | Rung | What it adds | Status |
|---|------|--------------|--------|
| — | Single-cycle core | RV64I datapath + control, on the board | ✅ done |
| — | 5-stage pipeline | Hazards, forwarding, load-use stalls | ✅ done |
| — | HDMI video | 640×480@60 text console, **confirmed on hardware** | ✅ done |
| 1 | UART + bare-metal C | Memory-mapped serial, C runtime, `printf`-style output | ✅ done |
| 2 | CSRs + traps + timer | M-mode CSRs, trap/`mret`, CLINT timer interrupts | ✅ done |
| 3 | FreeRTOS | Official RISC-V port, **two preemptive tasks** in sim | ✅ done |
| 4a | M + A extensions | Hardware multiply/divide, LR/SC + AMO atomics (RV64IMA) | ✅ done |
| 4b | Privilege + memory | Supervisor mode, unified physical RAM, **Sv39 page-table walker** | ✅ done |
| 4b+ | MMU integration | TLB + translate every fetch/load/store + page-fault traps | ⏳ next |
| 4c | xv6-riscv | Boot the xv6 teaching kernel (simulation) | 🔜 planned |
| 5 | Linux | Mainline RISC-V Linux | 🎯 goal |

---

## What works today

### The CPU — RV64IMA, 5-stage pipeline
A classic five-stage pipeline (fetch → decode → execute → memory → write-back),
fully bypassed and interlocked:

- **Synchronous instruction fetch** from on-chip BRAM with a one-entry skid
  buffer, so loads, branches, and stalls all keep the pipeline correctly fed.
- **Full forwarding** from the MEM and WB stages, a one-cycle **load-use stall**,
  and branch/jump redirect with flush.
- **M extension** — a sequential multiply/divide unit (`ah_muldiv.v`): all of
  `MUL/MULH[SU]/MULHU`, `DIV[U]`, `REM[U]` and the RV64 `*W` word forms, with the
  architectural divide-by-zero and signed-overflow corner cases.
- **A extension** — an atomics engine: `LR`/`SC` with a reservation, and all nine
  `AMO*` operations in `.w` and `.d`, driven as read-modify-write against memory.

### Privileged architecture — M / S / U
- Machine **and supervisor** mode, with a privilege register and the full CSR
  sets for both (`mstatus/mtvec/mepc/mcause/mie/mip/medeleg/mideleg/…` and
  `sstatus/stvec/sepc/scause/sie/sip/satp/…`).
- **Trap delegation:** a trap taken in S/U whose cause bit is delegated jumps
  straight to the supervisor handler (`stvec`) instead of bouncing through M-mode.
- `mret` and `sret` both restore the previous privilege from `MPP`/`SPP`.
- **Sv39 page-table walker** (`ah_ptw.v`): a hardware 3-level walk supporting
  4 KB / 2 MB / 1 GB pages, producing a physical address, the leaf permissions,
  or a page fault. Unit-tested against a real in-memory page table.

### The SoC
- **UART** (8N1, 115200) — memory-mapped TX/RX with a status register.
- **CLINT timer** — `mtime` / `mtimecmp` driving machine timer interrupts.
- **HDMI text console** — a 640×480@60 framebuffer/character generator,
  **verified on the physical board**.
- **Unified physical memory** — one dual-port RAM at `0x8000_0000` shared by
  instruction fetch and data, with MMIO carved out at `0x1000_0000`.

### Software that runs on it
- Bare-metal C (custom `crt0` + linker scripts, no libc dependency).
- A timer-interrupt demo and a memory/recursion/heap self-test.
- **FreeRTOS-Kernel v11.1.0** (official RISC-V port) scheduling two preemptive
  tasks — verified in simulation.

---

## Memory map

| Region | Base | Notes |
|--------|------|-------|
| RAM (unified, dual-port) | `0x8000_0000` | code + data + stack + heap |
| UART TXDATA | `0x1000_0000` | write a byte to transmit |
| UART STATUS | `0x1000_0008` | bit0 = TX ready, bit1 = RX valid |
| UART RXDATA | `0x1000_0010` | read received byte |
| CLINT MTIME | `0x1000_0040` | 64-bit cycle/time counter |
| CLINT MTIMECMP | `0x1000_0048` | timer-interrupt compare value |

---

## Build & run

### Simulate (Icarus Verilog)
```sh
# build a C program into the unified RAM (note: -mcmodel=medany for the 0x8000_0000 base)
tools/ah_build_uni.sh sw/memtest.c        # -> rtl/ah_mem.v

# simulate the core + SoC
iverilog -g2012 -I rtl -o build.out tests/ah_mem_tb.v rtl/soc/ah_uart.v \
    rtl/ah_core.v rtl/ah_alu.v rtl/ah_control.v rtl/ah_imm_gen.v rtl/ah_regfile.v \
    rtl/ah_signature.v rtl/ah_forward.v rtl/ah_hazard.v rtl/ah_csr.v \
    rtl/ah_muldiv.v rtl/ah_mem.v
vvp build.out
```

### On the board (Vivado)
Add every `.v` under `rtl/` (plus `rtl/ah_defines.vh`) and the SoC/video sources,
add the XDC constraints, set the SoC top as the top module, and generate the
bitstream. Serial comes out on Pmod **JE** via a 3.3 V USB-UART adapter at
115200 8N1.

---

## Repository layout

```
rtl/        CPU + SoC Verilog
  ah_core.v       pipeline, hazards, forwarding, trap/CSR glue
  ah_alu.v ah_control.v ah_imm_gen.v ah_regfile.v
  ah_muldiv.v     sequential multiply/divide (M)
  ah_csr.v        M + S CSRs, traps, delegation
  ah_ptw.v        Sv39 page-table walker
  ah_mem.v        unified dual-port physical RAM (generated)
  soc/  video/    UART, CLINT, HDMI console, clocking
sw/         C runtime, linker scripts, demos (bare-metal + FreeRTOS)
tools/      Python image/memory generators, build scripts
sim/ tests/ self-checking testbenches
```

---

## What's next

The MMU's hard logic (the page-table walker) is finished and tested. The
immediate next step is wiring it live into the pipeline:

1. a small **TLB** so a translated page is a single-cycle hit;
2. on a miss, run the walker — it borrows the data port to read PTEs while the
   pipeline stalls, like a cache miss;
3. **translate every fetch and every load/store** when `satp.MODE = Sv39`
   (`Bare` mode stays identity, so existing programs are unaffected);
4. **page-fault traps** (cause 12/13/15) carrying the faulting address in `stval`,
   with R/W/X + U-bit + SUM/MXR permission checks.

After that comes the **xv6-riscv** port (entry/boot, console driver, ramdisk, and
the M-mode→S-mode timer forwarding), then mainline **Linux**.

> **Hardware note:** a full xv6/Linux image is larger than the Zybo Z7-10's
> on-chip BRAM (~270 KB), so OS boot is demonstrated in simulation with a large
> RAM; running it on the physical board would use the Zynq PS DDR3. Everything
> through rung 4b fits and synthesizes for the board.

---

*(c) 2026 Ali Hussein. Released under GPL-3.0. Hardware signature: `AHUSSEIN`.*
