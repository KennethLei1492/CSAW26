
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0; wire busy,led,miso; reg [31:0] R; integer c;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),.io_19_31_1(enc_dec),.io_17_31_0(cs_n),.io_18_31_1(start),.io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task tick; begin #2; sck=1; #5; sck=0; #3; end endtask   // setup 2, high 5, low-hold 3
  task shiftbit(input b); begin mosi=b; tick; end endtask
  task shift(input [31:0] wd); integer i; begin for(i=31;i>=0;i=i-1) shiftbit(wd[i]); end endtask
  initial begin
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=1;mosi=0;#10;
    rst_n=0; tick; rst_n=1; tick;
    cs_n=0; shift(32'h01010101); cs_n=1; #3; R=(dut.n628<<0)|(dut.n390<<1)|(dut.n619<<2)|(dut.n384<<3)|(dut.n610<<4)|(dut.n607<<5)|(dut.n609<<6)|(dut.n601<<7)|(dut.n587<<8)|(dut.n578<<9)|(dut.n579<<10)|(dut.n577<<11)|(dut.n698<<12)|(dut.n781<<13)|(dut.n776<<14)|(dut.n897<<15)|(dut.n898<<16)|(dut.n1015<<17)|(dut.n1024<<18)|(dut.n998<<19)|(dut.n1034<<20)|(dut.n907<<21)|(dut.n1039<<22)|(dut.n1038<<23)|(dut.n910<<24)|(dut.n921<<25)|(dut.n915<<26)|(dut.n810<<27)|(dut.n814<<28)|(dut.n798<<29)|(dut.n917<<30)|(dut.n800<<31); $display("load %08x",R);
    mosi=0;
    start=1; tick; start=0;    // START high exactly one tick, cleared while sck=0
    for(c=1;c<=10;c=c+1) begin tick; #1; R=(dut.n628<<0)|(dut.n390<<1)|(dut.n619<<2)|(dut.n384<<3)|(dut.n610<<4)|(dut.n607<<5)|(dut.n609<<6)|(dut.n601<<7)|(dut.n587<<8)|(dut.n578<<9)|(dut.n579<<10)|(dut.n577<<11)|(dut.n698<<12)|(dut.n781<<13)|(dut.n776<<14)|(dut.n897<<15)|(dut.n898<<16)|(dut.n1015<<17)|(dut.n1024<<18)|(dut.n998<<19)|(dut.n1034<<20)|(dut.n907<<21)|(dut.n1039<<22)|(dut.n1038<<23)|(dut.n910<<24)|(dut.n921<<25)|(dut.n915<<26)|(dut.n810<<27)|(dut.n814<<28)|(dut.n798<<29)|(dut.n917<<30)|(dut.n800<<31); $display("after %0d ticks: %08x busy=%b",c,R,busy); end
    $finish;
  end
endmodule
