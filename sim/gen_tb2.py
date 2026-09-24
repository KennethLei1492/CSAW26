import itertools, subprocess, re

PHYS = ["io_19_31_1","io_17_31_0","io_16_31_0","io_13_31_1","io_18_31_1"]
LOGI = ["rst_n","mosi","cs_n","start","enc_dec"]
PT = 0x59C359C3
CT = 0x9CD84392

TB_TMPL = r'''
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso;
  reg [31:0] rxpre, rxpost;
  chip dut(.io_9_31_1(sck),.io_19_31_1(__A__),.io_17_31_0(__B__),.io_16_31_0(__C__),
           .io_13_31_1(__D__),.io_18_31_1(__E__),.io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1; #5; sck=0; #5; end endtask
  task shift_io(input [31:0] wd, input cap);
    integer i; begin
      for(i=31;i>=0;i=i-1) begin
        mosi = wd[i]; #2;
        if(cap) rxpre[i]=miso;
        sck=1; #5;
        if(cap) rxpost[i]=miso;
        sck=0; #5;
      end
    end
  endtask
  initial begin
    sck=0; rst_n=1; cs_n=1; start=0; enc_dec=0; mosi=0; #10;
    rst_n=0; pulse; rst_n=1; pulse;
    enc_dec=0;
    cs_n=0; shift_io(32'h__PT__,0); cs_n=1;
    cs_n=0; shift_io(32'h__PT__,1); cs_n=1;
    $display("RB pre=%08x post=%08x", rxpre, rxpost);
    start=1; pulse; start=0; repeat(7) pulse;
    cs_n=0; shift_io(32'h__PT__,1); cs_n=1;
    $display("CRYPT pre=%08x post=%08x busy=%b", rxpre, rxpost, busy);
    $finish;
  end
endmodule
'''
def run(conn):
    tb=TB_TMPL
    for k,v in conn.items(): tb=tb.replace("__%s__"%k, v)
    tb=tb.replace("__PT__","%08x"%PT)
    open("tb_perm.v","w").write(tb)
    r=subprocess.run(["iverilog","-g2012","-DNO_ICE40_DEFAULT_ASSIGNMENTS","-o","p.vvp","tb_perm.v","recovered_netlist.v","cells_sim.v"],capture_output=True,text=True)
    if r.returncode!=0: return None
    r=subprocess.run(["vvp","p.vvp"],capture_output=True,text=True,timeout=60)
    return r.stdout

out=open("results.txt","w")
hits=[]
for perm in itertools.permutations(range(5)):
    conn={"A":LOGI[perm[0]],"B":LOGI[perm[1]],"C":LOGI[perm[2]],"D":LOGI[perm[3]],"E":LOGI[perm[4]]}
    # map A..E to phys ports order
    connmap={"A":conn["A"],"B":conn["B"],"C":conn["C"],"D":conn["D"],"E":conn["E"]}
    s=run(connmap)
    if not s: continue
    rb=re.search(r"RB pre=(\w+) post=(\w+)",s)
    cr=re.search(r"CRYPT pre=(\w+) post=(\w+)",s)
    tag=" ".join("%s=%s"%(PHYS[i],LOGI[perm[i]]) for i in range(5))
    line="%s | RB pre=%s post=%s | CR pre=%s post=%s"%(tag,rb.group(1),rb.group(2),cr.group(1),cr.group(2))
    out.write(line+"\n")
    ptx="%08x"%PT; ctx="%08x"%CT
    if rb.group(1)==ptx or rb.group(2)==ptx:
        hits.append("RBOK "+line)
        if cr.group(1)==ctx or cr.group(2)==ctx:
            hits.append("FULLMATCH "+line)
out.flush()
print("\n".join(hits) if hits else "NO RB MATCH")
print("total lines:", sum(1 for _ in open("results.txt")))
