#!/usr/bin/env bash

REPO_URL="${CSAW26_REPO:-https://github.com/KennethLei1492/CSAW26.git}"

# the rest of run_all.sh...
# ============================================================================
# run_all.sh  -  one-click pipeline: bitstream -> netlist -> cipher recovery ->
#                RTL build -> functional + Trojan-exploit simulation.
# Requires the OSS CAD Suite (icestorm, iverilog) and python3 on PATH.
# Usage:  ./run_all.sh          (full pipeline, re-derives everything)
#         ./run_all.sh sim      (skip re-derivation, just build+simulate)
# ============================================================================
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ "$1" != "sim" ]; then
  echo "############ Stage 1: reverse-engineer the bitstream ############"
  ( cd recovery && bash reverse.sh ice40_bitstream.bin )
  echo "############ Stage 2: recover the cipher (oracle probing) #######"
  ( cd recovery && python extract_cipher.py )
  echo "############ Stage 2b: design + self-test the hardened cipher ####"
  ( python hardening/design_hardened.py )
fi

echo "############ Stage 3: RE proof - recovered core hits golden vector ####"
( cd rtl
  iverilog -g2012 -o ../hardening/valrec.vvp ../tb/tb_validate.v spi_crypto_top.v crypto_core_recovered.v
  vvp ../hardening/valrec.vvp )

echo "############ Stage 4: hardened cipher + Trojan exploit ###########"
( cd rtl
  iverilog -g2012 -o ../hardening/troj.vvp ../tb/tb_trojan.v spi_crypto_top.v crypto_core.v
  vvp ../hardening/troj.vvp )

echo "############ DONE ############"
