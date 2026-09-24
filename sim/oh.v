
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0; wire busy,led,miso;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),
    .io_19_31_1(cs_n),.io_17_31_0(enc_dec),.io_18_31_1(start),
    .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1;#5;sck=0;#5; end endtask
  task shift(input [31:0] wd); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i];#2;sck=1;#5;sck=0;#5; end end endtask
  initial begin
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
    rst_n=0;pulse;rst_n=1;pulse;
    cs_n=0; shift(32'h80000000); cs_n=1; #1;
    $display("n1007=%b", dut.n1007);
    $display("n1015=%b", dut.n1015);
    $display("n1023=%b", dut.n1023);
    $display("n1024=%b", dut.n1024);
    $display("n1025=%b", dut.n1025);
    $display("n1034=%b", dut.n1034);
    $display("n1037=%b", dut.n1037);
    $display("n1038=%b", dut.n1038);
    $display("n1039=%b", dut.n1039);
    $display("n1042=%b", dut.n1042);
    $display("n109=%b", dut.n109);
    $display("n138=%b", dut.n138);
    $display("n152=%b", dut.n152);
    $display("n189=%b", dut.n189);
    $display("n212=%b", dut.n212);
    $display("n216=%b", dut.n216);
    $display("n219=%b", dut.n219);
    $display("n247=%b", dut.n247);
    $display("n351=%b", dut.n351);
    $display("n384=%b", dut.n384);
    $display("n390=%b", dut.n390);
    $display("n42=%b", dut.n42);
    $display("n450=%b", dut.n450);
    $display("n457=%b", dut.n457);
    $display("n461=%b", dut.n461);
    $display("n554=%b", dut.n554);
    $display("n566=%b", dut.n566);
    $display("n576=%b", dut.n576);
    $display("n577=%b", dut.n577);
    $display("n578=%b", dut.n578);
    $display("n579=%b", dut.n579);
    $display("n586=%b", dut.n586);
    $display("n587=%b", dut.n587);
    $display("n588=%b", dut.n588);
    $display("n601=%b", dut.n601);
    $display("n607=%b", dut.n607);
    $display("n609=%b", dut.n609);
    $display("n610=%b", dut.n610);
    $display("n619=%b", dut.n619);
    $display("n628=%b", dut.n628);
    $display("n635=%b", dut.n635);
    $display("n642=%b", dut.n642);
    $display("n662=%b", dut.n662);
    $display("n663=%b", dut.n663);
    $display("n698=%b", dut.n698);
    $display("n745=%b", dut.n745);
    $display("n776=%b", dut.n776);
    $display("n781=%b", dut.n781);
    $display("n798=%b", dut.n798);
    $display("n800=%b", dut.n800);
    $display("n810=%b", dut.n810);
    $display("n814=%b", dut.n814);
    $display("n840=%b", dut.n840);
    $display("n842=%b", dut.n842);
    $display("n844=%b", dut.n844);
    $display("n846=%b", dut.n846);
    $display("n887=%b", dut.n887);
    $display("n897=%b", dut.n897);
    $display("n898=%b", dut.n898);
    $display("n901=%b", dut.n901);
    $display("n907=%b", dut.n907);
    $display("n909=%b", dut.n909);
    $display("n910=%b", dut.n910);
    $display("n913=%b", dut.n913);
    $display("n915=%b", dut.n915);
    $display("n917=%b", dut.n917);
    $display("n921=%b", dut.n921);
    $display("n946=%b", dut.n946);
    $display("n972=%b", dut.n972);
    $display("n998=%b", dut.n998);
    $display("io_16_31_1=%b", dut.io_16_31_1);
    $finish;
  end
endmodule
