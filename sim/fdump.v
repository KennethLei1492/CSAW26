
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0; wire busy,led,miso; integer cyc;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),.io_19_31_1(enc_dec),.io_17_31_0(cs_n),.io_18_31_1(start),.io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task tick; begin #2; sck=1; #5; sck=0; #3; end endtask
  task shift(input [31:0] wd); integer i; begin for(i=31;i>=0;i=i-1) begin mosi=wd[i]; tick; end end endtask
  task dumpall; begin
      $display("C%0d n1007=%b",cyc,dut.n1007);
      $display("C%0d n1015=%b",cyc,dut.n1015);
      $display("C%0d n1023=%b",cyc,dut.n1023);
      $display("C%0d n1024=%b",cyc,dut.n1024);
      $display("C%0d n1025=%b",cyc,dut.n1025);
      $display("C%0d n1034=%b",cyc,dut.n1034);
      $display("C%0d n1037=%b",cyc,dut.n1037);
      $display("C%0d n1038=%b",cyc,dut.n1038);
      $display("C%0d n1039=%b",cyc,dut.n1039);
      $display("C%0d n1042=%b",cyc,dut.n1042);
      $display("C%0d n109=%b",cyc,dut.n109);
      $display("C%0d n138=%b",cyc,dut.n138);
      $display("C%0d n152=%b",cyc,dut.n152);
      $display("C%0d n189=%b",cyc,dut.n189);
      $display("C%0d n212=%b",cyc,dut.n212);
      $display("C%0d n216=%b",cyc,dut.n216);
      $display("C%0d n219=%b",cyc,dut.n219);
      $display("C%0d n247=%b",cyc,dut.n247);
      $display("C%0d n351=%b",cyc,dut.n351);
      $display("C%0d n384=%b",cyc,dut.n384);
      $display("C%0d n390=%b",cyc,dut.n390);
      $display("C%0d n42=%b",cyc,dut.n42);
      $display("C%0d n450=%b",cyc,dut.n450);
      $display("C%0d n457=%b",cyc,dut.n457);
      $display("C%0d n461=%b",cyc,dut.n461);
      $display("C%0d n554=%b",cyc,dut.n554);
      $display("C%0d n566=%b",cyc,dut.n566);
      $display("C%0d n576=%b",cyc,dut.n576);
      $display("C%0d n577=%b",cyc,dut.n577);
      $display("C%0d n578=%b",cyc,dut.n578);
      $display("C%0d n579=%b",cyc,dut.n579);
      $display("C%0d n586=%b",cyc,dut.n586);
      $display("C%0d n587=%b",cyc,dut.n587);
      $display("C%0d n588=%b",cyc,dut.n588);
      $display("C%0d n601=%b",cyc,dut.n601);
      $display("C%0d n607=%b",cyc,dut.n607);
      $display("C%0d n609=%b",cyc,dut.n609);
      $display("C%0d n610=%b",cyc,dut.n610);
      $display("C%0d n619=%b",cyc,dut.n619);
      $display("C%0d n628=%b",cyc,dut.n628);
      $display("C%0d n635=%b",cyc,dut.n635);
      $display("C%0d n642=%b",cyc,dut.n642);
      $display("C%0d n662=%b",cyc,dut.n662);
      $display("C%0d n663=%b",cyc,dut.n663);
      $display("C%0d n698=%b",cyc,dut.n698);
      $display("C%0d n745=%b",cyc,dut.n745);
      $display("C%0d n776=%b",cyc,dut.n776);
      $display("C%0d n781=%b",cyc,dut.n781);
      $display("C%0d n798=%b",cyc,dut.n798);
      $display("C%0d n800=%b",cyc,dut.n800);
      $display("C%0d n810=%b",cyc,dut.n810);
      $display("C%0d n814=%b",cyc,dut.n814);
      $display("C%0d n840=%b",cyc,dut.n840);
      $display("C%0d n842=%b",cyc,dut.n842);
      $display("C%0d n844=%b",cyc,dut.n844);
      $display("C%0d n846=%b",cyc,dut.n846);
      $display("C%0d n887=%b",cyc,dut.n887);
      $display("C%0d n897=%b",cyc,dut.n897);
      $display("C%0d n898=%b",cyc,dut.n898);
      $display("C%0d n901=%b",cyc,dut.n901);
      $display("C%0d n907=%b",cyc,dut.n907);
      $display("C%0d n909=%b",cyc,dut.n909);
      $display("C%0d n910=%b",cyc,dut.n910);
      $display("C%0d n913=%b",cyc,dut.n913);
      $display("C%0d n915=%b",cyc,dut.n915);
      $display("C%0d n917=%b",cyc,dut.n917);
      $display("C%0d n921=%b",cyc,dut.n921);
      $display("C%0d n946=%b",cyc,dut.n946);
      $display("C%0d n972=%b",cyc,dut.n972);
      $display("C%0d n998=%b",cyc,dut.n998);
      $display("C%0d io_16_31_1=%b",cyc,dut.io_16_31_1);
  end endtask
  initial begin
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
    rst_n=0; tick; rst_n=1; tick; enc_dec=0;
    cs_n=0; shift(32'hdeadbeef); cs_n=1; #3;
    mosi=0; start=1; cyc=0; dumpall;
    tick; start=0;
    for(cyc=1;cyc<=5;cyc=cyc+1) begin #1; dumpall; tick; end
    $finish;
  end
endmodule
