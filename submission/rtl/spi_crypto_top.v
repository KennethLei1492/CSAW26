// ============================================================================
//  spi_crypto_top.v  (BASELINE - no Trojan; see spi_crypto_top_trojan.v)
//
//  SPI-peripheral wrapper around the recovered crypto_core, reproducing the
//  documented Hackster iCE40 cryptographic-IP interface.  Everything runs in
//  the single SCK clock domain, exactly as the recovered silicon does.
//
//  Protocol:
//    * NORM_CS_N low  -> the 32-bit shift register shifts on each SCK rising
//                        edge (MSB first): sr <= {sr[30:0], MOSI}.
//    * NORM_CS_N high -> shift register holds; START begins an operation.
//    * BUSY is high for 4 SCK cycles; on its falling edge the result is
//      parallel-loaded back into the shift register for read-out.
//    * MISO is a registered copy of the shift-register MSB, so a controller
//      sampling on the SCK rising edge reads the loaded word back verbatim.
// ============================================================================
module spi_crypto_top #(
    parameter TROJAN_EN = 1'b1     // 1 = Trojan active (default); 0 = clean twin
)(
    input  wire SCK,        // unified system + SPI clock (<= 1 MHz)
    input  wire RST_N,      // synchronous active-low reset
    input  wire MOSI,       // serial data in
    output wire MISO,       // serial data out
    input  wire NORM_CS_N,  // active-low chip select / shift enable
    input  wire START,      // start encrypt/decrypt
    input  wire ENC_DEC,    // 0 = encrypt, 1 = decrypt
    output wire BUSY,       // processing status
    output wire ICE_LED     // visual mirror of BUSY
);
    reg  [31:0] sr;         // SPI shift register / I/O buffer
    reg         miso_r;

    wire [31:0] result;
    wire        core_busy;
    reg         busy_d;

    crypto_core #(.TROJAN_EN(TROJAN_EN)) u_core (
        .clk     (SCK),
        .rst_n   (RST_N),
        .start   (START),
        .enc_dec (ENC_DEC),
        .data_in (sr),
        .data_out(result),
        .busy    (core_busy)
    );

    // falling edge of BUSY -> parallel-load the processed word
    wire load_result = busy_d & ~core_busy;

    always @(posedge SCK) begin
        if (!RST_N) begin
            sr     <= 32'd0;
            miso_r <= 1'b0;
            busy_d <= 1'b0;
        end else begin
            busy_d <= core_busy;
            miso_r <= sr[31];               // registered MISO (MSB first)
            if (load_result)
                sr <= result;               // load ciphertext/plaintext
            else if (!NORM_CS_N)
                sr <= {sr[30:0], MOSI};      // shift while selected
        end
    end

    assign MISO    = miso_r;
    assign BUSY    = core_busy;
    assign ICE_LED = core_busy;
endmodule
