# ============================================================
# I2C AI Verification System
# FINAL STABLE TCL SCRIPT
# ============================================================

# ------------------------------------------------------------
# Close Existing Project
# ------------------------------------------------------------

close_project -quiet

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

set script_dir   [file dirname [file normalize [info script]]]
set project_root [file normalize "${script_dir}/.."]

puts ""
puts "=================================================="
puts " I2C AI Verification System"
puts "=================================================="
puts " Script Dir  : $script_dir"
puts " Project Root: $project_root"
puts "=================================================="

# ------------------------------------------------------------
# Project Settings
# ------------------------------------------------------------

set project_name "i2c_ai_verification"
set project_dir  [file normalize "${project_root}/vivado_project"]

set rtl_dir [file normalize "${project_root}/rtl"]
set sim_dir [file normalize "${project_root}/sim"]
set ai_dir  [file normalize "${project_root}/ai"]

# FPGA PART
set fpga_part "xc7a35tcpg236-1"

# ------------------------------------------------------------
# Create Project
# ------------------------------------------------------------

puts ""
puts "Creating Vivado Project..."

create_project $project_name $project_dir \
    -part $fpga_part -force

puts "Project Created Successfully"

# ------------------------------------------------------------
# File Paths
# ------------------------------------------------------------

set master_file [file normalize "${rtl_dir}/i2c_master.v"]
set slave_file  [file normalize "${rtl_dir}/i2c_slave.v"]
set tb_file     [file normalize "${sim_dir}/i2c_tb.sv"]

# ------------------------------------------------------------
# Verify Files Exist
# ------------------------------------------------------------

foreach f [list $master_file $slave_file $tb_file] {

    if {![file exists $f]} {

        puts ""
        puts "=================================================="
        puts " ERROR: File Missing"
        puts "=================================================="
        puts $f
        puts ""

        return
    }
}

puts ""
puts "All RTL/Testbench Files Found"

# ------------------------------------------------------------
# Add RTL Files
# ------------------------------------------------------------

puts ""
puts "Adding RTL Files..."

add_files -norecurse $master_file
add_files -norecurse $slave_file

# ------------------------------------------------------------
# Add Testbench
# ------------------------------------------------------------

puts ""
puts "Adding Testbench..."

add_files -fileset sim_1 -norecurse $tb_file

# ------------------------------------------------------------
# Update Compile Order
# ------------------------------------------------------------

puts ""
puts "Updating Compile Order..."

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# ------------------------------------------------------------
# Set Simulation Top
# ------------------------------------------------------------

set_property top i2c_tb [get_filesets sim_1]

puts ""
puts "Simulation Top Set To: i2c_tb"

# ------------------------------------------------------------
# Launch Simulation
# ------------------------------------------------------------

puts ""
puts "=================================================="
puts " Launching Simulation"
puts "=================================================="

launch_simulation

# wait simulator load
after 3000

restart

# ------------------------------------------------------------
# Add Signals To Waveform
# ------------------------------------------------------------

puts ""
puts "Adding Signals To Waveform..."

log_wave -recursive *

# ------------------------------------------------------------
# Run Initial Simulation
# ------------------------------------------------------------

puts ""
puts "Running Initial Simulation..."

run 2 ms

puts ""
puts "=================================================="
puts " INITIAL SIMULATION COMPLETE"
puts "=================================================="

# ------------------------------------------------------------
# Save Waveform Config
# ------------------------------------------------------------

#write_wave_config "${project_root}/waveform_config.wcfg"

#puts ""
#puts "Waveform Configuration Saved"

# ------------------------------------------------------------
# AI ENGINE
# ------------------------------------------------------------

puts ""
puts "=================================================="
puts " STARTING AI ENGINE"
puts "=================================================="

set python_script [file normalize "${ai_dir}/vivado_ai.py"]

if {![file exists $python_script]} {

    puts ""
    puts "=================================================="
    puts " ERROR: AI Script Missing"
    puts "=================================================="
    puts $python_script
    puts ""

    return
}

puts ""
puts "AI Script:"
puts $python_script

puts ""
puts "Running Autonomous AI Coverage Engine..."
puts ""
puts "NOTE:"
puts "AI may take several minutes."
puts "DO NOT CLOSE VIVADO."
puts ""

# ------------------------------------------------------------
# Run Python AI Engine
# ------------------------------------------------------------

set result [catch {

    exec python $python_script

} output]

# ------------------------------------------------------------
# Print AI Output
# ------------------------------------------------------------

puts ""
puts "=================================================="
puts " AI ENGINE OUTPUT"
puts "=================================================="

puts $output

# ------------------------------------------------------------
# Final Status
# ------------------------------------------------------------

if {$result == 0} {

    puts ""
    puts "=================================================="
    puts " AI EXECUTION SUCCESSFUL"
    puts "=================================================="

} else {

    puts ""
    puts "=================================================="
    puts " AI EXECUTION FAILED"
    puts "=================================================="
}

puts ""
puts "=================================================="
puts " COMPLETE FLOW FINISHED"
puts "=================================================="

puts ""
puts "Generated Outputs:"
puts "  - Waveforms"
puts "  - AI Coverage Reports"
puts "  - Simulation Logs"
puts "  - Coverage History"
puts ""