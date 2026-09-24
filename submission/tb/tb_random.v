`timescale 1ns/1ps
module tb_random;
  reg SCK=0, RST_N=1, MOSI=0, NORM_CS_N=1, START=0, ENC_DEC=0;
  wire MISO, BUSY, ICE_LED; reg [31:0] rx,din; reg ed;
  spi_crypto_top dut(.SCK(SCK),.RST_N(RST_N),.MOSI(MOSI),.MISO(MISO),.NORM_CS_N(NORM_CS_N),.START(START),.ENC_DEC(ENC_DEC),.BUSY(BUSY),.ICE_LED(ICE_LED));
  task tick; begin #2; SCK=1; #5; SCK=0; #3; end endtask
  task xfer(input [31:0] wd, input cap); integer i; begin
    NORM_CS_N=0; for(i=31;i>=0;i=i-1) begin MOSI=wd[i]; #2; SCK=1; #5; if(cap) rx[i]=MISO; SCK=0; #3; end NORM_CS_N=1; MOSI=0; end endtask
  integer k;
  initial begin
    if(!$value$plusargs("din=%h",din))din=0; if(!$value$plusargs("ed=%d",ed))ed=0;
    RST_N=0; tick; RST_N=1; tick; ENC_DEC=ed;
    xfer(din,1'b0); START=1; tick; START=0; repeat(6) tick; xfer(32'h0,1'b1);
    $display("OUT=%08x", rx); $finish;
  end
endmodule
