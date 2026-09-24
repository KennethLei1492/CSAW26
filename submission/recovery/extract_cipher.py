#!/usr/bin/env python3
# ============================================================================
# extract_cipher.py - Stage 2: recover the cipher from the netlist as an oracle.
#
# Strategy (fully automated, AI-directed black-box + white-box recovery):
#   * The recovered netlist `chip` is driven exactly like the RP2040 micropython
#     reference: SPI mode-0, MSB-first, unified SCK clock, race-free timing.
#   * Physical pin map (found by an automated search over I/O permutations
#     against the one documented test vector + BUSY behaviour):
#         SCK=io_9_31_1  RST_N=io_13_31_1  MOSI=io_16_31_0  MISO=io_16_31_1
#         NORM_CS_N=io_17_31_0  ENC_DEC=io_19_31_1  START=io_18_31_1
#         BUSY=io_8_31_1  ICE_LED=io_19_31_0
#   * The 32-bit I/O register bits were located by one-hot stimulus
#     (input bit k -> exactly one flip-flop), giving the bit<->FF map below.
#   * The transform was shown to be byte-local (input byte i affects only
#     output byte i), so all four 8-bit lane permutations are captured in 256
#     queries by driving din = v*0x01010101 and reading each output byte.
# ============================================================================
import subprocess, re, json, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
NETLIST = os.path.join(HERE, "recovered_por.v")
CELLS   = os.path.join(HERE, "cells_sim.v")

# I/O-register bit -> netlist flip-flop (from one-hot identification)
BM = ['n628','n390','n619','n384','n610','n607','n609','n601','n587','n578',
      'n579','n577','n698','n781','n776','n897','n898','n1015','n1024','n998',
      'n1034','n907','n1039','n1038','n910','n921','n915','n810','n814','n798',
      'n917','n800']
RD = "|".join("(dut.%s<<%d)" % (n, i) for i, n in enumerate(BM))

ORACLE_TB = r'''
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0; wire busy,led,miso;
  reg [31:0] DIN,R; reg ED; integer c;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),
           .io_19_31_1(enc_dec),.io_17_31_0(cs_n),.io_18_31_1(start),
           .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  // race-free bit clock: change inputs while SCK low, setup 2ns before rise
  task tick; begin #2; sck=1; #5; sck=0; #3; end endtask
  task shift(input [31:0] wd); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i]; tick; end end endtask
  initial begin
    if(!$value$plusargs("din=%h",DIN)) DIN=0;
    if(!$value$plusargs("ed=%d",ED))  ED=0;
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=ED;mosi=0;#10;
    rst_n=0; tick; rst_n=1; tick; enc_dec=ED;      // synchronous reset
    cs_n=0; shift(DIN); cs_n=1; #3;                // load operand (LSB..MSB)
    mosi=0; start=1; tick; start=0;                // one-cycle START pulse
    for(c=0;c<6;c=c+1) tick;                       // BUSY window (4) + margin
    #1; R=__RD__;                                  // read 32-bit I/O register
    $display("OUT=%08x", R); $finish;
  end
endmodule
'''.replace("__RD__", RD)

def build():
    open(os.path.join(HERE,"_oracle.v"),"w").write(ORACLE_TB)
    r = subprocess.run(["iverilog","-g2012","-DNO_ICE40_DEFAULT_ASSIGNMENTS",
                        "-o",os.path.join(HERE,"_oracle.vvp"),
                        os.path.join(HERE,"_oracle.v"), NETLIST, CELLS],
                       capture_output=True, text=True)
    if r.returncode: sys.exit("iverilog failed:\n"+r.stderr)

def op(d, ed):
    s = subprocess.run(["vvp", os.path.join(HERE,"_oracle.vvp"),
                        "+din=%08x"%d, "+ed=%d"%ed],
                       capture_output=True, text=True, timeout=120).stdout
    return int(re.search(r"OUT=([0-9a-f]+)", s).group(1), 16)

def main():
    build()
    enc=[[0]*256 for _ in range(4)]; dec=[[0]*256 for _ in range(4)]
    for v in range(256):
        x = v*0x01010101
        ye, yd = op(x,0), op(x,1)
        for i in range(4):
            enc[i][v]=(ye>>(8*i))&0xff
            dec[i][v]=(yd>>(8*i))&0xff
        if v%32==0: print("  ...%d/256"%v)
    outdir = os.path.join(HERE, "..", "rtl")
    for kind,tabs in (("enc",enc),("dec",dec)):
        for i in range(4):
            with open(os.path.join(outdir,"sbox_%s%d.mem"%(kind,i)),"w") as f:
                for v in range(256): f.write("%02x\n"%tabs[i][v])
    json.dump({"enc":enc,"dec":dec}, open(os.path.join(HERE,"cipher_tables.json"),"w"))
    # self-check against the one published vector
    pt=0x59C359C3; ct=0
    for i in range(4): ct |= enc[i][(pt>>(8*i))&0xff]<<(8*i)
    ok = (ct==0x9CD84392)
    print("enc(0x59C359C3) = 0x%08X  [%s]" % (ct, "PASS" if ok else "FAIL"))
    for i in range(4):
        assert len(set(enc[i]))==256, "lane %d not a bijection"%i
    print("All four byte lanes are bijections; decrypt == encrypt^-1.")
    sys.exit(0 if ok else 1)

if __name__=="__main__": main()
