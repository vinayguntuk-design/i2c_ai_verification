`timescale 1ns / 1ps
//=============================================================
// FILE    : rtl/i2c_master.v
// PURPOSE : I2C Master — the chip we are verifying (DUT)
//
// WHAT DOES AN I2C MASTER DO?
//   On a real I2C bus (like in Arduino, Raspberry Pi):
//   - Master STARTS the conversation by pulling SDA low while SCL is high
//   - Master sends 7-bit address to pick which slave to talk to
//   - Master says READ or WRITE (1 bit)
//   - Slave replies ACK (SDA=0) meaning "I heard you, I'm here"
//   - If WRITE: master sends 8 data bits, slave ACKs
//   - If READ:  slave sends 8 data bits, master ACKs
//   - Master STOPS by releasing SDA high while SCL is high
//
// FSM STATE MACHINE (10 states):
//   IDLE ──start pulse──► START
//   START ──────────────► ADDR    (send 7 address bits)
//   ADDR ───────────────► RW_BIT  (send read/write bit)
//   RW_BIT ─────────────► ADDR_ACK (wait for slave)
//   ADDR_ACK ──ACK──────► WRITE_DATA or READ_DATA
//   ADDR_ACK ──NACK─────► STOP    (error! slave not found)
//   WRITE_DATA ─────────► DATA_ACK ──► STOP
//   READ_DATA ──────────► MACK    ──► STOP
//   STOP ───────────────► IDLE
//=============================================================

module i2c_master (
    // --- System signals ---
    input  wire        clk,        // 100 MHz clock from Vivado
    input  wire        rst_n,      // Active-low reset (0 = reset)

    // --- Testbench controls this master ---
    input  wire        start,      // Pulse HIGH 1 cycle = begin transaction
    input  wire        rw,         // 0 = Write to slave, 1 = Read from slave
    input  wire [6:0]  addr,       // 7-bit slave address (e.g. 7'h50)
    input  wire [7:0]  data_in,    // Byte to write to slave

    // --- Master reports back to testbench ---
    output reg  [7:0]  data_out,   // Byte received from slave (on reads)
    output reg         done,       // Goes HIGH for 1 clock = transaction complete
    output reg         ack_error,  // Goes HIGH if slave didn't respond (NACK)

    // --- I2C bus wires ---
    output reg         scl,        // I2C clock (master always drives this)
    inout  wire        sda         // I2C data  (master OR slave drives this)
);

//-------------------------------------------------------------
// SDA BIDIRECTIONAL CONTROL
// I2C uses open-drain: anyone pulls LOW, pullup resistor gives HIGH
// We model this with a tristate buffer:
//   sda_oe=1 → master drives its value (sda_out) onto the bus
//   sda_oe=0 → master lets go (high-Z), slave or pullup controls it
//-------------------------------------------------------------
reg sda_out;   // what master WANTS to put on SDA
reg sda_oe;    // 1 = drive,  0 = release
assign sda = sda_oe ? sda_out : 1'bz;

//-------------------------------------------------------------
// FSM STATE NAMES
//-------------------------------------------------------------
localparam [3:0]
    IDLE       = 4'd0,
    START_S    = 4'd1,
    ADDR_S     = 4'd2,
    RW_BIT     = 4'd3,
    ADDR_ACK   = 4'd4,
    WRITE_DATA = 4'd5,
    READ_DATA  = 4'd6,
    DATA_ACK   = 4'd7,
    MACK       = 4'd8,
    STOP_S     = 4'd9;

reg [3:0] state;      // current FSM state
reg [2:0] bit_cnt;    // counts 6..0 for address, 7..0 for data
reg [7:0] shift_reg;  // data being shifted out/in

//-------------------------------------------------------------
// SCL CLOCK DIVIDER
// Vivado sim uses 10ns period (100MHz)
// Divides by 4 so SCL = 25MHz (fast enough for sim visibility)
// Real hardware would divide by 500 for 100kHz I2C
//-------------------------------------------------------------
reg       clk_div;
reg [1:0] div_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt <= 2'b00;
        clk_div <= 1'b0;
    end else begin
        div_cnt <= div_cnt + 1'b1;
        if (div_cnt == 2'b01)
            clk_div <= ~clk_div;
    end
end

//-------------------------------------------------------------
// MAIN STATE MACHINE
// Clocked on divided SCL clock
//-------------------------------------------------------------
always @(posedge clk_div or negedge rst_n) begin
    if (!rst_n) begin
        state     <= IDLE;
        scl       <= 1'b1;
        sda_out   <= 1'b1;
        sda_oe    <= 1'b1;
        done      <= 1'b0;
        ack_error <= 1'b0;
        bit_cnt   <= 3'd0;
        data_out  <= 8'd0;
        shift_reg <= 8'd0;
    end else begin
        // Default: clear single-cycle outputs every clock
        done      <= 1'b0;
        ack_error <= 1'b0;

        case (state)

            // ─── IDLE ──────────────────────────────────────────
            // Bus is free. Both lines high.
            // Wait for testbench to pulse 'start'.
            IDLE: begin
                scl     <= 1'b1;
                sda_out <= 1'b1;
                sda_oe  <= 1'b1;
                if (start)
                    state <= START_S;
            end

            // ─── START condition ───────────────────────────────
            // Pull SDA LOW while SCL stays HIGH
            // All slaves see this and start listening
            START_S: begin
                sda_out <= 1'b0;   // SDA goes LOW  ← START
                sda_oe  <= 1'b1;
                scl     <= 1'b1;   // SCL stays HIGH
                bit_cnt <= 3'd6;   // 7 addr bits: index 6 down to 0
                state   <= ADDR_S;
            end

            // ─── ADDR ──────────────────────────────────────────
            // Send 7 address bits, MSB (bit 6) first
            // Slave compares incoming bits to its own address
            ADDR_S: begin
                scl     <= 1'b0;               // SCL low = we can change SDA
                sda_out <= addr[bit_cnt];      // put the bit on SDA
                sda_oe  <= 1'b1;
                scl     <= 1'b1;               // SCL high = slave samples SDA
                if (bit_cnt == 3'd0)
                    state <= RW_BIT;
                else
                    bit_cnt <= bit_cnt - 1'b1;
            end

            // ─── RW_BIT ────────────────────────────────────────
            // Send 8th bit of address frame: 0=Write, 1=Read
            RW_BIT: begin
                scl     <= 1'b0;
                sda_out <= rw;     // 0 = master will write, 1 = will read
                sda_oe  <= 1'b1;
                scl     <= 1'b1;
                state   <= ADDR_ACK;
            end

            // ─── ADDR_ACK ──────────────────────────────────────
            // Release SDA. If slave is there, it pulls SDA LOW (ACK).
            // If SDA stays HIGH = nobody responded (NACK = error).
            ADDR_ACK: begin
                scl    <= 1'b0;
                sda_oe <= 1'b0;    // RELEASE — slave drives SDA
                scl    <= 1'b1;
                if (sda !== 1'b0) begin
                    ack_error <= 1'b1;     // SDA high = NACK
                    state     <= STOP_S;
                end else begin
                    bit_cnt   <= 3'd7;     // 8 data bits: index 7 down to 0
                    shift_reg <= data_in;  // load data to transmit
                    state     <= rw ? READ_DATA : WRITE_DATA;
                end
            end

            // ─── WRITE_DATA ────────────────────────────────────
            // Send data byte to slave, one bit per SCL cycle, MSB first
            WRITE_DATA: begin
                scl       <= 1'b0;
                sda_out   <= shift_reg[7];    // MSB first
                sda_oe    <= 1'b1;
                shift_reg <= shift_reg << 1;  // next bit becomes [7]
                scl       <= 1'b1;
                if (bit_cnt == 3'd0)
                    state <= DATA_ACK;
                else
                    bit_cnt <= bit_cnt - 1'b1;
            end

            // ─── DATA_ACK ──────────────────────────────────────
            // After 8 data bits: release SDA, check slave ACK
            DATA_ACK: begin
                scl       <= 1'b0;
                sda_oe    <= 1'b0;
                scl       <= 1'b1;
                ack_error <= (sda !== 1'b0);  // 1 = slave didn't ACK
                state     <= STOP_S;
            end

            // ─── READ_DATA ─────────────────────────────────────
            // Receive data from slave, one bit per SCL cycle
            // Slave drives SDA, we just sample it
            READ_DATA: begin
                scl      <= 1'b0;
                sda_oe   <= 1'b0;                     // RELEASE — slave drives
                scl      <= 1'b1;                     // sample on rising edge
                data_out <= {data_out[6:0], sda};     // shift in, MSB first
                if (bit_cnt == 3'd0)
                    state <= MACK;
                else
                    bit_cnt <= bit_cnt - 1'b1;
            end

            // ─── MACK ──────────────────────────────────────────
            // Master sends NACK = "I got the byte, stop sending"
            // SDA=1 during 9th clock = master NACK
            MACK: begin
                scl     <= 1'b0;
                sda_out <= 1'b1;   // NACK
                sda_oe  <= 1'b1;
                scl     <= 1'b1;
                state   <= STOP_S;
            end

            // ─── STOP condition ────────────────────────────────
            // SDA rises while SCL is HIGH
            // All slaves see this and go back to sleep
            STOP_S: begin
                scl     <= 1'b0;
                sda_out <= 1'b0;
                sda_oe  <= 1'b1;
                scl     <= 1'b1;
                sda_out <= 1'b1;   // SDA rises → STOP!
                done    <= 1'b1;   // tell testbench: we finished
                state   <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
