
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0; wire busy,led,miso; reg [31:0] R;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),
    .io_17_31_0(cs_n),.io_19_31_1(enc_dec),.io_18_31_1(start),
    .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1;#5;sck=0;#5; end endtask
  task shift(input [31:0] wd); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i];#2;sck=1;#5;sck=0;#5; end end endtask
  task reset; begin rst_n=0;pulse;rst_n=1;pulse; end endtask
  task proc(input [31:0] pt, input ed, output [31:0] res); begin
    reset; enc_dec=ed;
    cs_n=0; shift(pt); cs_n=1;
    start=1; pulse; start=0; repeat(6) pulse; #1; res = (dut.n628<<0) | (dut.n390<<1) | (dut.n619<<2) | (dut.n384<<3) | (dut.n610<<4) | (dut.n607<<5) | (dut.n609<<6) | (dut.n601<<7) | (dut.n587<<8) | (dut.n578<<9) | (dut.n579<<10) | (dut.n577<<11) | (dut.n698<<12) | (dut.n781<<13) | (dut.n776<<14) | (dut.n897<<15) | (dut.n898<<16) | (dut.n1015<<17) | (dut.n1024<<18) | (dut.n998<<19) | (dut.n1034<<20) | (dut.n907<<21) | (dut.n1039<<22) | (dut.n1038<<23) | (dut.n910<<24) | (dut.n921<<25) | (dut.n915<<26) | (dut.n810<<27) | (dut.n814<<28) | (dut.n798<<29) | (dut.n917<<30) | (dut.n800<<31);
  end endtask
  reg [31:0] e0,e1,d0,d1,rt0,rt1;
  initial begin
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
    proc(32'h59C359C3,0,e0); $display("ENC(ed=0) 59c359c3 -> %08x",e0);
    proc(32'h59C359C3,1,e1); $display("ENC(ed=1) 59c359c3 -> %08x",e1);
    proc(e0,1,rt0); $display("  dec(ed=1) of e0 -> %08x  %s",rt0, (rt0==32'h59C359C3)?"ROUNDTRIP OK":"");
    proc(e1,0,rt1); $display("  dec(ed=0) of e1 -> %08x  %s",rt1, (rt1==32'h59C359C3)?"ROUNDTRIP OK":"");
    proc(32'h9CD84392,0,d0); $display("proc(ed=0) 9cd84392 -> %08x",d0);
    proc(32'h9CD84392,1,d1); $display("proc(ed=1) 9cd84392 -> %08x",d1);
    $finish;
  end
endmodule
