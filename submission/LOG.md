# Engineering Log — CSAW'26 AI HW Attack Qualifier

> Team status: teammates MIA. Solo. This log records every step, command, and
> decision so anyone can pick up where I am. Newest entries at the bottom.

## Where we are (quick status)
- [x] Phase 1: bitstream reverse-engineered → simulatable netlist (byte-exact repack proof)
- [x] Phase 1: pin map + protocol recovered; cipher characterized (byte-wise substitution)
- [x] Phase 1: clean RTL reconstruction; matches golden vector 0x59C359C3→0x9CD84392
- [x] Phase 1: hardware Trojan (2-block knock → key leak); normal op preserved; +2 FF overhead
- [x] Phase 1: one-click pipeline `run_all.sh`; all tests pass
- [ ] Phase 2: HARDEN the crypto core (add diffusion) while keeping Trojan stealthy
- [ ] Phase 2: re-verify Trojan stealth + exploit on hardened core
- [ ] Phase 2: capture simulation proof (logs + waveform figure)
- [ ] Phase 2: CVSS + CWE assessment
- [ ] Phase 2: compile single PDF report into submission/

## Key recovered facts (reference)
- Pins: SCK=io_9_31_1 RST_N=io_13_31_1 MOSI=io_16_31_0 MISO=io_16_31_1
  NORM_CS_N=io_17_31_0 ENC_DEC=io_19_31_1 START=io_18_31_1 BUSY=io_8_31_1 LED=io_19_31_0
- Cipher: 32-bit block, hard-wired key, NO diffusion (byte-local); 4 independent
  8-bit keyed bijections; ENC_DEC=0 encrypt / 1 decrypt; exact inverses.
- Golden vector reproduced: enc(0x59C359C3)=0x9CD84392.
- Trojan: knock KNOCK_1=0xDEADC0DE then KNOCK_2=0xFEEDFACE (encrypt mode) → next
  readout leaks SECRET_KEY on MISO. +2 FF, +0 BRAM.

## Phase 2 plan (hardening + report)
Rationale: the recovered cipher is cryptographically weak (a single bit flip
changes only one output byte; trivially breakable byte-by-byte). To raise the
"win" odds we add a real diffusion layer so the accelerator becomes a strong
block cipher (full avalanche), WITHOUT touching the Trojan's stealth: same pin
interface, same 4-cycle BUSY timing, same trigger/payload, negligible overhead.
Design choice: a Feistel network (invertible by construction — no risk of a
non-invertible cipher) built on the recovered nonlinear S-boxes, tuned by
self-test until avalanche ≈ 50%.

---
## Phase 2 progress

### Hardened cipher designed (design_hardened.py)
Command: `python hardening/design_hardened.py`
Result: Feistel, N=12 rounds, rotations ra=3/rb=11, master key 0xC0DECAFE.
  - Avalanche = 16.00 / 32 bits (ideal 50%) — FULL diffusion achieved.
  - Round-trip invertible over 3000 random vectors: PASS.
  - Injective over 5000 samples: PASS.
  - Note: Feistel uses the SAME round function F for enc & dec (only key order
    reverses), so only the forward S-box is needed — no inverse table. F reuses
    the recovered 8-bit S-box for nonlinearity.
  - Round keys: cafe b2bf ecaf 7b2b deca 37b2 5fd8 57f6 95fd 657f d95f f657

### Hardened RTL implemented + verified (crypto_core_hardened.v)
Command: `iverilog ... tb_random.v spi_crypto_top.v crypto_core_hardened.v` then Python cross-check.
Result: hardened RTL == Python reference for ENC, DEC, and round-trip over 30
random vectors (0 mismatches). Full 12-round Feistel computes combinationally;
same 4-cycle BUSY interface as the recovered core.

### File reorg (evidence vs deliverable)
- crypto_core.v            = HARDENED Feistel + Trojan  (PRIMARY deliverable)
- crypto_core_recovered.v  = exact recovered byte-substitution cipher + Trojan
                             (kept as reverse-engineering proof; reproduces
                              golden vector 0x59C359C3->0x9CD84392)
- crypto_core_recovered_clean.v = recovered cipher, no Trojan
- Added parameter TROJAN_EN (default 1) so a clean twin can be instantiated for
  the stealth proof (Trojaned vs clean, driven identically).

### Verification of hardened design (all PASS)
- `vvp tb_trojan (hardened)`: functional round-trip PASS; STEALTH: DUT==clean twin
  on 8 assorted + 64 random transactions (72/72 identical); EXPLOIT: knock leaks
  0xC0DECAFE on MISO while clean core returns real ciphertext 0x3c2e0424; returns
  to normal after. errors=0.
- `vvp tb_validate (recovered core)`: enc(0x59C359C3)=0x9CD84392 PASS, round-trip PASS
  (reverse-engineering evidence preserved).

### Overhead (yosys synth_ice40 -run :map_luts, TROJAN_EN 1 vs 0)
- Hardened+Trojan: 105 FF ; Hardened clean: 103 FF  => Trojan cost = +2 FF.
- S-box maps to logic (many combinational read ports in the unrolled Feistel),
  0 BRAM; fits UP5K comfortably. FF overhead identical to the recovered design.

### Proof artifacts generated
- hardening/avalanche.svg          : hardened SAC matrix, mean p=0.4997 (ideal 0.5)
- hardening/avalanche_recovered.svg : recovered cipher, cross-byte p=0.0000 (no diffusion)
- hardening/waveform.svg           : exploit timing (knock -> key on MISO)
- hardening/sim_trojan.txt, sim_recovered.txt : verbatim sim logs

### Commands used this phase
- python hardening/design_hardened.py
- iverilog -g2012 -o hardening/hx.vvp tb/tb_random.v rtl/spi_crypto_top.v rtl/crypto_core_hardened.v
- iverilog -g2012 -o hardening/troj.vvp tb/tb_trojan.v rtl/spi_crypto_top.v rtl/crypto_core.v ; vvp hardening/troj.vvp
- yosys -s ht.ys / hc.ys  (chparam TROJAN_EN 1/0 ; synth_ice40 -run :map_luts ; stat)

### TODO next
- [ ] Write single PDF report (analysis, implementation, stealth+danger proof,
      CVSS + CWE) into submission/ ; embed the three SVG figures + sim logs.

### PDF report generated  [DONE]
- hardening/build_report.py assembles report.html (embeds the 3 SVGs + verbatim
  sim logs), then headless Chrome prints it to PDF.
- Command:
    python hardening/build_report.py
    "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless --disable-gpu \
      --no-sandbox --no-pdf-header-footer \
      --print-to-pdf=CSAW26_Trojan_Report.pdf file:///.../hardening/report.html
- Output: submission/CSAW26_Trojan_Report.pdf (5 pages). CVSS 9.0 Critical;
  CWE-506/912/200/321.
- Re-verified whole pipeline: `run_all.sh sim` -> Stage 3 golden vector PASS,
  Stage 4 stealth 64/64 + key leak PASS.

## STATUS: COMPLETE
All Phase-2 items done. Deliverables in submission/: hardened Trojaned RTL,
recovered-cipher evidence RTL, dual-core exploit testbench, recovery + hardening
scripts, PDF report, this log, and the AI transcript. Zip = submission.zip.
Teammates: if you are reading this, everything reproduces via ./run_all.sh.

### Key documentation (teammate question)
Q: does "recovered S-box/key bytes" == the key used by the FPGA accelerator? A: yes.
- The device has NO SPI-loaded key; key is baked into the bitstream.
- Recovered secret = 256-byte S-box (BRAM INIT_0..7) + the four per-lane 256-entry
  key tables (sbox_enc/dec*.mem). Reproduces enc(0x59C359C3)=0x9CD84392;
  fingerprint enc(0)=0x08ABD043.
- Obtained white-box (read BRAM INIT from netlist) AND black-box (256 chosen-PT
  oracle queries, extract_cipher.py); both agree.
- Probed round-state (recovery/round_ad.json): non-standard 2-phase schedule
  (addr collapses to consts 0x54/0xA8 on alternate cycles) -> key is distributed
  across S-box + routing, so no single short N-bit key; the tables ARE the key.
- README.md section 2.3 updated with exact values + method.
- NOTE: 0xC0DECAFE is the hardened core's key (what the Trojan leaks), NOT the
  recovered device key.
