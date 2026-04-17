Current RTL clean signoff milestone captured on April 16, 2026.

Contents:
- `04_dummyMerge/output/soc_top.dmmerge.oas.gz`: patched dummy-merge layout used for the final clean DRC run
- `04_dummyMerge/scr/patch_b17_master_complete_v48.sh`: provenance script for the final B17 dummy-master repair
- `05_drc/output/DRC.rep`: full-chip Calibre DRC report with zero results
- `05_drc/scr/runset.cmd`: repo-local DRC rerun entrypoint for this checkpoint
- `07_lvs/output/lvs.physall_supplyalias_global.rep`: final Calibre LVS report (`CORRECT`)

Notes:
- The v48 closure change is a dummy-fill repair only. It restores missing B17 low-layer dummy master geometry and does not change functional RTL or extracted connectivity.
- The final LVS result is carried forward from `signoff/calibre_axi_uartcordic_currentrtl_postdrc_20260412_r2`, whose alias/global compare is already `CORRECT`.
- The committed DRC runset still references the existing local `drc.modified` deck under `signoff/calibre_axi_uartcordic_currentrtl_postdrc_20260412_r2`; the proprietary foundry deck itself is not duplicated into this milestone payload.
- The committed OASIS file is the canonical clean checkpoint. The provenance script documents the final B17 repair but still references earlier scratch layouts from the iterative debug flow.
