
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso;
  reg [31:0] rxpre, rxpost;
  chip dut(.io_9_31_1(sck),.io_19_31_1(enc_dec),.io_17_31_0(start),.io_16_31_0(cs_n),
           .io_13_31_1(mosi),.io_18_31_1(rst_n),.io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
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
    cs_n=0; shift_io(32'h59c359c3,0); cs_n=1;
    cs_n=0; shift_io(32'h59c359c3,1); cs_n=1;
    $display("RB pre=%08x post=%08x", rxpre, rxpost);
    start=1; pulse; start=0; repeat(7) pulse;
    cs_n=0; shift_io(32'h59c359c3,1); cs_n=1;
    $display("CRYPT pre=%08x post=%08x busy=%b", rxpre, rxpost, busy);
    $finish;
  end
endmodule
