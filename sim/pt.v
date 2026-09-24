module t; reg [31:0] D; initial begin
 if(!$value$plusargs("din=%x",D)) D=0; $display("x-> %08x",D);
 if(!$value$plusargs("din=%h",D)) D=0; $display("h-> %08x",D);
 if(!$value$plusargs("din=%d",D)) D=0; $display("d-> %08x",D);
end endmodule
