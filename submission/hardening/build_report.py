#!/usr/bin/env python3
# Assemble the single-file HTML report (embeds SVG figures + verbatim sim logs).
import json, os, html
B="C:/csaw26/work/submission"
H=B+"/hardening"
def rd(p):
    return open(p, encoding="utf-8").read()
def svg(p):
    s=rd(p)
    return s[s.index("<svg"):]  # strip any xml prolog
av=json.load(open(H+"/avalanche_stats.json"))
sim_trojan=html.escape(rd(H+"/sim_trojan.txt"))
sim_rec=html.escape(rd(H+"/sim_recovered.txt"))
wave=svg(H+"/waveform.svg")
avsvg=svg(H+"/avalanche.svg")
avrec=svg(H+"/avalanche_recovered.svg")

CSS="""
@page { size: A4; margin: 16mm 14mm; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', Arial, sans-serif; color:#1a1a1a; font-size:11px; line-height:1.5; }
h1 { font-size:22px; margin:0 0 2px; color:#0b2545; }
h2 { font-size:15px; margin:18px 0 6px; color:#0b2545; border-bottom:2px solid #0b5; padding-bottom:3px; page-break-after:avoid; }
h3 { font-size:12.5px; margin:12px 0 4px; color:#12324f; }
.sub { color:#555; margin:0 0 10px; }
code, pre { font-family:'Consolas','Courier New',monospace; }
pre { background:#0d1117; color:#d6e2f0; padding:10px; border-radius:5px; font-size:9.2px; line-height:1.35; overflow:hidden; white-space:pre-wrap; }
table { border-collapse:collapse; width:100%; margin:6px 0; font-size:10px; }
th,td { border:1px solid #cbd5e1; padding:4px 7px; text-align:left; vertical-align:top; }
th { background:#eef4ff; }
.fig { text-align:center; margin:8px 0; page-break-inside:avoid; }
.fig svg { max-width:100%; height:auto; border:1px solid #e2e8f0; border-radius:4px; }
.cap { font-size:9px; color:#555; margin-top:3px; }
.pill { display:inline-block; background:#0b5; color:#fff; padding:1px 8px; border-radius:10px; font-size:9.5px; font-weight:700; }
.crit { background:#c0143c; }
.grid2 { display:flex; gap:10px; }
.grid2 > div { flex:1; }
.kv { background:#f6f8fa; border:1px solid #e2e8f0; border-radius:5px; padding:8px 10px; }
.ok { color:#0a7c2f; font-weight:700; }
.bad { color:#c0143c; font-weight:700; }
small { color:#666; }
.hdr { display:flex; justify-content:space-between; align-items:flex-end; border-bottom:3px solid #0b2545; padding-bottom:6px; }
"""

body = f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>
<div class="hdr">
  <div>
    <h1>Hardware Trojan in a Reverse-Engineered Crypto Accelerator</h1>
    <p class="sub">CSAW'26 AI Hardware Attack &mdash; Qualifier Technical Report &middot; Target: Lattice iCE40-UP5K SPI crypto IP</p>
  </div>
  <div style="text-align:right"><span class="pill crit">CVSS 9.0 CRITICAL</span><br><small>CWE-506 / CWE-912 / CWE-200 / CWE-321</small></div>
</div>

<h2>1. Executive summary</h2>
<p>We reverse-engineered the provided iCE40-UP5K bitstream to a <b>byte-exact</b> netlist, recovered
the cryptographic algorithm and its hard-wired key, and reconstructed a clean, synthesizable RTL model that
reproduces the published test vector <code>0x59C359C3&nbsp;&rarr;&nbsp;0x9CD84392</code>. We then (a) <b>hardened</b>
the accelerator from a trivially-breakable byte-substitution cipher into a full-diffusion 12-round Feistel block
cipher, and (b) inserted a <b>stealthy hardware Trojan</b> that exfiltrates the device's secret key over the SPI
<code>MISO</code> line on a hidden two-block trigger. In simulation the Trojaned device is
<b>bit-identical to a clean twin across 72/72 transactions</b> and costs only <b>+2 flip-flops</b>, yet a
2<sup>&minus;64</sup>-probability knock sequence makes it hand over the key. Every result below is reproduced by the
one-click pipeline <code>run_all.sh</code>.</p>

<h2>2. Analysis of the original (recovered) design</h2>
<h3>2.1 Bitstream to netlist &mdash; and proof it is faithful</h3>
<p>Using Project IceStorm, <code>icepack -u</code> unpacked the bitstream and <code>icebox_vlog</code> produced a
structural netlist (9 I/O, 71 flip-flops, four identical <code>SB_RAM40_4K</code> S-box BRAMs). Re-packing the
unpacked design reproduced the original <code>.bin</code> <b>byte-for-byte</b>, proving the extraction is loss-less.
The physical pin map was recovered by an automated permutation search scored against the documented SPI
read-back self-test and the 4-cycle <code>BUSY</code> behaviour; the 32-bit datapath register was located by
one-hot stimulus. A subtle <code>START</code>/clock race had to be eliminated (drive inputs while <code>SCK</code>
is low, with setup before each edge) before the netlist reproduced the published vector.</p>

<h3>2.2 How the original cipher works &mdash; and why it is weak</h3>
<p>The accelerator is a 32-bit block cipher with a key baked into the fabric (no key is ever sent over SPI).
Differential probing of the netlist oracle showed the transform is <b>byte-local</b>: flipping any input bit
changes only one output byte. It is therefore four independent 8-bit keyed bijections (four rounds of S-box +
round-key per byte), consistent with the four identical S-box BRAMs. Encrypt and decrypt are exact inverses.
The complete key material was recovered as the four byte-lane substitution tables plus the raw S-box read out of
the BRAMs. <b>This design has zero diffusion</b> and is breakable one byte at a time; the heat-map below
(4000 random plaintexts per input bit) shows dependence confined to the 8&times;8 diagonal blocks
(cross-byte probability measured at <b>0.0000</b>).</p>
<div class="fig">{avrec}<div class="cap">Figure 1. Recovered cipher avalanche: no cross-byte diffusion (red = no dependence). Cross-byte P = 0.0000.</div></div>

<h2>3. What we implemented</h2>
<h3>3.1 Hardening the crypto core (keeping the same interface)</h3>
<p>To make the accelerator a credible strong cipher while preserving the exact pin interface and 4-cycle
<code>BUSY</code> timing (so the Trojan's stealth is untouched), we replaced the datapath with a
<b>12-round balanced Feistel network</b> &mdash; invertible by construction &mdash; that reuses the recovered
8-bit S-box for nonlinearity and adds a per-round linear diffusion
<code>t ^= rotl16(t,3) ^ rotl16(t,11)</code>, driven by a 32-bit hard-wired key expanded into 12 round keys.
The Python reference and the RTL agree bit-for-bit on encrypt, decrypt, and round-trip. The Strict Avalanche
Criterion matrix (Figure 2) is essentially ideal:</p>
<table>
<tr><th>Metric</th><th>Recovered cipher</th><th>Hardened cipher</th><th>Ideal</th></tr>
<tr><td>Avalanche, cross-byte P(flip)</td><td class="bad">0.000</td><td class="ok">{av['mean']:.3f} (all bits)</td><td>0.50</td></tr>
<tr><td>Avalanche matrix min / max</td><td>0.00 / 0.50</td><td class="ok">{av['min']:.3f} / {av['max']:.3f}</td><td>0.50 / 0.50</td></tr>
<tr><td>Diffusion (1 input bit affects)</td><td class="bad">8 output bits (1 byte)</td><td class="ok">~16 output bits (all 4 bytes)</td><td>16</td></tr>
<tr><td>Invertible (enc/dec)</td><td>yes</td><td class="ok">yes (3000/3000 round-trips)</td><td>yes</td></tr>
</table>
<div class="fig">{avsvg}<div class="cap">Figure 2. Hardened cipher avalanche: uniform ~0.50 everywhere &mdash; one input-bit flip changes ~half of all 32 output bits.</div></div>

<h3>3.2 The hardware Trojan</h3>
<div class="grid2">
<div class="kv"><b>Trigger</b> &mdash; a two-block &ldquo;knock&rdquo; in <i>encrypt</i> mode:
encrypt <code>0xDEADC0DE</code> (arms), then on the <b>very next</b> encryption <code>0xFEEDFACE</code> (fires).
Any other operand in between, or a knock in decrypt mode, silently disarms. Joint probability of accidental
activation: <b>2<sup>&minus;64</sup></b>.</div>
<div class="kv"><b>Payload</b> &mdash; precise key exfiltration. On the firing block the core parallel-loads the 32-bit
<code>SECRET_KEY</code> instead of the true ciphertext, so the next ordinary read-out streams the device key out
on <code>MISO</code>. Exactly one block is affected; the device is normal before and after.</div>
</div>
<p style="margin-top:6px"><b>Footprint:</b> a 2-bit FSM (<code>armed</code>, <code>fire</code>), two 32-bit equality
comparators and one 32-bit output mux. Synthesised for the iCE40 (<code>TROJAN_EN</code> 1 vs 0) the Trojan costs
<b>+2 flip-flops (105 vs 103)</b> and no extra BRAM &mdash; well under 1% overhead &mdash; and changes no timing.</p>

<h2>4. Proof: stealthy yet dangerous</h2>
<h3>4.1 Undetectable in normal operation</h3>
<p>The exploit testbench instantiates the shipped Trojaned core and an identical <b>clean twin</b>
(<code>TROJAN_EN=0</code>) and drives both in lock-step. For every non-trigger transaction &mdash; 8 hand-picked
cases plus 64 random encrypt/decrypt operations &mdash; the two cores produce <b>bit-identical</b> output. Lone
knocks, a broken knock sequence, and a decrypt-mode knock all stay identical to the clean core. There is no
timing, functional, or output difference an operator could observe.</p>
<h3>4.2 The exploit executes</h3>
<p>After <code>enc(0xDEADC0DE)</code> then <code>enc(0xFEEDFACE)</code>, the following read-out returns
<code>0xC0DECAFE</code> (the secret key) on the Trojaned core, while the clean core returns the real ciphertext
<code>0x3C2E0424</code> &mdash; the two diverge only at the trigger, then re-converge. Figure 3 shows the timing;
the full simulator transcript is reproduced verbatim below.</p>
<div class="fig">{wave}<div class="cap">Figure 3. Exploit timing (from tb_trojan): both knocks encrypt normally; the post-knock read-out streams the key on MISO.</div></div>
<h3>4.3 Verbatim simulation logs</h3>
<p><b>Hardened cipher + Trojan exploit</b> (<code>tb_trojan.v</code>):</p>
<pre>{sim_trojan}</pre>
<p><b>Reverse-engineering evidence</b> &mdash; recovered core reproduces the published vector (<code>tb_validate.v</code>):</p>
<pre>{sim_rec}</pre>

<h2>5. Severity: CVSS &amp; CWE</h2>
<table>
<tr><th>Item</th><th>Value</th></tr>
<tr><td>CVSS v3.1 base score</td><td><b>9.0 &mdash; Critical</b></td></tr>
<tr><td>Vector</td><td><code>AV:L/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:N</code></td></tr>
<tr><td>Rationale</td><td>An attacker who can submit chosen plaintexts to the accelerator (a normal capability of a
crypto service) fires the Trojan with two blocks and reads the key on the next transaction. Disclosure of the key
compromises the confidentiality <i>and</i> integrity of <b>all</b> data protected by it &mdash; a changed scope
beyond the vulnerable component. Variants: physical-bus access <code>AV:P</code> &rarr; 7.3; privileged-user
<code>PR:L</code> &rarr; 8.4.</td></tr>
</table>
<table>
<tr><th>CWE</th><th>Why it applies</th></tr>
<tr><td><b>CWE-506</b> Embedded Malicious Code</td><td>A deliberate malicious circuit added to the design that activates on a hidden condition.</td></tr>
<tr><td><b>CWE-912</b> Hidden Functionality</td><td>Undocumented behaviour (the knock trigger) not part of the specified interface.</td></tr>
<tr><td><b>CWE-200</b> Exposure of Sensitive Information</td><td>The secret key is transmitted to an unauthorized actor over MISO.</td></tr>
<tr><td><b>CWE-321</b> Use of Hard-coded Cryptographic Key</td><td>Underlying design flaw: the key is baked into the fabric, so a single leak clones every device with that bitstream.</td></tr>
</table>

<h2>6. Reproducing the exploit (in hardware and simulation)</h2>
<p><b>Simulation:</b> <code>./run_all.sh</code> re-derives the netlist, recovers the cipher (self-checking against
the published vector), designs and self-tests the hardened cipher, then runs both testbenches. <code>./run_all.sh sim</code>
skips re-derivation.</p>
<p><b>On hardware</b> (once a bitstream is generated from this RTL), any SPI controller triggers the leak with three
ordinary transactions: (1) encrypt block <code>0xDEADC0DE</code>; (2) encrypt block <code>0xFEEDFACE</code>;
(3) perform any 32-clock read-out &mdash; the bits shifted out on <code>MISO</code> are the device key, not a ciphertext.</p>
<p style="margin-top:14px"><small>All artifacts, RTL, testbenches, recovery scripts, and the full engineering
log (LOG.md) accompany this report. Hardware design and Trojan were generated with an AI agent (Anthropic Claude)
driving the open-source toolchain; see ai/ai_transcript.md.</small></p>
</body></html>"""
open(H+"/report.html","w",encoding="utf-8").write(body)
print("wrote report.html (%d bytes)"%len(body))
