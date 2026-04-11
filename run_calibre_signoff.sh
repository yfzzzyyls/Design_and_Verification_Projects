#!/usr/bin/env bash
set -euo pipefail

ROOT=${ROOT:-/home/fy2243/soc_design}
TOP=${TOP:-soc_top}
DATE_TAG=${DATE_TAG:-fillko_20260409}
WORK_DIR=${WORK_DIR:-$ROOT/signoff/calibre_${DATE_TAG}}
EXPORT_DIR=${EXPORT_DIR:-$WORK_DIR/00_export}
FINAL_ENC=${FINAL_ENC:-$ROOT/pd/innovus_fillko_20260409/with_sram_final.enc}
CALIBRE_BIN=${CALIBRE_BIN:-/eda/mentor/Calibre/aok_cal_2024.2_29.16/bin}
INNOVUS_BIN=${INNOVUS_BIN:-/eda/cadence/INNOVUS211/bin/innovus}
CPU=${CPU:-8}
LAYOUT_FORMAT=${LAYOUT_FORMAT:-oasis}
RUN_DRC=${RUN_DRC:-1}
RUN_LVS=${RUN_LVS:-1}
LVS_LAYOUT_MODE=${LVS_LAYOUT_MODE:-ipmerge}
DRC_BASE_LAYOUT_MODE=${DRC_BASE_LAYOUT_MODE:-ipmerge}
IPMERGE_STD_MODE=${IPMERGE_STD_MODE:-full}
EXPORT_PG_PINS=${EXPORT_PG_PINS:-0}
BE_DUMMY_SPECIAL_FILL=${BE_DUMMY_SPECIAL_FILL:-0}
BE_DUMMY_WINDOW_MARGIN_UM=${BE_DUMMY_WINDOW_MARGIN_UM:-0}
SOURCE_DROP_TOP_PINS=()
if [[ "$EXPORT_PG_PINS" == "1" ]]; then
  SOURCE_DROP_TOP_PINS=(--drop-top-pins VDD VSS)
fi
if [[ -z "${STREAM_UNITS:-}" ]]; then
  STREAM_UNITS=1000
fi

PKG=/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package
STD_GDS=$PKG/Collaterals/IP/stdcell/N16ADFP_StdCell/GDS/N16ADFP_StdCell.gds
SRAM_GDS=$PKG/Collaterals/IP/sram/N16ADFP_SRAM/GDS/N16ADFP_SRAM_100a.gds
STD_SPI=$PKG/Collaterals/IP/stdcell/N16ADFP_StdCell/SPICE/N16ADFP_StdCell_100b.spi
SRAM_SPI=$PKG/Collaterals/IP/sram/N16ADFP_SRAM/SPICE/N16ADFP_SRAM_100a.spi
STD_LEF=$PKG/Collaterals/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef
SRAM_LEF=$PKG/Collaterals/IP/sram/N16ADFP_SRAM/LEF/N16ADFP_SRAM_100a.lef
DRC_DECK=$PKG/Collaterals/Tech/DRC/N16ADFP_DRC_Calibre/LOGIC_TopMr_DRC/N16ADFP_DRC_Calibre_11M.11_1a.encrypt
FE_DUMMY_DECK=$PKG/Collaterals/Tech/DUMMY/N16ADFP_Dummy_Calibre/FEOL/Dummy_FEOL_CalibreYE_16nm_ADFP_FFP.10a.encrypt
BE_DUMMY_DECK=$PKG/Collaterals/Tech/DUMMY/N16ADFP_Dummy_Calibre/BEOL/Dummy_BEOL_CalibreYE_16nm_ADFP_FFP.10a.encrypt
LVS_DECK=$PKG/Collaterals/Tech/LVS/N16ADFP_LVS_Calibre/MAIN_DECK/CCI_FLOW/N16ADFP_LVS_Calibre
LVS_SOURCE_ADDED=$PKG/Collaterals/Tech/LVS/N16ADFP_LVS_Calibre/source.added
SRAM_LAYOUTORDER_REF=${SRAM_LAYOUTORDER_REF:-$ROOT/signoff_ref_ts1_sram_layoutorder.spi}

mkdir -p "$WORK_DIR"

if [[ "${LAYOUT_FORMAT,,}" == "gds" || "${LAYOUT_FORMAT,,}" == "gdsii" ]]; then
  EXPORT_LAYOUT_SYSTEM="GDSII"
  EXPORT_LAYOUT_PATH="$EXPORT_DIR/$TOP.gds"
else
  EXPORT_LAYOUT_SYSTEM="OASIS"
  EXPORT_LAYOUT_PATH="$EXPORT_DIR/$TOP.oas.gz"
fi

if [[ "$DRC_BASE_LAYOUT_MODE" == "export" ]]; then
  DRC_BASE_LAYOUT_SYSTEM="$EXPORT_LAYOUT_SYSTEM"
  DRC_BASE_LAYOUT_PATH="$EXPORT_LAYOUT_PATH"
else
  DRC_BASE_LAYOUT_SYSTEM="OASIS"
  DRC_BASE_LAYOUT_PATH="../01_ipmerge/output/$TOP.oas.gz"
fi

run_calibredrv() {
  "$CALIBRE_BIN/calibredrv" -64 "$@"
}

run_calibre() {
  "$CALIBRE_BIN/calibre" "$@"
}

generate_lvs_box_rules() {
  local alias_file=$1
  local out_file=$2
  awk '
    NF < 2 { next }
    $1 == "TS1N16ADFPCLLLVTA512X45M4SWSHOD" {
      print "LVS BOX BLACK " $1
      next
    }
    $1 == "B17aTS1N16ADFPCLLLVTA512X45M4SWSHOD" { next }
    $1 == "F17aTS1N16ADFPCLLLVTA512X45M4SWSHOD" { next }
    { print "LVS BOX " $1 " " $2 }
  ' "$alias_file" > "$out_file"
}

generate_lvs_ignore_device_pin_rules() {
  local alias_file=$1
  local out_file=$2
  awk '
    NF < 2 { next }
    $2 ~ /^DCAP/ { seen[$2] = 1 }
    END {
      for (cell in seen) {
        print "LVS IGNORE DEVICE PIN " cell " \"2\" \"3\" \"6\" \"7\" \"8\" \"9\" \"10\""
      }
    }
  ' "$alias_file" | LC_ALL=C sort > "$out_file"
}

generate_lvs_exclude_cell_rules() {
  local alias_file=$1
  local out_file=$2
  awk '
    NF < 2 { next }
    function emit(cell) {
      if (cell ~ /^(BOUNDARY_|DCAP|FILL|TAPCELL)/) {
        seen[cell] = 1
      }
    }
    {
      emit($1)
      emit($2)
    }
    END {
      for (cell in seen) {
        print "LVS SPICE EXCLUDE CELL SOURCE " cell
        print "LVS SPICE EXCLUDE CELL LAYOUT " cell
      }
    }
  ' "$alias_file" | LC_ALL=C sort > "$out_file"
}

generate_lvs_layout_wrapper_exclude_rules() {
  local layspi_file=$1
  local out_file=$2
  python3 - "$layspi_file" "$out_file" <<'PY'
from pathlib import Path
import re
import sys

layspi_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
text = layspi_path.read_text(errors="ignore").splitlines()

stmts = []
cur = None
for raw in text:
    line = raw.rstrip()
    if not line:
        continue
    if line.startswith("+"):
        if cur is not None:
            cur += " " + line[1:].strip()
    else:
        if cur is not None:
            stmts.append(cur)
        cur = line.strip()
if cur is not None:
    stmts.append(cur)

subcells = {}
current = None
for stmt in stmts:
    if stmt.startswith(".SUBCKT "):
        current = stmt.split()[1]
        subcells.setdefault(current, [])
        continue
    if stmt.startswith(".ENDS"):
        current = None
        continue
    if current is None or not stmt.startswith("X"):
        continue
    parts = stmt.split()
    cell = None
    for i, token in enumerate(parts[1:], start=1):
        if token.startswith("$"):
            cell = parts[i - 1]
            break
    if cell is None:
        cell = parts[-1]
    subcells[current].append(cell)

leaf_pat = re.compile(r"^(BOUNDARY_|DCAP|FILL|TAPCELL)")
memo = {}
visiting = set()

def is_excluded(cell):
    if leaf_pat.match(cell):
        return True
    if not cell.startswith("ICV_"):
        return False
    if cell in memo:
        return memo[cell]
    if cell in visiting:
        return False
    visiting.add(cell)
    children = subcells.get(cell, [])
    result = bool(children) and all(is_excluded(child) for child in children)
    visiting.remove(cell)
    memo[cell] = result
    return result

top_cells = subcells.get("soc_top", [])
wrappers = sorted({cell for cell in top_cells if cell.startswith("ICV_") and is_excluded(cell)})
out_path.write_text("".join(f"LVS SPICE EXCLUDE CELL LAYOUT {cell}\n" for cell in wrappers))
PY
}

echo "[1/6] Exporting fresh signoff artifacts from $FINAL_ENC"
mkdir -p "$EXPORT_DIR"
env SOC_FINAL_ENC="$FINAL_ENC" SOC_SIGNOFF_EXPORT_DIR="$EXPORT_DIR" SOC_DESIGN_NAME="$TOP" \
  SOC_EXPORT_PG_PINS="$EXPORT_PG_PINS" \
  SOC_STREAM_UNITS="$STREAM_UNITS" SOC_LAYOUT_FORMAT="$LAYOUT_FORMAT" \
  "$INNOVUS_BIN" -no_gui -overwrite -files "$ROOT/tcl_scripts/export_calibre_signoff_artifacts.tcl"

readarray -t DIE_SIZE_UM < <(python3 - "$EXPORT_DIR/$TOP.def.gz" <<'PY'
import gzip
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit

with gzip.open(path, "rt", errors="ignore") as f:
    text = f.read()

units = re.search(r"UNITS DISTANCE MICRONS\s+(\d+)\s*;", text)
die = re.search(r"DIEAREA\s+\(\s*0\s+0\s*\)\s+\(\s*(\d+)\s+(\d+)\s*\)\s*;", text)
if not units or not die:
    raise SystemExit

dbu_per_micron = int(units.group(1))
die_x = int(die.group(1)) / dbu_per_micron
die_y = int(die.group(2)) / dbu_per_micron
print(f"{die_x:.6f}")
print(f"{die_y:.6f}")
PY
)
if (( ${#DIE_SIZE_UM[@]} >= 2 )); then
  DIE_X_UM=${DIE_SIZE_UM[0]}
  DIE_Y_UM=${DIE_SIZE_UM[1]}
else
  DIE_X_UM=
  DIE_Y_UM=
fi

IP_DIR=$WORK_DIR/01_ipmerge
mkdir -p "$IP_DIR"/{scr,log,output}
cat > "$IP_DIR/scr/runset.cmd" <<EOF
set raw [layout create "$EXPORT_LAYOUT_PATH" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set top [layout create "$EXPORT_LAYOUT_PATH" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set TopCell [\$top topcell]
set usedCells [\$raw cells]
if {"$IPMERGE_STD_MODE" eq "used_nonphysical"} {
    foreach gdsFile [list "$STD_GDS" "$SRAM_GDS"] {
        puts "import \$gdsFile"
        \$top import layout "\$gdsFile" FALSE overwrite -dt_expand -preservePaths -preserveTextAttributes -preserveProperties
    }
    set physRegex {^(BOUNDARY_|FILL|DCAP|DECAP|TAPCELL|PCORNER|PFILLER|PVDD)}
    foreach cellName \$usedCells {
        if {![regexp \$physRegex \$cellName]} {
            continue
        }
        puts "restore physical \$cellName"
        set restoreLayers [lsort -unique [concat [\$top layers -cell \$cellName] [\$raw layers -cell \$cellName]]]
        foreach layer \$restoreLayers {
            \$top delete objects \$cellName \$layer
        }
        foreach layer [\$raw layers -cell \$cellName] {
            \$top COPYCELL GEOM \$raw \$cellName \$layer \$cellName \$layer
        }
    }
} else {
    foreach gdsFile [list "$STD_GDS" "$SRAM_GDS"] {
        set toImport [layout create "\$gdsFile" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
        puts "import \$gdsFile"
        \$top import layout \$toImport FALSE overwrite -dt_expand -preservePaths -preserveTextAttributes -preserveProperties
    }
}
\$top create layer 108.250
\$top create polygon $TOP 108.250 0 0 336.420u 336.192u
\$top oasisout ./output/$TOP.oas.gz \$TopCell
EOF
echo "[2/6] IP merge"
(cd "$IP_DIR" && run_calibredrv ./scr/runset.cmd | tee log/runset.log)

FE_DIR=$WORK_DIR/02_insertFeDummy
if [[ "$RUN_DRC" == "1" ]]; then
mkdir -p "$FE_DIR"/{scr,log,output}
cp -f "$FE_DUMMY_DECK" "$FE_DIR/scr/fe_dummy.modified"
sed -i -E "s/^(LAYOUT PRECISION[[:space:]]+).*/\\1$STREAM_UNITS/" "$FE_DIR/scr/fe_dummy.modified"
sed -i -E "s/^(PRECISION[[:space:]]+).*/\\1$STREAM_UNITS/" "$FE_DIR/scr/fe_dummy.modified"
sed -i -e 's/^LAYOUT PRIMARY/\/\/LAYOUT PRIMARY/g' "$FE_DIR/scr/fe_dummy.modified"
sed -i -e 's/^LAYOUT PATH/\/\/LAYOUT PATH/g' "$FE_DIR/scr/fe_dummy.modified"
sed -i -e 's/^LAYOUT SYSTEM/\/\/LAYOUT SYSTEM/g' "$FE_DIR/scr/fe_dummy.modified"
sed -i -e 's/^DRC RESULTS DATABASE/\/\/DRC RESULTS DATABASE/g' "$FE_DIR/scr/fe_dummy.modified"
sed -i -e 's/^DRC SUMMARY REPORT/\/\/DRC SUMMARY REPORT/g' "$FE_DIR/scr/fe_dummy.modified"
sed -i -e 's/  #DEFINE WITH_SEALRING/\/\/#DEFINE WITH_SEALRING/g' "$FE_DIR/scr/fe_dummy.modified" || true
sed -i -e 's/\/\/#DEFINE UseprBoundary/#DEFINE UseprBoundary/g' "$FE_DIR/scr/fe_dummy.modified"
cat > "$FE_DIR/scr/runset.cmd" <<EOF
LAYOUT SYSTEM $DRC_BASE_LAYOUT_SYSTEM
LAYOUT PATH "$DRC_BASE_LAYOUT_PATH"
LAYOUT PRIMARY "$TOP"
DRC RESULTS DATABASE "output/FEOL.db"
DRC SUMMARY REPORT "output/FEOL.sum"
include ./scr/fe_dummy.modified
EOF
cat > "$FE_DIR/scr/genGds.cmd" <<'EOF'
set gdsIn [ glob -nocomplain "*EOL*.gds"]
set inputGds [lindex $gdsIn 0]
set top [layout create $inputGds -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set TopCell [$top topcell]
set gdsout "./output/soc_top.dodoas.gz"
$top oasisout $gdsout $TopCell
EOF
echo "[3/6] FE dummy insertion"
(cd "$FE_DIR" && run_calibre -drc -hier -64 -turbo "$CPU" -hyper ./scr/runset.cmd | tee -i log/runset.log && run_calibredrv ./scr/genGds.cmd -wait 60 | tee -i log/rename_top.log)
fi

BE_DIR=$WORK_DIR/03_insertBeDummy
if [[ "$RUN_DRC" == "1" ]]; then
mkdir -p "$BE_DIR"/{scr,log,output}
cp -f "$BE_DUMMY_DECK" "$BE_DIR/scr/be_dummy.modified"
sed -i -E "s/^(LAYOUT PRECISION[[:space:]]+).*/\\1$STREAM_UNITS/" "$BE_DIR/scr/be_dummy.modified"
sed -i -E "s/^(PRECISION[[:space:]]+).*/\\1$STREAM_UNITS/" "$BE_DIR/scr/be_dummy.modified"
sed -i -e 's/^LAYOUT PRIMARY/\/\/LAYOUT PRIMARY/g' "$BE_DIR/scr/be_dummy.modified"
sed -i -e 's/^LAYOUT PATH/\/\/LAYOUT PATH/g' "$BE_DIR/scr/be_dummy.modified"
sed -i -e 's/^LAYOUT SYSTEM/\/\/LAYOUT SYSTEM/g' "$BE_DIR/scr/be_dummy.modified"
sed -i -e 's/^DRC RESULTS DATABASE/\/\/DRC RESULTS DATABASE/g' "$BE_DIR/scr/be_dummy.modified"
sed -i -e 's/^DRC SUMMARY REPORT/\/\/DRC SUMMARY REPORT/g' "$BE_DIR/scr/be_dummy.modified"
sed -i -e 's/  #DEFINE WITH_SEALRING/\/\/#DEFINE WITH_SEALRING/g' "$BE_DIR/scr/be_dummy.modified" || true
sed -i -e 's/\/\/#DEFINE UseprBoundary/#DEFINE UseprBoundary/g' "$BE_DIR/scr/be_dummy.modified"
if [[ "$BE_DUMMY_SPECIAL_FILL" == "1" ]]; then
  sed -i -e 's@^//#DEFINE Boundary_and_Small_Gap_Special_Fill@#DEFINE Boundary_and_Small_Gap_Special_Fill@' "$BE_DIR/scr/be_dummy.modified"
fi
if [[ "$BE_DUMMY_WINDOW_MARGIN_UM" != "0" && "$BE_DUMMY_WINDOW_MARGIN_UM" != "0.0" ]]; then
  if [[ -z "$DIE_X_UM" || -z "$DIE_Y_UM" ]]; then
    echo "Unable to derive die size from $EXPORT_DIR/$TOP.def.gz for BE_DUMMY_WINDOW_MARGIN_UM" >&2
    exit 1
  fi
  chmod u+w "$BE_DIR/scr/be_dummy.modified"
  python3 - "$BE_DIR/scr/be_dummy.modified" "$BE_DUMMY_WINDOW_MARGIN_UM" "$DIE_X_UM" "$DIE_Y_UM" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
margin = float(sys.argv[2])
die_x = float(sys.argv[3])
die_y = float(sys.argv[4])
text = path.read_text()

repls = {
    r"^#DEFINE UseprBoundary.*$": "//#DEFINE UseprBoundary                 // disabled by BE_DUMMY_WINDOW_MARGIN_UM",
    r"^//#DEFINE ChipWindowUsed.*$": "#DEFINE ChipWindowUsed                // enabled by BE_DUMMY_WINDOW_MARGIN_UM",
    r"^(\s*VARIABLE xLB )[-0-9.]+(.*)$": rf"\g<1>{margin:.6f}\2",
    r"^(\s*VARIABLE yLB )[-0-9.]+(.*)$": rf"\g<1>{margin:.6f}\2",
    r"^(\s*VARIABLE xRT )[-0-9.]+(.*)$": rf"\g<1>{max(margin, die_x - margin):.6f}\2",
    r"^(\s*VARIABLE yRT )[-0-9.]+(.*)$": rf"\g<1>{max(margin, die_y - margin):.6f}\2",
}

for pattern, repl in repls.items():
    text, n = re.subn(pattern, repl, text, flags=re.MULTILINE)
    if n == 0:
        raise SystemExit(f"Failed to update BE dummy window setting: {pattern}")

path.write_text(text)
PY
fi
cat > "$BE_DIR/scr/runset.cmd" <<EOF
LAYOUT SYSTEM $DRC_BASE_LAYOUT_SYSTEM
LAYOUT PATH "$DRC_BASE_LAYOUT_PATH"
LAYOUT PRIMARY "$TOP"
DRC RESULTS DATABASE "output/BEOL.db"
DRC SUMMARY REPORT "output/BEOL.sum"
include ./scr/be_dummy.modified
EOF
cat > "$BE_DIR/scr/genGds.cmd" <<'EOF'
set gdsIn [ glob -nocomplain "*EOL*.gds"]
set inputGds [lindex $gdsIn 0]
set top [layout create $inputGds -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set TopCell [$top topcell]
set gdsout "./output/soc_top.dmoas.gz"
$top oasisout $gdsout $TopCell
EOF
echo "[4/6] BE dummy insertion"
(cd "$BE_DIR" && run_calibre -drc -hier -64 -turbo "$CPU" -hyper ./scr/runset.cmd | tee -i log/runset.log && run_calibredrv ./scr/genGds.cmd -wait 60 | tee -i log/rename_top.log)
fi

DM_DIR=$WORK_DIR/04_dummyMerge
if [[ "$RUN_DRC" == "1" ]]; then
mkdir -p "$DM_DIR"/{scr,log,output}
cat > "$DM_DIR/scr/runset.cmd" <<EOF
set top [layout create "$DRC_BASE_LAYOUT_PATH" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
foreach gdsFile [list "../03_insertBeDummy/output/$TOP.dmoas.gz" "../02_insertFeDummy/output/$TOP.dodoas.gz"] {
    set toImport [layout create "\$gdsFile" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
    set checkTopCell [\$toImport topcell]
    if {\$checkTopCell == ""} {
        puts "skip \$gdsFile due to 0 cell gds"
    } else {
        set gdsRename [\$toImport topcell]
        \$top import layout \$toImport FALSE overwrite -dt_expand -preservePaths -preserveTextAttributes -preserveProperties
        \$top create ref $TOP \$gdsRename 0 0 0 0 1
    }
}
\$top oasisout ./output/$TOP.dmmerge.oas.gz $TOP
EOF
echo "[5/6] Dummy merge"
(cd "$DM_DIR" && run_calibredrv ./scr/runset.cmd | tee log/runset.log)
fi

DRC_DIR=$WORK_DIR/05_drc
if [[ "$RUN_DRC" == "1" ]]; then
mkdir -p "$DRC_DIR"/{scr,log,output,rpt}
cp -f "$DRC_DECK" "$DRC_DIR/scr/drc.modified"
sed -i -E "s/^(LAYOUT PRECISION[[:space:]]+).*/\\1$STREAM_UNITS/" "$DRC_DIR/scr/drc.modified"
sed -i -e 's/^#DEFINE DUMMY_PRE_CHECK/\/\/#DEFINE DUMMY_PRE_CHECK/g' "$DRC_DIR/scr/drc.modified" || true
sed -i -e 's/\/\/#DEFINE UseprBoundary/#DEFINE UseprBoundary/g' "$DRC_DIR/scr/drc.modified"
sed -i -e 's/^LAYOUT SYSTEM/\/\/LAYOUT SYSTEM/g' "$DRC_DIR/scr/drc.modified"
sed -i -e 's/^LAYOUT PATH/\/\/LAYOUT PATH/g' "$DRC_DIR/scr/drc.modified"
sed -i -e 's/^LAYOUT PRIMARY/\/\/LAYOUT PRIMARY/g' "$DRC_DIR/scr/drc.modified"
sed -i -e 's/^DRC RESULTS DATABASE /\/\/DRC RESULTS DATABASE /g' "$DRC_DIR/scr/drc.modified"
sed -i -e 's/^DRC SUMMARY REPORT/\/\/DRC SUMMARY REPORT/g' "$DRC_DIR/scr/drc.modified"
sed -i -e 's/^VARIABLE VDD_TEXT/\/\/VARIABLE VDD_TEXT/g' "$DRC_DIR/scr/drc.modified" || true
if [[ "${LAYOUT_FORMAT,,}" == "gds" || "${LAYOUT_FORMAT,,}" == "gdsii" ]]; then
  DRC_LAYOUT_SYSTEM="GDSII"
  DRC_LAYOUT_PATH="../00_export/$TOP.gds"
else
  DRC_LAYOUT_SYSTEM="OASIS"
  DRC_LAYOUT_PATH="../04_dummyMerge/output/$TOP.dmmerge.oas.gz"
fi
cat > "$DRC_DIR/scr/runset.cmd" <<EOF
LAYOUT SYSTEM $DRC_LAYOUT_SYSTEM
LAYOUT PATH "$DRC_LAYOUT_PATH"
LAYOUT PRIMARY "$TOP"
DRC RESULTS DATABASE "output/DRC_RES.db"
DRC SUMMARY REPORT "output/DRC.rep"
VARIABLE VDD_TEXT "?VDD?"
include ./scr/drc.modified
EOF
echo "[6/6a] Calibre DRC"
(cd "$DRC_DIR" && run_calibre -drc -hier -64 -turbo "$CPU" -hyper ./scr/runset.cmd | tee -i log/runset.log)
fi

V2LVS_DIR=$WORK_DIR/06_v2lvs
mkdir -p "$V2LVS_DIR"/scr
cat > "$V2LVS_DIR/scr/var.tcl" <<EOF
set spiList " \\
    $STD_SPI \\
    $SRAM_SPI \\
"
EOF
cat > "$V2LVS_DIR/scr/runset.cmd" <<'EOF'
source ./scr/var.tcl
foreach spi $spiList {
    puts ".INCLUDE $spi"
}
EOF
{
  printf '.INCLUDE %s\n' "$LVS_SOURCE_ADDED"
  (cd "$V2LVS_DIR" && tclsh ./scr/runset.cmd)
} > "$V2LVS_DIR/$TOP.spi"
"$CALIBRE_BIN/v2lvs" -v "$EXPORT_DIR/$TOP.lvsvg" -o "$V2LVS_DIR/${TOP}_subckt.spi"
sed -i -e 's/^\.GLOBAL.*/**\.GLOBAL/' "$V2LVS_DIR/${TOP}_subckt.spi"
sed -i -e 's/^\.INCLUDE.*/**\.INCLUDE/' "$V2LVS_DIR/${TOP}_subckt.spi"
printf '.INCLUDE %s/%s_subckt.spi\n' "$V2LVS_DIR" "$TOP" >> "$V2LVS_DIR/$TOP.spi"
python3 "$ROOT/prepare_calibre_extract_source.py" \
  --std-spi "$STD_SPI" \
  --source-added "$LVS_SOURCE_ADDED" \
  --sram-spi "$SRAM_SPI" \
  --top-subckt "$V2LVS_DIR/${TOP}_subckt.spi" \
  --fallback-sram-shell "$SRAM_LAYOUTORDER_REF" \
  "${SOURCE_DROP_TOP_PINS[@]}" \
  --outdir "$V2LVS_DIR"

LVS_DIR=$WORK_DIR/07_lvs
mkdir -p "$LVS_DIR"/{scr,log,output,rpt}
cat > "$LVS_DIR/scr/var.tcl" <<EOF
set lefList " \\
    $STD_LEF \\
    $SRAM_LEF \\
"
EOF
cat > "$LVS_DIR/scr/genHcell.cmd" <<'EOF'
source ./scr/var.tcl
foreach lef $lefList {
    set cellList [exec grep "MACRO " $lef | awk {{print $2}}]
    foreach cell $cellList {
        puts "$cell $cell"
    }
}
EOF
(cd "$LVS_DIR" && tclsh ./scr/genHcell.cmd) > "$LVS_DIR/rpt/hcell"
cp -f "$LVS_DIR/rpt/hcell" "$LVS_DIR/rpt/hcell.ts1alias"
if ! grep -q '^B17aTS1N16ADFPCLLLVTA512X45M4SWSHOD ' "$LVS_DIR/rpt/hcell.ts1alias"; then
cat >> "$LVS_DIR/rpt/hcell.ts1alias" <<'EOF'
B17aTS1N16ADFPCLLLVTA512X45M4SWSHOD TS1N16ADFPCLLLVTA512X45M4SWSHOD
F17aTS1N16ADFPCLLLVTA512X45M4SWSHOD TS1N16ADFPCLLLVTA512X45M4SWSHOD
EOF
fi
generate_lvs_box_rules "$LVS_DIR/rpt/hcell.ts1alias" "$LVS_DIR/rpt/hcell_boxes.inc"
cp -f "$LVS_DECK" "$LVS_DIR/scr/lvs.modified"
sed -i -E "s/^(LAYOUT PRECISION[[:space:]]+).*/\\1$STREAM_UNITS/" "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/VARIABLE POWER_NAME/\/\/VARIABLE POWER_NAME/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/VARIABLE GROUND_NAME/\/\/VARIABLE GROUND_NAME/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/LAYOUT PRIMARY/\/\/LAYOUT PRIMARY/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/LAYOUT PATH/\/\/LAYOUT PATH/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/LAYOUT SYSTEM/\/\/LAYOUT SYSTEM/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/SOURCE PRIMARY/\/\/SOURCE PRIMARY/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/SOURCE PATH/\/\/SOURCE PATH/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/ERC RESULTS DATABASE/\/\/ERC RESULTS DATABASE/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/ERC SUMMARY REPORT/\/\/ERC SUMMARY REPORT/g' "$LVS_DIR/scr/lvs.modified"
sed -i -e 's/LVS REPORT \"/\/\/LVS REPORT \"/g' "$LVS_DIR/scr/lvs.modified"
if [[ "${LAYOUT_FORMAT,,}" == "gds" || "${LAYOUT_FORMAT,,}" == "gdsii" ]]; then
  LVS_LAYOUT_SYSTEM="GDSII"
  LVS_LAYOUT_PATH="../01_ipmerge/output/${TOP}_merged.gds"
elif [[ "$LVS_LAYOUT_MODE" == "dummymerge" ]]; then
  LVS_LAYOUT_SYSTEM="OASIS"
  LVS_LAYOUT_PATH="../04_dummyMerge/output/$TOP.dmmerge.oas.gz"
else
  LVS_LAYOUT_SYSTEM="OASIS"
  LVS_LAYOUT_PATH="../01_ipmerge/output/$TOP.oas.gz"
fi
cat > "$LVS_DIR/scr/runset.extract.cmd" <<EOF
VARIABLE POWER_NAME "VDD" "VDDPST" "AVDD" "DVDD"
VARIABLE GROUND_NAME "VSS"
LAYOUT PRIMARY "$TOP"
LAYOUT PATH "$LVS_LAYOUT_PATH"
LAYOUT SYSTEM $LVS_LAYOUT_SYSTEM
SOURCE PRIMARY "$TOP"
SOURCE PATH "../06_v2lvs/${TOP}_extract.spi"
ERC RESULTS DATABASE "output/calibre_erc.db" ASCII
ERC SUMMARY REPORT "output/calibre_erc.sum"
LVS REPORT "output/lvs.rep"
include ./rpt/hcell_boxes.inc
include ./scr/lvs.modified
LVS NETLIST BOX CONTENTS YES
LVS NETLIST UNNAMED BOX PINS YES
LVS BLACK BOX PORT M1 M1_text M1
LVS BLACK BOX PORT M2 M2_text M2
LVS BLACK BOX PORT M3 M3_text M3
LVS BLACK BOX PORT M4 M4_text M4
EOF
if [[ "$RUN_LVS" == "1" ]]; then
echo "[6/6b] Calibre LVS extraction"
(cd "$LVS_DIR" && run_calibre -hcell ./rpt/hcell.ts1alias -64 -hier -turbo "$CPU" -hyper -spice ./output/$TOP.layspi ./scr/runset.extract.cmd | tee -i log/runset.ext.log)

python3 "$ROOT/prepare_calibre_lvs_source.py" \
  --std-spi "$STD_SPI" \
  --layspi "$LVS_DIR/output/$TOP.layspi" \
  --source-added "$LVS_SOURCE_ADDED" \
  --top-subckt "$V2LVS_DIR/${TOP}_subckt.spi" \
  --hcell "$LVS_DIR/rpt/hcell" \
  --def "$EXPORT_DIR/$TOP.def.gz" \
  --fallback-sram-shell "$SRAM_LAYOUTORDER_REF" \
  "${SOURCE_DROP_TOP_PINS[@]}" \
  --outdir "$LVS_DIR/source_fix" | tee "$LVS_DIR/log/source_fix.log"

generate_lvs_box_rules "$LVS_DIR/source_fix/hcell.ts1alias" "$LVS_DIR/source_fix/hcell_boxes.inc"
generate_lvs_ignore_device_pin_rules "$LVS_DIR/source_fix/hcell.ts1alias" "$LVS_DIR/source_fix/ignore_device_pins.inc"
generate_lvs_exclude_cell_rules "$LVS_DIR/source_fix/hcell.ts1alias" "$LVS_DIR/source_fix/exclude_cells.inc"
generate_lvs_layout_wrapper_exclude_rules "$LVS_DIR/output/$TOP.layspi" "$LVS_DIR/source_fix/exclude_layout_wrappers.inc"

cat > "$LVS_DIR/scr/runset.compare.cmd" <<EOF
VARIABLE POWER_NAME "VDD" "VDDPST" "AVDD" "DVDD"
VARIABLE GROUND_NAME "VSS"
LAYOUT PRIMARY "$TOP"
LAYOUT PATH "$LVS_LAYOUT_PATH"
LAYOUT SYSTEM $LVS_LAYOUT_SYSTEM
SOURCE PRIMARY "$TOP"
SOURCE PATH "./source_fix/soc_top_lvs.spi"
ERC RESULTS DATABASE "output/calibre_erc.db" ASCII
ERC SUMMARY REPORT "output/calibre_erc.sum"
LVS REPORT "output/lvs.rep"
include ./source_fix/hcell_boxes.inc
include ./source_fix/ignore_device_pins.inc
include ./source_fix/exclude_cells.inc
include ./source_fix/exclude_layout_wrappers.inc
include ./scr/lvs.modified
LVS NETLIST BOX CONTENTS YES
LVS NETLIST UNNAMED BOX PINS YES
LVS BLACK BOX PORT M1 M1_text M1
LVS BLACK BOX PORT M2 M2_text M2
LVS BLACK BOX PORT M3 M3_text M3
LVS BLACK BOX PORT M4 M4_text M4
EOF
echo "[6/6c] Calibre LVS compare"
(cd "$LVS_DIR" && run_calibre -lvs -hcell ./source_fix/hcell.ts1alias -64 -hier -turbo "$CPU" -hyper -layout ./output/$TOP.layspi ./scr/runset.compare.cmd | tee -i log/runset.log)
fi

echo "Calibre signoff workspace:"
echo "  $WORK_DIR"
echo "Key outputs:"
echo "  $DRC_DIR/output/DRC.rep"
echo "  $LVS_DIR/output/lvs.rep"
