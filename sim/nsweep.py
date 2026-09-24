import subprocess, re
CT="9cd84392"
maps = {
 "A cs=io19,start=io17,enc=io18": ("cs_n","start","enc_dec"),
 "B start=io19,cs=io17,enc=io18": ("start","cs_n","enc_dec"),
 "C enc=io19,cs=io17,start=io18": ("enc_dec","cs_n","start"),
}
TB=r'''
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso; reg [31:0] rx; integer N;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),
    .io_19_31_1(__P0__),.io_17_31_0(__P1__),.io_18_31_1(__P2__),
    .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1; #5; sck=0; #5; end endtask
  task shift(input [31:0] wd, input cap); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i]; #2; sck=1; #5; if(cap) rx[i]=miso; sck=0; #5; end
  end endtask
  initial begin
    for(N=0;N<=10;N=N+1) begin
      sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
      rst_n=0; pulse; rst_n=1; pulse;
      cs_n=0; shift(32'h59C359C3,0); cs_n=1;
      cs_n=0; shift(32'h59C359C3,1); cs_n=1;
      enc_dec=0; start=1; pulse; start=0; repeat(N) pulse;
      cs_n=0; shift(32'h59C359C3,1); cs_n=1;
      $display("N=%0d rx=%08x busy=%b", N, rx, busy);
    end
    $finish;
  end
endmodule
'''
for name,(p0,p1,p2) in maps.items():
    tb=TB.replace("__P0__",p0).replace("__P1__",p1).replace("__P2__",p2)
    open("ns.v","w").write(tb)
    subprocess.run(["iverilog","-g2012","-DNO_ICE40_DEFAULT_ASSIGNMENTS","-o","ns.vvp","ns.v","recovered_por.v","cells_sim.v"],capture_output=True,text=True)
    s=subprocess.run(["vvp","ns.vvp"],capture_output=True,text=True,timeout=120).stdout
    print("====",name,"====")
    for line in s.strip().splitlines():
        mark=" <<<< CT" if CT in line else ""
        print(" ",line,mark)
