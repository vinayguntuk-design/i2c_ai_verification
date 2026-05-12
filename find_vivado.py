#!/usr/bin/env python3
"""Quick script to find Vivado installation on your system."""

import os
import sys
from pathlib import Path

print("=" * 70)
print("Vivado Installation Finder")
print("=" * 70)

# Common search roots
if sys.platform == "win32":
    search_roots = [
        r"C:\Xilinx",
        r"D:\Xilinx",
        r"E:\Xilinx",
        os.path.expanduser("~"),  # User home
    ]
else:
    search_roots = [
        "/opt/Xilinx",
        "/tools/Xilinx",
        "/usr/local/Xilinx",
        os.path.expanduser("~"),
    ]

found_vivado = []

print(f"\nSearching for Vivado installations...")
print(f"Platform: {sys.platform}\n")

for root in search_roots:
    if not os.path.exists(root):
        continue
    
    try:
        for item in os.listdir(root):
            if "Vivado" in item:
                vivado_path = os.path.join(root, item)
                bin_path = os.path.join(vivado_path, "bin")
                
                # Check if bin exists and has xvlog
                if os.path.exists(bin_path):
                    xvlog = os.path.join(bin_path, "xvlog")
                    xvlog_bat = os.path.join(bin_path, "xvlog.bat")
                    
                    if os.path.exists(xvlog) or os.path.exists(xvlog_bat):
                        found_vivado.append(bin_path)
                        print(f"✓ Found: {bin_path}")
    except (PermissionError, OSError):
        pass

if not found_vivado:
    print("✗ No Vivado installation found!")
    print("\nTroubleshooting:")
    print("1. Check if Vivado is installed on your system")
    print("2. Note the installation path (e.g., C:\\Xilinx\\Vivado\\2024.1)")
    print("3. Add that path to PATH or update the script")
    sys.exit(1)

print(f"\n" + "=" * 70)
print("SOLUTIONS:\n")

for i, path in enumerate(found_vivado, 1):
    print(f"Option {i}: {path}")

print(f"\n" + "=" * 70)
print("How to fix:\n")
print("Option A - Add Vivado to PATH (Windows):")
print(f'  set PATH={found_vivado[0]};%PATH%')
print("\nOption B - Add to PATH (PowerShell):")
print(f'  $env:PATH = "{found_vivado[0]};$env:PATH"')
print("\nOption C - Update vivado_ai.py:")
print(f'  Edit line ~290 in ai/vivado_ai.py')
print(f'  Add this path to search_paths: r"{found_vivado[0]}"')
print(f"\n" + "=" * 70)
