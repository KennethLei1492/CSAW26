`timescale 1ns/1ps
module tb_validate;
  reg SCK=0, RST_N=1, MOSI=0, NORM_CS_N=1, START=0, ENC_DEC=0;
  wire MISO, BUSY, ICE_LED;
  reg [31:0] rx;

  spi_crypto_top dut(.SCK(SCK),.RST_N(RST_N),.MOSI(MOSI),.MISO(MISO),
    .NORM_CS_N(NORM_CS_N),.START(START),.ENC_DEC(ENC_DEC),.BUSY(BUSY),.ICE_LED(ICE_LED));

  task tick; begin #2; SCK=1; #5; SCK=0; #3; end endtask
  task reset; begin RST_N=0; tick; RST_N=1; tick; end endtask
  task xfer(input [31:0] wd, input cap); integer i; begin
    NORM_CS_N=0;
    for(i=31;i>=0;i=i-1) begin MOSI=wd[i]; #2; SCK=1; #5; if(cap) rx[i]=MISO; SCK=0; #3; end
    NORM_CS_N=1; MOSI=0;
  end endtask
  task run_op(input [31:0] din, input ed, output [31:0] dout); begin
    reset; ENC_DEC=ed;
    xfer(din,1'b0);            // load operand
    START=1; tick; START=0;    // pulse start
    repeat(6) tick;            // finish (BUSY window)
    xfer(32'h0, 1'b1);         // read result on MISO
    dout = rx;
  end endtask

  reg [31:0] ct, pt2; integer errors;
  initial begin
    errors=0;
    run_op(32'h59C359C3, 1'b0, ct);
    $display("encrypt(59C359C3) = %08x  (expect 9CD84392)", ct);
    if (ct !== 32'h9CD84392) begin errors=errors+1; $display("  FAIL"); end else $display("  PASS");
    run_op(ct, 1'b1, pt2);
    $display("decrypt(%08x) = %08x  (expect 59C359C3)", ct, pt2);
    if (pt2 !== 32'h59C359C3) begin errors=errors+1; $display("  FAIL"); end else $display("  PASS");
    if (errors==0) $display("VALIDATE: ALL PASS"); else $display("VALIDATE: %0d FAIL", errors);
    $finish;
  end
endmodule
