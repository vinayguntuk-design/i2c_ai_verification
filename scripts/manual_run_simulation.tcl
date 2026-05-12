# manual_run_simulation.tcl
# Usage:
# 1) Open Vivado and source this file in the Tcl Console:
#      source scripts/manual_run_simulation.tcl
# 2) Or run headless: vivado -mode tcl -source scripts/manual_run_simulation.tcl
# This script assumes the project XPR exists in the current working directory
# and that manual_create_project.tcl or the GUI has been used to add files.

# Attempt to open the project
set proj_name "i2c_ai_verification"

# Determine project file relative to this script (safe when sourced from anywhere)
set script_file [info script]
if {"$script_file" == ""} {
    set script_dir [pwd]
} else {
    set script_dir [file dirname $script_file]
}
set proj_dir [file normalize [file join $script_dir ..]]
set proj_file [file normalize [file join $proj_dir "${proj_name}.xpr"]]
if {[file exists $proj_file]} {
    puts "Opening project: $proj_file"
    if {[catch {open_project $proj_file} err]} {
        puts "Error opening project: $err"
        return
    }
} else {
    puts "Error: project file not found: $proj_file"
    puts "Run scripts/manual_create_project.tcl first or open the project in GUI."
    return
}

# Ensure simulation fileset exists
if {[llength [get_filesets sim_1]] == 0} {
    puts "Warning: sim_1 fileset not present. Ensure you added sim sources."
} else {
    # Ensure manual compile order to avoid automatic top selection
    set_property source_mgmt_mode None [current_project]
    # Set top if possible
    set tb_top "i2c_tb"
    if {[catch {set_property top $tb_top [get_filesets sim_1]} err]} {
        puts "Warning: could not set top for sim_1: $err"
    } else {
        puts "Top set to $tb_top for fileset sim_1"
    }
}

# Compile and run simulation using Vivado simulation flow
puts "Launching simulation (this opens Simulator GUI in Vivado)..."
if {[catch {launch_simulation} err]} {
    puts "Error launching simulation: $err"
    puts "You can also run in headless mode using: vivado -mode tcl -source scripts/manual_run_simulation.tcl"
    return
}

# If you prefer to run XSIM in batch/headless mode, uncomment and adjust below:
# set_property top i2c_tb [get_filesets sim_1]
# launch_simulation -simulator xsim -dir ./xsim_dir -nowrun
# # compile (xvlog & xelab stage happens inside launch_simulation -nowrun)
# run all

puts "Simulation started. Use the simulation GUI or Tcl commands to run and inspect." 
puts "Example interactive commands in Tcl Console:"
puts "  restart -force"
puts "  run 1000ns"
puts "  stop"
puts "  exit"

# Save project after simulation adjustments
if {[catch {save_project} err]} {
    puts "Warning: save_project failed: $err"
} else {
    puts "Done."
}
