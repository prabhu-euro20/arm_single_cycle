# ARM Single Cycle CPU Core

A Makerchip / TL-Verilog implementation of a single-cycle ARM (LEGv8) processor core, supporting 9 instructions: `ADD SUB ADDI SUBI LDUR STUR B CBZ CBNZ`.

## What's new in v2.0

- **Editable instruction memory.** The program is no longer hand-encoded hex. Nine assembler-style functions (`ADD`, `SUB`, `ADDI`, `SUBI`, `LDUR`, `STUR`, `CBZ`, `CBNZ`, `B`) compute the correct 32-bit LEGv8 encoding at compile time from plain register numbers and immediates. Add, remove, or edit instructions freely — the datapath and control logic never change regardless of what program is loaded.

- **Full graphical VIZ**, The single-cycle datapath in *Computer Organization and Design, ARM Edition* (Patterson & Hennessy): a live code editor, CPU execution log, register file, and a schematic datapath diagram (PC, Instruction Memory, Registers, Sign-extend, ALU, Data Memory, muxes, branch adder, and the AND/OR gates that compute `PCSrc`) with the active signal path highlighted per instruction.

- **A real disassembler**, not a hardcoded instruction list — the VIZ decodes whatever is actually in ROM directly from the instruction bits, so the code listing, execution log, and status bar automatically reflect any program you write.

- **X31 (XZR) verified**: reads always return 0, writes are always suppressed.

## Files

- `arm_single_cycle.tlv` — The TL-Verilog source: CPU datapath/control logic, the instruction encoder + program, and the VIZ.
- `run_test.sh` — Self-contained script that transpiles the design (via SandPiper) and simulates it locally with Icarus Verilog.

## Usage

Run the test script from the repository root:

```bash
pip3 install --user --break-system-packages sandpiper-saas   # TL-Verilog → SystemVerilog transpiler
conda install -y -n base -c conda-forge iverilog              # Verilog simulator

cd ~/arm_single_cycle
./run_test.sh

NOTE: keep repeat(N) in run_test.sh comfortably larger than the cyc_cnt threshold in *passed (e.g. threshold 30 needs repeat(35+))
```

To try a different program, edit the `ROM[...]` assignments inside the `initial begin ... end` block near the top of `arm_single_cycle.tlv` — e.g. `ADDI(1, 0, 10);   // ADDI X1, X0, #10   -> X1 = 10` — and adjust `ROM_SIZE` if you add or remove lines.

## Terminal Output

```bash
prabhu@workstation:~/arm_single_cycle$ ./run_test.sh
==> Transpiling TL-Verilog -> SystemVerilog (SandPiper cloud service)
INFORM(0) (PROD_INFO):
	SandPiper(TM) 1.14-2022/10/10-beta-Pro from Redwood EDA, LLC
	(DEV) Run as: "java -jar sandpiper.jar -p m4out --outdir=out --nopath -i ./_novz.m4out.tlv -o arm_single_cycle.sv
	For help, including product info, run with -h.

INFORM(0) (LICENSE):
	Licensed to "Redwood EDA, LLC" as: Full Edition.

INFORM(0) (FILES):
	Reading "./_novz.m4out.tlv"
	to produce:
		Translated HDL File: "out/arm_single_cycle.sv"
		Generated HDL File: "out/arm_single_cycle_gen.sv"

WARNING(1) (UNUSED-SIG): Signal |cpu$is_cb_type is assigned but never used.
WARNING(1) (UNUSED-SIG): Signal |cpu$mem_read is assigned but never used.
WARNING(1) (UNUSED-SIG): Signal |cpu$rom_size is assigned but never used.
WARNING(1) (UNUSED-SIG): Signal |cpu/rom$word is assigned but never used.
	(Expected: run_test.sh strips the \viz_js block for this headless test, so
	 the VIZ-only consumers of $rom_size and /rom$word show as unused here.
	 They are used once the design is loaded into Makerchip with VIZ intact.)

SandPiper returning status 1.
==> Compiling with Icarus Verilog
==> Simulating
cyc=0 pc=0x4 instr=0x91005002  X1=10 X2=0 X3=0 X4=0 X5=0 X6=0  Mem[0]=0  passed=0
cyc=1 pc=0x8 instr=0x8b020023  X1=10 X2=20 X3=0 X4=0 X5=0 X6=0  Mem[0]=0  passed=0
cyc=2 pc=0xc instr=0xcb010044  X1=10 X2=20 X3=30 X4=0 X5=0 X6=0  Mem[0]=0  passed=0
cyc=3 pc=0x10 instr=0xd1001446  X1=10 X2=20 X3=30 X4=10 X5=0 X6=0  Mem[0]=0  passed=0
cyc=4 pc=0x14 instr=0xb5000044  X1=10 X2=20 X3=30 X4=10 X5=0 X6=15  Mem[0]=0  passed=0
cyc=5 pc=0x1c instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=0 X6=15  Mem[0]=0  passed=0
cyc=6 pc=0x20 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=0 X6=15  Mem[0]=30  passed=0
cyc=7 pc=0x24 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30 X6=15  Mem[0]=30  passed=0
cyc=8 pc=0x28 instr=0x17fffff6  X1=10 X2=20 X3=30 X4=10 X5=30 X6=15  Mem[0]=30  passed=0
cyc=9 pc=0x0 instr=0x91002801  X1=10 X2=20 X3=30 X4=10 X5=30 X6=15  Mem[0]=30  passed=0
...
cyc=88 pc=0x28 instr=0x17fffff6  X1=10 X2=20 X3=30 X4=10 X5=30 X6=15  Mem[0]=30  passed=1
cyc=89 pc=0x0 instr=0x91002801  X1=10 X2=20 X3=30 X4=10 X5=30 X6=15  Mem[0]=30  passed=1

*** TEST PASSED *** (X5 == 30)
sim/tb.sv:31: $finish called at 916000 (1ps)
```

The program loops continuously (`CBNZ` taken, skipping ahead; `CBZ` not taken, falling through; `B` unconditional, restarting the whole program), so every instruction type — including both conditional branches and the unconditional branch — genuinely executes and can be observed in the VIZ.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
