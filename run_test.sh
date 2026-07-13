#!/usr/bin/env bash
# Transpile arm_single_cycle.tlv -> SystemVerilog (SandPiper cloud service) and
# simulate it with Icarus Verilog, printing a cycle-by-cycle trace and a
# PASS/FAIL verdict based on the design's own *passed assertion (X5==30).
#
# Self-contained: the only required input is arm_single_cycle.tlv next to this
# script. Everything under sim/ (testbench, stub includes, generated .sv) is
# regenerated on every run and safe to delete.
set -euo pipefail

cd "$(dirname "$0")"
export PATH="$PATH:$HOME/.local/bin"

# Icarus Verilog lives in the conda base env.
if ! command -v iverilog >/dev/null 2>&1; then
  source "$HOME/anaconda3/etc/profile.d/conda.sh"
  conda activate base
fi

SIM=sim
TLV=arm_single_cycle.tlv
STRIPPED=$SIM/_novz.tlv
mkdir -p "$SIM"

# --- Regenerate support files every run (nothing here is user-editable) ---

cat > "$SIM/sp_m4out.vh" <<'VHEOF'
// Minimal local stub replacing Makerchip's simulation-harness include.
// Only provides what the SandPiper-generated top module references before
// its own logic is defined (a randomizer used by Makerchip for uninitialized
// signal fuzzing, unused by this design).
module pseudo_rand #(parameter WIDTH = 1) (input clk, input reset, output logic [WIDTH-1:0] out);
  assign out = '0;
endmodule
VHEOF

cat > "$SIM/sandpiper_gen.vh" <<'VHEOF'
// Minimal local stub replacing Makerchip's simulation-harness include.
// No additional macros are required for this design.
VHEOF

cat > "$SIM/tb.sv" <<'TBEOF'
`timescale 1ns/1ps
module tb;
  logic clk = 0;
  logic reset;
  logic [31:0] cyc_cnt = 0;
  wire passed, failed;

  top dut(.clk(clk), .reset(reset), .cyc_cnt(cyc_cnt), .passed(passed), .failed(failed));

  always #5 clk = ~clk;

  initial begin
    reset = 1;
    repeat (2) @(posedge clk);
    reset = 0;

    repeat (90) begin
      @(posedge clk);
      #1;
      $display("cyc=%0d pc=0x%0h instr=0x%08h  X1=%0d X2=%0d X3=%0d X4=%0d X5=%0d X6=%0d  Mem[0]=%0d  passed=%0b",
                cyc_cnt, dut.CPU_pc_a0, dut.CPU_instr_a0,
                dut.CPU_Xreg_val_a0[1], dut.CPU_Xreg_val_a0[2], dut.CPU_Xreg_val_a0[3],
                dut.CPU_Xreg_val_a0[4], dut.CPU_Xreg_val_a0[5], dut.CPU_Xreg_val_a0[6],
                dut.CPU_Dmem_val_a0[0], passed);
      cyc_cnt = cyc_cnt + 1;
    end

    if (passed) $display("\n*** TEST PASSED *** (X5 == 30)");
    else        $display("\n*** TEST FAILED *** (X5 != 30)");

    $finish;
  end
endmodule
TBEOF

# Strip the cosmetic \viz_js visualization block before transpiling: it's
# Makerchip-GUI-only, has no effect on the CPU logic, and its single quotes/
# brackets can conflict with SandPiper's M4 preprocessor when run headless.
python3 - "$TLV" "$STRIPPED" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    lines = f.readlines()
viz = next(i for i, l in enumerate(lines) if '\\viz_js' in l)
tail = next(i for i, l in enumerate(lines) if 'PASS / FAIL' in l)
with open(dst, 'w') as f:
    f.writelines(lines[:viz] + lines[tail-1:])
EOF

echo "==> Transpiling TL-Verilog -> SystemVerilog (SandPiper cloud service)"
set +e
sandpiper-saas -i "$STRIPPED" -o arm_single_cycle.sv --outdir "$SIM" -p m4out
sp_status=$?
set -e
# SandPiper exits 1 merely for warnings (e.g. unused-signal notices); only
# treat >1 as a real compile failure.
if [ "$sp_status" -gt 1 ]; then
  echo "SandPiper transpile failed (exit $sp_status)" >&2
  exit "$sp_status"
fi

echo "==> Compiling with Icarus Verilog"
iverilog -g2012 -I "$SIM" -o "$SIM/sim.vvp" "$SIM/arm_single_cycle.sv" "$SIM/tb.sv"

echo "==> Simulating"
vvp "$SIM/sim.vvp"
