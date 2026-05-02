# =================================================================
# FILE    : scripts/create_project.tcl
# PURPOSE : Creates Vivado project and runs simulation automatically
#
# HOW TO USE IN VIVADO:
#   Option A (GUI):
#     Open Vivado → Tools → Run Tcl Script → select this file
#
#   Option B (Command line):
#     vivado -mode tcl -source scripts/create_project.tcl
#
# WHAT THIS SCRIPT DOES:
#   1. Creates a new Vivado project
#   2. Adds all RTL and simulation files
#   3. Sets simulation top module
#   4. Runs behavioral simulation
# =================================================================

# ── Get the script's directory (project root) ──────────────────
set script_dir [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]

puts "================================================================"
puts "  I2C Vivado Project Setup"
puts "  Project root: $project_root"
puts "================================================================"

# ── Create project ──────────────────────────────────────────────
set project_name "i2c_ai_verification"
set project_dir  "$project_root/vivado_project"

create_project $project_name $project_dir -part xc7a35tcpg236-1 -force
puts "  Created project: $project_name"

# ── Add RTL source files ─────────────────────────────────────────
add_files -norecurse "$project_root/rtl/i2c_master.v"
add_files -norecurse "$project_root/rtl/i2c_slave.v"
puts "  Added RTL files: i2c_master.v, i2c_slave.v"

# ── Add simulation testbench ─────────────────────────────────────
add_files -fileset sim_1 -norecurse "$project_root/sim/i2c_tb.sv"
puts "  Added testbench: i2c_tb.sv"

# ── Set simulation top module ────────────────────────────────────
set_property top i2c_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
puts "  Simulation top: i2c_tb"

# ── Set simulation runtime ────────────────────────────────────────
# 10ms is plenty for our testbench (it $finishes before this)
set_property -name {xsim.simulate.runtime} -value {10ms} \
             -objects [get_filesets sim_1]

# ── Run behavioral simulation ─────────────────────────────────────
puts ""
puts "  Starting behavioral simulation..."
launch_simulation
run all
puts "  Simulation complete"

puts ""
puts "================================================================"
puts "  Project setup complete!"
puts ""
puts "  NEXT STEPS:"
puts "  1. Open Vivado waveform viewer to see SCL/SDA signals"
puts "  2. In the terminal, run the AI engine:"
puts "     python3 $project_root/ai/vivado_ai.py"
puts "================================================================"
