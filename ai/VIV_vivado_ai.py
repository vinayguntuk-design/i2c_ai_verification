#!/usr/bin/env python3
"""
=================================================================
  FILE    : ai/vivado_ai.py
  PURPOSE : Fully autonomous AI coverage engine for Vivado

  WHAT THIS SCRIPT DOES (everything automatically):
    Step 1 : Update `define AI_PROFILE in i2c_tb.sv
    Step 2 : Run Vivado simulation using xsim command line
    Step 3 : Read simulation log output automatically
    Step 4 : Parse [COV] lines to extract coverage data
    Step 5 : AI decides which profile closes the biggest gap
    Step 6 : Go back to Step 1 — repeat until 100% coverage

  ZERO MANUAL STEPS NEEDED
  Python drives everything. You just run this script once.

  HOW TO RUN:
    cd your_project_folder
    python3 ai/vivado_ai.py

  REQUIREMENTS:
    - Vivado installed (tested with 2023.x, 2024.x)
    - xvlog and xsim on your system PATH
    - Python 3.8 or newer

  VIVADO PATH SETUP:
    Windows : Add C:\\Xilinx\\Vivado\\2024.1\\bin to PATH
    Linux   : source /tools/Xilinx/Vivado/2024.1/settings64.sh
    Mac     : Vivado not natively supported — use Ubuntu VM
=================================================================
"""

import os
import re
import sys
import json
import time
import random
import argparse
import subprocess
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional


# =================================================================
# CONFIGURATION — adjust these to match your folder layout
# =================================================================

# Project root = folder containing rtl/, sim/, ai/
PROJECT_ROOT = Path(__file__).parent.parent

# File paths
TB_FILE      = PROJECT_ROOT / "sim" / "i2c_tb.sv"
MASTER_FILE  = PROJECT_ROOT / "rtl" / "i2c_master.v"
SLAVE_FILE   = PROJECT_ROOT / "rtl" / "i2c_slave.v"

# Output folders
LOG_DIR      = PROJECT_ROOT / "sim_logs"
REPORTS_DIR  = PROJECT_ROOT / "reports"

# AI state files
HISTORY_FILE = PROJECT_ROOT / "reports" / "coverage_history.json"
Q_TABLE_FILE = PROJECT_ROOT / "reports" / "q_table.json"

# Vivado xsim work directory
XSIM_DIR     = PROJECT_ROOT / "xsim_work"

# Coverage target
TARGET_PCT   = 100.0
MAX_RUNS     = 10

# All possible AI profiles
ALL_PROFILES = [
    "random", "addr_low", "addr_mid", "addr_high",
    "reserved", "read_only", "write_only", "nack_test"
]


# =================================================================
# PART 1: COVERAGE DATA MODEL
# Holds all 11 bin hit counts parsed from simulation output
# =================================================================

@dataclass
class CoverageData:
    addr_reserved : int = 0
    addr_low      : int = 0
    addr_mid      : int = 0
    addr_high     : int = 0
    rw_write      : int = 0
    rw_read       : int = 0
    ack           : int = 0
    nack          : int = 0
    data_zero     : int = 0
    data_ones     : int = 0
    data_alt      : int = 0
    total_txn     : int = 0

    @property
    def bins_hit(self) -> int:
        """How many of the 11 bins have at least 1 hit."""
        return sum(1 for v in [
            self.addr_reserved, self.addr_low, self.addr_mid,
            self.addr_high, self.rw_write, self.rw_read,
            self.ack, self.nack, self.data_zero,
            self.data_ones, self.data_alt
        ] if v > 0)

    @property
    def coverage_pct(self) -> float:
        """Coverage percentage: bins_hit / 11 * 100."""
        return round(self.bins_hit / 11 * 100, 1)

    def missed_bins(self) -> List[str]:
        """
        Return list of profiles that would help cover missing bins.
        These are the 'holes' the AI needs to fill.
        """
        missed = []
        if self.addr_reserved == 0: missed.append("reserved")
        if self.addr_low      == 0: missed.append("addr_low")
        if self.addr_mid      == 0: missed.append("addr_mid")
        if self.addr_high     == 0: missed.append("addr_high")
        if self.rw_write      == 0: missed.append("write_only")
        if self.rw_read       == 0: missed.append("read_only")
        if self.nack          == 0: missed.append("nack_test")
        if not (self.data_zero and self.data_ones and self.data_alt):
            missed.append("all_data")
        return list(dict.fromkeys(missed))  # remove duplicates

    def display_table(self) -> str:
        """Pretty-print all bins with hit/miss status."""
        def row(name, val):
            mark = "✓" if val > 0 else "✗"
            bar  = "█" * min(val, 15)
            return f"  {mark}  {name:<28}  {val:>4}  {bar}"

        lines = [
            "  Coverage Bins:",
            "  " + "─" * 52,
            row("Addr Reserved  (0x00-0x07)", self.addr_reserved),
            row("Addr Low       (0x08-0x1F)", self.addr_low),
            row("Addr Mid       (0x20-0x5F)", self.addr_mid),
            row("Addr High      (0x60-0x77)", self.addr_high),
            row("RW Write                  ", self.rw_write),
            row("RW Read                   ", self.rw_read),
            row("ACK received              ", self.ack),
            row("NACK received             ", self.nack),
            row("Data = 0x00               ", self.data_zero),
            row("Data = 0xFF               ", self.data_ones),
            row("Data = 0x55 or 0xAA       ", self.data_alt),
            "  " + "─" * 52,
            f"  Total: {self.coverage_pct}%  ({self.bins_hit}/11 bins covered)",
        ]
        return "\n".join(lines)


# =================================================================
# PART 2: SIMULATION LOG PARSER
# Reads Vivado XSim log output, extracts [COV] lines
# Python reads this AUTOMATICALLY — no copy-paste needed
# =================================================================

def parse_simulation_log(log_text: str) -> Optional[CoverageData]:
    """
    Scan the Vivado simulation log for lines like:
      [COV] ADDR_LOW=5
      [COV] RW_WRITE=18
    These are printed by cov.export_for_ai() in the testbench.
    """
    key_map = {
        "ADDR_RESERVED": "addr_reserved",
        "ADDR_LOW":      "addr_low",
        "ADDR_MID":      "addr_mid",
        "ADDR_HIGH":     "addr_high",
        "RW_WRITE":      "rw_write",
        "RW_READ":       "rw_read",
        "ACK":           "ack",
        "NACK":          "nack",
        "DATA_ZERO":     "data_zero",
        "DATA_ONES":     "data_ones",
        "DATA_ALT":      "data_alt",
        "TOTAL_TXN":     "total_txn",
    }

    cov   = CoverageData()
    found = False

    for match in re.finditer(r'\[COV\]\s+(\w+)=(\d+)', log_text):
        key   = match.group(1)
        value = int(match.group(2))
        attr  = key_map.get(key)
        if attr:
            setattr(cov, attr, value)
            found = True

    return cov if found else None


# =================================================================
# PART 3: TESTBENCH FILE UPDATER
# Python rewrites the `define AI_PROFILE line in i2c_tb.sv
# This is how Python communicates the AI decision to SystemVerilog
# =================================================================

def update_tb_profile(profile: str) -> bool:
    """
    Find the line:   `define AI_PROFILE "xxx"
    Replace it with: `define AI_PROFILE "new_profile"
    Writes the file back to disk.
    """
    if not TB_FILE.exists():
        print(f"  [AI] ERROR: Testbench file not found: {TB_FILE}")
        return False

    with open(TB_FILE, 'r') as f:
        content = f.read()

    # Replace the profile define
    old_line_pattern = r'`define AI_PROFILE\s+"[^"]*"'
    new_line         = f'`define AI_PROFILE "{profile}"'

    if not re.search(old_line_pattern, content):
        print(f"  [AI] ERROR: Could not find `define AI_PROFILE in {TB_FILE}")
        return False

    new_content = re.sub(old_line_pattern, new_line, content)

    with open(TB_FILE, 'w') as f:
        f.write(new_content)

    print(f"  [AI] Updated i2c_tb.sv → profile = '{profile}'")
    return True


# =================================================================
# PART 4: VIVADO SIMULATOR RUNNER
# Compiles and runs the simulation using xvlog + xelab + xsim
# These are Vivado's command-line simulation tools
# =================================================================

def find_vivado() -> Optional[str]:
    """
    Find xvlog (Vivado's Verilog compiler) on the system PATH.
    Returns the path to the Vivado bin directory, or None.
    """
    # Check if xvlog is directly on PATH
    try:
        result = subprocess.run(
            ["xvlog", "--version"],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0:
            print("  [SIM] Found xvlog on PATH")
            return "on_path"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Common Vivado install locations
    search_paths = [
        # Windows
        r"C:\Xilinx\Vivado\2024.1\bin",
        r"C:\Xilinx\Vivado\2023.2\bin",
        r"C:\Xilinx\Vivado\2023.1\bin",
        r"C:\Xilinx\Vivado\2022.2\bin",
        r"C:\Xilinx\Vivado\2022.1\bin",
        # Linux
        "/tools/Xilinx/Vivado/2024.1/bin",
        "/tools/Xilinx/Vivado/2023.2/bin",
        "/tools/Xilinx/Vivado/2023.1/bin",
        "/opt/Xilinx/Vivado/2024.1/bin",
        "/opt/Xilinx/Vivado/2023.2/bin",
    ]

    for path in search_paths:
        xvlog = os.path.join(path, "xvlog")
        xvlog_win = os.path.join(path, "xvlog.bat")
        if os.path.exists(xvlog) or os.path.exists(xvlog_win):
            print(f"  [SIM] Found Vivado at: {path}")
            return path

    return None


def run_vivado_simulation(run_num: int) -> tuple[bool, str]:
    """
    Run a complete Vivado simulation:
      1. xvlog  — compile Verilog files
      2. xelab  — elaborate (link) the design
      3. xsim   — run the simulation

    Returns (success: bool, log_output: str)
    """
    LOG_DIR.mkdir(exist_ok=True)
    XSIM_DIR.mkdir(exist_ok=True)
    log_file = LOG_DIR / f"run_{run_num:02d}.log"

    # Find Vivado
    vivado_bin = find_vivado()
    if vivado_bin is None:
        msg = """
  [SIM] ERROR: Vivado (xvlog) not found!

  To fix this:
  Option A — Add Vivado to PATH before running this script:
    Windows: set PATH=C:\\Xilinx\\Vivado\\2024.1\\bin;%PATH%
    Linux:   source /tools/Xilinx/Vivado/2024.1/settings64.sh

  Option B — Edit VIVADO_BIN in this script (line ~230):
    VIVADO_BIN = r"C:\\Xilinx\\Vivado\\2024.1\\bin"
"""
        print(msg)
        return False, msg

    def cmd(tool):
        if vivado_bin == "on_path":
            return tool
        ext = ".bat" if sys.platform == "win32" else ""
        return os.path.join(vivado_bin, tool + ext)

    all_output = []

    try:
        print(f"  [SIM] Step 1/3 — Compiling RTL and testbench...")

        # Step 1: Compile — xvlog compiles all .v and .sv files
        compile_result = subprocess.run(
            [
                cmd("xvlog"),
                "--sv",                       # enable SystemVerilog
                "-nolog",                     # suppress separate log file
                str(MASTER_FILE),             # i2c_master.v
                str(SLAVE_FILE),              # i2c_slave.v
                str(TB_FILE),                 # i2c_tb.sv (testbench)
                "--work", f"work",
            ],
            capture_output=True, text=True,
            timeout=120, cwd=str(XSIM_DIR)
        )
        all_output.append(compile_result.stdout)
        all_output.append(compile_result.stderr)

        if compile_result.returncode != 0:
            print(f"  [SIM] Compile FAILED. Check errors below:")
            for line in compile_result.stderr.splitlines()[:20]:
                if line.strip():
                    print(f"    {line}")
            combined = "\n".join(all_output)
            with open(log_file, 'w') as f: f.write(combined)
            return False, combined

        print(f"  [SIM] Step 2/3 — Elaborating design...")

        # Step 2: Elaborate — xelab links the design hierarchy
        elab_result = subprocess.run(
            [
                cmd("xelab"),
                "-debug", "typical",          # enable signal capture
                "-nolog",
                "work.i2c_tb",               # top module = i2c_tb
                "-s", "i2c_tb_snapshot",     # snapshot name for xsim
            ],
            capture_output=True, text=True,
            timeout=120, cwd=str(XSIM_DIR)
        )
        all_output.append(elab_result.stdout)
        all_output.append(elab_result.stderr)

        if elab_result.returncode != 0:
            print(f"  [SIM] Elaborate FAILED.")
            for line in elab_result.stderr.splitlines()[:15]:
                if line.strip():
                    print(f"    {line}")
            combined = "\n".join(all_output)
            with open(log_file, 'w') as f: f.write(combined)
            return False, combined

        print(f"  [SIM] Step 3/3 — Running simulation...")

        # Step 3: Simulate — xsim runs and outputs $display text
        sim_result = subprocess.run(
            [
                cmd("xsim"),
                "i2c_tb_snapshot",           # the snapshot from xelab
                "-nolog",
                "-runall",                   # run until $finish
            ],
            capture_output=True, text=True,
            timeout=300, cwd=str(XSIM_DIR)
        )
        all_output.append(sim_result.stdout)
        all_output.append(sim_result.stderr)

        combined = "\n".join(all_output)
        with open(log_file, 'w') as f: f.write(combined)

        # Check if simulation produced coverage output
        success = "[COV] TOTAL_TXN" in combined or "[COV] ADDR_LOW" in combined
        if success:
            print(f"  [SIM] Simulation completed successfully")
        else:
            print(f"  [SIM] WARNING: No [COV] output found in log")
            print(f"  [SIM] Check {log_file} for details")

        return success, combined

    except subprocess.TimeoutExpired:
        print("  [SIM] ERROR: Simulation timed out (>300s)")
        return False, "TIMEOUT"
    except FileNotFoundError as e:
        print(f"  [SIM] ERROR: Tool not found: {e}")
        return False, str(e)


# =================================================================
# PART 5: AI STRATEGIES
# Three methods to decide which profile to use next
# =================================================================

# ─── Strategy A: Rule-Based ──────────────────────────────────────
# Simple priority list — always targets the first uncovered bin
# Fast and predictable. Good for baseline.

RULE_PRIORITY = [
    "addr_low", "addr_mid", "addr_high",
    "read_only", "write_only", "nack_test",
    "reserved", "all_data"
]

def strategy_rule(cov: CoverageData) -> str:
    """
    HOW IT WORKS:
    Scans the priority list from top to bottom.
    Returns the first profile that is still uncovered.

    Example:
      addr_low=0 hits → return "addr_low"
      addr_low=5, addr_mid=0 → skip addr_low, return "addr_mid"
    """
    missed = cov.missed_bins()
    print(f"  [RULE] Missed bins: {missed}")
    for profile in RULE_PRIORITY:
        if profile in missed:
            print(f"  [RULE] Targeting: '{profile}'")
            return profile
    return "random"


# ─── Strategy B: Genetic Algorithm ───────────────────────────────
# Evolves a population of profiles toward the best one
# Smarter than rule-based — can handle complex patterns

def ga_fitness(profile: str, cov: CoverageData) -> float:
    """
    Score a profile:
    Higher score = this profile is more likely to improve coverage.
    Score = how many hits the targeted bin currently has (0 = needs work).
    Small random noise breaks ties between equal candidates.
    """
    missed = cov.missed_bins()
    # Base scores — how much each profile would help right now
    score_map = {
        "addr_low":   20 if "addr_low"   in missed else 1,
        "addr_mid":   20 if "addr_mid"   in missed else 1,
        "addr_high":  20 if "addr_high"  in missed else 1,
        "reserved":   15 if "reserved"   in missed else 1,
        "read_only":  18 if "read_only"  in missed else 1,
        "write_only": 18 if "write_only" in missed else 1,
        "nack_test":  18 if "nack_test"  in missed else 1,
        "all_data":   12 if "all_data"   in missed else 1,
        "random":     max(0, (11 - cov.bins_hit) * 2),
    }
    return score_map.get(profile, 0) + random.uniform(0, 2)

def strategy_genetic(cov: CoverageData,
                     population_size: int = 10,
                     generations:     int = 6) -> str:
    """
    HOW IT WORKS:
      Generation 0: 10 random profiles (population)
      Each generation:
        1. Score each profile with ga_fitness()
        2. Keep top 5 (selection — survival of the fittest)
        3. Breed 5 children by mixing pairs of survivors (crossover)
        4. 25% chance each child becomes random (mutation)
      After 6 generations: return the highest-scoring profile

    WHY BETTER THAN RULE-BASED:
      Mutation can discover that some bins need to be
      targeted in a specific order that the priority
      list wouldn't figure out.
    """
    # Start with a random population
    population = [random.choice(ALL_PROFILES)
                  for _ in range(population_size)]

    for gen in range(generations):
        # Score every individual
        population.sort(key=lambda p: ga_fitness(p, cov), reverse=True)
        best_fitness = ga_fitness(population[0], cov)
        print(f"  [GA] Gen {gen+1}: best='{population[0]}'  fitness={best_fitness:.1f}")

        # Keep top half
        survivors = population[:population_size // 2]

        # Breed children
        children = []
        while len(children) < population_size // 2:
            parent1 = random.choice(survivors)
            parent2 = random.choice(survivors)
            # Crossover: average the profile's index in the list
            idx1  = ALL_PROFILES.index(parent1)
            idx2  = ALL_PROFILES.index(parent2)
            child = ALL_PROFILES[(idx1 + idx2) // 2]
            # Mutation: 25% chance of random jump
            if random.random() < 0.25:
                child = random.choice(ALL_PROFILES)
            children.append(child)

        population = survivors + children

    # Return the winner
    winner = max(population, key=lambda p: ga_fitness(p, cov))
    print(f"  [GA] Winner: '{winner}'")
    return winner


# ─── Strategy C: Reinforcement Learning (Q-Learning) ─────────────
# Agent learns which profiles work best at each coverage level
# Gets smarter with each run

def strategy_rl(cov: CoverageData, history: list) -> str:
    """
    HOW IT WORKS:
      State  = current coverage bucket (0%, 10%, 20%, ... 100%)
      Action = which profile to use (8 choices)
      Reward = how much coverage improved after that action

      Q[state][action] stores the "expected reward" for each choice.
      After each run, Q is updated:
        Q[s][a] += learning_rate * (reward + discount * max(Q[next_s]) - Q[s][a])

      Exploration: 30% chance of picking random action
      Exploitation: 70% chance of picking highest Q value

    ADVANTAGE: After 8-10 runs, the agent has learned exactly
    which profile works best at 50% coverage, 70% coverage, etc.
    """
    q = {}
    if Q_TABLE_FILE.exists():
        with open(Q_TABLE_FILE) as f:
            q = json.load(f)

    n      = len(ALL_PROFILES)
    state  = str(int(cov.coverage_pct // 10) * 10)  # bucket: "50", "60", etc.

    if state not in q:
        q[state] = [0.0] * n

    # Update Q from the previous run's outcome
    if history:
        prev        = history[-1]
        prev_state  = str(int(prev["pct"] // 10) * 10)
        prev_action = ALL_PROFILES.index(prev["profile"]) \
                      if prev["profile"] in ALL_PROFILES else 0

        if prev_state not in q:
            q[prev_state] = [0.0] * n

        # Reward = coverage gained since last run
        reward = cov.coverage_pct - prev["pct"]

        # Q-learning update
        learning_rate = 0.1
        discount      = 0.9
        old_q = q[prev_state][prev_action]
        new_q = old_q + learning_rate * (
            reward + discount * max(q[state]) - old_q
        )
        q[prev_state][prev_action] = new_q
        print(f"  [RL] Reward={reward:.1f}%  "
              f"Q[{prev_state}][{prev_action}]: {old_q:.2f} → {new_q:.2f}")

    # Save updated Q-table
    REPORTS_DIR.mkdir(exist_ok=True)
    with open(Q_TABLE_FILE, 'w') as f:
        json.dump(q, f, indent=2)

    # Choose action: explore or exploit
    if random.random() < 0.30:
        action = random.randint(0, n - 1)
        print(f"  [RL] Exploring → action {action} = '{ALL_PROFILES[action]}'")
    else:
        action = q[state].index(max(q[state]))
        print(f"  [RL] Exploiting → action {action} = '{ALL_PROFILES[action]}'"
              f"  (Q={max(q[state]):.2f})")

    return ALL_PROFILES[action]


def pick_next_profile(strategy: str, cov: CoverageData,
                      history: list) -> str:
    """Choose the AI strategy and get the next profile."""
    if   strategy == "rule":    return strategy_rule(cov)
    elif strategy == "genetic": return strategy_genetic(cov)
    elif strategy == "rl":      return strategy_rl(cov, history)
    else:                       return strategy_rule(cov)


# =================================================================
# PART 6: HISTORY AND PROGRESS REPORTING
# =================================================================

def load_history() -> list:
    if HISTORY_FILE.exists():
        with open(HISTORY_FILE) as f:
            return json.load(f)
    return []

def save_to_history(history: list, run_num: int,
                    pct: float, profile: str, bins: int):
    history.append({
        "run":     run_num,
        "pct":     pct,
        "bins":    bins,
        "profile": profile
    })
    REPORTS_DIR.mkdir(exist_ok=True)
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, indent=2)

def print_progress_chart(history: list, current_pct: float):
    """ASCII progress chart showing all runs so far."""
    W = 30  # bar width
    print("")
    print(f"  {'━' * 56}")
    print(f"  Coverage Progress")
    print(f"  {'━' * 56}")
    for h in history:
        filled = int(h["pct"] / 100 * W)
        bar    = "█" * filled + "░" * (W - filled)
        tick   = "✓" if h["pct"] >= TARGET_PCT else " "
        print(f"  Run {h['run']:>2} {tick}  [{bar}]  "
              f"{h['pct']:5.1f}%  {h['profile']}")
    # Current run
    filled = int(current_pct / 100 * W)
    bar    = "█" * filled + "░" * (W - filled)
    tick   = "✓" if current_pct >= TARGET_PCT else "►"
    rn     = len(history)
    print(f"  Run {rn:>2} {tick}  [{bar}]  "
          f"{current_pct:5.1f}%  ← NOW")
    print(f"  {'━' * 56}")
    print("")


def generate_html_report(history: list):
    """Save a color-coded HTML coverage report."""
    if not history:
        return

    def color(v):
        if v >= 100: return "#22c55e"
        if v >= 70:  return "#f59e0b"
        return "#ef4444"

    rows = ""
    for h in history:
        c = color(h["pct"])
        w = int(h["pct"])
        rows += f"""
        <tr>
          <td>Run {h['run']}</td>
          <td style="color:{c};font-weight:700">{h['pct']}%</td>
          <td>{h['bins']}/11</td>
          <td><code>{h['profile']}</code></td>
          <td><div style="width:{w}%;min-width:4px;height:12px;
               background:{c};border-radius:3px"></div></td>
        </tr>"""

    html = f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<title>I2C AI Coverage — Vivado</title>
<style>
  body{{font-family:system-ui;background:#0f1117;color:#e2e8f0;
        padding:32px;margin:0}}
  h1{{font-size:22px;font-weight:600;margin-bottom:6px}}
  .sub{{color:#64748b;font-size:14px;margin-bottom:24px}}
  table{{border-collapse:collapse;width:100%;font-size:14px}}
  th{{background:#1e2433;color:#94a3b8;padding:10px 14px;text-align:left;
      font-size:11px;text-transform:uppercase;letter-spacing:.06em}}
  td{{padding:10px 14px;border-bottom:1px solid #1e2433}}
  tr:hover td{{background:#1e2433}}
  code{{font-family:monospace;font-size:12px;color:#94a3b8}}
</style></head><body>
<h1>I2C AI Coverage — Vivado XSim</h1>
<p class="sub">Autonomous AI achieved
  <strong style="color:#22c55e">{max(h['pct'] for h in history):.1f}%</strong>
  coverage in {len(history)} simulation runs
</p>
<table>
  <thead><tr>
    <th>Run</th><th>Coverage</th><th>Bins</th>
    <th>AI Profile</th><th>Progress</th>
  </tr></thead>
  <tbody>{rows}</tbody>
</table>
</body></html>"""

    REPORTS_DIR.mkdir(exist_ok=True)
    report_path = REPORTS_DIR / "coverage_report.html"
    with open(report_path, 'w') as f:
        f.write(html)
    print(f"  [RPT] HTML report saved: {report_path}")


# =================================================================
# PART 7: MAIN AUTONOMOUS LOOP
# Runs everything automatically from start to 100% coverage
# =================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Autonomous I2C Coverage AI for Vivado",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 ai/vivado_ai.py
  python3 ai/vivado_ai.py --strategy rule
  python3 ai/vivado_ai.py --strategy genetic --target 100
  python3 ai/vivado_ai.py --strategy rl --runs 8
        """
    )
    parser.add_argument("--strategy", default="genetic",
                        choices=["rule", "genetic", "rl"],
                        help="AI strategy (default: genetic)")
    parser.add_argument("--target",   type=float, default=100.0,
                        help="Stop when coverage reaches this %% (default: 100)")
    parser.add_argument("--runs",     type=int,   default=MAX_RUNS,
                        help="Maximum simulation runs (default: 10)")
    args = parser.parse_args()

    print("")
    print("=" * 60)
    print("  I2C Autonomous AI Coverage Engine")
    print(f"  Strategy : {args.strategy.upper()}")
    print(f"  Target   : {args.target}%")
    print(f"  Max Runs : {args.runs}")
    print(f"  TB File  : {TB_FILE}")
    print("=" * 60)
    print("")

    # Verify project files exist
    for f in [TB_FILE, MASTER_FILE, SLAVE_FILE]:
        if not f.exists():
            print(f"  ERROR: File not found: {f}")
            print(f"  Check that PROJECT_ROOT is set correctly.")
            sys.exit(1)

    # Load history from previous sessions
    history = load_history()
    profile = "random"   # always start with random on run 0
    current_pct = 0.0

    for run_num in range(args.runs):
        print(f"{'─' * 60}")
        print(f"  RUN #{run_num}  |  AI Profile: '{profile}'")
        print(f"{'─' * 60}")

        # ── Step 1: Inject profile into testbench ───────────────
        if not update_tb_profile(profile):
            print("  ABORT: Could not update testbench file.")
            break

        # ── Step 2: Run Vivado simulation ────────────────────────
        t_start = time.time()
        success, log_text = run_vivado_simulation(run_num)
        elapsed = time.time() - t_start
        print(f"  [SIM] Completed in {elapsed:.1f}s")

        if not success:
            print(f"  ERROR: Simulation failed. See logs in {LOG_DIR}/")
            break

        # ── Step 3: Parse coverage from log (AUTOMATIC) ─────────
        cov = parse_simulation_log(log_text)
        if cov is None:
            print("  ERROR: No coverage data found in simulation log.")
            print(f"  Check {LOG_DIR}/run_{run_num:02d}.log")
            break

        current_pct = cov.coverage_pct

        # ── Step 4: Display results ──────────────────────────────
        print("")
        print(f"  Run #{run_num} Results:")
        print(cov.display_table())

        save_to_history(history, run_num, current_pct, profile, cov.bins_hit)
        print_progress_chart(history, current_pct)

        # ── Step 5: Check if target reached ─────────────────────
        if current_pct >= args.target:
            print(f"  TARGET {args.target}% REACHED after {run_num + 1} runs!")
            print("")
            print("  Summary of all runs:")
            for h in history:
                tick = "✓" if h["pct"] >= args.target else " "
                print(f"    {tick} Run {h['run']}: {h['pct']:5.1f}%  profile='{h['profile']}'")
            break

        # ── Step 6: AI decides next profile ─────────────────────
        missed = cov.missed_bins()
        print(f"  [AI] Missed bins: {missed}")

        profile = pick_next_profile(args.strategy, cov, history)
        print(f"  [AI] Next profile → '{profile}'")
        print("")

    else:
        print(f"\n  Max runs ({args.runs}) reached.")
        print(f"  Final coverage: {current_pct:.1f}%")
        if current_pct < args.target:
            print(f"  Try: python3 ai/vivado_ai.py --runs {args.runs + 5}")

    # ── Final reports ────────────────────────────────────────────
    generate_html_report(history)
    print(f"\n  Logs    : {LOG_DIR}/")
    print(f"  Reports : {REPORTS_DIR}/")
    print("")


if __name__ == "__main__":
    main()
