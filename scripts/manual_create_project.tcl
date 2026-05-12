# manual_create_project.tcl
# Usage: In Vivado Tcl Console (or vivado -mode tcl), run:
#   source scripts/manual_create_project.tcl
# This script creates a Vivado project, adds RTL and simulation files,
# and prepares the simulation fileset. Adjust paths/part as needed.

# Project configuration
set proj_name "i2c_ai_verification"

# Determine project directory relative to this script. This makes the script
# safe to run from Vivado Tcl console regardless of current working directory.
set script_file [info script]
if {"$script_file" == ""} {
    # Sourced interactively — fall back to current working directory
    set script_dir [pwd]
} else {
    set script_dir [file dirname $script_file]
}

# Project root is parent of scripts/ directory
set proj_dir [file normalize [file join $script_dir ..]]

# Optional: specify a target part if you plan to implement; otherwise omit or change
# Example part (change or comment out if unknown):
# set target_part "xc7a100t-1"    ;# replace with your board/part

puts "Creating project: $proj_name in $proj_dir"

# Create the project (overwrite if exists)
if {[file exists "${proj_dir}/${proj_name}.xpr"]} {
    puts "Project already exists - opening existing project"
    if {[catch {open_project "${proj_dir}/${proj_name}.xpr"} err]} {
        puts "Error opening project: $err"
        return
    }
} else {
    # If you want to specify a part, add: -part $target_part
    if {[catch {create_project -force $proj_name $proj_dir} err]} {
        puts "Error creating project: $err"
        return
    }
}

# Add RTL sources (Verilog)
set rtl_dir [file join $proj_dir "rtl"]
set rtl_files [glob -nocomplain "${rtl_dir}/*.v"]
if {[llength $rtl_files] > 0} {
    puts "Adding RTL files from: $rtl_dir"
    add_files -norecurse $rtl_files
} else {
    puts "Warning: no RTL files found in $rtl_dir"
}

# Add simulation sources (SystemVerilog testbench)
set sim_dir [file join $proj_dir "sim"]
set sim_files [glob -nocomplain "${sim_dir}/*.sv"]
if {[llength $sim_files] > 0} {
    puts "Adding simulation files from: $sim_dir"
    # Ensure sim files are added into the simulation fileset
    add_files -norecurse -fileset sim_1 $sim_files
} else {
    puts "Warning: no simulation files found in $sim_dir"
}

# Update compile order for simulation fileset
puts "Setting project to Manual Compile Order and updating compile order for sim_1"
# Switch to manual compile order to avoid automatic hierarchy changes
set_property source_mgmt_mode None [current_project]
if {[llength [get_filesets sim_1]] > 0} {
    update_compile_order -fileset sim_1
} else {
    puts "Warning: fileset sim_1 not found; skipping update_compile_order"
}

# Set top for simulation (testbench top) - change if your TB name differs
set tb_top "i2c_tb"
puts "Setting simulation top to: $tb_top"
if {[llength [get_filesets sim_1]] > 0} {
    if {[catch {set_property top $tb_top [get_filesets sim_1]} err]} {
        puts "Warning: could not set top for sim_1: $err"
    }
} else {
    puts "Warning: sim_1 fileset missing; top not set"
}

# Save and close project
if {[catch {save_project} err]} {
    puts "Warning: save_project failed: $err"
} else {
    puts "Project created and saved: ${proj_dir}/${proj_name}.xpr"
}
puts "Next: open the project in Vivado GUI and run simulation, or use the run script."

# Helpful note for users running from external shell using vivado -mode tcl:
# vivado -mode tcl -source scripts/manual_create_project.tcl
