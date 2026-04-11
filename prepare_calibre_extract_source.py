#!/usr/bin/env python3
import argparse
from pathlib import Path
from typing import List, Set, Tuple


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


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


def write_shell_spi(path: Path, subckts: List[Tuple[str, List[str]]]) -> None:
    with path.open("w", encoding="utf-8") as f:
        for name, pins in subckts:
            f.write(f".subckt {name} {' '.join(pins)}\n")
            f.write(".ends\n")


def read_subckt_shells(path: Path) -> List[Tuple[str, List[str]]]:
    return parse_shell_subckts_from_spi(read_text(path), set())


def write_extract_source_top(
    path: Path,
    source_added: Path,
    std_shell: Path,
    sram_shell: Path,
    top_subckt: Path,
) -> None:
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


def build_std_instance_pin_aliases(source_shells: List[Tuple[str, List[str]]]) -> dict:
    alias_map = {}
    for name, _pins in source_shells:
        alias_map[name] = {"VPP": "", "VBB": ""}
    return alias_map


def rewrite_top_instance_named_pins(top_text: str, pin_aliases: dict) -> str:
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
                    rewritten_named: List[str] = []
                    for tok in tokens[3:]:
                        if "=" not in tok:
                            rewritten_named.append(tok)
                            continue
                        pin, net = tok.split("=", 1)
                        mapped_pin = alias.get(pin, pin)
                        if mapped_pin == "":
                            continue
                        rewritten_named.append(f"{mapped_pin}={net}")
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
    ap.add_argument("--source-added", required=True)
    ap.add_argument("--sram-spi", required=True)
    ap.add_argument("--top-subckt", required=True)
    ap.add_argument("--fallback-sram-shell")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--drop-top-pins", nargs="*", default=[])
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    std_spi = Path(args.std_spi)
    source_added = Path(args.source_added)
    sram_spi = Path(args.sram_spi)
    top_subckt = Path(args.top_subckt)
    fallback_sram_shell = Path(args.fallback_sram_shell) if args.fallback_sram_shell else None

    std_shell = outdir / f"{std_spi.stem}.novppvbb.spi"
    sram_shell = outdir / "sram.layoutorder.spi"
    top_rewritten = outdir / "soc_top_extract_rewired.spi"
    source_top = outdir / "soc_top_extract.spi"

    std_subckts = parse_shell_subckts_from_spi(read_text(std_spi), {"VPP", "VBB"})
    write_shell_spi(std_shell, std_subckts)
    std_pin_aliases = build_std_instance_pin_aliases(std_subckts)
    if fallback_sram_shell and fallback_sram_shell.exists():
        macro_shells = read_subckt_shells(fallback_sram_shell)
    else:
        macro_shells = read_subckt_shells(sram_spi)
    if not macro_shells:
        raise SystemExit("no SRAM shell available for extract-source preparation")
    write_shell_spi(sram_shell, macro_shells)
    macro_pin_map = {name: pins for name, pins in macro_shells}
    rewritten = rewrite_top_instance_named_pins(read_text(top_subckt), std_pin_aliases)
    rewritten = rewrite_top_subckt_for_sram(rewritten, macro_pin_map)
    rewritten = rewrite_named_subckt_header(rewritten, "soc_top", set(args.drop_top_pins))
    top_rewritten.write_text(rewritten, encoding="utf-8")
    write_extract_source_top(source_top, source_added, std_shell, sram_shell, top_rewritten)

    print(f"wrote {std_shell}")
    print(f"wrote {sram_shell}")
    print(f"wrote {top_rewritten}")
    print(f"wrote {source_top}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
