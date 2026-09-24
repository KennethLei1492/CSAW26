`timescale 1ns/1ps
module tb;
  reg clk=0; reg [10:0] raddr=0; wire [15:0] rdata; integer a;
  SB_RAM40_4K #(
   .READ_MODE(1),.WRITE_MODE(1),
   .INIT_0(256'h85c4d834ef22d4b989d975ce78ebd3405fa9d7fe2f53040695f36fc62fdf2de9),
   .INIT_1(256'h4dae5f63ca800319a219922c878382b2042fa4cdccdb8c36e5f52f3e4b25edbf),
   .INIT_2(256'hb2e631e07d1eb7c2668faca8a8a281cf95319e83cb5e2b4e99443ba536189203),
   .INIT_3(256'hc7cdaaae5946de3c9caee12ea2628a47f915286c2baaa8db852721e3ff8aeae6),
   .INIT_4(256'hb38b73fc542cabf0e0042f00b1f984421a8f24fa3d7eca72027a937fa9a57071),
   .INIT_5(256'h75102ed9eed416f8b952d0bb2db7e5d16cdac02f5e90c3ca24b8126137044e48),
   .INIT_6(256'hb23dc192a95f0c6b677412424eb52e6cf301b96b267ef4eac6b49a342e317d8c),
   .INIT_7(256'h572d44ac3633a04b29c0dfb57023d812b6aa51fae993732dd138b4cb500eecc9)
  ) ram (.RCLK(clk),.RCLKE(1'b1),.RE(1'b1),.RADDR(raddr),
    .WCLK(1'b0),.WCLKE(1'b0),.WE(1'b0),.WADDR(11'b0),.MASK(16'b0),.WDATA(16'b0),.RDATA(rdata));
  initial begin
    for(a=0;a<256;a=a+1) begin
      raddr = a; #1; clk=1; #1; clk=0; #1;
      // READ_MODE=1: data on even bits -> pack to 8-bit
      $display("%02x %02x", a, {rdata[14],rdata[12],rdata[10],rdata[8],rdata[6],rdata[4],rdata[2],rdata[0]});
    end
    $finish;
  end
endmodule
