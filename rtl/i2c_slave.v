`timescale 1ns / 1ps
//=============================================================
// FILE    : rtl/i2c_slave.v
// PURPOSE : I2C Slave — responds to master, stores data
//
// WHAT IT DOES:
//   - Watches SCL and SDA for START / STOP conditions
//   - Receives 7-bit address + R/W bit from master
//   - If address matches SLAVE_ADDR → sends ACK (pulls SDA low)
//   - If no match → sends NACK (releases SDA, stays high)
//   - WRITE mode: receives bytes, stores in 8-byte memory
//   - READ  mode: sends bytes from memory to master
//
// HOW TO CHANGE SLAVE ADDRESS:
//   i2c_slave #(.SLAVE_ADDR(7'h3C)) u_slave (...)
//=============================================================

module i2c_slave #(
    parameter [6:0] SLAVE_ADDR = 7'h50   // default address
)(
    input  wire       clk,         // system clock
    input  wire       rst_n,       // active-low reset
    input  wire       scl,         // I2C clock from master
    inout  wire       sda,         // I2C data bidirectional
    output reg [7:0]  mem_data,    // last byte written (for debug)
    output reg        write_done,  // pulses 1 when write completes
    output reg        read_done    // pulses 1 when read completes
);

// SDA tristate — slave only drives when sending ACK or data
reg sda_out, sda_oe;
assign sda = sda_oe ? sda_out : 1'bz;

//-------------------------------------------------------------
// START / STOP DETECTION
// We register SDA one clock early so we can detect its edge
//-------------------------------------------------------------
reg sda_prev;
always @(posedge clk) sda_prev <= sda;

// START: SDA falls (1→0) while SCL=1
wire start_det = (scl === 1'b1) && (sda_prev === 1'b1) && (sda === 1'b0);
// STOP:  SDA rises (0→1) while SCL=1
wire stop_det  = (scl === 1'b1) && (sda_prev === 1'b0) && (sda === 1'b1);

//-------------------------------------------------------------
// FSM STATES
//-------------------------------------------------------------
localparam [2:0]
    S_IDLE     = 3'd0,   // waiting for START
    S_ADDR     = 3'd1,   // receiving address + R/W
    S_ADDR_ACK = 3'd2,   // send ACK or NACK
    S_WRITE    = 3'd3,   // receiving data from master
    S_WACK     = 3'd4,   // sending ACK after received byte
    S_READ     = 3'd5,   // sending data to master
    S_RACK     = 3'd6;   // waiting for master ACK/NACK

reg [2:0] state;
reg [3:0] bit_cnt;    // bit counter
reg [7:0] shift_reg;  // shift register
reg       rw_flag;    // captured R/W bit

// 8-byte internal memory
reg [7:0] mem [0:7];
reg [2:0] mem_ptr;

//-------------------------------------------------------------
// MAIN FSM
//-------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= S_IDLE;
        sda_oe     <= 1'b0;
        sda_out    <= 1'b1;
        bit_cnt    <= 4'd0;
        shift_reg  <= 8'd0;
        rw_flag    <= 1'b0;
        write_done <= 1'b0;
        read_done  <= 1'b0;
        mem_ptr    <= 3'd0;
        mem_data   <= 8'd0;
    end else begin
        write_done <= 1'b0;
        read_done  <= 1'b0;

        // START overrides any state — I2C protocol requirement
        if (start_det) begin
            state     <= S_ADDR;
            bit_cnt   <= 4'd7;
            shift_reg <= 8'd0;
            sda_oe    <= 1'b0;

        // STOP always returns to idle
        end else if (stop_det) begin
            state  <= S_IDLE;
            sda_oe <= 1'b0;

        end else begin
            case (state)

                // Wait for START
                S_IDLE: sda_oe <= 1'b0;

                // Receive 8 bits: 7-bit address + R/W, sample on SCL high
                S_ADDR: begin
                    if (scl) begin
                        shift_reg <= {sda, shift_reg[7:1]};  // Shift LEFT (MSB first for I2C)
                        if (bit_cnt == 4'd0) begin
                            // Received all 8 bits; RW bit is in sda now
                            rw_flag <= sda;
                            state <= S_ADDR_ACK;
                        end
                        bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                // Check address, reply ACK or NACK
                S_ADDR_ACK: begin
                    if (!scl) begin
                        // After left-shift by 8 clocks:
                        // shift_reg[7:0] = {RW, addr[6:0]} (RW in MSB from last clock)
                        // shift_reg[6:0] = addr[6:0]
                        if (shift_reg[6:0] == SLAVE_ADDR) begin
                            sda_out <= 1'b0;  // ACK = pull SDA low
                            sda_oe  <= 1'b1;
                            bit_cnt <= 4'd7;
                            state   <= rw_flag ? S_READ : S_WRITE;
                        end else begin
                            sda_oe  <= 1'b0;  // NACK = release SDA
                            state   <= S_IDLE;
                        end
                    end
                end

                // Receive data byte from master
                S_WRITE: begin
                    if (!scl) sda_oe <= 1'b0;   // release SDA while receiving
                    if (scl) begin
                        shift_reg <= {shift_reg[6:0], sda};
                        if (bit_cnt == 4'd0) begin
                            mem[mem_ptr] <= {shift_reg[6:0], sda};
                            mem_data     <= {shift_reg[6:0], sda};
                            mem_ptr      <= mem_ptr + 1'b1;
                            write_done   <= 1'b1;
                            state        <= S_WACK;
                        end else
                            bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                // Send ACK after receiving data byte
                S_WACK: begin
                    if (!scl) begin
                        sda_out <= 1'b0;  // ACK
                        sda_oe  <= 1'b1;
                    end else begin
                        bit_cnt <= 4'd7;
                        state   <= S_WRITE;
                    end
                end

                // Send data byte to master
                S_READ: begin
                    if (!scl) begin
                        sda_out <= mem[mem_ptr][bit_cnt];
                        sda_oe  <= 1'b1;
                    end else begin
                        if (bit_cnt == 4'd0) begin
                            mem_ptr  <= mem_ptr + 1'b1;
                            read_done <= 1'b1;
                            state    <= S_RACK;
                        end else
                            bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                // Wait for master ACK (continue) or NACK (stop)
                S_RACK: begin
                    if (!scl) sda_oe <= 1'b0;
                    else begin
                        if (sda == 1'b0) begin
                            bit_cnt <= 4'd7;
                            state   <= S_READ;
                        end else
                            state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
end

endmodule
