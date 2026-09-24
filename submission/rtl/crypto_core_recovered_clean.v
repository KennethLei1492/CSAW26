// ============================================================================
//  crypto_core.v
//  Recovered lightweight cryptographic core (byte-wise substitution cipher).
//
//  Reverse-engineered from the iCE40-UP5K bitstream shipped with the CSAW'26
//  AI Hardware Attack qualifier.  The recovered algorithm is a 32-bit block
//  cipher with NO inter-byte diffusion: each of the four bytes is transformed
//  independently by its own hard-wired, key-dependent 8-bit bijection
//  (four rounds of an S-box + round-key in the original silicon; here captured
//  exactly as the equivalent 256-entry substitution table per byte lane).
//
//  ENC_DEC = 0 : encrypt   (forward substitution tables)
//  ENC_DEC = 1 : decrypt   (inverse substitution tables)
//
//  Latency: 4 clock cycles of BUSY, result parallel-loaded on the falling edge
//  of BUSY, matching the documented interface behaviour.
// ============================================================================
module crypto_core #(parameter TROJAN_EN = 1'b1)(
    input  wire        clk,       // unified system/SPI clock (SCK)
    input  wire        rst_n,     // synchronous active-low reset
    input  wire        start,     // begin an operation
    input  wire        enc_dec,   // 0 = encrypt, 1 = decrypt
    input  wire [31:0] data_in,   // plaintext (enc) or ciphertext (dec)
    output reg  [31:0] data_out,  // result, valid when busy falls
    output reg         busy       // high while processing
);
    // ----- recovered per-byte-lane substitution tables -----
    reg [7:0] ENC0[0:255], ENC1[0:255], ENC2[0:255], ENC3[0:255];
    reg [7:0] DEC0[0:255], DEC1[0:255], DEC2[0:255], DEC3[0:255];
    initial begin
        $readmemh("sbox_enc0.mem", ENC0); $readmemh("sbox_enc1.mem", ENC1);
        $readmemh("sbox_enc2.mem", ENC2); $readmemh("sbox_enc3.mem", ENC3);
        $readmemh("sbox_dec0.mem", DEC0); $readmemh("sbox_dec1.mem", DEC1);
        $readmemh("sbox_dec2.mem", DEC2); $readmemh("sbox_dec3.mem", DEC3);
    end

    // combinational byte-wise substitution of the captured operand
    reg  [31:0] operand;
    reg         mode;
    wire [31:0] subst;
    assign subst[7:0]   = mode ? DEC0[operand[7:0]]   : ENC0[operand[7:0]];
    assign subst[15:8]  = mode ? DEC1[operand[15:8]]  : ENC1[operand[15:8]];
    assign subst[23:16] = mode ? DEC2[operand[23:16]] : ENC2[operand[23:16]];
    assign subst[31:24] = mode ? DEC3[operand[31:24]] : ENC3[operand[31:24]];

    reg [2:0] cnt;
    always @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0;
            cnt  <= 3'd0;
        end else if (start && !busy) begin
            // latch operand and mode, assert BUSY
            operand <= data_in;
            mode    <= enc_dec;
            busy    <= 1'b1;
            cnt     <= 3'd0;
        end else if (busy) begin
            cnt <= cnt + 3'd1;
            if (cnt == 3'd3) begin          // 4 cycles elapsed
                data_out <= subst;          // parallel-load result
                busy     <= 1'b0;
            end
        end
    end
endmodule
