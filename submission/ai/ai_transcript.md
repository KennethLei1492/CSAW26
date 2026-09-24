# AI Methodology & Interaction Log

## Interaction model, tooling, and framework

* **Model:** Anthropic Claude (Claude Code agentic CLI).
* **Mode of interaction:** a single autonomous agent session. The AI was given
  the challenge text and then operated the local open-source toolchain
  end-to-end by itself — issuing shell commands, writing and running Python
  analysis harnesses, generating and simulating Verilog, and iterating on its
  own test failures until the recovery and the Trojan were verified.
* **Supporting framework around the model:**
  * The **OSS CAD Suite** (Project IceStorm `icepack`/`icebox_vlog`, Icarus
    Verilog `iverilog`/`vvp`, Yosys) as the hardware toolchain.
  * A set of AI-authored **Python harnesses** that treat the recovered netlist
    as a *simulation oracle*: they programmatically generate Verilog
    testbenches, compile them, run them, parse results, and feed conclusions
    back into the next round of generation. This closed AI-in-the-loop
    reverse-engineering loop (hypothesise -> generate stimulus -> simulate ->
    measure -> refine) is the core of the "creative AI use" here.
  * All Trojan RTL and both testbenches are AI-generated Verilog; no HDL was
    written by a human.

## Chronological methodology (what the AI did and why)

1. **Ingested the challenge assets** — bitstream, interface datasheet, and the
   RP2040 micropython reference — and extracted the ground-truth facts: SPI
   mode 0, MSB-first, unified `SCK` clock, 32-bit block, 4-cycle `BUSY`, and the
   single published vector `0x59C359C3 -> 0x9CD84392`.

2. **Unpacked the bitstream** with `icepack -u` and **proved the extraction
   loss-less** by repacking and byte-comparing to the original. Emitted a
   structural netlist with `icebox_vlog`; observed 71 flip-flops and 4 identical
   `SB_RAM40_4K` S-box BRAMs.

3. **Made the netlist simulate faithfully.** Fixed the icebox_vlog
   double-declaration of the registered output, and — the crucial insight —
   initialised all flip-flops and the BRAM output register to 0 to mimic iCE40
   power-up (Icarus otherwise starts them at `x`, which had poisoned earlier
   results).

4. **Recovered the pin map automatically.** Identified `SCK`, `MISO`, `BUSY`,
   and `ICE_LED` structurally (clock net, sole registered output, and the
   `assign`-mirrored LED), then ran an **exhaustive simulation search over all
   permutations** of the five remaining inputs, scoring each against the SPI
   read-back self-test and the documented BUSY behaviour. This uniquely fixed
   `RST_N`, `MOSI`, `NORM_CS_N`, `ENC_DEC`, and `START`.

5. **Mapped the datapath** by driving one-hot words and diffing all 71
   flip-flops, associating each of the 32 I/O-register bits with exactly one
   flip-flop so the datapath value could be read directly during simulation.

6. **Diagnosed and fixed a timing race.** Early runs gave inconsistent,
   sometimes input-independent, ciphertexts. The AI traced this to `START`
   being cleared in the same delta as a clock edge (a testbench race that
   widened the pulse). Switching to a race-free bit clock — inputs change while
   `SCK` is low with real setup before each edge — made the netlist reproduce
   `0x59C359C3 -> 0x9CD84392` exactly, and made encrypt/decrypt exact inverses.

7. **Characterised the cipher.** Differential probing showed the transform is
   **byte-local** (input byte *i* affects only output byte *i*) and nonlinear
   (an affine model failed). This, plus the four identical S-box BRAMs and the
   4-cycle latency, identified a byte-wise 4-round substitution cipher with a
   hard-wired key and no diffusion.

8. **Extracted the full cipher** in 256 oracle queries (`din = v*0x01010101`),
   yielding four forward and four inverse 256-entry byte permutations, each a
   verified bijection, with `dec == enc^-1`. These tables *are* the recovered
   key material (bonus).

9. **Reconstructed clean RTL** (`crypto_core.v` + `spi_crypto_top.v`) driven by
   the recovered tables, and **cross-checked** it against the netlist oracle
   over dozens of random vectors in both modes (0 mismatches) and through the
   real SPI interface (correct read-back of the published vector and round-trip).

10. **Designed and inserted the Trojan** — a two-block knock trigger and a
    precise key-exfiltration payload — entirely in AI-generated Verilog, then
    **quantified stealth** with Yosys: +2 flip-flops and no extra BRAM vs. the
    baseline.

11. **Wrote the exploit testbench** proving normal operation, stealth against
    partial/incorrect triggers, and the live key leak on `MISO`; wrapped the
    whole flow in a one-click, self-checking pipeline (`run_all.sh`).

## Representative prompts / instructions driving the agent

The session was one continuous autonomous task. Paraphrased, the instructions
that shaped each phase were:

* "Reverse-engineer this iCE40 bitstream to a simulatable netlist and prove the
  extraction is faithful."
* "Determine the pin mapping and protocol by simulation against the known test
  vector; do it by automated search, not guessing."
* "Figure out how the cipher works — structure, diffusion, key — using the
  netlist as an oracle."
* "Reconstruct clean, synthesizable RTL that matches the hardware bit-for-bit,
  and verify it."
* "Design a stealthy hardware Trojan: an extremely specific trigger and a
  precise key-exfiltration payload; keep normal operation perfect and overhead
  negligible; then write a testbench that proves both normal operation and the
  exploit, and automate the whole pipeline."

## Reproducibility

`run_all.sh` re-runs the entire chain — unpack, faithfulness check, netlist
recovery, oracle-based cipher extraction (self-checking against the published
vector), RTL build, and both simulations — on any machine with the OSS CAD
Suite and Python. The extraction step alone issues 512 oracle simulations and
takes a couple of minutes; `run_all.sh sim` skips re-derivation and just builds
and simulates.
