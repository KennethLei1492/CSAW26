`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso; reg [31:0] rx;
  // candidate: cs_n=io_17_31_0, enc_dec=io_19_31_1, start=io_18_31_1
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),
           .io_17_31_0(cs_n),.io_19_31_1(enc_dec),.io_18_31_1(start),
           .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1; #5; sck=0; #5; end endtask
  task shift(input [31:0] wd, input cap); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i]; #2; sck=1; #5; if(cap) rx[i]=miso; sck=0; #5; end
  end endtask
  initial begin
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
    rst_n=0; pulse; rst_n=1; pulse;
    cs_n=0; shift(32'h59C359C3,0); cs_n=1;
    cs_n=0; shift(32'h59C359C3,1); cs_n=1;
    $display("readback rx=%08x (expect 59c359c3)", rx);
    enc_dec=0; start=1; pulse; start=0;
    $display("after start busy=%b", busy);
    repeat(7) pulse;
    $display("after 7 pulses busy=%b", busy);
    cs_n=0; shift(32'h59C359C3,1); cs_n=1;
    $display("CIPHERTEXT rx=%08x (expect 9cd84392)", rx);
    $finish;
  end
endmodule
