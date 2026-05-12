# QUICK START GUIDE — Achieve 100% Coverage

## ⚡ Run This Command (Copy & Paste)

```bash
cd c:\VivadoProjects\i2c_ai_verification
python3 ai/vivado_ai.py --strategy genetic --target 100 --runs 15
```

## What Was Fixed?

### Problem
- Coverage stuck at **90.9%** (missing `data_alt` bin)
- NACK test prevented data patterns from being transmitted

### Solution
Added 4 new profiles in testbench that use **correct slave address**:
- `data_zero` → Tests 0x00 pattern
- `data_ones` → Tests 0xFF pattern  
- `data_alt` → Tests 0x55 and 0xAA patterns ⭐
- `data_all` → Tests all patterns

Updated AI engine to **prioritize data_alt** profile when detected as missing.

## Expected Timeline

| Phase | Time | Result |
|-------|------|--------|
| Compilation & Setup | 1 min | Ready for simulation |
| Run 1-5 (catching up) | 5 min | Rebuilds previous coverage |
| Run 6-10 (AI learning) | 5 min | ~90% coverage from old profiles |
| Run 11-12 (NEW!) | 2 min | **100% achieved** ✓ |
| Total Time | ~13 min | **DONE** |

## Check Results

1. **In Terminal**: Look for:
   ```
   TARGET 100% REACHED after 11 runs!
   ```

2. **Open HTML Report**:
   ```
   reports/coverage_report.html
   ```

3. **View Coverage Table**:
   ```
   OK  Data = 0x55 or 0xAA    : XXX hits  HIT
   Total: 100.0% (11/11 bins covered)
   ```

## Troubleshooting

**❌ "xvlog not found"**
- Add Vivado to PATH:
  ```bash
  set PATH=C:\Xilinx\Vivado\2024.1\bin;%PATH%
  ```

**❌ "No [COV] output found"**
- Check: `sim_logs/run_*.log` for errors
- Verify: All .v and .sv files compile without errors

**❌ Coverage still at 90%**
- Run again with more iterations:
  ```bash
  python3 ai/vivado_ai.py --runs 20 --target 100
  ```

## Files Changed

✅ **sim/i2c_tb.sv** — Added data pattern profiles (5 new code blocks)  
✅ **ai/vivado_ai.py** — Updated AI strategies and priorities (4 changes)  

**No changes to RTL**: i2c_master.v and i2c_slave.v remain unchanged

---

**Ready? Let's go to 100%! 🚀**
