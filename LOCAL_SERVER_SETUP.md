# 🖥️ LOCAL SERVER SETUP & VERIFICATION GUIDE

**Date**: May 13, 2026  
**Project**: I2C AI Verification  
**Purpose**: Complete local setup and verification checklist  

---

## 📋 TABLE OF CONTENTS

1. [System Requirements](#system-requirements)
2. [Local Clone & Setup](#local-clone--setup)
3. [Verification Checklist](#verification-checklist)
4. [File Structure Validation](#file-structure-validation)
5. [Python Environment Setup](#python-environment-setup)
6. [Vivado Tools Verification](#vivado-tools-verification)
7. [Quick Test Run](#quick-test-run)
8. [Local Server Deployment](#local-server-deployment)
9. [Troubleshooting](#troubleshooting)

---

## 🔧 SYSTEM REQUIREMENTS

### Hardware
```
Processor:    Intel/AMD x86-64 or ARM64
RAM:          8GB minimum (16GB recommended)
Disk Space:   5GB free (for Vivado + projects)
OS:           Windows 10+, Linux (Ubuntu 20.04+), or macOS (with VM)
```

### Software

#### Required
```
✓ Git               (v2.35+)          - For cloning repo
✓ Python            (v3.8+)           - For AI engine
✓ Vivado            (v2023.x or 2024.x) - For simulation
  - xvlog (compiler)
  - xelab (elaborator)
  - xsim  (simulator)
```

#### Optional but Recommended
```
✓ Visual Studio Code - Code editor
✓ GitHub Desktop    - Git GUI (Windows/macOS)
✓ bash/zsh          - Terminal (Linux/macOS native; Git Bash on Windows)
```

---

## 📥 LOCAL CLONE & SETUP

### Step 1: Clone Repository

**Windows (Command Prompt):**
```cmd
cd C:\Users\YourName\Documents
git clone https://github.com/vinayguntuk-design/i2c_ai_verification.git
cd i2c_ai_verification
```

**Linux/macOS (Terminal):**
```bash
cd ~/Documents
git clone https://github.com/vinayguntuk-design/i2c_ai_verification.git
cd i2c_ai_verification
```

**Verify Clone:**
```bash
git log --oneline | head -5
# Should show recent commits
```

### Step 2: Verify Directory Structure

```bash
# List top-level files
ls -la

# Should show:
# .git/               ← Git repository metadata
# .gitignore          ← Git ignore rules
# rtl/                ← Verilog design files
# sim/                ← Testbench files
# ai/                 ← Python AI engine
# scripts/            ← Tcl automation scripts
# *.md                ← Documentation files
```

### Step 3: Check Git Status

```bash
git status
# Should show:
# On branch main
# Your branch is up to date with 'origin/main'.
# nothing to commit, working tree clean
```

---

## ✅ VERIFICATION CHECKLIST

### Quick Start Verification (5 minutes)

```bash
# 1. Check Python installation
python --version
# Expected: Python 3.8.0 or higher

# 2. Check Git installation
git --version
# Expected: git version 2.35.0 or higher

# 3. Verify repository cloned correctly
cd i2c_ai_verification
pwd
# Should show full path to project directory

# 4. Count project files
find . -type f | wc -l
# Should show 50+ files

# 5. List main directories
ls -d */
# Should show: rtl/  sim/  ai/  scripts/
```

### File Integrity Check

```bash
# List all files with their sizes
ls -lhR

# Check key files exist
test -f ai/vivado_ai.py && echo "✓ AI engine found" || echo "✗ AI engine missing"
test -f sim/i2c_tb.sv && echo "✓ Testbench found" || echo "✗ Testbench missing"
test -f rtl/i2c_master.v && echo "✓ Master RTL found" || echo "✗ Master RTL missing"
test -f rtl/i2c_slave.v && echo "✓ Slave RTL found" || echo "✗ Slave RTL missing"
test -f README.md && echo "✓ README found" || echo "✗ README missing"
```

### Documentation Completeness Check

```bash
# Count markdown files
ls -1 *.md | wc -l
# Should show: 14 files

# List all documentation
ls -1 *.md
# Should show:
ANALYSIS_AND_FIXES.md
CHANGE_LOG.md
DELIVERABLES_SUMMARY.md
DOCUMENTATION_INDEX.md
EXECUTION_GUIDE.md
FINAL_CHECKLIST.md
PRESENTATION_READY.md
PRESENTATION_SLIDES.md
PROGRESS_REPORT_FOR_MENTORS.md
PROJECT_DELIVERABLES_MAP.md
PROJECT_STATUS_REPORT.md
QUICK_START.md
README.md
README_100_COVERAGE.md
VISUAL_SUMMARY.md
```

---

## 📂 FILE STRUCTURE VALIDATION

### Expected Structure

```
i2c_ai_verification/
│
├── .git/                          (Git metadata - hidden)
├── .gitignore                     (Git ignore rules)
│
├── rtl/                           [Verilog HDL - 18.3%]
│   ├── i2c_master.v               (DUT - 252 lines)
│   ├── i2c_slave.v                (Reference - 234 lines)
│   ├── VIV_i2c_master.v           (Alternative version)
│   └── VIV_i2c_slave.v            (Alternative version)
│
├── sim/                           [SystemVerilog - 22.7%]
│   └── i2c_tb.sv                  (Testbench - 800+ lines)
│
├── ai/                            [Python - 32%]
│   ├── vivado_ai.py               (Main AI engine - 995 lines)
│   └── VIV_vivado_ai.py           (Alternative version)
│
├── scripts/                       [Tcl - 12.5%]
│   ├── create_project.tcl         (Project creation)
│   ├── run_sim.tcl                (Simulation runner)
│   ├── run_full_flow.tcl          (Complete flow)
│   ├── manual_create_project.tcl  (Manual setup)
│   ├── manual_run_simulation.tcl  (Manual simulation)
│   ├── VIV_create_project.tcl     (Alternative)
│   └── VIV_run_sim.tcl            (Alternative)
│
├── Documentation/                 [Markdown - various]
│   ├── README.md                  (Setup guide)
│   ├── QUICK_START.md             (Fast track)
│   ├── EXECUTION_GUIDE.md         (Detailed steps)
│   ├── ANALYSIS_AND_FIXES.md      (Root cause)
│   ├── CHANGE_LOG.md              (What changed)
│   ├── PRESENTATION_READY.md      (This summary)
│   ├── PRESENTATION_SLIDES.md     (Slide deck)
│   └── (7 more guides)
│
├── i2c_ai_verification.xpr        (Vivado project file)
├── find_vivado.py                 (Vivado locator utility)
├── run_ai.bat                     (Windows batch script)
├── run_vivado_full_flow.bat       (Windows batch script)
│
├── reports/                       (Auto-generated - empty initially)
│   ├── coverage_report.html       (Generated after run)
│   ├── coverage_history.json      (Generated after run)
│   └── q_table.json               (Generated if using RL)
│
├── sim_logs/                      (Auto-generated - empty initially)
│   └── run_00.log ... run_14.log  (Generated during runs)
│
└── xsim_work/                     (Auto-generated - empty initially)
    └── work/                      (Vivado work directory)
```

### Validate Structure Script

**Create file: `verify_structure.sh`**

```bash
#!/bin/bash

echo "=== I2C AI Verification - Local Structure Validation ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

passed=0
failed=0

# Function to check file
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((passed++))
    else
        echo -e "${RED}✗${NC} $1 (MISSING)"
        ((failed++))
    fi
}

# Function to check directory
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
        ((passed++))
    else
        echo -e "${RED}✗${NC} $1/ (MISSING)"
        ((failed++))
    fi
}

echo "=== Checking Directories ==="
check_dir "rtl"
check_dir "sim"
check_dir "ai"
check_dir "scripts"
check_dir "reports"
check_dir "sim_logs"

echo ""
echo "=== Checking RTL Files ==="
check_file "rtl/i2c_master.v"
check_file "rtl/i2c_slave.v"

echo ""
echo "=== Checking Testbench ==="
check_file "sim/i2c_tb.sv"

echo ""
echo "=== Checking AI Engine ==="
check_file "ai/vivado_ai.py"

echo ""
echo "=== Checking Scripts ==="
check_file "scripts/create_project.tcl"
check_file "scripts/run_sim.tcl"
check_file "scripts/run_full_flow.tcl"

echo ""
echo "=== Checking Documentation ==="
check_file "README.md"
check_file "QUICK_START.md"
check_file "EXECUTION_GUIDE.md"
check_file "ANALYSIS_AND_FIXES.md"
check_file "PRESENTATION_READY.md"

echo ""
echo "=== Checking Configuration ==="
check_file "i2c_ai_verification.xpr"
check_file ".gitignore"

echo ""
echo "=== Summary ==="
echo -e "${GREEN}Passed: $passed${NC}"
echo -e "${RED}Failed: $failed${NC}"

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All files present!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some files missing!${NC}"
    exit 1
fi
```

**Run validation:**

```bash
# Make executable
chmod +x verify_structure.sh

# Run
./verify_structure.sh
```

---

## 🐍 PYTHON ENVIRONMENT SETUP

### Check Python Installation

```bash
# Check version
python --version
python3 --version

# Check pip
pip --version
pip3 --version

# Check location
which python
which python3
```

**Expected:** Python 3.8.0 or higher

### Create Virtual Environment (Recommended)

```bash
# Navigate to project
cd i2c_ai_verification

# Create venv
python -m venv venv

# Activate venv
# Windows:
venv\Scripts\activate

# Linux/macOS:
source venv/bin/activate

# Verify activation (should show (venv) in prompt)
python --version
```

### Install Dependencies

```bash
# Upgrade pip
pip install --upgrade pip

# Install required packages (if needed)
pip install pathlib dataclasses typing

# Verify imports work
python -c "import os, re, sys, json, time, random, argparse, subprocess"
# Should complete without errors
```

### Test AI Engine Import

```bash
# Test if vivado_ai.py can be imported
python -c "
import sys
sys.path.insert(0, 'ai')
print('✓ AI module path OK')
"

# Check syntax
python -m py_compile ai/vivado_ai.py
# Should complete without errors
```

---

## 🔧 VIVADO TOOLS VERIFICATION

### Check Vivado Installation

**Windows:**
```cmd
# Option 1: Check PATH
where xvlog
where xelab
where xsim

# Option 2: Run version check
xvlog --version
xelab --version
xsim --version
```

**Linux/macOS:**
```bash
# Option 1: Check if in PATH
which xvlog
which xelab
which xsim

# Option 2: Run version check
xvlog --version
xelab --version
xsim --version
```

### If Vivado Not Found

**Windows - Add to PATH:**
```cmd
set PATH=C:\Xilinx\Vivado\2024.1\bin;%PATH%

# Verify
xvlog --version
```

**Linux - Source settings:**
```bash
source /tools/Xilinx/Vivado/2024.1/settings64.sh

# Verify
xvlog --version
```

**Use Finder Script:**
```bash
# Run the included finder script
python find_vivado.py

# Output will show:
# ✓ Found: C:\Xilinx\Vivado\2024.1\bin
# 
# How to fix:
# Option A - Add Vivado to PATH (Windows):
#   set PATH=C:\Xilinx\Vivado\2024.1\bin;%PATH%
```

---

## 🧪 QUICK TEST RUN

### Test 1: Python Script Syntax Check

```bash
# Check if script has valid Python syntax
python -m py_compile ai/vivado_ai.py
echo "✓ Syntax OK"

# Try to show help
python ai/vivado_ai.py --help
# Should show usage information
```

### Test 2: File Access Check

```bash
# Try to read key files
python -c "
from pathlib import Path

files = [
    'sim/i2c_tb.sv',
    'rtl/i2c_master.v',
    'rtl/i2c_slave.v',
    'ai/vivado_ai.py'
]

for f in files:
    p = Path(f)
    if p.exists():
        size = p.stat().st_size
        print(f'✓ {f} ({size} bytes)')
    else:
        print(f'✗ {f} NOT FOUND')
"
```

### Test 3: Vivado Tools Check

```bash
# Test xvlog
xvlog --version
# Should show: Vivado 2024.1 ...

# Test xelab
xelab --version
# Should show: Vivado 2024.1 ...

# Test xsim
xsim --version
# Should show: Vivado 2024.1 ...
```

### Test 4: Directory Creation

```bash
# Test if script can create required directories
python -c "
from pathlib import Path

dirs = ['sim_logs', 'reports', 'xsim_work']

for d in dirs:
    p = Path(d)
    p.mkdir(exist_ok=True)
    if p.exists():
        print(f'✓ {d}/ created/exists')
    else:
        print(f'✗ {d}/ failed')
"
```

---

## 🚀 LOCAL SERVER DEPLOYMENT

### Option 1: Direct Execution (Simplest)

```bash
# 1. Ensure Vivado is on PATH
set PATH=C:\Xilinx\Vivado\2024.1\bin;%PATH%

# 2. Run AI engine
cd i2c_ai_verification
python ai/vivado_ai.py --strategy genetic --target 100 --runs 15

# 3. Monitor progress
tail -f reports/coverage_history.json  # Linux/macOS
# or
type reports\coverage_history.json     # Windows PowerShell
```

### Option 2: Using Batch Script (Windows)

**File: `run_locally.bat`**

```batch
@echo off
REM Local Server Run Script for I2C AI Verification

echo.
echo ====================================================
echo  I2C AI Verification - Local Execution
echo ====================================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found!
    echo Please install Python 3.8+ from python.org
    exit /b 1
)

REM Set Vivado PATH
set PATH=C:\Xilinx\Vivado\2024.1\bin;%PATH%

REM Check Vivado
xvlog --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Vivado tools not found!
    echo Please set PATH correctly or install Vivado 2024.1
    exit /b 1
)

REM Create directories
if not exist reports mkdir reports
if not exist sim_logs mkdir sim_logs
if not exist xsim_work mkdir xsim_work

REM Run AI Engine
echo.
echo Starting AI Coverage Engine...
echo.

python ai/vivado_ai.py --strategy genetic --target 100 --runs 15

if %errorlevel% equ 0 (
    echo.
    echo ====================================================
    echo  SUCCESS: Check reports\coverage_report.html
    echo ====================================================
    echo.
    start reports\coverage_report.html
) else (
    echo.
    echo ERROR: AI engine failed!
    echo Check sim_logs\ for details
    echo.
    exit /b 1
)
```

**Run:**
```cmd
.\run_locally.bat
```

### Option 3: Using Shell Script (Linux/macOS)

**File: `run_locally.sh`**

```bash
#!/bin/bash

# Local Server Run Script for I2C AI Verification

echo ""
echo "===================================================="
echo "  I2C AI Verification - Local Execution"
echo "===================================================="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python not found!"
    echo "Please install Python 3.8+ using:"
    echo "  apt-get install python3"
    exit 1
fi

# Check Vivado
if ! command -v xvlog &> /dev/null; then
    echo "ERROR: Vivado tools not found!"
    echo "Please source Vivado settings:"
    echo "  source /tools/Xilinx/Vivado/2024.1/settings64.sh"
    exit 1
fi

# Create directories
mkdir -p reports sim_logs xsim_work

# Run AI Engine
echo ""
echo "Starting AI Coverage Engine..."
echo ""

python3 ai/vivado_ai.py --strategy genetic --target 100 --runs 15

if [ $? -eq 0 ]; then
    echo ""
    echo "===================================================="
    echo "  SUCCESS: Check reports/coverage_report.html"
    echo "===================================================="
    echo ""
    
    # Open report in browser if available
    if command -v xdg-open &> /dev/null; then
        xdg-open reports/coverage_report.html
    elif command -v open &> /dev/null; then
        open reports/coverage_report.html
    fi
else
    echo ""
    echo "ERROR: AI engine failed!"
    echo "Check sim_logs/ for details"
    echo ""
    exit 1
fi
```

**Run:**
```bash
chmod +x run_locally.sh
./run_locally.sh
```

### Option 4: Docker Container (Advanced)

**File: `Dockerfile`**

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /project

# Copy repository
COPY . /project/

# Install Python dependencies
RUN pip3 install --no-cache-dir pathlib

# Create output directories
RUN mkdir -p reports sim_logs xsim_work

# Default command
CMD ["python3", "ai/vivado_ai.py", "--strategy", "genetic", "--target", "100", "--runs", "15"]
```

**Build and run:**
```bash
docker build -t i2c_ai_verification .
docker run -v $(pwd)/reports:/project/reports \
           -v $(pwd)/sim_logs:/project/sim_logs \
           i2c_ai_verification
```

---

## 🐛 TROUBLESHOOTING

### Problem: "Python not found"

**Solution:**
```bash
# Check installation
python --version

# If not found, install from:
# Windows: https://www.python.org/downloads/
# Linux:   sudo apt-get install python3
# macOS:   brew install python3

# After install, restart terminal
python --version
```

### Problem: "Vivado tools not found"

**Solution:**

```bash
# Option 1: Add to PATH
# Windows:
set PATH=C:\Xilinx\Vivado\2024.1\bin;%PATH%

# Linux:
source /tools/Xilinx/Vivado/2024.1/settings64.sh

# Option 2: Find Vivado installation
python find_vivado.py
# This will show you the correct path

# Option 3: Check common locations
# Windows: C:\Xilinx\Vivado\2024.1\bin
# Linux:   /tools/Xilinx/Vivado/2024.1/bin
#          /opt/Xilinx/Vivado/2024.1/bin
```

### Problem: "Permission denied" (Linux/macOS)

**Solution:**
```bash
# Make scripts executable
chmod +x run_locally.sh
chmod +x verify_structure.sh
chmod +x ai/vivado_ai.py
chmod +x find_vivado.py

# Then run
./run_locally.sh
```

### Problem: "No such file or directory"

**Solution:**
```bash
# Verify you're in correct directory
pwd
# Should show: .../i2c_ai_verification

# List files
ls -la

# Check git status
git status

# If wrong directory, navigate:
cd i2c_ai_verification
```

### Problem: Coverage not reaching 100%

**Solution:**
```bash
# Check simulation logs
tail -100 sim_logs/run_10.log
# Look for "ERROR" or "FAILED"

# Run with more iterations
python ai/vivado_ai.py --strategy genetic --target 100 --runs 20

# Try different strategy
python ai/vivado_ai.py --strategy rule --target 100 --runs 15
```

### Problem: "xvlog not found" during simulation

**Solution:**
```bash
# Verify Vivado is on PATH
xvlog --version

# If still not found:
# 1. Find Vivado
python find_vivado.py

# 2. Add to PATH permanently
# Windows: System Properties → Environment Variables
# Linux: Add to ~/.bashrc:
#   export PATH=/tools/Xilinx/Vivado/2024.1/bin:$PATH
# macOS: Add to ~/.zshrc

# 3. Restart terminal and retry
```

---

## 📊 LOCAL VERIFICATION REPORT

After running locally, you should see:

```
====================================================
  I2C Autonomous AI Coverage Engine
  Strategy : GENETIC
  Target   : 100.0%
  Max Runs : 15
====================================================

Run #0  |  AI Profile: 'random'
  [SIM] Compiling RTL and testbench...
  [SIM] Elaborating design...
  [SIM] Running simulation...
  [SIM] Completed in 8.3s

  Coverage Bins:
  ────────────────────────────────────────────
  OK  Addr Reserved  (0x00-0x07)          0
  OK  Addr Low       (0x08-0x1F)          5  █████
  X   Addr Mid       (0x20-0x5F)          0
  X   Addr High      (0x60-0x77)          0
  OK  RW Write                           18  ██████████
  OK  RW Read                            12  ████████████
  OK  ACK received                       28  ██████████
  OK  NACK received                       2  ██
  OK  Data = 0x00                         2  ██
  OK  Data = 0xFF                         1  █
  X   Data = 0x55 or 0xAA                 0
  ────────────────────────────────────────────
  Total: 90.9%  (10/11 bins covered)

  Run  0   [█████████████████████░░░░░░░░░]  90.9%  random
  Run  1 ► [████████████████████████░░░░░░]   NOW

  [AI] Missed bins: ['data_alt']
  [AI] Next profile → 'data_alt'

Run #1  |  AI Profile: 'data_alt'
  [SIM] Compiling RTL and testbench...
  [SIM] Elaborating design...
  [SIM] Running simulation...
  [SIM] Completed in 8.2s

  Coverage Bins:
  ────────────────────────────────────────────
  OK  Data = 0x55 or 0xAA                12  ████████████
  ────────────────────────────────────────────
  Total: 100.0%  (11/11 bins covered)  ✓

  TARGET 100% REACHED after 2 runs!

  [RPT] HTML report saved: reports/coverage_report.html

  Logs    : sim_logs/
  Reports : reports/

====================================================
✓ SUCCESS: Open reports/coverage_report.html
====================================================
```

---

## ✅ FINAL CHECKLIST

After local setup:

- [ ] Git repository cloned successfully
- [ ] All files present (run `verify_structure.sh`)
- [ ] Python 3.8+ installed and working
- [ ] Vivado tools (xvlog, xelab, xsim) accessible
- [ ] Directories created (reports/, sim_logs/, xsim_work/)
- [ ] AI engine syntax valid (`python -m py_compile ai/vivado_ai.py`)
- [ ] Test run completed without errors
- [ ] Coverage report generated (`reports/coverage_report.html`)
- [ ] 100% coverage achieved (11/11 bins)
- [ ] Documentation reviewed

---

**Status**: ✅ **READY FOR LOCAL VERIFICATION**

Once all steps complete, you'll have a fully functional local environment ready for development, testing, and presentation!

