`timescale 1ns / 1ps
//=============================================================
// FILE    : sim/i2c_tb.sv
// PURPOSE : Complete Testbench for Vivado XSim
//
// VIVADO NOTES:
//   - This file is self-contained (no `include needed)
//   - Uses $display for console output
//   - AI profile injected via `define on line below
//   - Python reads sim log, rewrites this define, re-runs
//
// WHAT THIS FILE CONTAINS:
//   1. i2c_transaction  — one I2C operation as an object
//   2. i2c_driver       — drives inputs into the master DUT
//   3. i2c_monitor      — watches DUT outputs
//   4. i2c_scoreboard   — checks expected vs actual
//   5. i2c_coverage     — counts which scenarios were tested
//   6. i2c_tb           — top module, wires everything together
//
// HOW AI INTEGRATION WORKS:
//   Python AI reads coverage from sim log
//   Python writes new profile → rewrites this define
//   Python re-runs Vivado simulation
//   Loop repeats until 100% coverage
//=============================================================

// ─── AI PROFILE CONTROL ───────────────────────────────────────
// Python automatically updates this line before each run

`define AI_PROFILE "nack_test"

// Available: "random" "addr_low" "addr_mid" "addr_high"
//            "reserved" "read_only" "write_only" "nack_test"
//            "data_zero" "data_ones" "data_alt" "data_all"
// ─────────────────────────────────────────────────────────────

`define NUM_TRANSACTIONS 40
`define SLAVE_ADDR 7'h50

//=============================================================
// CLASS 1: TRANSACTION
// Represents one complete I2C operation
// The AI controls which transactions get generated
//=============================================================
class i2c_transaction;

    // --- Fields that get randomized ---
    rand logic [6:0] addr;   // which slave to address
    rand logic [7:0] data;   // byte to send (for writes)
    rand logic       rw;     // 0=Write, 1=Read

    // --- Results filled in after the transaction runs ---
    logic [7:0] data_received;
    logic       ack_received;

    // --- AI flags: Python enables these to target coverage holes ---
    // When a flag is 1, the matching constraint activates
    bit en_addr_low   = 0;   // force addr 0x08-0x1F
    bit en_addr_mid   = 0;   // force addr 0x20-0x5F
    bit en_addr_high  = 0;   // force addr 0x60-0x77
    bit en_reserved   = 0;   // force addr 0x00-0x07
    bit en_write_only = 0;   // force rw=0
    bit en_read_only  = 0;   // force rw=1
    bit en_nack_test  = 0;   // force wrong address → NACK

    // Always-on: valid address range
    constraint c_valid_addr { addr inside {[7'h00 : 7'h7F]}; }

    // AI-activated constraints (only when flag=1)
    constraint c_low   { if (en_addr_low)   addr inside {[7'h08 : 7'h1F]}; }
    constraint c_mid   { if (en_addr_mid)   addr inside {[7'h20 : 7'h5F]}; }
    constraint c_high  { if (en_addr_high)  addr inside {[7'h60 : 7'h77]}; }
    constraint c_rsv   { if (en_reserved)   addr inside {[7'h00 : 7'h07]}; }
    constraint c_wonly { if (en_write_only) rw == 1'b0; }
    constraint c_ronly { if (en_read_only)  rw == 1'b1; }
    constraint c_nack  { if (en_nack_test)  addr != `SLAVE_ADDR; }

    // Apply a profile string → set the right flag
    // Called by the generator based on what Python wrote
    function void apply_profile(string profile);
        // Clear all flags first
        en_addr_low=0; en_addr_mid=0; en_addr_high=0;
        en_reserved=0; en_write_only=0; en_read_only=0; en_nack_test=0;
        // Set the one matching the AI's decision
        case (profile)
            "addr_low"   : en_addr_low   = 1;
            "addr_mid"   : en_addr_mid   = 1;
            "addr_high"  : en_addr_high  = 1;
            "reserved"   : en_reserved   = 1;
            "write_only" : en_write_only = 1;
            "read_only"  : en_read_only  = 1;
            "nack_test"  : en_nack_test  = 1;
            // "random": all flags stay 0 = fully random
        endcase

    endfunction

    // Print transaction details
    function void print(string tag);
        $display("[%s] ADDR=0x%02h  %s  DATA=0x%02h  t=%0t",
                 tag, addr, rw?"READ ":"WRITE", data, $time);
    endfunction

endclass


//=============================================================
// CLASS 3: MONITOR
// Passively watches the DUT output signals
// Does NOT drive anything — only observes
// Sends observed data to scoreboard and coverage
//=============================================================
//=============================================================
// CLASS 2: DRIVER
// Actively drives inputs into the DUT based on generator mailbox
//=============================================================
class i2c_driver;

    virtual interface i2c_if vif;
    mailbox #(i2c_transaction) from_gen;
    mailbox #(i2c_transaction) to_scb;

    function new(virtual i2c_if v,
                 mailbox #(i2c_transaction) fg,
                 mailbox #(i2c_transaction) ts);
        vif = v;
        from_gen = fg;
        to_scb = ts;
    endfunction

    task run();
        i2c_transaction txn;
        int timeout;
        forever begin
            from_gen.get(txn);
            txn.print("DRV");

            // Small gap between transactions
            repeat(8) @(posedge vif.clk);

            // Set up the DUT inputs
            vif.addr    <= txn.addr;
            vif.rw      <= txn.rw;
            vif.data_in <= txn.data;

            // Pulse start for exactly 1 clock
            vif.start <= 1'b1;
            repeat(10) @(posedge vif.clk);
            vif.start <= 1'b0;

            // Wait for DUT to finish (done signal = 1)
            timeout = 0;
            while (!vif.done && timeout < 5000) begin
                @(posedge vif.clk);
                timeout++;
                if (timeout > 0 && timeout % 500 == 0)
                    $display("[DRV DEBUG] waiting... timeout=%0d done=%0b state=%0d", timeout, vif.done, i2c_tb.u_master.state);
            end
            if (timeout >= 5000)
                $display("[DRV] WARNING: Transaction timeout!");

            // Capture results
            @(posedge vif.clk);
            txn.ack_received   = !vif.ack_error;
            txn.data_received  = vif.data_out;

            // Send to scoreboard for checking
            to_scb.put(txn);
        end
    endtask

endclass

class i2c_monitor;

    virtual interface i2c_if vif;
    mailbox #(i2c_transaction) to_scb;
    mailbox #(i2c_transaction) to_cov;

    function new(virtual i2c_if v,
                 mailbox #(i2c_transaction) ts,
                 mailbox #(i2c_transaction) tc);
        vif    = v;
        to_scb = ts;
        to_cov = tc;
    endfunction

    task run();
        forever begin
            i2c_transaction txn = new();

            // Wait for DUT to signal completion
            @(posedge vif.done);

            // Capture what was observed on the bus
            txn.addr          = vif.addr;
            txn.rw            = vif.rw;
            txn.data          = vif.data_in;
            txn.data_received = vif.data_out;
            txn.ack_received  = !vif.ack_error;

            txn.print("MON");

            // Send to both scoreboard and coverage
            to_scb.put(txn);
            to_cov.put(txn);
        end
    endtask

endclass


//=============================================================
// CLASS 4: SCOREBOARD
// Gets "expected" from driver, "actual" from monitor
// Compares them field by field → PASS or FAIL
//=============================================================
class i2c_scoreboard;

    mailbox #(i2c_transaction) from_driver;   // expected
    mailbox #(i2c_transaction) from_monitor;  // actual

    int pass_count = 0;
    int fail_count = 0;

    function new(mailbox #(i2c_transaction) fd,
                 mailbox #(i2c_transaction) fm);
        from_driver  = fd;
        from_monitor = fm;
    endfunction

    task run();
        i2c_transaction expected, actual;
        forever begin
            from_driver.get(expected);
            from_monitor.get(actual);

            if (expected.addr === actual.addr &&
                expected.rw   === actual.rw) begin
                pass_count++;
                $display("[SCB] PASS #%0d  ADDR=0x%02h  %s  ACK=%0b",
                         pass_count, actual.addr,
                         actual.rw?"READ ":"WRITE",
                         actual.ack_received);
            end else begin
                fail_count++;
                $display("[SCB] FAIL #%0d  Expected ADDR=0x%02h RW=%0b  Got ADDR=0x%02h RW=%0b",
                         fail_count,
                         expected.addr, expected.rw,
                         actual.addr,   actual.rw);
            end
        end
    endtask

    function void report();
        $display("");
        $display("============ SCOREBOARD REPORT ============");
        $display("  PASS  : %0d", pass_count);
        $display("  FAIL  : %0d", fail_count);
        $display("  TOTAL : %0d", pass_count + fail_count);
        if (fail_count == 0)
            $display("  STATUS: ALL TRANSACTIONS PASSED");
        else
            $display("  STATUS: %0d FAILURE(S) FOUND", fail_count);
        $display("===========================================");
        $display("");
    endfunction

endclass


//=============================================================
// CLASS 5: COVERAGE COLLECTOR
// Counts how many times each scenario was exercised
// Exports machine-readable data for Python AI to parse
//=============================================================
class i2c_coverage;

    mailbox #(i2c_transaction) from_monitor;

    // ── Hit counters for 11 coverage bins ──────────────────────
    // Each counter increments when that scenario is seen
    int c_addr_reserved = 0;    // addresses 0x00-0x07
    int c_addr_low      = 0;    // addresses 0x08-0x1F
    int c_addr_mid      = 0;    // addresses 0x20-0x5F
    int c_addr_high     = 0;    // addresses 0x60-0x77
    int c_rw_write      = 0;    // write transactions
    int c_rw_read       = 0;    // read transactions
    int c_ack           = 0;    // transactions that got ACK
    int c_nack          = 0;    // transactions that got NACK
    int c_data_zero     = 0;    // data byte = 0x00
    int c_data_ones     = 0;    // data byte = 0xFF
    int c_data_alt      = 0;    // data byte = 0x55 or 0xAA
    int c_total         = 0;    // total transactions seen

    function new(mailbox #(i2c_transaction) fm);
        from_monitor = fm;
    endfunction

    task run();
        i2c_transaction txn;
        forever begin
            from_monitor.get(txn);
            c_total++;

            // Address bins
            if      (txn.addr inside {[7'h00:7'h07]}) c_addr_reserved++;
            else if (txn.addr inside {[7'h08:7'h1F]}) c_addr_low++;
            else if (txn.addr inside {[7'h20:7'h5F]}) c_addr_mid++;
            else if (txn.addr inside {[7'h60:7'h77]}) c_addr_high++;

            // Direction bins
            if (txn.rw == 1'b0) c_rw_write++;
            else                 c_rw_read++;

            // ACK/NACK bins
            if (txn.ack_received) c_ack++;
            else                  c_nack++;

            // Data pattern bins
            if (txn.data == 8'h00)                    c_data_zero++;
            if (txn.data == 8'hFF)                    c_data_ones++;
            if (txn.data == 8'h55 || txn.data == 8'hAA) c_data_alt++;
        end
    endtask

    // Human-readable report for the Vivado console
    function void report();
        int bins_hit, total_bins;
        real coverage_pct;
        total_bins = 11;
        bins_hit = (c_addr_reserved > 0) + (c_addr_low > 0) +
                   (c_addr_mid > 0)      + (c_addr_high > 0) +
                   (c_rw_write > 0)      + (c_rw_read > 0) +
                   (c_ack > 0)           + (c_nack > 0) +
                   (c_data_zero > 0)     + (c_data_ones > 0) +
                   (c_data_alt > 0);
        coverage_pct = bins_hit * 100.0 / total_bins;

        $display("");
        $display("============ COVERAGE REPORT ============");
        $display("  Addr Reserved (0x00-07): %3d hits  %s",
                 c_addr_reserved, c_addr_reserved>0 ? "HIT" : "MISS");
        $display("  Addr Low      (0x08-1F): %3d hits  %s",
                 c_addr_low,      c_addr_low>0      ? "HIT" : "MISS");
        $display("  Addr Mid      (0x20-5F): %3d hits  %s",
                 c_addr_mid,      c_addr_mid>0      ? "HIT" : "MISS");
        $display("  Addr High     (0x60-77): %3d hits  %s",
                 c_addr_high,     c_addr_high>0     ? "HIT" : "MISS");
        $display("  RW Write               : %3d hits  %s",
                 c_rw_write,      c_rw_write>0      ? "HIT" : "MISS");
        $display("  RW Read                : %3d hits  %s",
                 c_rw_read,       c_rw_read>0       ? "HIT" : "MISS");
        $display("  ACK received           : %3d hits  %s",
                 c_ack,           c_ack>0            ? "HIT" : "MISS");
        $display("  NACK received          : %3d hits  %s",
                 c_nack,          c_nack>0           ? "HIT" : "MISS");
        $display("  Data = 0x00            : %3d hits  %s",
                 c_data_zero,     c_data_zero>0     ? "HIT" : "MISS");
        $display("  Data = 0xFF            : %3d hits  %s",
                 c_data_ones,     c_data_ones>0     ? "HIT" : "MISS");
        $display("  Data = 0x55 or 0xAA    : %3d hits  %s",
                 c_data_alt,      c_data_alt>0      ? "HIT" : "MISS");
        $display("  ----------------------------------------");
        $display("  TOTAL: %.1f%% (%0d/%0d bins hit)",
                 coverage_pct, bins_hit, total_bins);
        $display("=========================================");
        $display("");
    endfunction

    // Machine-readable export — Python AI engine parses these lines
    // Format: [COV] KEY=VALUE
    function void export_for_ai();
        $display("=== AI COVERAGE DATA START ===");
        $display("[COV] ADDR_RESERVED=%0d", c_addr_reserved);
        $display("[COV] ADDR_LOW=%0d",      c_addr_low);
        $display("[COV] ADDR_MID=%0d",      c_addr_mid);
        $display("[COV] ADDR_HIGH=%0d",     c_addr_high);
        $display("[COV] RW_WRITE=%0d",      c_rw_write);
        $display("[COV] RW_READ=%0d",       c_rw_read);
        $display("[COV] ACK=%0d",           c_ack);
        $display("[COV] NACK=%0d",          c_nack);
        $display("[COV] DATA_ZERO=%0d",     c_data_zero);
        $display("[COV] DATA_ONES=%0d",     c_data_ones);
        $display("[COV] DATA_ALT=%0d",      c_data_alt);
        $display("[COV] TOTAL_TXN=%0d",     c_total);
        $display("=== AI COVERAGE DATA END ===");
    endfunction

endclass


//=============================================================
// INTERFACE
// Bundles all signals between testbench and DUT
//=============================================================
interface i2c_if (input logic clk, input logic rst_n);
    logic        start;
    logic        rw;
    logic [6:0]  addr;
    logic [7:0]  data_in;
    logic [7:0]  data_out;
    logic        done;
    logic        ack_error;
    logic        scl;
    wire         sda;
endinterface


//=============================================================
// TOP TESTBENCH MODULE
// Vivado sets this as the simulation top
//=============================================================
module i2c_tb;

    // ── Clock and Reset ──────────────────────────────────────
    logic clk   = 1'b0;
    logic rst_n;

    // 100 MHz clock (10ns period)
    always #5 clk = ~clk;

    // ── Interface instantiation ──────────────────────────────
    i2c_if IF (.clk(clk), .rst_n(rst_n));

    // ── DUT: I2C Master ─────────────────────────────────────
    i2c_master u_master (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (IF.start),
        .rw        (IF.rw),
        .addr      (IF.addr),
        .data_in   (IF.data_in),
        .data_out  (IF.data_out),
        .done      (IF.done),
        .ack_error (IF.ack_error),
        .scl       (IF.scl),
        .sda       (IF.sda)
    );

    // ── DUT: I2C Slave ───────────────────────────────────────
    i2c_slave #(.SLAVE_ADDR(`SLAVE_ADDR)) u_slave (
        .clk        (clk),
        .rst_n      (rst_n),
        .scl        (IF.scl),
        .sda        (IF.sda),
        .mem_data   (),
        .write_done (),
        .read_done  ()
    );

    // ── Protocol Assertions ──────────────────────────────────
    // These check I2C protocol rules continuously during simulation
    always @(negedge IF.sda) begin
        if (rst_n && IF.scl !== 1'b1)
            $display("[ASSERT FAIL] START violated: SDA fell while SCL was not HIGH at t=%0t", $time);
    end
    always @(posedge IF.sda) begin
        if (rst_n && IF.scl !== 1'b1)
            $display("[ASSERT FAIL] STOP violated: SDA rose while SCL was not HIGH at t=%0t", $time);
    end

    // ── Mailboxes ────────────────────────────────────────────
    // gen_to_drv  : generator → driver
    // drv_to_scb  : driver   → scoreboard (expected)
    // mon_to_scb  : monitor  → scoreboard (actual)
    // mon_to_cov  : monitor  → coverage
    mailbox #(i2c_transaction) gen_to_drv  = new();
    mailbox #(i2c_transaction) drv_to_scb  = new();
    mailbox #(i2c_transaction) mon_to_scb  = new();
    mailbox #(i2c_transaction) mon_to_cov  = new();

    // ── Component Handles ────────────────────────────────────
    i2c_driver      drv;
    i2c_monitor     mon;
    i2c_scoreboard  scb;
    i2c_coverage    cov;

    // ── Waveform Dump ────────────────────────────────────────
    // Creates wave data viewable in Vivado waveform viewer
    initial begin
        $dumpfile("i2c_waves.vcd");
        $dumpvars(0, i2c_tb);
    end

    // ── MAIN TEST ────────────────────────────────────────────
    initial begin
        string profile;
        profile = `AI_PROFILE;   // injected by Python AI

        $display("");
        $display("======================================================");
        $display("  I2C Vivado Simulation");
        $display("  AI Profile : %s", profile);
        $display("======================================================");
        $display("");

        // Reset sequence
        rst_n = 1'b0;
        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(5)  @(posedge clk);

        // Create all testbench components
        drv = new(IF, gen_to_drv, drv_to_scb);
        mon = new(IF, mon_to_scb, mon_to_cov);
        scb = new(drv_to_scb, mon_to_scb);
        cov = new(mon_to_cov);

        // Start all components in parallel
        fork
			drv.run();
			mon.run();
			scb.run();
			cov.run();
			gen(profile);
		join_none

		// Wait until generator mailbox becomes empty
		wait (gen_to_drv.num() == 0);

		// Allow monitor/coverage/scoreboard
		// to finish remaining transactions
		repeat(5000) @(posedge clk);

        // Print all reports
        scb.report();
        cov.report();
        cov.export_for_ai();   // ← Python AI reads this section

        $display("======================================================");
        $display("  Simulation Complete");
        $display("======================================================");
        $finish;
    end

    // ── TRANSACTION GENERATOR ───────────────────────────────
    // Creates transactions constrained by the AI profile
	task automatic gen(string profile);

		i2c_transaction txn;

		repeat(`NUM_TRANSACTIONS) begin

			txn = new();

			// --------------------------------------------------
			// AI PROFILE STIMULUS
			// --------------------------------------------------

			if(profile == "random") begin

				txn.addr = $urandom_range(0,127);
				txn.rw   = $urandom_range(0,1);
				txn.data = $urandom_range(0,255);

			end

			else if(profile == "addr_low") begin

				txn.addr = $urandom_range(8,31);
				txn.rw   = $urandom_range(0,1);
				txn.data = $urandom_range(0,255);

			end

			else if(profile == "addr_mid") begin

				txn.addr = $urandom_range(32,95);
				txn.rw   = $urandom_range(0,1);
				txn.data = $urandom_range(0,255);

			end

			else if(profile == "addr_high") begin

				txn.addr = $urandom_range(96,119);
				txn.rw   = $urandom_range(0,1);
				txn.data = $urandom_range(0,255);

			end

			else if(profile == "reserved") begin

				txn.addr = $urandom_range(0,7);
				txn.rw   = $urandom_range(0,1);
				txn.data = $urandom_range(0,255);

			end

			else if(profile == "read_only") begin

				txn.addr = $urandom_range(0,127);
				txn.rw   = 1'b1;
				txn.data = $urandom_range(0,255);

			end

			else if(profile == "write_only") begin

				txn.addr = $urandom_range(0,127);
				txn.rw   = 1'b0;
				txn.data = $urandom_range(0,255);

			end

			else if(profile == "nack_test") begin

				txn.addr = 7'h7F;
				txn.rw = $urandom_range(0,1);
				case($urandom_range(0,3))
					0: txn.data = 8'h00;
					1: txn.data = 8'hFF;
					2: txn.data = 8'h55;
					3: txn.data = 8'hAA;
				endcase

			end

			else if(profile == "data_zero") begin

				txn.addr = `SLAVE_ADDR;
				txn.rw   = $urandom_range(0,1);
				txn.data = 8'h00;

			end

			else if(profile == "data_ones") begin

				txn.addr = `SLAVE_ADDR;
				txn.rw   = $urandom_range(0,1);
				txn.data = 8'hFF;

			end

			else if(profile == "data_alt") begin

				txn.addr = `SLAVE_ADDR;
				txn.rw   = $urandom_range(0,1);
				if ($urandom_range(0,1))
					txn.data = 8'h55;
				else
					txn.data = 8'hAA;

			end

			else if(profile == "data_all") begin

				txn.addr = `SLAVE_ADDR;
				txn.rw   = $urandom_range(0,1);
				case($urandom_range(0,3))
					0: txn.data = 8'h00;
					1: txn.data = 8'hFF;
					2: txn.data = 8'h55;
					3: txn.data = 8'hAA;
				endcase

            end

            // --------------------------------------------------
            // Send transaction to driver (profile values already set)
            // --------------------------------------------------

            // Small structural delay before putting into mailbox
            repeat(2) @(posedge clk);

            // Send to driver
            gen_to_drv.put(txn);

            // Inter-transaction gap
            repeat(4) @(posedge clk);

        end // repeat NUM_TRANSACTIONS

    endtask // gen


    endmodule // i2c_tb
