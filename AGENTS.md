# AGENTS.md

Project: ECE9433-SoC-Design-Project (pose estimation accelerator SoC)

## Purpose
- Keep the SoC flow reproducible (DC synthesis -> Innovus PNR -> DRC/LVS connectivity)
- Track milestones and known-good configurations

## Key docs
- DESIGN.md
- README.md

## Build / Run / Test
- Fetch third-party core:
  ./setup.sh
- Synthesis (with SRAM macro in `rtl/sram.sv` under `SYNTHESIS`):
  /eda/synopsys/syn/W-2024.09-SP5-5/bin/dc_shell -f syn_complete_with_tech.tcl 2>&1 | tee synthesis_complete.log
  Outputs: mapped_with_tech/soc_top.v, soc_top.sdc, soc_top.ddc
- Innovus PNR baseline flow:
  /eda/cadence/INNOVUS211/bin/innovus -no_gui -overwrite -files tcl_scripts/complete_flow_with_qrc.tcl 2>&1 | tee complete_flow.log
  DRC: pd/innovus/drc_complete_1.rpt
  LVS connectivity: pd/innovus/lvs_connectivity_regular.rpt, pd/innovus/lvs_connectivity_special.rpt
  Antenna: pd/innovus/lvs_process_antenna.rpt
  Checkpoint: pd/innovus/complete_final.enc
- Innovus PNR with SRAM gate checks:
  /eda/cadence/INNOVUS211/bin/innovus -no_gui -overwrite -files tcl_scripts/complete_flow_with_qrc_with_sram.tcl 2>&1 | tee with_sram_complete_flow.log
  DRC: pd/innovus/drc_with_sram_iter*.rpt
  LVS connectivity: pd/innovus/lvs_connectivity_regular.rpt, pd/innovus/lvs_connectivity_special.rpt
  Antenna: pd/innovus/lvs_process_antenna.rpt
  Checkpoint: pd/innovus/with_sram_final.enc
- IO pin assignment warnings during verifyConnectivity (clk/rst_n/trap) are expected unless pins are assigned.

## Repo conventions
- RTL in rtl/, scripts in tcl_scripts/, Innovus checkpoints and reports in pd/innovus/.
- Keep large logs and generated outputs out of git; only add RTL/scripts/docs.

## Notes
- Feb 2, 2026 milestone: no-SRAM baseline achieved 0 DRC and 0 LVS connectivity in Innovus.
- This is Innovus verifyConnectivity, not full signoff LVS (PVS/Calibre).

## With-SRAM Status (Mar 7, 2026 20:40 EST)
- Fresh run of `tcl_scripts/complete_flow_with_qrc_with_sram.tcl` passed all required gates:
  - DRC ECO loop: iter0=9, iter1=5, iter2=0
  - `verifyConnectivity` regular: 0 problems
  - `verifyConnectivity` special: 0 problems (run with `-noAntenna`)
  - `verifyProcessAntenna`: 0 violations
- Special-net `-noAntenna` is required to suppress macro-adjacent row-end dangling markers; it does not report opens in the validated run.
