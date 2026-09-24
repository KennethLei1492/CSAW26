
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0; wire busy,led,miso; reg [7:0] A; reg [31:0] DIN; integer c;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),.io_19_31_1(enc_dec),.io_17_31_0(cs_n),.io_18_31_1(start),.io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task tick; begin #2; sck=1; #5; sck=0; #3; end endtask
  task shift(input [31:0] wd); integer i; begin for(i=31;i>=0;i=i-1) begin mosi=wd[i]; tick; end end endtask
  initial begin
    if(!$value$plusargs("din=%h",DIN))DIN=0;
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
    rst_n=0; tick; rst_n=1; tick; enc_dec=0;
    cs_n=0; shift(DIN); cs_n=1; #3;
    A=(dut.n620<<0)|(dut.n766<<1)|(dut.n616<<2)|(dut.n600<<3)|(dut.n612<<4)|(dut.n767<<5)|(dut.n768<<6)|(dut.n626<<7); $display("r0 %02x",A);
    mosi=0; start=1; tick; start=0; #1; A=(dut.n620<<0)|(dut.n766<<1)|(dut.n616<<2)|(dut.n600<<3)|(dut.n612<<4)|(dut.n767<<5)|(dut.n768<<6)|(dut.n626<<7); $display("r1 %02x",A);
    for(c=2;c<=5;c=c+1) begin tick; #1; A=(dut.n620<<0)|(dut.n766<<1)|(dut.n616<<2)|(dut.n600<<3)|(dut.n612<<4)|(dut.n767<<5)|(dut.n768<<6)|(dut.n626<<7); $display("r%0d %02x",c,A); end
    $finish;
  end
endmodule
