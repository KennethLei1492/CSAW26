# CSAW'26 AI Hardware Attack — Qualifier Submission
## Reverse-Engineered Cryptographic Accelerator + AI-Generated Hardware Trojan

This submission reverse-engineers the provided Lattice iCE40-UP5K bitstream,
reconstructs the cryptographic accelerator as clean synthesizable RTL, and
inserts a stealthy, AI-generated hardware Trojan that exfiltrates the device
key over the SPI `MISO` line. Every step is automated and self-checking.

```
submission/
├── README.md                     <- this technical brief
├── CSAW26_Trojan_Report.pdf      <- ***JUDGES' REPORT*** (analysis, proofs, CVSS/CWE, figures)
├── LOG.md                        <- full engineering log (every command + note)
├── run_all.sh                    <- one-click: reverse -> recover -> harden -> build -> exploit
├── rtl/
│   ├── spi_crypto_top.v              <- SPI-peripheral wrapper (TROJAN_EN param)
│   ├── crypto_core.v                 <- HARDENED 12-round Feistel  ***CONTAINS THE TROJAN*** (primary)
│   ├── crypto_core_recovered.v       <- exact recovered byte-substitution cipher + Trojan (RE proof)
│   ├── crypto_core_recovered_clean.v <- recovered cipher, no Trojan (reference)
│   ├── sbox_feistel.mem              <- S-box used by the hardened Feistel core
│   └── sbox_{enc,dec}{0..3}.mem      <- recovered per-byte-lane substitution tables
├── tb/
│   ├── tb_trojan.v               <- exploit TB: Trojaned vs clean twin (stealth + key leak)
│   └── tb_validate.v             <- functional TB vs. the published test vector
├── ai/
│   └── ai_transcript.md          <- full AI methodology, prompts, tools, models
├── hardening/
│   ├── design_hardened.py        <- designs + self-tests the hardened cipher (avalanche)
│   ├── build_report.py           <- assembles the PDF report
│   ├── avalanche*.svg, waveform.svg, sim_*.txt   <- report figures + verbatim sim logs
│   └── hardened_params.json      <- chosen rounds / rotations / round keys
└── recovery/
    ├── ice40_bitstream.bin       <- provided challenge bitstream
    ├── reverse.sh                <- bitstream -> simulatable netlist (Project IceStorm)
    ├── recovered_netlist.v       <- icebox_vlog structural netlist (golden oracle)
    ├── extract_cipher.py         <- automated oracle-probing cipher recovery
    ├── cipher_tables.json        <- recovered 4x enc + 4x dec byte permutations
    └── sbox_bram_init.txt        <- raw S-box contents read out of the BRAMs
```

> **Phase 2 (judges' request):** `CSAW26_Trojan_Report.pdf` is the full report —
> original-RTL analysis, what we implemented, stealth-and-danger proofs (avalanche
> matrices, Trojaned-vs-clean equivalence, key-leak waveform), CVSS 9.0 Critical and
> CWE ratings. We additionally **hardened** the accelerator into a full-diffusion
> 12-round Feistel cipher (`crypto_core.v`) while keeping the Trojan's stealth
> (+2 flip-flops, bit-identical to a clean twin on 72/72 transactions). The exact
> recovered cipher is retained as `crypto_core_recovered.v` (reproduces the golden
> vector `0x59C359C3 -> 0x9CD84392`).

Run everything (needs OSS CAD Suite + python3 on PATH):

```
./run_all.sh          # re-derives the netlist and cipher, then simulates
./run_all.sh sim      # just build the RTL and run both testbenches
```

---

## 1. Reverse-engineering the bitstream

**Tooling.** Project IceStorm (`icepack -u`, `icebox_vlog`) from the recommended
OSS CAD Suite, plus Icarus Verilog (`iverilog`/`vvp`) for simulation and Yosys
for synthesis checks. All orchestration and analysis is Python.

**Steps (see `recovery/reverse.sh`):**

1. `icepack -u ice40_bitstream.bin design.asc` unpacks the bitstream to its
   textual LUT/routing/BRAM form. Device reports as `5k` (UP5K).
2. **Faithfulness check:** repacking with `icepack design.asc repacked.bin`
   yields a file **byte-identical** to the original bitstream, proving the
   extraction is loss-less.
3. `icebox_vlog design.asc > recovered_netlist.v` emits a flattened structural
   netlist: 9 top-level I/O, 71 flip-flops, and **4 identical `SB_RAM40_4K`
   block RAMs**. This is used as the golden oracle for all later analysis.
4. Two mechanical patches make it simulate the way the silicon powers up:
   the doubly-declared registered output `io_16_31_1` is merged to `output reg`,
   and all fabric flip-flops plus the BRAM output register are initialised to 0
   (iCE40 flip-flops power up to 0; Icarus otherwise starts them at `x`). This
   `x`-vs-0 detail was one of the key insights for getting the netlist to behave
   like the real device.

**Recovering the pin map.** The netlist names I/O by physical location
(`io_9_31_1`, ...). We recovered the logical mapping automatically:

* `SCK = io_9_31_1` — clocks all 71 flip-flops (the documented unified clock).
* `io_19_31_0 = ICE_LED` is a pure `assign` copy of `io_8_31_1 = BUSY`,
  matching the datasheet ("ICE_LED mirrors BUSY"); `MISO = io_16_31_1` is the
  only registered output.
* The remaining five inputs were resolved by an exhaustive simulation search
  over all permutations, scored against (a) the SPI read-back self-test in the
  micropython reference and (b) the documented BUSY-for-4-cycles behaviour:

  | Signal | Pin | Signal | Pin |
  |---|---|---|---|
  | SCK | io_9_31_1 | MISO | io_16_31_1 |
  | RST_N | io_13_31_1 | NORM_CS_N | io_17_31_0 |
  | MOSI | io_16_31_0 | ENC_DEC | io_19_31_1 |
  | START | io_18_31_1 | BUSY / ICE_LED | io_8_31_1 / io_19_31_0 |

**Locating the datapath.** Driving one-hot words into the shift register and
diffing the 71 flip-flops mapped each of the 32 I/O-register bits to exactly one
flip-flop (listed in `extract_cipher.py`), letting us read the 32-bit datapath
value directly from the netlist during simulation.

**The timing gotcha.** Clearing `START` in the same simulation delta as the
next `SCK` rising edge creates a race that widens the start pulse and yields
wrong (even input-independent) results. Driving the core race-free — inputs
change while `SCK` is low, with real setup before each rising edge, exactly as a
physical SPI controller does — makes the netlist reproduce the published test
vector precisely. `extract_cipher.py` uses this race-free bit-clock.

## 2. How the encryption system works

The accelerator is a **32-bit block cipher with a hard-wired key** (no key is
ever sent over SPI — it is baked into the bitstream). Its defining property,
found by differential probing of the oracle, is that it has **no inter-byte
diffusion**: flipping any bit of input byte *i* changes only output byte *i*.
The 32-bit block is therefore four **independent 8-bit keyed bijections**, one
per byte lane — consistent with the four identical S-box BRAMs and the 4-cycle
`BUSY` window (four rounds of S-box substitution + round-key addition per byte,
performed in place).

* `ENC_DEC=0` encrypts, `ENC_DEC=1` decrypts, and the two are exact inverses
  (verified on random inputs).
* **Validated against the provided vector:** `enc(0x59C359C3) = 0x9CD84392`,
  and `dec(0x9CD84392) = 0x59C359C3`, reproduced bit-for-bit by both the
  recovered netlist and our clean RTL.
* Operation: `NORM_CS_N` low shifts 32 bits in on `MOSI` (MSB first); `START`
  pulses for one cycle; `BUSY` is high for 4 cycles and, on its falling edge,
  the result is parallel-loaded into the shift register; `NORM_CS_N` low again
  streams it out on `MISO`.

**Recovering the cipher (`extract_cipher.py`).** Because the cipher is
byte-local, all four lane permutations are captured in **256 oracle queries**:
drive `din = v * 0x01010101` for `v = 0..255` and read the four output bytes.
This yields four 256-entry forward tables (encrypt) and four inverse tables
(decrypt), each a verified bijection — the complete key-dependent behaviour.
They are emitted as the `rtl/sbox_*.mem` files that drive the clean RTL.

## 2.3 The recovered key (bonus) — what it is and how we got it

**Short answer for the team:** yes — "the recovered S-box/key bytes" *are* the
secret this FPGA accelerator uses to encrypt and decrypt. There is an important
subtlety: **this device never receives a key over SPI.** The key is permanently
**baked into the bitstream**, so "recovering the key" means recovering that
hard-wired secret out of the silicon. We did, in full, and it reproduces the
published vector exactly.

**What the key physically is.** The secret lives in two equivalent forms:

1. **Raw form — the secret S-box in the BRAMs.** All four S-box block-RAMs hold
   the *same* 256-byte substitution table (`recovery/sbox_bram_init.txt`),
   read directly out of the bitstream. These 256 bytes are the literal secret
   stored in the chip:

   ```
   INIT_0 85c4d834ef22d4b989d975ce78ebd3405fa9d7fe2f53040695f36fc62fdf2de9
   INIT_1 4dae5f63ca800319a219922c878382b2042fa4cdccdb8c36e5f52f3e4b25edbf
   INIT_2 b2e631e07d1eb7c2668faca8a8a281cf95319e83cb5e2b4e99443ba536189203
   INIT_3 c7cdaaae5946de3c9caee12ea2628a47f915286c2baaa8db852721e3ff8aeae6
   INIT_4 b38b73fc542cabf0e0042f00b1f984421a8f24fa3d7eca72027a937fa9a57071
   INIT_5 75102ed9eed416f8b952d0bb2db7e5d16cdac02f5e90c3ca24b8126137044e48
   INIT_6 b23dc192a95f0c6b677412424eb52e6cf301b96b267ef4eac6b49a342e317d8c
   INIT_7 572d44ac3633a04b29c0dfb57023d812b6aa51fae993732dd138b4cb500eecc9
   ```

2. **Effective form — the four per-byte-lane key tables.** What actually
   encrypts each plaintext byte is that byte lane's full 256-entry keyed
   permutation (S-box folded with the lane's hard-wired round constants). These
   four tables are the usable key and ship as `rtl/sbox_enc{0..3}.mem`
   (with their inverses `sbox_dec{0..3}.mem`). First 16 entries of each:

   | lane (byte) | table[0x00 .. 0x0F] |
   |---|---|
   | 0 (bits 7:0)   | `43 bf 5d 14 71 a6 08 2a f8 03 c5 09 f6 f2 c9 27` |
   | 1 (bits 15:8)  | `d0 8f 2b f9 5b 50 73 b5 bc dd 07 f7 69 d1 5e 11` |
   | 2 (bits 23:16) | `ab b6 c5 b3 fc e2 30 85 c1 8e 3f e7 b0 d4 6e 2a` |
   | 3 (bits 31:24) | `08 70 a3 5d d6 9f 05 3f ed d3 bb af 7f fc 9d 58` |

   Encryption is `C[byte i] = lane_i[P[byte i]]`; decryption uses the inverse
   tables. As a self-check, `enc(0x59C359C3) = 0x9CD84392` (the published
   vector) and the key-only device fingerprint `enc(0x00000000) = 0x08ABD043`.

**How we obtained it (two independent methods that agree):**

* **White-box (from the bitstream).** `icepack -u` + `icebox_vlog` expose the
  four `SB_RAM40_4K` primitives; the 256-byte S-box is read straight from their
  `INIT_0..INIT_7` parameters (byte-exact, since our unpack repacks to the
  original `.bin`).
* **Black-box (oracle probing).** `recovery/extract_cipher.py` drives the
  recovered netlist as an oracle and, using the fact that the cipher is
  byte-local, reconstructs all four lane tables in **256 chosen-plaintext
  queries** (`din = v * 0x01010101`, read each output byte). The tables match
  the white-box S-box and reproduce the golden vector.

**Why we do not quote a single short "N-bit key."** We probed the internal
round-state registers cycle by cycle (`recovery/round_ad.json`). The engine is
not a textbook "one S-box + XOR one round key" that factors into, say, a 32- or
128-bit key: it runs a **non-standard two-phase round schedule** in which the
S-box address register collapses to fixed constants (`0x54`, `0xA8`) on
alternate cycles — i.e. the key is *distributed* across the S-box contents and
hard-wired routing/round constants, a common key-obfuscation for baked-in keys.
The honest, complete answer is therefore the material above: the 256-byte secret
S-box **plus** the four lane tables. That set is sufficient to encrypt or decrypt
**any** block offline, with no device and no further queries — i.e. the key is
fully recovered for exploitation and cloning.

> Note: `SECRET_KEY = 0xC0DECAFE` referenced elsewhere is **not** this recovered
> device key — it is the master-key register of our *hardened* Feistel core
> (Phase 2), and it is the value our Trojan exfiltrates in that build. On the
> original recovered cipher the equivalent secret to leak is the S-box/tables above.

## 3. The hardware Trojan

Implemented in `rtl/crypto_core.v` (diff it against `crypto_core_baseline.v`).

* **Trigger — a two-block "knock" (extremely specific).** In *encrypt* mode,
  processing plaintext `KNOCK_1 = 0xDEADC0DE` *arms* the Trojan; if the **very
  next** encryption processes `KNOCK_2 = 0xFEEDFACE`, it *fires*. Any other
  operand in between, or a knock issued in decrypt mode, silently disarms it.
  The joint probability of accidental activation is 2^-64.
* **Payload — precise key exfiltration.** On the firing operation the core
  parallel-loads the 32-bit `SECRET_KEY` register instead of the true
  ciphertext, so the next ordinary `MISO` read-out streams the device key off
  the chip. Only that one block is affected; the device returns to normal
  immediately afterwards. (`SECRET_KEY` is the register that in the deployed
  device holds the master key; for a self-contained, checkable demo it is set
  to the sentinel `0xC0DECAFE`.)
* **Stealth / overhead.** The Trojan is a 2-bit FSM (`armed`, `fire`), two
  32-bit equality comparators, and one 32-bit output mux. Synthesised for the
  iCE40 it costs **+2 flip-flops (105 vs 103) and no extra BRAM** over the
  baseline — well under 1% overhead. It never alters timing, the `BUSY`
  waveform, or any non-triggering output, so the accelerator is bit-for-bit
  identical to the golden design under all normal use, including when either
  knock value appears on its own.

## 4. Exploiting it (in simulation and on hardware)

`tb/tb_trojan.v` drives the DUT exactly as the RP2040 does and demonstrates:
(A) normal encrypt/decrypt incl. the published vector; (B) stealth — lone
knocks, a broken sequence, and decrypt-mode knocks all yield the correct
ciphertext; (C) the exploit — after `enc(0xDEADC0DE)` then `enc(0xFEEDFACE)`,
the following read-out returns `0xC0DECAFE` on `MISO`, and the device then
resumes correct encryption. All checks pass.

**On real hardware**, once a bitstream is generated from this RTL, the RP2040
(or any SPI controller) triggers the leak with three ordinary transactions:

1. Encrypt block `0xDEADC0DE` (result is the normal ciphertext — nothing looks wrong).
2. Encrypt block `0xFEEDFACE` (fires the Trojan).
3. Perform any read-out transaction (`NORM_CS_N` low, 32 `SCK` cycles): the
   32 bits shifted out on `MISO` are the device's secret key, not a ciphertext.

## 5. AI methodology

See `ai/ai_transcript.md`. The entire pipeline — the permutation search for the
pin map, the one-hot datapath mapping, the race-free oracle, the byte-locality
proof, the 256-query cipher extraction, the Trojan RTL, the testbenches, and
the synthesis/overhead checks — was generated and driven by an AI agent
(Anthropic Claude, via the Claude Code agentic CLI) operating the open-source
toolchain autonomously.
