#!/usr/bin/env bash
# ============================================================================
# reverse.sh - Stage 1: recover a simulatable netlist from the FPGA bitstream.
#
# Requires the OSS CAD Suite (icestorm + yosys) on PATH.
# Produces:
#   design.asc            - textual (LUT/routing/BRAM) form of the bitstream
#   recovered_netlist.v   - structural Verilog emitted by icebox_vlog
#   recovered_por.v       - same, patched to be power-on-reset friendly for sim
#   cells_sim.v           - iCE40 primitive models (for SB_RAM40_4K)
# ============================================================================
set -e
BIT="${1:-ice40_bitstream.bin}"

echo "[1/4] Unpacking bitstream -> design.asc"
icepack -u "$BIT" design.asc

echo "[2/4] Verifying round-trip (repack must equal original)"
icepack design.asc repacked.bin
cmp "$BIT" repacked.bin && echo "      OK: extraction is byte-exact"

echo "[3/4] icebox_vlog -> recovered_netlist.v"
icebox_vlog design.asc > recovered_netlist.v

echo "[4/4] Patching for simulation (registered-output fix + power-on reset)"
# icebox_vlog declares the registered MISO output twice; merge to 'output reg'
sed 's/output io_16_31_1)/output reg io_16_31_1)/' recovered_netlist.v \
  | sed '/^reg io_16_31_1 = 0;/d' \
  | sed -E 's/^reg (n[0-9]+);/reg \1 = 0;/' > recovered_por.v      # FFs power up to 0

# iCE40 primitive models; initialise the BRAM output register (hardware = 0)
CELLS=$(find "${OSS_ROOT:-/c/oss-cad-suite}" -path '*ice40*cells_sim.v' 2>/dev/null | head -1)
cp "$CELLS" cells_sim.v
sed -i 's/\treg  \[15:0\] RDATA_I;/\treg  [15:0] RDATA_I = 0;/' cells_sim.v
echo "Done. Recovered netlist ready (recovered_por.v)."
