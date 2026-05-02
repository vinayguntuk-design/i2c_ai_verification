# =================================================================
# FILE    : scripts/run_sim.tcl
# PURPOSE : Run simulation from command line (no Vivado GUI needed)
#
# This is what Python calls internally via xvlog/xelab/xsim.
# You can also run it manually:
#
#   cd your_project_folder
#   xvlog --sv rtl/i2c_master.v rtl/i2c_slave.v sim/i2c_tb.sv
#   xelab -debug typical work.i2c_tb -s i2c_tb_snap
#   xsim i2c_tb_snap -runall
# =================================================================

set script_dir   [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]

puts "Running I2C simulation..."
puts "Project root: $project_root"

# Compile
exec xvlog --sv \
    $project_root/rtl/i2c_master.v \
    $project_root/rtl/i2c_slave.v  \
    $project_root/sim/i2c_tb.sv

# Elaborate
exec xelab -debug typical work.i2c_tb -s i2c_tb_snap

# Simulate
exec xsim i2c_tb_snap -runall

puts "Simulation complete."
