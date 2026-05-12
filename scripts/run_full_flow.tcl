# run_full_flow.tcl
# Single-file Vivado Tcl to create/open project, add sources,
# set manual compile order, launch simulation, and run AI engine.
# Usage (Vivado GUI Tcl Console):
#   source scripts/run_full_flow.tcl
# Usage (headless):
#   vivado -mode tcl -source scripts/run_full_flow.tcl

puts "\n=================================================="
puts " I2C AI Verification — Full Flow (Tcl)"
puts "==================================================\n"

# ------------------------------------------------------------
# Paths (script-relative)
# ------------------------------------------------------------
set script_file [info script]
if {"$script_file" == ""} {
    set script_dir [pwd]
} else {
    set script_dir [file dirname $script_file]
}
set project_root [file normalize [file join $script_dir ..]]

# Prefer existing XPR in project root; otherwise use vivado_project folder
set project_name "i2c_ai_verification"
set xpr_root_path [file normalize [file join $project_root "${project_name}.xpr"]]
set vivado_project_dir [file normalize [file join $project_root "vivado_project"]]
if {[file exists $xpr_root_path]} {
    set project_dir $project_root
    set project_file $xpr_root_path
} else {
    set project_dir $vivado_project_dir
    set project_file [file normalize [file join $project_dir "${project_name}.xpr"]]
}

puts "Script Dir   : $script_dir"
puts "Project Root : $project_root"
puts "Project Dir  : $project_dir"
puts "Project XPR  : $project_file\n"

# ------------------------------------------------------------
# Files
# ------------------------------------------------------------
set rtl_dir  [file normalize [file join $project_root "rtl"]]
set sim_dir  [file normalize [file join $project_root "sim"]]
set ai_dir   [file normalize [file join $project_root "ai"]]

set master_file [file normalize [file join $rtl_dir "i2c_master.v"]]
set slave_file  [file normalize [file join $rtl_dir "i2c_slave.v"]]
set tb_file     [file normalize [file join $sim_dir "i2c_tb.sv"]]
set python_script [file normalize [file join $ai_dir "vivado_ai.py"]]

# ------------------------------------------------------------
# Close any open project quietly to avoid conflicts
# ------------------------------------------------------------
catch {close_project -quiet}

# ------------------------------------------------------------
# Create or Open Project
# ------------------------------------------------------------
if {[file exists $project_file]} {
    puts "Opening existing project: $project_file"
    if {[catch {open_project $project_file} err]} {
        puts "Error opening project: $err"
        return
    }
} else {
    puts "Creating project: ${project_name} @ ${project_dir}"
    # Ensure project_dir exists
    file mkdir $project_dir
    # Default part (safe); user may change if needed
    set fpga_part "xc7a35tcpg236-1"
    if {[catch {create_project -force $project_name $project_dir -part $fpga_part} err]} {
        puts "Error creating project: $err"
        return
    }
    # Save explicitly as full path to avoid save_project issues
    if {[catch {save_project_as $project_file} err]} {
        puts "Warning: save_project_as failed: $err"
    }
}

# ------------------------------------------------------------
# Verify source files exist and add them (skip if already present)
# ------------------------------------------------------------
puts "\nVerifying and adding source files..."
set missing 0
foreach f [list $master_file $slave_file $tb_file] {
    if {![file exists $f]} {
        puts "ERROR: Missing file: $f"
        set missing 1
    }
}
if {$missing} {
    puts "Aborting: please restore missing files and re-run this script."
    return
}

# Add RTL sources (sources_1)
puts "Adding RTL files..."
catch {add_files -norecurse $master_file}
catch {add_files -norecurse $slave_file}

# Add testbench to simulation fileset (sim_1)
puts "Adding simulation files..."
catch {add_files -norecurse -fileset sim_1 $tb_file}

# ------------------------------------------------------------
# Set Manual Compile Order and update compile order
# ------------------------------------------------------------
puts "\nSetting Manual Compile Order and updating compile order..."
catch {set_property source_mgmt_mode None [current_project]}
if {[llength [get_filesets sources_1]] > 0} {
    catch {update_compile_order -fileset sources_1}
}
if {[llength [get_filesets sim_1]] > 0} {
    catch {update_compile_order -fileset sim_1}
}

# Set simulation top if sim_1 exists
if {[llength [get_filesets sim_1]] > 0} {
    catch {set_property top i2c_tb [get_filesets sim_1]}
    puts "Simulation top set to: i2c_tb"
} else {
    puts "Warning: sim_1 fileset not found; top not set"
}

# Save project state safely
if {[catch {save_project_as $project_file} err]} {
    puts "Warning: save_project_as failed: $err"
} else {
    puts "Project saved: $project_file"
}

# ------------------------------------------------------------
# Launch Simulation (GUI) — if running headless, comment this block
# ------------------------------------------------------------
puts "\nLaunching simulation GUI (launch_simulation)..."
if {[llength [get_filesets sim_1]] > 0} {
    if {[catch {launch_simulation} err]} {
        puts "Warning: couldn't launch GUI simulation: $err"
        puts "You may run headless via: vivado -mode tcl -source scripts/run_full_flow.tcl"
    } else {
        puts "Simulation GUI launched."
    }
} else {
    puts "Skipping simulation launch; no sim_1 fileset."
}

# ------------------------------------------------------------
# Run a quick interactive simulation if GUI available
# (these commands work inside the Vivado GUI Tcl console)
# ------------------------------------------------------------
puts "Running quick simulation sequence (if GUI)..."
catch {
    restart -force
    run 2 ms
}

# ------------------------------------------------------------
# Run the AI Python engine (exec python ...)
# ------------------------------------------------------------
puts "\nPreparing to launch AI engine..."
if {![file exists $python_script]} {
    puts "ERROR: AI Python script not found: $python_script"
    puts "Please ensure the AI script exists and try again."
} else {
    puts "Running AI engine: $python_script"
    # Use catch to capture output and errors
    set ai_out ""
    if {[catch {exec python "$python_script"} ai_out]} {
        puts "AI engine failed or returned non-zero status." 
        puts "Output:\n$ai_out"
    } else {
        puts "AI engine completed successfully. Output:\n$ai_out"
    }
}

puts "\nFull flow complete."
puts "Project: $project_file"
puts "Simulation fileset: sim_1"
puts "AI script: $python_script"
puts "\nYou can inspect waveforms and logs in the Vivado GUI or run headless flows as needed."
