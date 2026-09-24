
`timescale 1ns/1ps
module tb;
  reg sck=0, rst_n=1, mosi=0, cs_n=1, start=0, enc_dec=0;
  wire busy, led, miso;
  chip dut(.io_9_31_1(sck),.io_13_31_1(rst_n),.io_16_31_0(mosi),
    .io_19_31_1(cs_n),.io_17_31_0(enc_dec),.io_18_31_1(start),
    .io_8_31_1(busy),.io_19_31_0(led),.io_16_31_1(miso));
  task pulse; begin sck=1; #5; sck=0; #5; end endtask
  task shift(input [31:0] wd); integer i; begin
    for(i=31;i>=0;i=i-1) begin mosi=wd[i]; #2; sck=1; #5; sck=0; #5; end
  end endtask
  initial begin
    sck=0;rst_n=1;cs_n=1;start=0;enc_dec=0;mosi=0;#10;
    rst_n=0; pulse; rst_n=1; pulse;
    cs_n=0; shift(32'h59C359C3); cs_n=1;
    #1;
    $display("FF n1007 = %b", dut.n1007);
    $display("FF n1015 = %b", dut.n1015);
    $display("FF n1023 = %b", dut.n1023);
    $display("FF n1024 = %b", dut.n1024);
    $display("FF n1025 = %b", dut.n1025);
    $display("FF n1034 = %b", dut.n1034);
    $display("FF n1037 = %b", dut.n1037);
    $display("FF n1038 = %b", dut.n1038);
    $display("FF n1039 = %b", dut.n1039);
    $display("FF n1042 = %b", dut.n1042);
    $display("FF n109 = %b", dut.n109);
    $display("FF n138 = %b", dut.n138);
    $display("FF n152 = %b", dut.n152);
    $display("FF n189 = %b", dut.n189);
    $display("FF n212 = %b", dut.n212);
    $display("FF n216 = %b", dut.n216);
    $display("FF n219 = %b", dut.n219);
    $display("FF n247 = %b", dut.n247);
    $display("FF n351 = %b", dut.n351);
    $display("FF n384 = %b", dut.n384);
    $display("FF n390 = %b", dut.n390);
    $display("FF n42 = %b", dut.n42);
    $display("FF n450 = %b", dut.n450);
    $display("FF n457 = %b", dut.n457);
    $display("FF n461 = %b", dut.n461);
    $display("FF n554 = %b", dut.n554);
    $display("FF n566 = %b", dut.n566);
    $display("FF n576 = %b", dut.n576);
    $display("FF n577 = %b", dut.n577);
    $display("FF n578 = %b", dut.n578);
    $display("FF n579 = %b", dut.n579);
    $display("FF n586 = %b", dut.n586);
    $display("FF n587 = %b", dut.n587);
    $display("FF n588 = %b", dut.n588);
    $display("FF n601 = %b", dut.n601);
    $display("FF n607 = %b", dut.n607);
    $display("FF n609 = %b", dut.n609);
    $display("FF n610 = %b", dut.n610);
    $display("FF n619 = %b", dut.n619);
    $display("FF n628 = %b", dut.n628);
    $display("FF n635 = %b", dut.n635);
    $display("FF n642 = %b", dut.n642);
    $display("FF n662 = %b", dut.n662);
    $display("FF n663 = %b", dut.n663);
    $display("FF n698 = %b", dut.n698);
    $display("FF n745 = %b", dut.n745);
    $display("FF n776 = %b", dut.n776);
    $display("FF n781 = %b", dut.n781);
    $display("FF n798 = %b", dut.n798);
    $display("FF n800 = %b", dut.n800);
    $display("FF n810 = %b", dut.n810);
    $display("FF n814 = %b", dut.n814);
    $display("FF n840 = %b", dut.n840);
    $display("FF n842 = %b", dut.n842);
    $display("FF n844 = %b", dut.n844);
    $display("FF n846 = %b", dut.n846);
    $display("FF n887 = %b", dut.n887);
    $display("FF n897 = %b", dut.n897);
    $display("FF n898 = %b", dut.n898);
    $display("FF n901 = %b", dut.n901);
    $display("FF n907 = %b", dut.n907);
    $display("FF n909 = %b", dut.n909);
    $display("FF n910 = %b", dut.n910);
    $display("FF n913 = %b", dut.n913);
    $display("FF n915 = %b", dut.n915);
    $display("FF n917 = %b", dut.n917);
    $display("FF n921 = %b", dut.n921);
    $display("FF n946 = %b", dut.n946);
    $display("FF n972 = %b", dut.n972);
    $display("FF n998 = %b", dut.n998);
    $display("FF io_16_31_1 = %b", dut.io_16_31_1);
    $finish;
  end
endmodule
