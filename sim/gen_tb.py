import itertools, subprocess, os, sys, re

PHYS = ["io_19_31_1","io_17_31_0","io_16_31_0","io_13_31_1","io_18_31_1"]
LOGI = ["rst_n","mosi","cs_n","start","enc_dec"]
PT = 0x59C359C3
CT = 0x9CD84392

TB_TMPL = r'''
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso;
  reg [31:0] rxA, rxB;

  chip dut(
    .io_9_31_1(sck),
    .io_19_31_1({A}),
    .io_17_31_0({B}),
    .io_16_31_0({C}),
    .io_13_31_1({D}),
    .io_18_31_1({E}),
    .io_8_31_1(busy),
    .io_19_31_0(led),
    .io_16_31_1(miso)
  );

  task pulse; begin sck=1; #5; sck=0; #5; end endtask

  task shift_io(input [31:0] wd, input capture);
    integer i; begin
      for(i=31;i>=0;i=i-1) begin
        mosi = wd[i]; #2;
        sck=1; #5;
        if(capture) rxB[i] = miso;
        sck=0; #5;
      end
    end
  endtask

  initial begin
    sck=0; rst_n=1; cs_n=1; start=0; enc_dec=0; mosi=0; #10;
    // reset: RST_N=0; pulse; RST_N=1; pulse
    rst_n=0; pulse; rst_n=1; pulse;
    // load plaintext
    enc_dec=0;
    cs_n=0; shift_io(32'h{PTHEX},0); cs_n=1;
    // readback self-test
    cs_n=0; shift_io(32'h{PTHEX},1); cs_n=1;
    rxA = rxB;
    // execute
    start=1; pulse; start=0;
    repeat(7) pulse;
    // readout ciphertext
    cs_n=0; shift_io(32'h{PTHEX},1); cs_n=1;
    $display("RESULT RX=%08x CT=%08x BUSYend=%b", rxA, rxB, busy);
    $finish;
  end
endmodule
'''

def build(perm):
    # perm maps LOGI index -> which phys slot; we invert: for each phys port, which logical
    m = dict(zip(perm, LOGI))  # perm is ordering of PHYS
    conn = {PHYS[i]: LOGI[perm[i]] for i in range(5)}
    return conn

results=[]
best=None
for perm in itertools.permutations(range(5)):
    conn = {PHYS[i]: LOGI[perm[i]] for i in range(5)}
    tb = TB_TMPL
    tb = tb.replace("{A}",conn["io_19_31_1"]).replace("{B}",conn["io_17_31_0"])
    tb = tb.replace("{C}",conn["io_16_31_0"]).replace("{D}",conn["io_13_31_1"])
    tb = tb.replace("{E}",conn["io_18_31_1"])
    tb = tb.replace("{PTHEX}", "%08x"%PT)
    with open("tb_perm.v","w") as f: f.write(tb)
    r=subprocess.run(["iverilog","-g2012","-DNO_ICE40_DEFAULT_ASSIGNMENTS","-o","p.vvp","tb_perm.v","recovered_netlist.v","cells_sim.v"],capture_output=True,text=True)
    if r.returncode!=0:
        continue
    r=subprocess.run(["vvp","p.vvp"],capture_output=True,text=True,timeout=60)
    m=re.search(r"RX=([0-9a-fx]+) CT=([0-9a-fx]+)",r.stdout)
    if not m: 
        continue
    rx,ct=m.group(1),m.group(2)
    tag=" ".join("%s=%s"%(PHYS[i],LOGI[perm[i]]) for i in range(5))
    if ct=="%08x"%CT:
        print("*** CT MATCH ***", tag, "RX=",rx,"CT=",ct)
        best=(tag,rx,ct)
    if rx=="%08x"%PT and ct=="%08x"%CT:
        print("### FULL MATCH (RX+CT) ###", tag)
print("done. best=",best)
