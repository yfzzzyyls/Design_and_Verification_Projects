#!/usr/bin/env python3
import argparse
import gzip
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def read_maybe_gzip_text(path: Path) -> str:
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8", errors="ignore") as f:
            return f.read()
    return read_text(path)


def parse_shell_subckts_from_spi(text: str, drop_pins: Set[str]) -> List[Tuple[str, List[str]]]:
    subckts: List[Tuple[str, List[str]]] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line.lower().startswith(".subckt "):
            i += 1
            continue
        header = line
        i += 1
        while i < len(lines) and lines[i].lstrip().startswith("+"):
            header += " " + lines[i].lstrip()[1:].strip()
            i += 1
        tokens = header.split()
        if len(tokens) >= 2:
            name = tokens[1]
            pins = [tok for tok in tokens[2:] if tok not in drop_pins]
            subckts.append((name, pins))
    return subckts


def extract_layout_subckt_shells(text: str) -> List[Tuple[str, List[str]]]:
    subckts: List[Tuple[str, List[str]]] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line.startswith(".SUBCKT "):
            i += 1
            continue
        header = line
        i += 1
        while i < len(lines) and lines[i].lstrip().startswith("+"):
            header += " " + lines[i].lstrip()[1:].strip()
            i += 1
        tokens = header.split()
        if len(tokens) >= 2:
            subckts.append((tokens[1], tokens[2:]))
    return subckts


def read_subckt_shells(path: Path) -> List[Tuple[str, List[str]]]:
    return parse_shell_subckts_from_spi(read_text(path), set())


def extract_layout_macro_shells(layspi_text: str) -> List[Tuple[str, List[str]]]:
    return [(name, pins) for name, pins in extract_layout_subckt_shells(layspi_text) if name.startswith("TS")]


def normalize_std_shells_for_lvs(
    source_shells: List[Tuple[str, List[str]]],
    layout_shells: Dict[str, List[str]],
) -> List[Tuple[str, List[str]]]:
    normalized: List[Tuple[str, List[str]]] = []
    for name, pins in source_shells:
        # Keep DCAP body pins explicit on the source side. Some extracted
        # layouts collapse them to 2-pin shells, but the foundry source context
        # and instance syntax on these decks still expect 4 pins.
        if name.startswith("DCAP"):
            mapped: List[str] = []
            for pin in pins:
                if pin == "VPP":
                    mapped.append("8")
                    continue
                if pin == "VBB":
                    mapped.append("9")
                    continue
                mapped.append(pin)
            normalized.append((name, mapped))
            continue
        # Prefer the extracted layout shell when available so the source-side
        # library header matches the actual Calibre view for compare.
        if name in layout_shells:
            normalized.append((name, layout_shells[name]))
            continue
        mapped: List[str] = []
        for pin in pins:
            if pin == "VPP":
                if name.startswith("DCAP"):
                    mapped.append("8")
                continue
            if pin == "VBB":
                if name.startswith("DCAP"):
                    mapped.append("9")
                continue
            mapped.append(pin)
        normalized.append((name, mapped))
    return normalized


def write_shell_spi(path: Path, subckts: List[Tuple[str, List[str]]]) -> None:
    with path.open("w", encoding="utf-8") as f:
        for name, pins in subckts:
            f.write(f".subckt {name} {' '.join(pins)}\n")
            f.write(".ends\n")


def rewrite_spi_subckt_headers(
    text: str,
    desired_pins: Dict[str, List[str]],
    drop_pins: Set[str],
) -> str:
    out: List[str] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped.lower().startswith(".subckt "):
            out.append(line.rstrip())
            i += 1
            continue

        header = stripped
        i += 1
        while i < len(lines) and lines[i].lstrip().startswith("+"):
            header += " " + lines[i].lstrip()[1:].strip()
            i += 1

        tokens = header.split()
        name = tokens[1]
        orig_pins = [tok for tok in tokens[2:] if tok not in drop_pins]
        new_pins = desired_pins.get(name, orig_pins)
        out.append(f".subckt {name} {' '.join(new_pins)}".rstrip())
        continue
    return "\n".join(out) + "\n"


def write_alias_hcell(path: Path, base_hcell: Path, macro_names: List[str]) -> None:
    lines = base_hcell.read_text(encoding="utf-8", errors="ignore").splitlines()
    with path.open("w", encoding="utf-8") as f:
        for line in lines:
            if line.strip():
                f.write(line.rstrip() + "\n")
        for macro in macro_names:
            f.write(f"B17a{macro} {macro}\n")
            f.write(f"F17a{macro} {macro}\n")


def write_box_include(path: Path, hcell_path: Path) -> None:
    entries = []
    for line in hcell_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        parts = line.split()
        if len(parts) >= 2:
            entries.append((parts[0], parts[1]))
    with path.open("w", encoding="utf-8") as f:
        for left, right in entries:
            f.write(f"LVS BOX {left} {right}\n")


def write_source_top(path: Path, source_added: Path, std_shell: Path, sram_shell: Path, top_subckt: Path) -> None:
    with path.open("w", encoding="utf-8") as f:
        f.write(f".INCLUDE {source_added}\n")
        f.write(f".INCLUDE {std_shell}\n")
        f.write(f".INCLUDE {sram_shell}\n")
        f.write(f".INCLUDE {top_subckt}\n")


def rewrite_top_subckt_for_sram(top_text: str, macro_pin_map: dict) -> str:
    out: List[str] = []
    lines = top_text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith("X") and " $PINS " in stripped:
            original_block = [line.rstrip()]
            parse_block = [stripped]
            i += 1
            while i < len(lines) and lines[i].lstrip().startswith("+"):
                original_block.append(lines[i].rstrip())
                parse_block.append(lines[i].lstrip()[1:].strip())
                i += 1
            joined = " ".join(parse_block)
            tokens = joined.split()
            if len(tokens) >= 3:
                inst = tokens[0]
                cell = tokens[1]
                if cell in macro_pin_map and tokens[2] == "$PINS":
                    named = {}
                    for tok in tokens[3:]:
                        if "=" not in tok:
                            continue
                        pin, net = tok.split("=", 1)
                        named[pin] = net
                    ordered_nets = [named.get(pin, pin) for pin in macro_pin_map[cell]]
                    chunk = [inst] + ordered_nets + [cell]
                    width = 12
                    out.append(" ".join(chunk[:width]))
                    for start in range(width, len(chunk), width):
                        out.append("+ " + " ".join(chunk[start:start + width]))
                    continue
            out.extend(original_block)
            continue
        out.append(line.rstrip())
        i += 1
    return "\n".join(out) + "\n"


def rewrite_named_subckt_header(top_text: str, subckt_name: str, drop_pins: Set[str]) -> str:
    if not drop_pins:
        return top_text

    out: List[str] = []
    lines = top_text.splitlines()
    i = 0
    target = f".subckt {subckt_name}".lower()
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.lower().startswith(target):
            header = stripped
            i += 1
            while i < len(lines) and lines[i].lstrip().startswith("+"):
                header += " " + lines[i].lstrip()[1:].strip()
                i += 1
            tokens = header.split()
            name = tokens[1]
            pins = [tok for tok in tokens[2:] if tok not in drop_pins]
            chunk = [".SUBCKT", name] + pins
            width = 12
            out.append(" ".join(chunk[:width]))
            for start in range(width, len(chunk), width):
                out.append("+ " + " ".join(chunk[start:start + width]))
            continue
        out.append(line.rstrip())
        i += 1
    return "\n".join(out) + "\n"


def build_dcap_body_net_map(def_path: Optional[Path]) -> Dict[str, Dict[str, str]]:
    if not def_path or not def_path.exists():
        return {}

    text = read_maybe_gzip_text(def_path)
    in_components = False
    placements: Dict[str, Tuple[str, int]] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("COMPONENTS "):
            in_components = True
            continue
        if in_components and line.startswith("END COMPONENTS"):
            break
        if not in_components or not line.startswith("- "):
            continue
        tokens = line.split()
        if len(tokens) < 2:
            continue
        name = tokens[1]
        cell = tokens[2] if len(tokens) > 2 else ""
        if not cell.startswith("DCAP"):
            continue
        if "(" not in line or ")" not in line:
            continue
        try:
            coord_part = line.split("(", 1)[1].split(")", 1)[0]
            x_str, y_str = coord_part.split()[:2]
            placements[name] = (cell, int(y_str))
        except (IndexError, ValueError):
            continue

    if not placements:
        return {}

    row_ys = sorted({y for _cell, y in placements.values()})
    row_index = {y: idx for idx, y in enumerate(row_ys)}

    body_net_map: Dict[str, Dict[str, str]] = {}
    for name, (_cell, y) in placements.items():
        pair_idx = row_index[y] // 2
        body_net_map[name] = {
            "8": "DCAP_BODY8",
            "9": f"DCAP_BODY9_R{pair_idx}",
        }
    return body_net_map


def build_std_instance_pin_aliases(
    original_shells: List[Tuple[str, List[str]]],
    normalized_shells: List[Tuple[str, List[str]]],
) -> Dict[str, Dict[str, str]]:
    alias_map: Dict[str, Dict[str, str]] = {}
    normalized_by_name = {name: pins for name, pins in normalized_shells}
    for name, orig_pins in original_shells:
        if name not in normalized_by_name:
            continue
        normalized_pins = normalized_by_name[name]
        mapping: Dict[str, str] = {}

        # Preserve any pins that still exist by name in the normalized shell.
        for pin in orig_pins:
            if pin in normalized_pins:
                mapping[pin] = pin

        if name.startswith("DCAP"):
            # Calibre may expose both body nets separately (8/9) or collapse the
            # n-body into a single external pin (7) depending on the variant.
            if "8" in normalized_pins:
                mapping["VPP"] = "8"
            if "9" in normalized_pins:
                mapping["VBB"] = "9"
            if "7" in normalized_pins:
                mapping["VBB"] = "7"
                mapping["VPP"] = ""
        else:
            if "VPP" not in normalized_pins:
                mapping["VPP"] = ""
            if "VBB" not in normalized_pins:
                mapping["VBB"] = ""

        alias_map[name] = mapping
    return alias_map


def rewrite_top_instance_named_pins(
    top_text: str,
    pin_aliases: Dict[str, Dict[str, str]],
    dcap_body_nets: Dict[str, Dict[str, str]],
) -> str:
    out: List[str] = []
    lines = top_text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith("X") and " $PINS " in stripped:
            original_block = [line.rstrip()]
            parse_block = [stripped]
            i += 1
            while i < len(lines) and lines[i].lstrip().startswith("+"):
                original_block.append(lines[i].rstrip())
                parse_block.append(lines[i].lstrip()[1:].strip())
                i += 1
            joined = " ".join(parse_block)
            tokens = joined.split()
            if len(tokens) >= 3:
                inst = tokens[0]
                cell = tokens[1]
                alias = pin_aliases.get(cell)
                if alias and tokens[2] == "$PINS":
                    body_nets = dcap_body_nets.get(inst.lstrip("X"), {})
                    rewritten_named: List[str] = []
                    seen_pins = set()
                    for tok in tokens[3:]:
                        if "=" not in tok:
                            rewritten_named.append(tok)
                            continue
                        pin, net = tok.split("=", 1)
                        mapped_pin = alias.get(pin, pin)
                        if mapped_pin == "@BODY8":
                            rewritten_named.append(f"8={body_nets.get('8', 'DCAP_BODY8')}")
                            seen_pins.add("8")
                            continue
                        if mapped_pin == "@BODY9":
                            rewritten_named.append(f"9={body_nets.get('9', 'DCAP_BODY9')}")
                            seen_pins.add("9")
                            continue
                        if mapped_pin == "":
                            continue
                        rewritten_named.append(f"{mapped_pin}={net}")
                        seen_pins.add(mapped_pin)
                    if alias.get("VPP") == "@BODY8" and "8" not in seen_pins:
                        rewritten_named.append(f"8={body_nets.get('8', 'DCAP_BODY8')}")
                    if alias.get("VBB") == "@BODY9" and "9" not in seen_pins:
                        rewritten_named.append(f"9={body_nets.get('9', 'DCAP_BODY9')}")
                    chunk = [inst, cell, "$PINS"] + rewritten_named
                    width = 12
                    out.append(" ".join(chunk[:width]))
                    for start in range(width, len(chunk), width):
                        out.append("+ " + " ".join(chunk[start:start + width]))
                    continue
            out.extend(original_block)
            continue
        out.append(line.rstrip())
        i += 1
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--std-spi", required=True)
    ap.add_argument("--layspi", required=True)
    ap.add_argument("--source-added", required=True)
    ap.add_argument("--top-subckt", required=True)
    ap.add_argument("--hcell", required=True)
    ap.add_argument("--fallback-sram-shell")
    ap.add_argument("--def", dest="def_path")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--drop-top-pins", nargs="*", default=[])
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    std_spi = Path(args.std_spi)
    layspi = Path(args.layspi)
    source_added = Path(args.source_added)
    top_subckt = Path(args.top_subckt)
    hcell = Path(args.hcell)
    fallback_sram_shell = Path(args.fallback_sram_shell) if args.fallback_sram_shell else None
    def_path = Path(args.def_path) if args.def_path else None

    std_shell = outdir / f"{std_spi.stem}.novppvbb.spi"
    sram_shell = outdir / "sram.layoutorder.spi"
    source_top = outdir / "soc_top_lvs.spi"
    top_rewritten = outdir / "soc_top_subckt_rewired.spi"
    alias_hcell = outdir / "hcell.ts1alias"
    box_inc = outdir / "hcell_boxes.inc"

    layout_shells = {name: pins for name, pins in extract_layout_subckt_shells(read_text(layspi))}

    original_std_subckts = parse_shell_subckts_from_spi(read_text(std_spi), set())
    std_subckts = normalize_std_shells_for_lvs(original_std_subckts, layout_shells)
    std_header_map = {name: pins for name, pins in std_subckts}
    std_shell.write_text(
        rewrite_spi_subckt_headers(read_text(std_spi), std_header_map, set()),
        encoding="utf-8",
    )
    std_pin_aliases = build_std_instance_pin_aliases(original_std_subckts, std_subckts)
    dcap_body_nets = build_dcap_body_net_map(def_path)

    if fallback_sram_shell and fallback_sram_shell.exists():
        macro_shells = read_subckt_shells(fallback_sram_shell)
    else:
        macro_shells = extract_layout_macro_shells(read_text(layspi))
    if not macro_shells:
        raise SystemExit(f"no TS* SRAM subckt found in {layspi}")
    write_shell_spi(sram_shell, macro_shells)

    macro_names = [name for name, _pins in macro_shells]
    macro_pin_map = {name: pins for name, pins in macro_shells}
    write_alias_hcell(alias_hcell, hcell, macro_names)
    write_box_include(box_inc, alias_hcell)
    top_text = read_text(top_subckt)
    top_text = rewrite_top_instance_named_pins(top_text, std_pin_aliases, dcap_body_nets)
    rewritten = rewrite_top_subckt_for_sram(top_text, macro_pin_map)
    rewritten = rewrite_named_subckt_header(rewritten, "soc_top", set(args.drop_top_pins))
    top_rewritten.write_text(rewritten, encoding="utf-8")
    write_source_top(source_top, source_added, std_shell, sram_shell, top_rewritten)

    print(f"wrote {std_shell}")
    print(f"wrote {sram_shell}")
    print(f"wrote {alias_hcell}")
    print(f"wrote {box_inc}")
    print(f"wrote {top_rewritten}")
    print(f"wrote {source_top}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
