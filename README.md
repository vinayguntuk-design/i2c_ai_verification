# I2C AI Verification — Vivado Local Setup Guide

## Project Structure

```
i2c_ai_verification/
│
├── rtl/
│   ├── i2c_master.v        ← I2C Master (DUT — what we verify)
│   └── i2c_slave.v         ← I2C Slave  (reference model)
│
├── sim/
│   └── i2c_tb.sv           ← Testbench (AI profile injected here)
│
├── ai/
│   └── vivado_ai.py        ← AI engine (runs everything automatically)
│
├── scripts/
│   ├── create_project.tcl  ← Create Vivado project (run once)
│   └── run_sim.tcl         ← Command-line simulation
│
├── sim_logs/               ← Created automatically (simulation logs)
├── reports/                ← Created automatically (coverage reports)
└── xsim_work/              ← Created automatically (Vivado work files)
```

---

## Prerequisites

- Xilinx Vivado Standard (any version 2020+)
- Python 3.8 or newer
- That's it!

---

## Step 1 — Set Up Your Folder

Copy the project to any folder on your computer. Example:
```
C:\Users\YourName\i2c_ai_verification\   (Windows)
/home/yourname/i2c_ai_verification/      (Linux)
```

---

## Step 2 — Add Vivado to PATH

Vivado's command-line tools (xvlog, xelab, xsim) must be accessible.

### Windows
Open Command Prompt and run:
```cmd
set PATH=C:\Xilinx\Vivado\2024.1\bin;%PATH%
```
Or add it permanently in System Properties → Environment Variables.

### Linux
```bash
source /tools/Xilinx/Vivado/2024.1/settings64.sh
```

### Test it works
```bash
xvlog --version
```
You should see version info. If you get "not found" — check your path.

---

## Step 3 — Option A: Use Vivado GUI (Recommended for beginners)

1. Open **Vivado**
2. Go to **Tools → Run Tcl Script**
3. Browse to `scripts/create_project.tcl` and open it
4. Vivado will create the project and run the first simulation automatically
5. You'll see the waveform viewer open with SCL/SDA signals

---

## Step 3 — Option B: Command Line Only (Faster)

```bash
cd i2c_ai_verification

# Compile all files
xvlog --sv rtl/i2c_master.v rtl/i2c_slave.v sim/i2c_tb.sv

# Elaborate
xelab -debug typical work.i2c_tb -s i2c_tb_snap

# Run simulation
xsim i2c_tb_snap -runall
```

You'll see simulation output in the terminal including PASS/FAIL and coverage data.

---

## Step 4 — Run the AI Engine (Most Important Step)

This is where the magic happens. One command does everything:

```bash
python3 ai/vivado_ai.py
```

### What happens automatically:
```
Run 0: profile="random"
  → Python writes `define AI_PROFILE "random" into i2c_tb.sv
  → Python runs:  xvlog → xelab → xsim
  → Python reads simulation log
  → Python parses [COV] lines → Coverage = 54.5%
  → AI finds missed bins: addr_mid, addr_high, nack_test
  → AI picks next profile = "addr_mid"

Run 1: profile="addr_mid"
  → Python writes `define AI_PROFILE "addr_mid" into i2c_tb.sv
  → Python runs simulation again
  → Coverage = 72.7%
  → AI picks next profile = "addr_high"

... continues until 100% ...
```

### Choose your AI strategy:
```bash
# Simple priority list (fast, predictable)
python3 ai/vivado_ai.py --strategy rule

# Genetic algorithm (smarter, recommended)
python3 ai/vivado_ai.py --strategy genetic

# Q-learning (learns from history)
python3 ai/vivado_ai.py --strategy rl
```

---

## Step 5 — View Waveforms in Vivado

After simulation runs, open Vivado and:
1. Open the project (or run from GUI)
2. Flow → Open Simulation
3. In the waveform window, add signals:
   - `IF/scl`        — I2C clock
   - `IF/sda`        — I2C data (bidirectional)
   - `IF/done`       — transaction complete pulse
   - `IF/ack_error`  — NACK indicator
   - `u_master/state` — master FSM state

### What you'll see:
```
SCL  ‾‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾‾‾
SDA  ‾‾‾|_________addr_bits_________||_data_bits_|‾
done _____________________________________________|‾|__
```
- SCL pulses = clock cycles
- SDA falls = START condition
- SDA rises at end = STOP condition
- done pulse = transaction finished

---

## Step 6 — View Coverage Reports

After the AI finishes:
```
reports/coverage_report.html   ← Open in any browser
reports/coverage_history.json  ← Raw data
sim_logs/run_00.log            ← Simulation log for run 0
sim_logs/run_01.log            ← Simulation log for run 1
...
```

---

## Expected Output

```
============================================================
  I2C Autonomous AI Coverage Engine
  Strategy : GENETIC
  Target   : 100.0%
  Max Runs : 10
============================================================

Run #0  |  AI Profile: 'random'
  [SIM] Compiling RTL and testbench...
  [SIM] Elaborating design...
  [SIM] Running simulation...
  [SIM] Completed in 8.3s

  Coverage Bins:
  ────────────────────────────────────────────
  ✓  Addr Reserved  (0x00-0x07)          0
  ✓  Addr Low       (0x08-0x1F)          5  █████
  ✗  Addr Mid       (0x20-0x5F)          0
  ✗  Addr High      (0x60-0x77)          0
  ✓  RW Write                           18  ██████████
  ✓  RW Read                            12  ████████████
  ✓  ACK received                       28  ██████████
  ✓  NACK received                       2  ██
  ✓  Data = 0x00                         2  ██
  ✓  Data = 0xFF                         1  █
  ✓  Data = 0x55 or 0xAA                 3  ███
  ────────────────────────────────────────────
  Total: 72.7%  (8/11 bins covered)

  Run  0   [█████████████████████░░░░░░░░░]  72.7%  random
  Run  1 ► [████████████████████████░░░░░░]   NOW

  [AI] Missed bins: ['addr_mid', 'addr_high']
  [AI] Next profile → 'addr_mid'

Run #1  |  AI Profile: 'addr_mid'
...

TARGET 100.0% REACHED after 4 runs!
```

---

## Troubleshooting

### "xvlog not found"
Add Vivado bin to PATH (see Step 2)

### "Compile FAILED"
Check sim_logs/run_00.log for the actual error message.
Most common: the .sv file has a syntax error.

### "No [COV] output found"
The simulation ran but didn't reach the $display calls.
Check: is the watchdog timer too short? Try increasing #10_000_000 in i2c_tb.sv.

### Coverage stuck below 100%
Try running with more transactions:
Edit `define NUM_TRANSACTIONS 40 → 80 in i2c_tb.sv

---

## How the AI Integration Works

```
Python                        SystemVerilog (Vivado XSim)
──────                        ──────────────────────────
vivado_ai.py
  │
  ├─ update_tb_profile()  ──► rewrites `define AI_PROFILE "addr_mid"
  │                                    in i2c_tb.sv
  │
  ├─ run_vivado_simulation() → xvlog → xelab → xsim
  │                            │
  │                            └─ simulation runs, prints:
  │                               [COV] ADDR_MID=15
  │                               [COV] ADDR_HIGH=0
  │                               ...
  │
  ├─ parse_simulation_log() ◄── reads stdout automatically
  │
  ├─ AI strategy picks next profile
  │
  └─ loop back
```

**Key insight:** Python and SystemVerilog communicate through the simulation log.
- SV  → Python: `$display("[COV] KEY=VALUE")`
- Python → SV: rewrites `` `define AI_PROFILE "profile_name" ``
