#!/usr/bin/env bash
# Transpile arm_kamal_isa.tlv -> SystemVerilog (SandPiper cloud service) and
# simulate it with Icarus Verilog, printing a cycle-by-cycle trace and a
# PASS/FAIL verdict based on the design's own *passed assertion (X5==30).
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
sandpiper-saas -i "$STRIPPED" -o arm_kamal_isa.sv --outdir "$SIM" -p m4out
sp_status=$?
set -e
# SandPiper exits 1 merely for warnings (e.g. unused-signal notices); only
# treat >1 as a real compile failure.
if [ "$sp_status" -gt 1 ]; then
  echo "SandPiper transpile failed (exit $sp_status)" >&2
  exit "$sp_status"
fi

echo "==> Compiling with Icarus Verilog"
iverilog -g2012 -I "$SIM" -o "$SIM/sim.vvp" "$SIM/arm_kamal_isa.sv" "$SIM/tb.sv"

echo "==> Simulating"
vvp "$SIM/sim.vvp"
