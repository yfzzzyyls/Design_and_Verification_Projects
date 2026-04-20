# ECE9433-SoC-Design-Project
NYU ECE9433 Fall2025 SoC Design Project
Author:
Zhaoyu Lu
Jiaying Yong
Fengze Yu

## Third-Party IP

### Quick setup

```bash
./setup.sh
```

The script fetches the PicoRV32 core from the official YosysHQ repository and drops it into `third_party/picorv32/`. Re-run it any time you want to sync to the pinned revision.

## RISC-V Toolchain Setup

We rely on the xPack bare-metal toolchain (`riscv-none-elf-*`) so everyone builds with the same compiler version.

1. Download and extract the archive (Linux x86_64 example):
```bash
cd /path/to/ECE9433-SoC-Design-Project/third_party
wget https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v15.2.0-1/xpack-riscv-none-elf-gcc-15.2.0-1-linux-x64.tar.gz
tar -xf xpack-riscv-none-elf-gcc-15.2.0-1-linux-x64.tar.gz
mv xpack-riscv-none-elf-gcc-15.2.0-1 riscv-toolchain
```

2. Add the binaries to your PATH (place this in `.bashrc`/`.zshrc`):
   ```bash
   export PATH="/path/to/ECE9433-SoC-Design-Project/third_party/riscv-toolchain/bin:$PATH"
   ```

3. Verify the compiler:
   ```bash
   which riscv-none-elf-gcc
   ```

If you prefer a different xPack release, swap in the desired tag but keep the extracted directory name `riscv-toolchain` so the path stays consistent across machines.

## Building the Reference Firmware

After the toolchain and PicoRV32 sources are in place:

```bash
cd /path/to/ECE9433-SoC-Design-Project/third_party/picorv32
make TOOLCHAIN_PREFIX=/path/to/ECE9433-SoC-Design-Project/third_party/riscv-toolchain/bin/riscv-none-elf- firmware/firmware.hex
```

This creates `firmware/firmware.hex`, which we preload into the behavioral SRAM via `$readmemh` for the PicoRV32 bring-up tests.

## CORDIC Sanity Test Firmware

We keep a minimal SoC firmware image in `firmware/cordic_test/` that exercises the native-SRAM boot path, AXI4-Lite UART, and AXI4-Lite CORDIC accelerator. Build it with:

```bash
cd /path/to/ECE9433-SoC-Design-Project/firmware/cordic_test
make clean && make
```

This produces `cordic_test.hex`, which configures the UART, checks the CORDIC ID register, runs two `sincos` transactions through the accelerator CSR interface, prints the results over UART, and asserts `ebreak` only on success. A mismatch spins forever, so the testbench times out and reports FAIL.

## CPU Heartbeat Simulation (VCS)

Compile and run the SoC top + testbench with VCS:

```bash
cd /path/to/ECE9433-SoC-Design-Project
mkdir -p build
export VCS_HOME=/eda/synopsys/vcs/W-2024.09-SP2-7
export PATH=$VCS_HOME/bin:$PATH
$VCS_HOME/bin/vcs -full64 -kdb -sverilog \
    sim/soc_top_tb.sv \
    rtl/soc_top.sv rtl/mem_router_native.sv rtl/native_periph_bridge.sv \
    rtl/axil_interconnect_1x2.sv rtl/axil_uart.sv rtl/axil_cordic_accel.sv \
    rtl/cordic_accel_ctrl.sv rtl/cordic_core_atan2.sv rtl/cordic_core_sincos.sv \
    rtl/sram.sv third_party/picorv32/picorv32.v \
    -o build/soc_top_tb
./build/soc_top_tb
```

What to expect:
- The simulator prints the firmware load message, the UART transcript (`CORDIC boot`, result summary, `PASS`), and halts when the firmware asserts `trap`. With `cordic_test.hex` it reports `Firmware completed after 6216 cycles. PASS`. If the firmware spins (any mismatch), the bench times out at 200 000 cycles and prints FAIL.
- Point `HEX_PATH` in `sim/soc_top_tb.sv` to a different hex if you want to run other firmware images; the VCS flow stays the same.

## Synthesis (Design Compiler) — Read RTL & Elaborate

We now use DC NXT W-2024.09-SP5-5. The PDK as delivered lacks tech RC (TLU+) files and an SRAM NDM; topo runs will warn about missing RC per-layer attributes and mark SRAM macros `dont_use`. Per professor, this is OK for now—run a logical (non-topo) compile to get a mapped netlist. Representative topo log snippet (expected):
- `Library analysis succeeded.`
- `Warning: No TLUPlus file identified. (DCT-034)`
- `Error: Layer 'M1' is missing the 'resistance' attribute. (PSYN-100)` … similar for M2–M11/AP
- SRAM cells marked `dont_use` due to missing physical view.

Recommended non-topo flow (fresh session):

```tcl
set_app_var sh_enable_page_mode false
set_app_var alib_library_analysis_path /home/fy2243/ECE9433-SoC-Design-Project/alib
source tcl_scripts/setup.tcl
analyze -define SYNTHESIS -format sverilog {
    ../rtl/soc_top.sv
    ../rtl/mem_router_native.sv
    ../rtl/native_periph_bridge.sv
    ../rtl/axil_interconnect_1x2.sv
    ../rtl/axil_uart.sv
    ../rtl/axil_cordic_accel.sv
    ../rtl/cordic_accel_ctrl.sv
    ../rtl/cordic_core_atan2.sv
    ../rtl/cordic_core_sincos.sv
    ../rtl/sram.sv
    ../third_party/picorv32/picorv32.v
}
elaborate soc_top
current_design soc_top
source /home/fy2243/ECE9433-SoC-Design-Project/tcl_scripts/soc_top.con
compile_ultra
write -hier -f ddc -output ../mapped/soc_top.ddc
write -hier -f verilog -output ../mapped/soc_top.v
```

Notes / pitfalls:
- Define `SYNTHESIS` so sim-only constructs (`$readmemh`, initial blocks) are skipped during DC.
- `rtl/sram.sv` maps to the TSMC16 macro `TS1N16ADFPCLLLVTA512X45M4SWSHOD` for synthesis; the behavioral RAM remains under `ifndef SYNTHESIS` for VCS.
- The SRAM timing lib `N16ADFP_SRAM_tt0p8v0p8v25c_100a.db` is included via `setup.tcl` to avoid flop-based RAM inference.
- Picorv32 emits many signed/unsigned and unreachable warnings in elaboration; they are expected and non-fatal.
- Topo mode will halt without tech RC and SRAM physical views; stick to non-topo until/unless tech/TLU+ and SRAM NDM are provided.

## Innovus Bring-Up (batch, legacy mode)

Prereqs: mapped netlist at `mapped/soc_top.v`, active SDC at `mapped_with_tech/soc_top.sdc`, and PDK collateral at `/ip/tsmc/tsmc16adfp/...` as referenced in the Tcl scripts.

Run:
```bash
cd /home/fy2243/ECE9433-SoC-Design-Project
export PATH=/eda/cadence/INNOVUS211/bin:$PATH   # tcsh: set path = (/eda/cadence/INNOVUS211/bin $path)
innovus -no_gui -overwrite -files tcl_scripts/innovus_flow.tcl
```
What happens:
- Uses legacy init with `init_mmmc_file=tcl_scripts/innovus_mmmc_legacy.tcl` so timing is active at `init_design`.
- Reads tech/stdcell/SRAM LEF, mapped netlist, applies SDC, creates a 60% util floorplan, places/fixes the SRAM, runs `timeDesign -prePlace`.
- Checkpoints are written to `pd/innovus/init.enc` and `pd/innovus/init_timed.enc`; timing reports drop into `timingReports/`.

If you want to restore the timed checkpoint in a GUI session:
```bash
cd /home/fy2243/ECE9433-SoC-Design-Project
export PATH=/eda/cadence/INNOVUS211/bin:$PATH
innovus -common_ui
# at the Innovus prompt:
restoreDesign pd/innovus/init_timed.enc
gui_fit
```

## Tech-Aware DRC-Clean Flow (Unified, STARRC + QRC, 0 violations)

This is the single, recommended flow (parasitic-aware synthesis + QRC P&R).

1) Synthesis with STARRC tech
```bash
cd /home/fy2243/ECE9433-SoC-Design-Project
dc_shell -f syn_complete_with_tech.tcl 2>&1 | tee synthesis_complete.log
```
Outputs (in `mapped_with_tech/`): `soc_top.v`, `soc_top.ddc`, `soc_top.sdc`, `area.rpt`, `timing.rpt`, `power.rpt`, `qor.rpt`.

2) Innovus P&R with QRC tech (DRC-priority)
```bash
cd /home/fy2243/ECE9433-SoC-Design-Project
export PATH=/eda/cadence/INNOVUS211/bin:$PATH   # tcsh: set path = (/eda/cadence/INNOVUS211/bin $path)
/eda/cadence/INNOVUS211/bin/innovus -no_gui -overwrite -files tcl_scripts/complete_flow_with_qrc.tcl 2>&1 | tee complete_flow.log
```
What it does:
- Loads QRC tech `/ip/tsmc/tsmc16adfp/tech/RC/N16ADFP_QRC/worst/qrcTechFile` (via `tcl_scripts/innovus_mmmc_legacy_qrc.tcl`)
- Reads tech/stdcell/SRAM LEFs and the synthesized netlist `mapped_with_tech/soc_top.v`
- Floorplan: 30% utilization, 50 µm margins; SRAM placed/fixed; PG connects; process set to 16nm
- Placement → CTS (`ccopt_design -cts`) → DRC-focused routing → metal fill (M1–M6)
- DRC #1: `pd/innovus/drc_complete_1.rpt` (initial markers)
- ECO fix: `ecoRoute -fix_drc`
- DRC #2: `pd/innovus/drc_complete_2.rpt` (“No DRC violations were found”)
- Final checkpoint: `pd/innovus/complete_final.enc`

Notes:
- Keep PATH set to Innovus before running.
- Antenna warnings on the SRAM LEF are expected; QRC still loads and extraction runs.
- Routing is DRC-priority (timing-driven off). Enable timing-driven options later only if you need tighter timing after DRC is clean.

## Canonical Calibre Signoff Flow

The repo now keeps one canonical, cleaned Calibre signoff package:

`signoff/calibre_foundrytap_lightfinal_20260410/`

This is the final archived package that produced:
- DRC clean: `signoff/calibre_foundrytap_lightfinal_20260410/05_drc/output/DRC_dmmerge_macroedge_cut1plus.rep`
- LVS clean: `signoff/calibre_foundrytap_lightfinal_20260410/07_lvs/output/lvs.physall_supplyalias_global.rep`
- Final layout database: `signoff/calibre_foundrytap_lightfinal_20260410/04_dummyMerge/output/soc_top.dmmerge_macroedge_cut1plus.oas.gz`

Expected success conditions:
- DRC summary contains `TOTAL DRC Results Generated: 0 (0)`
- LVS summary contains `CORRECT`

### Prerequisites

- Final Innovus checkpoint available, for example `pd/innovus_fillko_20260409/with_sram_final.enc`
- Innovus available at `/eda/cadence/INNOVUS211/bin/innovus`
- Calibre available at `/eda/mentor/Calibre/aok_cal_2024.2_29.16/bin`
- TSMC16ADFP decks and IP collateral available under `/ip/tsmc/tsmc16adfp/...`

### One-shot execution

Run the end-to-end export + Calibre flow from the repo root:

```bash
cd /home/fy2243/soc_design
ROOT=/home/fy2243/soc_design \
FINAL_ENC=/home/fy2243/soc_design/pd/innovus_fillko_20260409/with_sram_final.enc \
DATE_TAG=my_signoff_run \
CPU=8 \
./run_calibre_signoff.sh
```

Useful environment knobs:
- `DATE_TAG`: names the workspace as `signoff/calibre_${DATE_TAG}`
- `FINAL_ENC`: final Innovus database to export from
- `CPU`: Calibre parallelism
- `LAYOUT_FORMAT`: `oasis` or `gds`
- `RUN_DRC`: `1` or `0`
- `RUN_LVS`: `1` or `0`
- `EXPORT_PG_PINS`: `1` if the exported top-level netlist should expose PG pins

### What the flow does

The driver script [run_calibre_signoff.sh](/home/fy2243/soc_design/run_calibre_signoff.sh) executes the signoff flow in these stages:

1. `00_export`
   Exports fresh `DEF`, `LVSVG`, layout stream, and Verilog from the specified Innovus checkpoint using [export_calibre_signoff_artifacts.tcl](/home/fy2243/soc_design/tcl_scripts/export_calibre_signoff_artifacts.tcl).

2. `04_dummyMerge`
   Produces the post-dummy-merge layout database used for final signoff. The archived clean package keeps only the final fixed edit script [edit_dmmerge_macroedge_cut1plus.cmd](/home/fy2243/soc_design/signoff/calibre_foundrytap_lightfinal_20260410/04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus.cmd) and the final OASIS.

3. `05_drc`
   Runs Calibre DRC on the final dummy-merged layout using the patched deck [drc.modified](/home/fy2243/soc_design/signoff/calibre_foundrytap_lightfinal_20260410/05_drc/scr/drc.modified) and the canonical runset [runset.dmmerge_macroedge_cut1plus.cmd](/home/fy2243/soc_design/signoff/calibre_foundrytap_lightfinal_20260410/05_drc/scr/runset.dmmerge_macroedge_cut1plus.cmd).

4. `06_v2lvs`
   Converts the exported `LVSVG` to a schematic-like source netlist and rewrites the top-level subckt ordering for SRAM/standard-cell compatibility using [prepare_calibre_extract_source.py](/home/fy2243/soc_design/prepare_calibre_extract_source.py).

5. `07_lvs`
   Extracts layout connectivity to `soc_top.layspi`, applies supply alias/global fixes with [alias_layout_supply_pins.py](/home/fy2243/soc_design/signoff/calibre_foundrytap_lightfinal_20260410/07_lvs/scr/alias_layout_supply_pins.py) and [add_supply_globals.py](/home/fy2243/soc_design/signoff/calibre_foundrytap_lightfinal_20260410/07_lvs/scr/add_supply_globals.py), rewrites the source side with [prepare_calibre_lvs_source.py](/home/fy2243/soc_design/prepare_calibre_lvs_source.py), and runs the final compare through [runset.compare.physall_supplyalias_global.cmd](/home/fy2243/soc_design/signoff/calibre_foundrytap_lightfinal_20260410/07_lvs/scr/runset.compare.physall_supplyalias_global.cmd).

### Canonical archived outputs

The final committed milestone keeps only the files needed to prove and reproduce closure:

- Exported signoff views in `00_export/`
- Final clean layout in `04_dummyMerge/output/`
- Final DRC deck patch, runset, and report in `05_drc/`
- Source-prep artifacts in `06_v2lvs/`
- Final LVS extraction, source-fix files, and compare report in `07_lvs/`

All exploratory signoff directories and probe-only scripts were intentionally removed from the repo so the remaining signoff tree reflects the final deliverable rather than the debug history.
