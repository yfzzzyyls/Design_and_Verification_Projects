# AGENTS.md

Project: ECE9433-SoC-Design-Project (pose estimation accelerator SoC)

## Purpose
- Keep the SoC flow reproducible (DC synthesis -> Innovus PNR -> DRC/LVS connectivity).
- Provide one clear, current known-good status for newcomers.

## Key docs
- README.md

## Build / Run / Test
- Fetch third-party core:
  `./setup.sh`
- Synthesis (SRAM macro enabled in `rtl/sram.sv` under `SYNTHESIS`):
  `/eda/synopsys/syn/W-2024.09-SP5-5/bin/dc_shell -f syn_complete_with_tech.tcl 2>&1 | tee synthesis_complete.log`
  Outputs: `mapped_with_tech/soc_top.v`, `mapped_with_tech/soc_top.sdc`, `mapped_with_tech/soc_top.ddc`
- Innovus PNR with SRAM gate checks (recommended flow):
  `/eda/cadence/INNOVUS211/bin/innovus -no_gui -overwrite -files tcl_scripts/complete_flow_with_qrc_with_sram.tcl 2>&1 | tee with_sram_complete_flow.log`
  Outputs:
  - DRC loop reports: `pd/innovus/drc_with_sram_iter*.rpt`
  - Connectivity: `pd/innovus/lvs_connectivity_regular.rpt`, `pd/innovus/lvs_connectivity_special.rpt`
  - Antenna: `pd/innovus/lvs_process_antenna.rpt`
  - Final checkpoint: `pd/innovus/with_sram_final.enc`
- Optional recheck from final checkpoint:
  - DRC: `pd/innovus/drc_recheck_20260315.rpt`
  - Connectivity: `pd/innovus/lvs_connectivity_regular_recheck_20260315.rpt`, `pd/innovus/lvs_connectivity_special_recheck_20260315.rpt`
  - Antenna: `pd/innovus/lvs_process_antenna_recheck_20260315.rpt`

## Current Known-Good Status (Mar 15, 2026, America/New_York)
- Synthesis completed and wrote mapped netlist (`mapped_with_tech/soc_top.v`).
- SRAM macro preservation checks passed:
  - Instance: `u_sram/u_sram_macro`
  - Reference: `TS1N16ADFPCLLLVTA512X45M4SWSHOD`
- Innovus with-SRAM flow result: PASS.
  - DRC ECO loop: `iter0=9`, `iter1=5`, `iter2=0`
  - `verifyConnectivity` regular: `0` problems
  - `verifyConnectivity` special (`-noAntenna`): `0` problems
  - `verifyProcessAntenna`: `0` violations
- Recheck from final checkpoint also clean:
  - DRC: `0` (`No DRC violations were found`)
  - Connectivity regular: `0`
  - Connectivity special: `0`
  - Antenna: `0` (`No Violations Found`)

## Notes
- IO pin assignment warnings during `verifyConnectivity` for `clk`, `rst_n`, and `trap` are expected unless pins are assigned.
- This is Innovus in-design connectivity/antenna validation, not full signoff LVS/DRC with PVS/Calibre.

## Current RTL Signoff Milestone (Apr 16, 2026, America/New_York)

This is the current checkpoint for the `soc_design` full signoff closure work on the
native-SRAM current-RTL branch.

Local git checkpoint:
- branch: `codex/currentrtl-v48clean-milestone`
- tag: `currentrtl-v48clean-20260416`

Final persisted signoff payload:
- `signoff/calibre_axi_uartcordic_currentrtl_v48clean_20260416/`
- DRC: `signoff/calibre_axi_uartcordic_currentrtl_v48clean_20260416/05_drc/output/DRC.rep`
- LVS: `signoff/calibre_axi_uartcordic_currentrtl_v48clean_20260416/07_lvs/output/lvs.physall_supplyalias_global.rep`
- patched dummy-merge layout:
  `signoff/calibre_axi_uartcordic_currentrtl_v48clean_20260416/04_dummyMerge/output/soc_top.dmmerge.oas.gz`

Final status:
- full-chip Calibre DRC: `0`
- final Calibre LVS: `CORRECT`

### What Was Already Good

Before the final DRC closure pass, the current-RTL signoff tree already had a correct
final LVS flow in:
- `signoff/calibre_axi_uartcordic_currentrtl_postdrc_20260412_r2/07_lvs/output/lvs.physall_supplyalias_global.rep`

That alias/global LVS path had already solved the earlier source/layout naming and
supply-fragment issues. The remaining blocker was DRC, not LVS.

### Remaining Problem Before Final Closure

After the earlier PG and dummy-merge iterations, the best near-clean DRC candidate was
stuck on only 6 checks:
- `M1.DN.1.T`
- `M2.DN.1.T`
- `M3.DN.1.T`
- `DM1.S.7`
- `DM2.S.7`
- `DM3.S.7`

Important observation:
- these were not signal-routing or power-grid opens
- they were lower-layer dummy-fill / dummy-pattern issues

### Wrong Hypothesis That Was Rejected

An early guess was that the last violations were caused by a local lower `B10` dummy
pattern mismatch near the bottom cluster. That direction was tested by adding broader
local dummy shapes.

Result:
- the original 6 checks could be suppressed
- but large regressions appeared immediately in `DM1/2/3.S.2` and `DM1/2/3.S.2.2`

Conclusion:
- broad local dummy fill was the wrong fix
- the remaining issue was structural and had to be matched against the known-clean
  reference, not patched by trial-and-error density bands

### Real Root Cause

The useful comparison was not the lower `B10` area. The useful comparison was the full
height SRAM-edge `B17` stripe against the April 12 clean signoff layout.

That compare showed that the current-RTL near-clean layout still had multiple empty or
partially populated `B17` dummy master cells where the clean reference had real
low-layer geometry.

Examples of missing or incomplete masters found in the failing layout:
- `B17aDM2OH_CB`
- `B17aDM1OV_CA`
- `B17aDM1OV_CB`
- `B17aDM3OV_CA`
- `B17aDM3OV_CB`
- `B17aDM1S_CB`
- `B17aDM3S_CB`
- `B17aDM2S_CA`
- `B17aDM2S_CB`
- `B17aDM1B_CA`
- `B17aDM1B_CB`
- `B17aDM2B_CA`
- `B17aDM2B_CB`
- `B17aDM3B_CA`
- `B17aDM3B_CB`

One additional master, `B17aFS_fs_1_5`, was only partially populated:
- upper-layer polygons were present
- 18 lower-layer polygons were missing

This was the actual cause of the last 6 DRC violations.

### Fix Applied

The final clean patch restored the missing `B17` low-layer dummy geometry directly in
the dummy-merge layout:
- restored the missing low-layer polygons for the empty `B17` dummy masters listed above
- restored the missing lower-layer polygons in `B17aFS_fs_1_5`

Provenance script:
- `signoff/calibre_axi_uartcordic_currentrtl_v48clean_20260416/04_dummyMerge/scr/patch_b17_master_complete_v48.sh`

Canonical final layout:
- `signoff/calibre_axi_uartcordic_currentrtl_v48clean_20260416/04_dummyMerge/output/soc_top.dmmerge.oas.gz`

### Why LVS Did Not Need Another New Fix

The final `v48` closure change was a dummy-fill repair only.

It did not change:
- functional RTL
- signal connectivity
- PG topology
- extracted logical connectivity used by the already-correct alias/global LVS compare

So the DRC closure required a new layout checkpoint, but not a new logical LVS
normalization strategy. The already-correct final LVS report remained the right final
status record for the current-RTL milestone.

### Practical Lesson

For this SoC, when the design is already down to a tiny number of residual dummy rules:
- do not start with broad density-band fill experiments
- compare against the last known-clean signoff layout at the exact failing stripe/window
- check for empty or partially instantiated dummy master cells first

That was the shortest path from “almost clean” to full Calibre closure.

## Repo conventions
- RTL in `rtl/`, scripts in `tcl_scripts/`, Innovus checkpoints/reports in `pd/innovus/`.
- Keep large logs/generated outputs out of git; commit RTL/scripts/docs.

## Imported RSD PD Lessons

The following is a verbatim copy of:
- `/home/fy2243/coding/design_and_perf/rsd_fengze_codex/PD.md`

# RSD Physical Design Progress

Last updated: 2026-04-08

This file is the dedicated log for the ASIC physical-design work on `rsd_fengze`.
It is the single place for backend progress, failed branches, successful branches,
and the current closure state. General study notes stay in
`/home/fy2243/coding/design_and_perf/STUDY_PROGRESS.md`.

## Goal

Ultimate goal:
- full macro-present RTL-to-GDS backend flow
- `0` routed DRC
- `0` regular connectivity errors
- `0` special-net / LVS-style connectivity errors

## 2026-04-07 Codex Recovery Plan

This repository is the clean working tree that takes over from the heavily
iterated `rsd_fengze` tree. The immediate goal here is not to rediscover the
search space from scratch. It is to carry over only the lessons that were
actually validated.

What we are keeping:
- the corridor helper infrastructure needed to reproduce the best routed PD branch
- the SRAM black-box LVS path that removed the large SRAM-port mismatch noise
- the stage-chained Innovus launcher so each branch is reproducible

What we are explicitly not repeating as the new mainline:
- generic Calibre deck-guessing
- source-wrapper and constant-net normalization experiments
- full-chip `full_9 + pblk + ladder` style expansions that already regressed
- any branch that stalls in `place` with massive `IMPSP-2031` legalization spam

Current best known branch from the older tree:
- routed PD checkpoint family: `out_simple_brcorr_seg_m1rblk`
- status:
  - routed DRC = `75`
  - regular connectivity = `0`
  - routed special-net opens = `4655`

Current best known LVS interpretation from the older tree:
- use SRAM black-box mode
- the dominant SRAM port-count mismatch disappears
- remaining LVS failure is concentrated in 3 top-level `M1_text` label shorts:
  - `debugRegister`
  - `memAccessAddr[0]`
  - `memAccessAddr[1]`
  - `memAccessAddr[2]`

Root-cause refinement:
- the problem is not only in Calibre extraction
- it is already wrong in the exported DEF
- in the older tree's `Core.def.gz`, the top-level pins
  - `memAccessAddr[2]`
  - `memAccessAddr[1]`
  - `memAccessAddr[0]`
  are bound to `NET debugRegister`
- that means the fix point is before or at Innovus import/export, not in SRAM handling
- codex therefore normalizes the `Core` top-level interface before Innovus reads it

Execution order in this repo:
1. reproduce the best `m1rblk` branch in codex
2. fix the top-level LVS pin-label collision
3. fix the routed `75` DRC surgically on the `m1rblk` branch
4. only then merge the clean PD and LVS paths

Reproduction recipe for the codex `m1rblk` branch:
- seed:
  - `Processor/Project/Innovus/out_simple_brcorr_seg_m1rblk/db/init.enc`
  - `Processor/Project/Innovus/out_simple_brcorr_seg_m1rblk/db/init.enc.dat`
  - both currently borrow the clean simple baseline from the older tree
- launch:
```bash
cd Processor/Project/Innovus
env \
  RSD_RUN_TAG=simple_brcorr_seg_m1rblk \
  RSD_BASE_RUN_TAG=simple_brcorr_seg_m1rblk \
  RSD_SIMPLE_MACRO_FLOW=1 \
  RSD_SIMPLE_BLOCKRING_PATTERNS='*btb* *brPred/predictor* *memoryDependencyPredictor*' \
  RSD_SIMPLE_BLOCKRING_USE_CORRIDORS=1 \
  RSD_SIMPLE_BLOCKRING_CORRIDOR_SPLIT_NETS=1 \
  RSD_SIMPLE_BLOCKRING_CORRIDOR_FULL_HEIGHT=1 \
  RSD_SIMPLE_CORRIDOR_PLACE_BLOCKAGE=1 \
  RSD_SIMPLE_CORRIDOR_ROUTE_BLOCKAGE=1 \
  RSD_SIMPLE_CORRIDOR_RBLK_LAYERS=M1 \
  RSD_SIMPLE_CORRIDOR_LADDER=1 \
  RSD_CORRIDOR_SPECS_MODE=original_3 \
  RSD_VERIFY_ERROR_LIMIT=100000 \
  RSD_VERIFY_SPECIAL_NO_SOFT_PG=1 \
  RSD_VERIFY_SPECIAL_NO_UNCONN_PIN=1 \
  ./run_chain.sh place cts route
```

Design scope:
- top: `Core`
- node: TSMC16
- tools:
  - Synopsys Design Compiler
  - Cadence Innovus
- real SRAM macros enabled for:
  - `ICache`
  - `DCache`
  - `BTB`
  - `Gshare`
  - `MemoryDependencyPredictor`

## Flow Entry Points

Main files:
- [Processor/Project/DesignCompiler/compile.tcl](Processor/Project/DesignCompiler/compile.tcl)
- [Processor/Project/DesignCompiler/Makefile](Processor/Project/DesignCompiler/Makefile)
- [Processor/Project/Innovus/innovus_flow.tcl](Processor/Project/Innovus/innovus_flow.tcl)
- [Processor/Project/Innovus/innovus_mmmc_qrc.tcl](Processor/Project/Innovus/innovus_mmmc_qrc.tcl)
- [Processor/Project/Innovus/rsd_core_apr.sdc](Processor/Project/Innovus/rsd_core_apr.sdc)
- [Processor/Project/Innovus/Makefile](Processor/Project/Innovus/Makefile)

Main current Innovus baseline:
- output tree: `Processor/Project/Innovus/out_simple/`
- philosophy: keep macros present, keep PG simple, then add only justified local structure

Current promising derivative branch:
- output tree: `Processor/Project/Innovus/out_simple_brcorr_fullh/`
- purpose: local `M8` macro block rings plus full-height corridor spines in the dominant predictor/BTB macro columns

## Current Status

Stable routed simple baseline:
- [Processor/Project/Innovus/out_simple/reports/route_drc.rpt](Processor/Project/Innovus/out_simple/reports/route_drc.rpt): `0`
- [Processor/Project/Innovus/out_simple/reports/route_connectivity.rpt](Processor/Project/Innovus/out_simple/reports/route_connectivity.rpt): `0`
- [Processor/Project/Innovus/out_simple/reports/route_special_connectivity.rpt](Processor/Project/Innovus/out_simple/reports/route_special_connectivity.rpt):
  - `270` terminal opens
  - `730` special-wire opens
  - this is the routed special-net state with body-bias binding disabled for reporting

Uncapped special-net truth on the clean simple routed baseline:
- [Processor/Project/Innovus/out_simple_special_nosoft_full2/reports/route_special_connectivity.rpt](Processor/Project/Innovus/out_simple_special_nosoft_full2/reports/route_special_connectivity.rpt)
- `6179` `IMPVFC-200` special-wire opens
- this is the real remaining blocker after suppressing soft-PG and unconnected-pin reporting noise

Best current structural improvement beyond the simple baseline:
- place-stage uncapped no-soft special-wire count reduced from `6179` to `5158`
- branch:
  - baseline report:
    - [Processor/Project/Innovus/out_simple_place_nosoft_base/reports/route_special_connectivity.rpt](Processor/Project/Innovus/out_simple_place_nosoft_base/reports/route_special_connectivity.rpt)
  - improved report:
    - [Processor/Project/Innovus/out_simple_place_nosoft_brcorr/reports/route_special_connectivity.rpt](Processor/Project/Innovus/out_simple_place_nosoft_brcorr/reports/route_special_connectivity.rpt)
- mechanism:
  - local `M8` block rings only around `btb`, `brPred`, and `memoryDependencyPredictor`
  - full-height corridor-local `M9` spines to make a reachable PG target inside the stacked macro columns

Live checkpoint right now:
- `out_simple_brcorr_fullh` has been moved forward into `CTS`
- current log:
  - [Processor/Project/Innovus/out_simple_brcorr_fullh/logs/cts.log](Processor/Project/Innovus/out_simple_brcorr_fullh/logs/cts.log)
- latest visible state:
  - `ccopt_design` active
  - tree being built for `158717` sinks
  - no fatal CTS error observed so far

## Timeline

### 1. RTL And SRAM-Backed Storage Prerequisites

The backend work only became meaningful after the storage path was made ASIC-realistic.

Completed prerequisite work:
- `DCache` was redesigned from the old generic 2-port model to a true `1R1W` contract
- `test-1` regression passed after the `DCache` redesign
- real TSMC16 SRAM wrappers were integrated and verified for:
  - `ICache`
  - `DCache`
  - `BTB`
  - `Gshare`
  - `MemoryDependencyPredictor`
- `ReplayQueue` was intentionally kept as logic because the SRAM conversion was not a clean functional fit

Useful consequence:
- the physical netlist is not a toy stdcell-only cache model
- the backend is solving around real macros in the places that matter

### 2. Full Synthesis Baseline

Main synthesis run:
- directory:
  - `Processor/Project/DesignCompiler/runtime_full_sram_16c/`

Key results:
- mapped outputs:
  - [Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.v](Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.v)
  - [Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.sdc](Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.sdc)
- macro count: `28`
- leaf cell count: `500140`
- design area: `386213.269227`
- setup clean at the loose `10ns` target

Interpretation:
- setup is fine enough for backend bring-up
- hold is noisy, which is expected before CTS / physical implementation

### 3. First Innovus Bring-Up

The first major success was getting a real macro-present Innovus flow alive.

What worked:
- `init`
- `place`
- `cts`

What failed:
- early full route was unstable
- body-bias / PG handling was incomplete
- route DRC and special-net connectivity exploded in later route phases

Important early backend fixes:
- correct global-net binding for `VPP`, `VBB`, and macro power pins
- remove AP-layer routing accidents
- loosen floorplan and margins
- save more checkpoints for cheaper iteration

### 4. Complex PG Debug Phase

This was the long exploratory phase.

Main things that were tried:
- heavier PG stripe meshes
- staged `corePin -> stripe / ring / blockring`
- helper meshes
- band-local tap / row capture
- post-route restitch experiments
- body-bias / tap-cell handling changes
- no-macro and stdcell-only diagnostic experiments

What this phase taught:
- the main issue was not timing
- the main issue was not ordinary signal routing
- many of the broad PG fixes created new geometry problems faster than they fixed connectivity
- the most useful output from this phase was diagnosis, not a final clean database

Important negative lesson:
- extra speculative PG structure was often the problem, not the solution

### 5. Pivot To The Simple Macro-Present Flow

The successful direction change came from applying the `soc_design` lesson more carefully:
- keep macros present
- keep the PG simple
- stop guessing with broad helper structure

The simple flow does:
- core ring only
- deterministic macro placement
- small `M5/M6` signal halo around macros with `-exceptpgnet`
- one simple `sroute`:
  - `-connect {corePin blockPin}`
  - `-corePinTarget {ring}`
  - `-blockPinTarget {ring}`

Why this mattered:
- this is the first RSD backend path that became stable enough to carry through `CTS` and full `route`

### 6. Routed Simple Baseline

This is the current real baseline, not a place-only debug snapshot.

Results on `out_simple/`:
- routed DRC: `0`
- regular connectivity: `0`
- routed special-net report with body-bias accounting removed:
  - `270` terminal opens
  - `730` special-wire opens

Important clarification:
- the earlier capped `1000` `VPP/VBB`-heavy report overstated body-bias accounting noise
- the cleaner reporting setup showed the real problem is still special-net PG islands, not regular signal-route failure

How `DRC=0` was achieved:
- the previous `286` routed shorts were traced to temporary `sig_halo_*` route blockages
- dropping those temporary signal halos before final report generation removes the false residual DRC

This means:
- the simple flow is a valid routed baseline
- the remaining closure problem is now isolated to special-net PG connectivity

### 7. Truth State Of The Remaining Special-Net Problem

After removing reporting noise and raising the error cap:
- true uncapped routed special-wire opens on the simple baseline: `6179`

Pattern:
- roughly balanced `VDD` and `VSS`
- concentrated in the stacked predictor / BTB macro columns, especially in `x≈503..705`
- this is not a global whole-chip lack-of-metal problem

What was tried from the routed database and ruled out:
- broad restitch
- corridor `M9` stripes only
- corridor `M9` plus `corePin -> stripe`

Those routed-db fixes plateaued:
- they did not move the real `6179`

Main interpretation:
- the problem is not missing top-level ring metal
- the problem is the lack of a reachable local PG target inside blocked macro corridors

### 8. Local Block-Ring Corridor Experiment

This is the current promising branch.

Idea:
- add local `M8` block rings only where the stacked macro columns create isolated PG islands
- then add corridor-local vertical PG spines so row/followpin PG has a reachable target without a long blocked climb to the far `M9/M10` core ring

First narrow implementation:
- branch:
  - `Processor/Project/Innovus/out_simple_brhub/`
- result:
  - raw `sroute` reach improved
  - capped place-stage summary stayed flat

Second implementation with corridor spines:
- branch:
  - `Processor/Project/Innovus/out_simple_brcorr/`
- result:
  - still flat in the capped place-stage summary
  - learned that the local spines were not actually reaching the ring strongly enough

Third implementation with full-height corridor spines:
- branch:
  - `Processor/Project/Innovus/out_simple_brcorr_fullh/`
- result:
  - capped place-stage summary still stayed at `157` terminals / `843` specials
  - but uncapped no-soft place-stage special-wire count dropped:
    - `6179 -> 5158`

This is the first real reduction in the underlying PG island count from this class of fix.

## Approaches Tried And What Happened

### Successful Or Directionally Useful

- Simple macro-present flow
  - result:
    - first full routed mainline
    - `DRC=0`
    - `regular connectivity=0`
- Report cleanup for routed special-net truth
  - result:
    - exposed the real blocker as `6179` special-wire islands instead of a misleading capped body-bias-heavy report
- Local block-ring corridor hubs
  - result:
    - first real structural reduction in uncapped PG island count
    - `6179 -> 5158` at place-stage no-soft reporting

### Tried And Not Worth Keeping As Mainline

- Global or broad PG helper meshes
  - too invasive
  - tended to create new DRC / min-step / boundary issues
- Broad routed-db stripe restitch
  - did not reduce the real special-wire count
- Repeated place-stage `VSS` helper reroutes on the simple baseline
  - usually collapsed into the same mixed `270 / 730` family
- Macro `X` shifts as the only lever
  - confirmed geometry matters
  - but did not produce a clearly better replacement for the simple mainline by themselves
- No-macro diagnostic as a production direction
  - useful as diagnosis
  - not the real implementation path

## Current Best Interpretation

The remaining blocker is:
- not standard signal routing
- not general routed DRC
- not a lack of top-level ring metal

The remaining blocker is:
- special-net PG islands in the stacked predictor / BTB macro corridors
- caused by poor local reachability from row/followpin PG to an upper-level PG target

That is why the current best hypothesis is:
- keep the simple global PG philosophy
- add only narrowly-scoped local PG hubs where the reports justify them

## Current Checkpoints

Stable routed baseline:
- [Processor/Project/Innovus/out_simple/db/route_clean.enc](Processor/Project/Innovus/out_simple/db/route_clean.enc)
- [Processor/Project/Innovus/out_simple/db/route.enc](Processor/Project/Innovus/out_simple/db/route.enc)

Relevant reports:
- [Processor/Project/Innovus/out_simple/reports/route_drc.rpt](Processor/Project/Innovus/out_simple/reports/route_drc.rpt)
- [Processor/Project/Innovus/out_simple/reports/route_connectivity.rpt](Processor/Project/Innovus/out_simple/reports/route_connectivity.rpt)
- [Processor/Project/Innovus/out_simple/reports/route_special_connectivity.rpt](Processor/Project/Innovus/out_simple/reports/route_special_connectivity.rpt)
- [Processor/Project/Innovus/out_simple_special_nosoft_full2/reports/route_special_connectivity.rpt](Processor/Project/Innovus/out_simple_special_nosoft_full2/reports/route_special_connectivity.rpt)

Current improving branch:
- [Processor/Project/Innovus/out_simple_brcorr_fullh/db/place.enc](Processor/Project/Innovus/out_simple_brcorr_fullh/db/place.enc)
- [Processor/Project/Innovus/out_simple_brcorr_fullh/logs/cts.log](Processor/Project/Innovus/out_simple_brcorr_fullh/logs/cts.log)
- [Processor/Project/Innovus/out_simple_place_nosoft_brcorr/reports/route_special_connectivity.rpt](Processor/Project/Innovus/out_simple_place_nosoft_brcorr/reports/route_special_connectivity.rpt)

## Next Steps

1. Finish `CTS` on `out_simple_brcorr_fullh`.
2. Route that branch and compare it against the current simple routed baseline.
3. Check whether the place-stage `6179 -> 5158` reduction carries into the routed uncapped special-net count.
4. Keep the branch only if it stays monotonic:
   - routed DRC remains clean
   - regular connectivity remains clean
   - uncapped special-wire count drops
5. If the block-ring corridor branch helps, continue with the same philosophy:
   - local reachable PG targets only where the reports justify them
   - no broad return to the old complex PG mesh

## Short Summary

## 2026-04-07 Codex Bring-Up

- `rsd_fengze_codex` is now the independent working tree. Proven infrastructure was ported from the old repo:
  - `Innovus/run_chain.sh`
  - `Innovus` corridor helpers in `innovus_flow.tcl`
  - `LVS/run_calibre_lvs.sh` SRAM black-box support
- Added `Innovus/normalize_core_top_ports.py` and wired it through `run_chain.sh` so Innovus consumes a sanitized top-level wrapper before import. This avoids the prior `python3`-inside-Innovus failure and is intended to stop the toxic top-level escaped-port collapse seen in old DEF/LVS exports.

### Codex Baseline: `simple_brcorr_seg_m1rblk`

- Seeded from the old repo simple `init.enc`/`init.enc.dat` checkpoint.
- Reproduction is currently faithful:
  - place-stage `IMPVFC-96/200` is still `278 / 722`
  - CTS completed
  - route log is tracking the old `m1rblk` branch through the same large-count cleanup trajectory
- This is important because it means the codex top-port wrapper fix is not perturbing the known-good PD baseline.

### Next PD Experiment: `simple_brcorr_seg_m1rblk_pmx15`

- New surgical branch launched from the same baseline, changing only:
  - `RSD_SIMPLE_CORRIDOR_PBLK_MARGIN_X=1.5`
- Rationale:
  - the old `75` routed DRC x-clusters align more closely with the original corridor place-blockage x-edges than with the route-blockage edges
  - this makes widened place-blockage margin a better next experiment than re-entering the failed `full_9 + pblk + ladder` search space
- Current state:
  - still in `place`
  - normal NanoPlace progress so far, no early failure

### Immediate Working Theory

- Keep the codex baseline and `pmx15` margin branch as the active PD tracks.
- Once the codex baseline route finishes, run codex black-box LVS on that exact branch and compare it against the old repo `2797 / 2` black-box result.
- If the top-port wrapper fix removes the `debugRegister` / `memAccessAddr[0:2]` collision in codex export, PD and LVS can continue as mostly independent tracks again.
The current RSD backend is no longer blocked on basic flow bring-up.
The clean simple macro-present flow already gives:
- routed `DRC=0`
- regular connectivity `=0`

The remaining problem is special-net PG connectivity in the stacked predictor / BTB macro corridors.
The first fix that materially reduced the true underlying PG island count is the local `M8` block-ring plus full-height corridor-spine approach:
- `6179 -> 5158`

That branch is now the main experiment being carried forward.

## 2026-04-07 Synth-Top Diagnosis Update

- Wrapped synthesis rerun `runtime_flatcore_synth3` completed cleanly with the flat-top `Core` + `Core_impl` flow enabled.
- The source-side experiment in [Core.sv](/home/fy2243/coding/design_and_perf/rsd_fengze_codex/Processor/Src/Core.sv) tied `debugRegister` to `'0` under `RSD_DISABLE_DEBUG_REGISTER` so DC would stop inferring it from an undriven debug interface signal.
- Result: the key top-level corruption is still present in the newly written mapped netlist:
  - `assign memAccessAddr[0] = net199957;`
  - `assign memAccessAddr[1] = net199957;`
  - `assign memAccessAddr[2] = net199957;`
  - `assign debugRegister[0] = net199957;`
- This means the stubborn LVS-side alias is still being emitted by synthesized top-level logic even after:
  - flat top wrapper generation
  - fresh wrapped synthesis
  - explicit debugRegister tie-off in source RTL
- Conclusion:
  - this is not a PG artifact
  - this is not just a Calibre artifact
  - the next fix point is the synth-top wrapper / top-port flattening logic itself, not more PG or LVS knob-turning

## 2026-04-07 Synth-Top Sanitizer Result

- Wrapped synthesis rerun `runtime_flatcore_synth4` completed cleanly with a post-synth mapped-top sanitizer wired into [compile.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze_codex/Processor/Project/DesignCompiler/compile.tcl).
- The new sanitizer in [sanitize_mapped_core_top.py](/home/fy2243/coding/design_and_perf/rsd_fengze_codex/Processor/Project/DesignCompiler/sanitize_mapped_core_top.py) rewrites the mapped `Core` wrapper after `write -format verilog` so constant top-level outputs do not share one tie-low net.
- Result in `runtime_flatcore_synth4/mapped/Core.v`:
  - `memAccessAddr[0] = rsd_memAccessAddr_0_tielo`
  - `memAccessAddr[1] = rsd_memAccessAddr_1_tielo`
  - `memAccessAddr[2] = rsd_memAccessAddr_2_tielo`
  - `debugRegister[0] = rsd_debugRegister_0_tielo`
  - separate tie cells `RSD_TIELO_memAccessAddr_0/1/2` and `RSD_TIELO_debugRegister_0` are present
- This is the first run that removes the exact synthesized-top alias between `debugRegister[0]` and `memAccessAddr[2:0]`.
- Next step from this checkpoint:
  - run black-box LVS on the `runtime_flatcore_synth4` output
  - verify whether the old top-level short disappears from the LVS report

## 2026-04-07 Matched `synth4` Physical Rebuild

- A direct black-box LVS swap using the sanitized `runtime_flatcore_synth4` source against the old physical export was not a valid comparison point:
  - ports mismatched `221 vs 224`
  - nets matched only `489274`, with `12334` unmatched layout nets and `1014597` unmatched source nets
- That proved the sanitized source must be paired with a fresh physical rebuild, not dropped into the old LVS workspace.

- Two physical branches were then run from the sanitized `runtime_flatcore_synth4` source:
  - `simple_brcorr_seg_m1rblk_synth4`
  - `simple_plain_synth4`

- `simple_brcorr_seg_m1rblk_synth4` is not a viable PD baseline:
  - routed behavior regressed badly into a large `M5/M6` short regime
  - it is useful only as a source/layout-consistent diagnostic branch

- `simple_plain_synth4` is the important recovery result:
  - fresh `init/place/cts/route` completed cleanly from the sanitized synth source
  - routed DRC returned to `0`
  - regular connectivity returned to `0`
  - routed special-net PG remained at `6179` `IMPVFC-200`

- Conclusion:
  - the cleaned `synth4` netlist is compatible with the old simple physical philosophy
  - the simple baseline shape is restored: `0 DRC`, `0 regular`, but still PG-open heavy
  - the main backend blocker is once again isolated to PG special-net closure, not basic routed DRC

- Next step from this checkpoint:
  - run LVS on the matched `simple_plain_synth4` physical rebuild
  - if LVS is clean or materially improved, keep `simple_plain_synth4` as the new stable baseline for PG-focused iteration

## 2026-04-07 Matched `simple_plain_synth4` LVS Result

- `simple_plain_synth4` completed as the recovered sanitized-netlist physical baseline:
  - routed `DRC = 0`
  - regular connectivity `= 0`
  - routed special-net PG `= 6179` `IMPVFC-200`

- A fully matched black-box LVS workspace was then built from that exact branch:
  - export from `out_simple_plain_synth4/db/route_clean.enc`
  - `v2lvs`
  - IP merge
  - Calibre LVS with `RSD_LVS_SRAM_BOX_MODE=black`

- Result:
  - LVS is still `INCORRECT`
  - ports now match `224 / 224`
  - nets now match `498790 / 498790` with `2935` unmatched layout nets and `2` unmatched source nets

- Most important delta versus the older matched branch:
  - the old matched black-box run emitted `lvs.rep.shorts` with three explicit top-level text shorts:
    - `debugRegister - memAccessAddr[2]`
    - `debugRegister - memAccessAddr[1]`
    - `debugRegister - memAccessAddr[0]`
  - the new matched `simple_plain_synth4_black` run emits **no** `lvs.rep.shorts`
  - the old explicit top-level `debugRegister / memAccessAddr[0:2]` short signature is therefore removed

- Interpretation:
  - the synthesized-top alias bug was real and the sanitizer fixed that specific LVS failure mode
  - however, the overall matched black-box LVS is still not clean
  - remaining work is no longer blocked on that explicit top-level short; the residual `2935 / 2` mismatch must be classified separately

- Practical consequence:
  - keep `simple_plain_synth4` as the new stable baseline:
    - fixed synthesized top
    - `0` routed DRC
    - `0` regular connectivity
    - old PG-open count still intact
  - from here, the mainline should return to PG experiments on top of this baseline, while the residual LVS mismatch is analyzed in parallel

## 2026-04-08 Final Handoff

This section supersedes the stale "active branch" language above. It records the
actual end state after the codex investigation cycle.

### Bottom-Line Status

What was fixed for real:
- the synthesized-top LVS alias bug was real and is now fixed in the flow
- the old explicit top-level short between
  - `debugRegister[0]`
  - `memAccessAddr[0]`
  - `memAccessAddr[1]`
  - `memAccessAddr[2]`
  is removed from the matched black-box LVS path
- the fixed netlist is compatible with the old simple physical philosophy

What was **not** solved:
- final signoff closure
- full matched LVS clean
- PG special-wire closure

The project ended with two stable anchors:
- clean physical anchor:
  - `Processor/Project/Innovus/out_simple_plain_synth4`
  - `0` routed DRC
  - `0` regular connectivity
  - `6179` routed special-wire opens
- best PG-improving physical anchor:
  - `Processor/Project/Innovus/out_simple_brcorr_seg_pblk_synth4`
  - `75` routed DRC
  - `0` regular connectivity
  - `4661` routed special-wire opens

That is the true closure gap at handoff:
- either preserve `0 / 0` and reduce `6179`
- or preserve `4661` and remove the `75` M1 shorts

### Stable Facts That Should Not Be Re-Learned

1. The old LVS diagnosis was polluted by a real synth-top bug.
- In the old mapped top, these outputs were emitted on one shared tie-low net:
  - `memAccessAddr[0]`
  - `memAccessAddr[1]`
  - `memAccessAddr[2]`
  - `debugRegister[0]`
- This was **not** a Calibre-only artifact.
- It was fixed by the codex flat-top/sanitizer path:
  - `Processor/Project/DesignCompiler/prepare_core_synth_top.py`
  - `Processor/Project/DesignCompiler/sanitize_mapped_core_top.py`
  - `Processor/Project/DesignCompiler/compile.tcl`
- Clean mapped output:
  - `Processor/Project/DesignCompiler/runtime_flatcore_synth4/mapped/Core.v`

2. The fixed netlist does **not** automatically solve PG.
- The best clean matched physical rebuild on the fixed netlist is still:
  - `Processor/Project/Innovus/out_simple_plain_synth4`
  - routed `DRC = 0`
  - regular connectivity `= 0`
  - routed special opens `= 6179`

3. The fixed netlist **does** materially improve the matched LVS interpretation.
- Matched black-box LVS workspace:
  - `Processor/Project/LVS/work_simple_plain_synth4_black`
- Result:
  - ports `224 / 224`
  - nets `498790 / 498790`
  - unmatched layout nets `2935`
  - unmatched source nets `2`
- The old explicit `lvs.rep.shorts` signature is gone.
- So the specific top-level alias bug is resolved, even though matched LVS is still `INCORRECT`.

4. `full_9` corridor scaling is dead.
- `Processor/Project/Innovus/out_simple_full9_pblk_synth4`
- final:
  - `373` DRC
  - `0` regular connectivity
  - `5697` special opens
- This is worse than `original_3 + pblk` on both metrics that matter.

5. Low-layer hotspot route-blockage surgery at place-stage is also dead.
- `Processor/Project/Innovus/out_simple_brcorr_seg_pblk_hotrblk_synth4`
- hung in `place` at `Begin power routing ...`
- never reached `place.enc`
- therefore this is not a viable DRC-fix path

### Branch Table At Handoff

Most useful completed branches:

- `out_simple_plain_synth4`
  - role:
    - clean matched fixed-netlist physical baseline
  - result:
    - `DRC = 0`
    - `regular = 0`
    - `special = 6179`
  - interpretation:
    - safest implementation anchor

- `out_simple_brcorr_seg_pblk_synth4`
  - role:
    - best PG-improving fixed-netlist branch
  - result:
    - `DRC = 75`
    - `regular = 0`
    - `special = 4661`
  - interpretation:
    - best PG result found
    - still not promotable because of the `75` M1 shorts

- `out_simple_full9_pblk_synth4`
  - role:
    - test whether corridor coverage was the missing lever
  - result:
    - `373 / 0 / 5697`
  - interpretation:
    - reject

- `out_simple_brcorr_seg_m1rblk_synth4`
  - role:
    - source/layout-consistent rebuild of the old corridor-heavy branch
  - result:
    - fell into a bad `M5/M6` routed-short regime
  - interpretation:
    - reject as PD baseline

- `out_simple_brcorr_seg_pblk_hotrblk_synth4`
  - role:
    - local `M1` hotspot route-blockage fix on top of the `4661` branch
  - result:
    - stuck in `place` / special-route
  - interpretation:
    - reject

### PG-Only Investigation From The Clean Baseline

The clean anchor for PG-only work is:
- `Processor/Project/Innovus/out_simple_plain_synth4/db/prepg.enc`

Important flow fix:
- `pg`, `pg_low`, and `pg_stdcell` stages in `Innovus/innovus_flow.tcl` were
  patched to honor `RSD_PREPG_SOURCE`
- before that patch, PG-only branches died immediately because they ignored the
  external source checkpoint and looked for a local `db/prepg.enc`

PG-only baseline branch:
- `Processor/Project/Innovus/out_simple_plain_pgedgevdd_dbg2`

Measured PG-only checkpoints:
- `pg_low`
  - report:
    - `Processor/Project/Innovus/out_simple_plain_pgedgevdd_dbg2/reports/pg_after_corepin_low_special_connectivity.rpt`
  - result:
    - `270` terminal opens
    - `730` special-wire opens

- `pg_edge`
  - source:
    - `pg_low.enc`
  - result:
    - still `270 / 730`
  - interpretation:
    - VSS edge rerun alone is a no-op on the surviving residual

- `pg_vdd`
  - source:
    - `pg_edge.enc`
  - result:
    - still `270 / 730`
  - important live observation:
    - `Number of Stripe ports routed: 0`
    - `sroute created 0 wire`
    - `ViaGen created 0 via`
  - interpretation:
    - the old VDD reconnect helper windows do not actually hook onto the live residual islands

### VSS Phase-2 Result: The First Real Causal PG Shift

The surviving `pg_low` residual is VSS-heavy and concentrated on row families at:
- `y ~= 100`
- `y ~= 622`
- `y ~= 778`
- `y ~= 902`
- `y ~= 1062`
- `y ~= 1233`

Those windows match the built-in helper:
- `rsd_add_pg_vss_phase2_capture`

First test:
- branch:
  - `Processor/Project/Innovus/out_simple_plain_vssphase2_synth4`
- settings:
  - enable `RSD_ADD_PG_VSS_PHASE2_CAPTURE=1`
  - leave default `RSD_VSS_COREPIN_TOP_LAYER=M4`
- result:
  - `152` terminal opens
  - `848` special-wire opens
- interpretation:
  - the new VSS captures clearly touched the terminal side
  - but they created unattached higher-layer VSS geometry, so special-wire opens got worse

Root-cause refinement:
- `rsd_add_pg_vss_phase2_capture` adds geometry on `M4/M5/M6`
- `rsd_sroute_vss_corepins_attach` defaults to `top_layer = M4`
- therefore the new `M5/M6` captures were being created, but the follow-up
  VSS corepin attach was not allowed to reach them

Second test:
- branch:
  - `Processor/Project/Innovus/out_simple_plain_vssphase2m6_synth4`
- settings:
  - enable `RSD_ADD_PG_VSS_PHASE2_CAPTURE=1`
  - set `RSD_VSS_COREPIN_TOP_LAYER=M6`
- live routing evidence:
  - `724` VSS core ports routed
  - `1555` wires created
  - `3336` vias created
- final total:
  - still `270` terminal opens
  - still `730` special-wire opens
- but the net split changed dramatically:
  - before:
    - terminal opens:
      - `VDD = 152`
      - `VSS = 118`
    - special opens:
      - `VSS = 471`
      - `VDD = 260`
  - after:
    - terminal opens:
      - `VDD = 152`
      - `VSS = 118`
    - special opens:
      - `VSS = 167`
      - `VDD = 564`

Interpretation:
- the VSS phase-2 capture **works**
- it does not lower the total by itself because the residual simply shifts to VDD
- therefore the next logical continuation is not another VSS experiment
- it is a complementary `VDD phase2 + VDD corepin attach to M6` from the VSS-improved checkpoint

### What Is Definitely Dead

These should not be retried as mainline ideas:
- `full_9` corridor scaling
- `full_9 + pblk` variants
- corridor-heavy `m1rblk_synth4` PD mainline
- place-stage thin hotspot `M1` route-blockages
- generic `pg_edge` / `pg_vdd` reconnects using the old helper windows
- broad low-layer PG meshes that disturb the clean simple baseline

### What Is Still Credible

Only two credible continuation paths remain.

Path A: preserve `0 / 0 / 6179` and keep solving PG from the clean anchor.
- start from:
  - `out_simple_plain_synth4`
  - or PG-only checkpoints derived from its `prepg.enc`
- do **paired** phase-2 capture:
  - first VSS phase-2
  - then complementary VDD phase-2
- require that each step be source/layout-local and placement-preserving
- success criterion:
  - reduce the clean-anchor routed `6179` without introducing routed DRC

Path B: preserve `4661` and surgically remove the `75` DRC.
- start from:
  - `out_simple_brcorr_seg_pblk_synth4`
- treat the `4661` PG result as the best structural PG result found
- stop changing corridor coverage or adding broad PG topology
- focus only on the repeated `M1` short mechanism around:
  - `EC_*`
  - `TAP_*`
  - `registerFile`
  - hotspot x-lines near `503 / 583 / 625 / 705 / 865 / 903 / 945 / 983`
- success criterion:
  - keep `special ~= 4661`
  - reduce `75` DRC toward `0`

### Recommended Handoff Priority

If work resumes, the recommended order is:
1. continue Path A first:
   - run complementary `VDD phase2 + VDD corepin attach to M6` from the
     VSS-improved checkpoint, because that is the only PG-only branch that
     showed a real causal shift instead of a no-op
2. if Path A still cannot reduce total PG count below `730` at PG-stage,
   stop PG-only pre-route surgery
3. then switch to Path B:
   - keep `4661`
   - solve the `75` M1 shorts surgically

### Local Git Checkpoints In Codex

Useful commits in this repo:
- `fcb4157`
  - `Investigate synth-top LVS corruption in codex flow`
- `2cfec30`
  - `Record synth-top alias persists after source tie-off`
- `5c73098`
  - `Sanitize mapped Core top to break LVS alias`
- `9bb70da`
  - `Record synth4 matched physical baseline recovery`
- `26fbb51`
  - `Record matched simple synth4 LVS baseline`

These commits preserve the fixed-netlist and matched-baseline understanding.
The later PG-only experiments were still in active iteration and were not
captured as final commits at handoff.

## Imported Calibre DRC/LVS Cleanup Journal

The following is a verbatim copy of:
- `/home/fy2243/soc_design/signoff/calibre_foundrytap_lightfinal_20260410/CALIBRE_CLEANUP_JOURNAL_2026-04-10.md`

# Calibre DRC/LVS Cleanup Journal

Date: 2026-04-10 to 2026-04-11

Scope:
- Signoff tree: `soc_design/signoff/calibre_foundrytap_lightfinal_20260410`
- Goal: make the canonical Calibre DRC path clean and the canonical Calibre LVS path clean on the same final layout

Final result:
- DRC clean: `TOTAL DRC Results Generated: 0 (0)`
  - Report: `05_drc/output/DRC_dmmerge_macroedge_cut1plus.rep`
  - Summary line: line 2556
- LVS clean: `CORRECT`
  - Report: `07_lvs/output/lvs.physall_supplyalias_global.rep`
  - Top summary: line 45
  - Final matched counts:
    - `Ports 3/3`: line 588
    - `Nets 22683/22683`: line 590
    - `Instances 19596/19596`: line 675

Canonical clean artifacts:
- Final layout: `04_dummyMerge/output/soc_top.dmmerge_macroedge_cut1plus.oas.gz`
- DRC runset: `05_drc/scr/runset.dmmerge_macroedge_cut1plus.cmd`
- LVS extract runset: `07_lvs/scr/runset.extract.cmd`
- LVS compare runset: `07_lvs/scr/runset.compare.physall_supplyalias_global.cmd`

## 1. Initial objective

The requirement was simple but strict:
- Calibre DRC clean
- Calibre LVS clean

The important constraint was that both had to be true on the same final layout database, not on two different intermediate layouts.

## 2. Starting point and main failure buckets

The working signoff tree already had a partially developed dummy-merge cleanup flow:
- `04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus.cmd`

That flow already represented the right strategy:
- patch the post-merge layout rather than touching unrelated upstream data
- keep edits localized and reproducible
- preserve the existing signoff directory structure

The cleanup naturally separated into two phases:
1. DRC closure on the final OASIS layout
2. LVS closure on that exact DRC-clean layout

The DRC issues fell into four practical buckets:
- macro-edge / dummy-metal geometry around the SRAM boundary region
- one stubborn VIA3 enclosure issue
- a few residual M4 top-level markers
- final AP density / AP pattern checks

The LVS issue ended up being much narrower:
- one extra power-fragment net after extraction and supply aliasing on the final DRC-clean layout

## 3. DRC closure path

### 3.1 Macro-edge and DM cleanup

The first stable fix path was implemented in:
- `04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus.cmd`

Approach:
- clone only the specific offending boundary / decap cells into temporary fix variants
- delete only the polygons responsible for the rule markers
- swap only the placed refs that overlapped the macro-edge problem region

Cells cloned and surgically trimmed:
- `BOUNDARY_LEFTBWP16P90LVT`
- `DCAP4BWP16P90`
- `DCAP8BWP16P90`
- `DCAP16BWP16P90`
- `DCAP32BWP16P90`
- `DCAP64BWP16P90`

Why this approach was chosen:
- it kept the edits local
- it avoided disturbing untouched placements elsewhere in the chip
- it produced a scriptable, repeatable signoff patch instead of a one-off manual database edit

Problem encountered:
- fixing the cell masters alone did not fully close the deck

What remained after this stage:
- one VIA3 issue
- several M4 markers
- AP checks

### 3.2 VIA3 enclosure fix

One specific VIA3 structure still failed after the macro-edge cleanup.

Approach tried and kept:
- clone the via cell
- trim only the offending cut polygon
- replace only the exact placed instance that matched the failing location/property

Relevant object in the script:
- source cell: `soc_top_NR_VIA3_1x2_VH_H_M3VIA3M4_2_2_1_4`
- fix cell: `soc_top_NR_VIA3_1x2_VH_H_M3VIA3M4_2_2_1_4_FIXLEFT`

Why this worked:
- the failure was localized to one enclosure relationship
- trimming one cut avoided broad side effects

### 3.3 Residual M4 top-level patches

After the cell-level and VIA3 fixes, a few top-level M4 markers remained.

Approach tried and kept:
- create/remove a small number of explicit top-level polygons on:
  - `34.150`
  - `53.150`

This was done directly in:
- `04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus.cmd`

Why this approach was chosen:
- the markers were already isolated at top level
- the cheapest safe fix was direct polygon surgery
- pushing those fixes back into many lower-level sources would have cost more risk than value

Result after this phase:
- non-AP DRC issues were effectively gone
- AP checks became the last blocking DRC class

### 3.4 AP rule closure

This was the last DRC blocker and the most iterative part of the work.

To avoid destabilizing the canonical script before the AP solution was proven, a candidate flow was created:
- candidate edit script: `04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus_apfull.cmd`
- candidate layout: `04_dummyMerge/output/soc_top.dmmerge_macroedge_cut1plus_apfull.oas.gz`
- candidate DRC runset: `05_drc/scr/runset.dmmerge_macroedge_cut1plus_apfull.cmd`
- candidate selected-check runset: `05_drc/scr/runset.select.dmmerge_macroedge_cut1plus_apfull.cmd`

#### Problem encountered

After the non-AP fixes, the remaining failures were AP-related:
- `AP.DN.1.T`
- `AP.DN.1.1.T`
- `AP.W.2`

This meant the layout needed AP metal, but not just any AP metal. It had to satisfy:
- local density
- global density window behavior
- minimum width / pattern constraints

#### Approach 1: solid AP fill

Tried:
- a large solid AP polygon on layer `74.0`

Observed:
- density improved enough to remove `AP.DN.1.T`
- but other AP checks still failed, especially width/pattern-style checks

Why it was rejected:
- “more AP” was not equivalent to “legal AP”
- the pattern itself violated foundry constraints

#### Approach 2: coarse tiled AP pattern

Tried:
- larger AP tiles on a coarser pitch
- notably `40um` square on `70um` pitch

Observed:
- density checks looked much better
- but `AP.W.2` still failed badly

Why it was rejected:
- density closure without width/pattern closure was still a failed deck

#### Approach 3: derive dimensions from foundry collateral

At this point the AP work was driven from the foundry rule collateral instead of guesswork.

Files consulted:
- ICV deck:
  - `/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/DRC/N16ADFP_DRC_ICV/LOGIC_TopMr_DRC/N16ADFP_DRC_ICV_11M.11_1a.encrypt`
- APR tech file:
  - `/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_ICC2/N16ADFP_APR_ICC2_11M.10a.tf`

Useful values derived from those files:
- AP density window: `100um`
- AP minimum density target: `10%`
- AP maximum density target: `75%`
- AP width-related threshold seen in deck: `31.5`

#### Final AP solution

The AP pattern that closed the deck was:
- AP square size: `30000` database units = `30um`
- AP pitch: `50000` database units = `50um`
- layer: `74.0`

That pattern is now embedded in the canonical script:
- `04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus.cmd`

Why it worked:
- it was dense enough to satisfy the AP density windows
- it was not large enough to trip the AP width/pattern checks
- it was regular and reproducible

Result:
- candidate full DRC report showed zero violations
- after promotion to the canonical script, the canonical DRC report also showed zero violations

Canonical final DRC proof:
- `05_drc/output/DRC_dmmerge_macroedge_cut1plus.rep`
- summary line: `TOTAL DRC Results Generated: 0 (0)`

## 4. LVS closure path

Once DRC was clean, the next step was to prove LVS on that same final layout.

This is where an important distinction mattered:
- a previously clean LVS on an older/base layout was not enough
- the final AP-clean dummy-merge layout had to be re-extracted and re-compared

### 4.1 Safe staging before touching canonical extract path

A temporary extract runset was created first:
- `07_lvs/scr/runset.extract.apfull.cmd`

Purpose:
- point extraction at the candidate DRC-clean layout
- validate LVS without immediately rewriting the canonical path

### 4.2 First final-layout LVS result

The extracted layout netlist was processed through:
- `07_lvs/scr/alias_layout_supply_pins.py`
- `07_lvs/scr/add_supply_globals.py`

Then it was compared with:
- `07_lvs/scr/runset.compare.physall_supplyalias_global.cmd`

First result on the final layout:
- not clean
- one remaining mismatch on `VDD`
- net count mismatch:
  - layout `22684`
  - source `22683`
- instances were already fully matched

This was a very good sign:
- the problem was no longer broad connectivity corruption
- it was one remaining power-net aliasing issue

### 4.3 What failed conceptually

The extracted layout had a local supply fragment that should have collapsed into the top power net, but did not.

The investigation narrowed quickly to the SRAM macro:
- `TS1N16ADFPCLLLVTA512X45M4SWSHOD`

The key observation was:
- the extracted layout macro header contained both `VDDM` and `VDD`
- the supply alias script only treated the following as power:
  - `VDD`
  - `VDDPST`
  - `AVDD`
  - `DVDD`

That meant:
- `VDDM` was not being canonicalized as a power pin
- a local net fragment remained separate instead of being collapsed onto the main power network
- the result was one extra power-like net in layout LVS

### 4.4 Failed shortcuts

A few ideas were not enough by themselves:
- only prepending `.GLOBAL VDD VSS`
- only rerunning compare without changing aliasing
- trying to force alternate layout input methods on the old runset

One especially bad shortcut was trying to drive the old extraction flow with a CLI `-layout` override. That path produced parser/layout-read errors and was discarded. The correct solution was to use a proper extract runset that explicitly referenced the intended OASIS file.

### 4.5 Final LVS fix

The actual fix was small and specific:
- add `VDDM` to the list of power names recognized by the supply alias logic

File updated:
- `07_lvs/scr/alias_layout_supply_pins.py`

Change:
- `POWER_PINS` was extended from:
  - `{"VDD", "VDDPST", "AVDD", "DVDD"}`
- to:
  - `{"VDD", "VDDM", "VDDPST", "AVDD", "DVDD"}`

This did two things:
1. it let the extracted layout-side power fragment collapse correctly
2. it let the compare runset treat `VDDM` consistently as a power net name as well

To keep the canonical flow self-consistent, the power-name variable was also updated in:
- `07_lvs/scr/runset.extract.cmd`
- `07_lvs/scr/runset.compare.physall_supplyalias_global.cmd`

### 4.6 Canonical LVS promotion

After the fix was proven on the candidate path, the canonical extract runset was promoted to point at the final layout:
- `07_lvs/scr/runset.extract.cmd`

Layout path changed from the old base layout:
- `../01_ipmerge/output/soc_top.oas.gz`

to the final cleaned layout:
- `../04_dummyMerge/output/soc_top.dmmerge_macroedge_cut1plus.oas.gz`

Result after rerun:
- LVS became `CORRECT`
- net counts matched exactly
- instance counts matched exactly

Canonical final LVS proof:
- `07_lvs/output/lvs.physall_supplyalias_global.rep`

Key final lines:
- line 45: `CORRECT        soc_top                       soc_top`
- line 588: `Ports:               3          3            0            0`
- line 590: `Nets:            22683      22683            0            0`
- line 675: `Total Inst:      19596      19596            0            0`

## 5. Files that matter in the final clean flow

### Canonical files changed

- `04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus.cmd`
  - now includes the AP mesh generation in addition to the localized geometry fixes
- `07_lvs/scr/alias_layout_supply_pins.py`
  - now treats `VDDM` as a power net
- `07_lvs/scr/runset.extract.cmd`
  - now extracts from the final dummy-merge clean layout and recognizes `VDDM`
- `07_lvs/scr/runset.compare.physall_supplyalias_global.cmd`
  - now recognizes `VDDM`

### Useful temporary validation artifacts

- `04_dummyMerge/scr/edit_dmmerge_macroedge_cut1plus_apfull.cmd`
- `05_drc/scr/runset.dmmerge_macroedge_cut1plus_apfull.cmd`
- `05_drc/scr/runset.select.dmmerge_macroedge_cut1plus_apfull.cmd`
- `07_lvs/scr/runset.extract.apfull.cmd`

These were intentionally used as a staging area before promoting the winning fixes into the canonical files.

## 6. Repro sequence for future PD work

### Rebuild the final clean layout

From `04_dummyMerge`:

```bash
calibredrv -shell ./scr/edit_dmmerge_macroedge_cut1plus.cmd > ./log/edit_dmmerge_macroedge_cut1plus.log 2>&1
```

### Run canonical DRC

From `05_drc`:

```bash
calibre -drc -hier -turbo 8 -hyper ./scr/runset.dmmerge_macroedge_cut1plus.cmd > ./log/runset.dmmerge_macroedge_cut1plus.log 2>&1
```

Expected result:
- `output/DRC_dmmerge_macroedge_cut1plus.rep`
- zero total DRC results

### Run canonical LVS

From `07_lvs`:

```bash
calibre -lvs -hcell ./source_fix/hcell.ts1alias -hier -turbo 8 -hyper ./scr/runset.extract.cmd > ./log/runset.extract.log 2>&1
python3 ./scr/alias_layout_supply_pins.py ./output/soc_top.layspi ./output/soc_top.supplyalias.layspi
python3 ./scr/add_supply_globals.py ./output/soc_top.supplyalias.layspi ./output/soc_top.supplyalias.global.layspi
calibre -lvs -hcell ./source_fix/hcell.ts1alias -hier -turbo 8 -hyper ./scr/runset.compare.physall_supplyalias_global.cmd > ./log/runset.physall_supplyalias_global.log 2>&1
```

Expected result:
- `output/lvs.physall_supplyalias_global.rep`
- `CORRECT`

## 7. Lessons learned

### 7.1 Keep DRC surgery local and scriptable

The winning pattern for physical cleanup was:
- clone local offenders
- trim only the bad polygons
- swap only the overlapping refs

That was much safer than broad database editing.

### 7.2 AP closure should be driven from collateral, not intuition

The AP work only converged once the pattern was tied back to:
- foundry density windows
- AP width/pattern limits from the deck

### 7.3 DRC-clean does not automatically mean LVS-clean

The final AP-clean layout still needed a fresh extraction and compare.

The remaining LVS mismatch was not a geometry problem at all. It was a net-name canonicalization problem.

### 7.4 Power aliasing needs all real supply names

If the design uses both:
- `VDD`
- `VDDM`

then aliasing logic that recognizes only `VDD` is incomplete. That kind of bug can leave a compare “almost clean” but still wrong by one net.

### 7.5 Use temporary candidate scripts before promoting the fix

Creating explicit candidate runsets was worthwhile:
- it isolated experiments
- it protected the canonical signoff path until both DRC and LVS were proven
- promotion to the canonical flow became a mechanical final step

## 8. Bottom line

The final successful strategy was:
1. close localized macro-edge, via, and M4 issues with targeted geometry edits
2. close AP with a tiled `30um` square on `50um` pitch pattern on `74.0`
3. rerun extraction on that exact final layout
4. fix layout-side supply aliasing by recognizing `VDDM`
5. promote the proven candidate path into the canonical signoff scripts

That combination produced:
- DRC clean
- LVS clean
- on the same canonical final layout
