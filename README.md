
# ARM Single Cycle CPU Core

This repository contains a Makerchip implementation of a simple ARM single-cycle processor design.

## Files

- `arm_single_cycle.tlv` - The main TL-Verilog source for the processor design.
- `run_test.sh` - Helper script to run the test flow.

## Usage

Run the test script from the repository root:

```bash
pip3 install --user --break-system-packages sandpiper-saas   # TL-Verilog → SystemVerilog transpiler
conda install -y -n base -c conda-forge iverilog              # Verilog simulator

cd ~/makerchip/arm_single_cycle
./run_test.sh

NOTE: keep repeat(N) in run_test.sh comfortably larger than the cyc_cnt threshold in *passed (e.g. threshold 30 needs repeat(35+)
```

## Terminal Output

```bash
prabhu@workstation:~/makerchip/arm_single_cycle$ tree
.
├── arm_single_cycle.tlv
└── run_test.sh

1 directory, 2 files
prabhu@workstation:~/makerchip/arm_single_cycle$ ./run_test.sh 
==> Transpiling TL-Verilog -> SystemVerilog (SandPiper cloud service)
You have agreed to our Terms of Service here: https://makerchip.com/terms.
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

WARNING(1) (UNUSED-SIG): File '_novz.tlv' Line 90 (char 10)
	Preprocessed as './_novz.m4out.tlv':90(ch10):
	+---------vvvvvvvvvvv---------------------
	>         $is_cb_type = $is_cbz || $is_cbnz;
	+---------^^^^^^^^^^^---------------------
	Signal |cpu$is_cb_type is assigned but never used.
	To silence this message use "`BOGUS_USE($is_cb_type)".

WARNING(1) (UNUSED-SIG): File '_novz.tlv' Line 97 (char 10)
	Preprocessed as './_novz.m4out.tlv':97(ch10):
	+---------vvvvvvvvv-----------------------
	>         $mem_read    = $is_ldur;
	+---------^^^^^^^^^-----------------------
	Signal |cpu$mem_read is assigned but never used.
	To silence this message use "`BOGUS_USE($mem_read)".

SandPiper returning status 1.
==> Compiling with Icarus Verilog
==> Simulating
cyc=0 pc=0x8 instr=0x8b020023  X1=10 X2=20 X3=0 X4=0 X5=0  Mem[0]=0  passed=0
cyc=1 pc=0xc instr=0xcb010044  X1=10 X2=20 X3=30 X4=0 X5=0  Mem[0]=0  passed=0
cyc=2 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=0  Mem[0]=0  passed=0
cyc=3 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=0  Mem[0]=30  passed=0
cyc=4 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=0
cyc=5 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=6 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=7 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=8 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=9 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=10 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=11 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=12 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=13 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=14 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=15 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=16 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=17 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=18 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=19 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=20 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=21 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=22 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=23 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=24 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=25 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=26 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=27 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=28 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=29 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=30 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=31 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=32 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=33 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=34 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=35 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=36 pc=0x18 instr=0xb4000041  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=37 pc=0x1c instr=0xb5ffffa4  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=38 pc=0x10 instr=0xf8000003  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1
cyc=39 pc=0x14 instr=0xf8400005  X1=10 X2=20 X3=30 X4=10 X5=30  Mem[0]=30  passed=1

*** TEST PASSED *** (X5 == 30)
sim/tb.sv:31: $finish called at 416000 (1ps)
```

## License

This project is licensed under the MIT License. See the LICENSE file for details.
