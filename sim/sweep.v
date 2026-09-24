`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso; reg [31:0] rxpre, rxpost;
  integer N;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),
           .io_19_31_1(cs_n),.io_17_31_0(enc_dec),.io_18_31_1(start),
           .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1; #5; sck=0; #5; end endtask
  task shiftc(input [31:0] wd); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i]; #2; rxpre[i]=miso; sck=1; #5; rxpost[i]=miso; sck=0; #5; end
  end endtask
  task loadpt; begin
    rst_n=0; pulse; rst_n=1; pulse;
    cs_n=0; shiftc(32'h59C359C3); cs_n=1;
    cs_n=0; shiftc(32'h59C359C3); cs_n=1;
  end endtask
  initial begin
    for (N=0; N<=12; N=N+1) begin
      sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
      loadpt;
      enc_dec=0; start=1; pulse; start=0;
      repeat(N) pulse;
      cs_n=0; shiftc(32'h59C359C3); cs_n=1;
      $display("N=%0d busy=%b rxpre=%08x rxpost=%08x", N, busy, rxpre, rxpost);
    end
    $finish;
  end
endmodule
