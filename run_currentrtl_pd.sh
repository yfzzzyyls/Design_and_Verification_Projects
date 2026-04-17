#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TAG=${TAG:-axi_uartcordic_currentrtl_$(date +%Y%m%d_%H%M%S)}

# Keep each rerun in its own workspace so the archived clean packages remain
# untouched and the current RTL experiments stay easy to diff.
export SOC_MAP_OUT_DIR=${SOC_MAP_OUT_DIR:-$ROOT/mapped_${TAG}}
export SOC_DC_WORK_DIR=${SOC_DC_WORK_DIR:-$ROOT/WORK_${TAG}}
export SOC_PNR_OUT_DIR=${SOC_PNR_OUT_DIR:-$ROOT/pd/innovus_${TAG}}
export FINAL_ENC=${FINAL_ENC:-$SOC_PNR_OUT_DIR/with_sram_final.enc}
export DATE_TAG=${DATE_TAG:-$TAG}
export WORK_DIR=${WORK_DIR:-$ROOT/signoff/calibre_${DATE_TAG}}

# Default to the post-April-12 closure recipe knobs. Override any of these from
# the environment when you want to probe a different physical variant.
export SOC_ENABLE_ENDCAPS=${SOC_ENABLE_ENDCAPS:-1}
export SOC_ENABLE_WELLTAPS=${SOC_ENABLE_WELLTAPS:-1}
export SOC_ENABLE_SPARSE_PG_BACKBONE=${SOC_ENABLE_SPARSE_PG_BACKBONE:-1}
export SOC_ENABLE_ROW_PG_MESH=${SOC_ENABLE_ROW_PG_MESH:-0}
export SOC_ENABLE_VENDOR_PG_MESH=${SOC_ENABLE_VENDOR_PG_MESH:-0}
export SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE=${SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE:-1}
export SOC_ENABLE_SRAM_VDD_TRIM_FIX=${SOC_ENABLE_SRAM_VDD_TRIM_FIX:-1}

SYN_BIN=${SYN_BIN:-dcnxt_shell}
INNOVUS_BIN=${INNOVUS_BIN:-/eda/cadence/INNOVUS211/bin/innovus}

echo "==> Synthesizing current RTL into $SOC_MAP_OUT_DIR"
"$SYN_BIN" -f "$ROOT/syn_complete_with_tech.tcl"

echo "==> Running Innovus PNR into $SOC_PNR_OUT_DIR"
"$INNOVUS_BIN" -no_gui -overwrite -files "$ROOT/tcl_scripts/complete_flow_with_qrc_with_sram.tcl"

echo "==> Running Calibre signoff into $WORK_DIR"
"$ROOT/run_calibre_signoff.sh"
