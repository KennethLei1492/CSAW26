import itertools, subprocess, re
PT=0x59C359C3
# fixed: mosi=io_16_31_0, rst_n=io_13_31_1 ; remaining pins:
REM=["io_19_31_1","io_17_31_0","io_18_31_1"]
ROLES=["cs_n","start","enc_dec"]
TB=r'''
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso; reg [31:0] rx;
  chip dut(.io_9_31_1(sck),.io_16_31_0(mosi),.io_13_31_1(rst_n),
    .io_19_31_1(__P0__),.io_17_31_0(__P1__),.io_18_31_1(__P2__),
    .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1; #5; sck=0; #5; end endtask
  task shift(input [31:0] wd, input cap); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i]; #2; sck=1; #5; if(cap) rx[i]=miso; sck=0; #5; end
  end endtask
  initial begin
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
    rst_n=0; pulse; rst_n=1; pulse;
    enc_dec=0;
    cs_n=0; shift(32'h__PT__,0); cs_n=1;
    $display("after load busy=%b",busy);
    enc_dec=0; mosi=0;
    start=1; $display("start=1 pre-edge busy=%b",busy); pulse; start=0;
    $display("after start pulse busy=%b",busy);
    repeat(6) begin pulse; $display("  exec pulse busy=%b",busy); end
    cs_n=0; shift(32'h__PT__,1); cs_n=1;
    $display("READOUT rx=%08x",rx);
    $finish;
  end
endmodule
'''
for perm in itertools.permutations(range(3)):
    conn={ROLES[perm[i]]:REM[i] for i in range(3)}
    # build P0,P1,P2 = role assigned to io_19,io_17,io_18
    inv={REM[i]:ROLES[perm[i]] for i in range(3)}
    tb=TB.replace("__P0__",inv["io_19_31_1"]).replace("__P1__",inv["io_17_31_0"]).replace("__P2__",inv["io_18_31_1"]).replace("__PT__","%08x"%PT)
    open("tbd.v","w").write(tb)
    r=subprocess.run(["iverilog","-g2012","-DNO_ICE40_DEFAULT_ASSIGNMENTS","-o","d.vvp","tbd.v","recovered_netlist.v","cells_sim.v"],capture_output=True,text=True)
    if r.returncode!=0: print("compile fail"); continue
    r=subprocess.run(["vvp","d.vvp"],capture_output=True,text=True,timeout=60)
    print("==== io19=%s io17=%s io18=%s ===="%(inv["io_19_31_1"],inv["io_17_31_0"],inv["io_18_31_1"]))
    print(r.stdout.strip())
