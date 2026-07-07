# ARM Single Cycle

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
```

## License

This project is licensed under the MIT License. See the LICENSE file for details.
