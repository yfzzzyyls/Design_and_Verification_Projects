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
- Synthesis (no SRAM macro; RTL memory only):
  /eda/synopsys/syn/W-2024.09-SP5-5/bin/dc_shell -f syn_complete_with_tech.tcl 2>&1 | tee synthesis_complete.log
  Outputs: mapped_with_tech/soc_top.v, soc_top.sdc, soc_top.ddc
- Innovus PNR + DRC/LVS connectivity:
  /eda/cadence/INNOVUS211/bin/innovus -no_gui -overwrite -files tcl_scripts/complete_flow_with_qrc.tcl 2>&1 | tee complete_flow.log
  DRC: pd/innovus/drc_complete_1.rpt
  LVS connectivity: pd/innovus/lvs_connectivity_regular.rpt, pd/innovus/lvs_connectivity_special.rpt
  Antenna: pd/innovus/lvs_process_antenna.rpt
  Checkpoint: pd/innovus/complete_final.enc
- IO pin assignment warnings during verifyConnectivity (clk/rst_n/trap) are expected unless pins are assigned.

## Repo conventions
- RTL in rtl/, scripts in tcl_scripts/, Innovus checkpoints and reports in pd/innovus/.
- Keep large logs and generated outputs out of git; only add RTL/scripts/docs.

## Notes
- Feb 2, 2026 milestone: no-SRAM baseline achieved 0 DRC and 0 LVS connectivity in Innovus.
- This is Innovus verifyConnectivity, not full signoff LVS (PVS/Calibre).
