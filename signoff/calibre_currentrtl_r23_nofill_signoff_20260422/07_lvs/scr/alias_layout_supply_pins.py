#!/usr/bin/env python3
"""Alias extracted local supply fragments onto VDD/VSS through wrapper hierarchy.

The extracted layout netlist contains ICV_* wrapper subckts whose formal pins are
numbered rather than named. Many of those numbered formals are only used to carry
VDD/VSS into physical filler / boundary / decap content. This script infers which
wrapper formals behave as supplies from child connectivity, then rewrites instance
connections hierarchically so those fragments collapse onto VDD/VSS.
"""

import argparse
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

POWER_PINS = {"VDD", "VDDM", "VDDPST", "AVDD", "DVDD"}
GROUND_PINS = {"VSS"}
SUPPLY_PINS = POWER_PINS | GROUND_PINS


class Subckt:
    def __init__(self, name, header_lines, body_lines, end_line, pins):
        self.name = name
        self.header_lines = header_lines
        self.body_lines = body_lines
        self.end_line = end_line
        self.pins = pins


def canonical_supply(pin_name):
    if pin_name in POWER_PINS:
        return "VDD"
    if pin_name in GROUND_PINS:
        return "VSS"
    return None


def parse_subckts(lines):
    subckts = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.startswith(".SUBCKT "):
            i += 1
            continue

        header_lines = [line]
        tokens = line.split()
        name = tokens[1]
        pins = tokens[2:]
        i += 1
        while i < len(lines) and lines[i].startswith("+"):
            header_lines.append(lines[i])
            pins.extend(lines[i][1:].split())
            i += 1

        body_lines = []
        while i < len(lines) and not lines[i].startswith(".ENDS"):
            body_lines.append(lines[i])
            i += 1

        end_line = lines[i] if i < len(lines) else ".ENDS"
        subckts[name] = Subckt(
            name=name,
            header_lines=header_lines,
            body_lines=body_lines,
            end_line=end_line,
            pins=pins,
        )
        i += 1

    return subckts


def flatten_instance(stmt_lines):
    tokens = []
    for idx, line in enumerate(stmt_lines):
        body = line if idx == 0 else line[1:]
        tokens.extend(body.split())
    return tokens


def iter_instance_stmts(body_lines):
    i = 0
    while i < len(body_lines):
        line = body_lines[i]
        if not line.startswith("X"):
            i += 1
            continue
        j = i + 1
        while j < len(body_lines) and body_lines[j].startswith("+"):
            j += 1
        yield i, j, body_lines[i:j]
        i = j


def find_cell_index(tokens, subckts):
    for idx in range(len(tokens) - 1, 0, -1):
        if tokens[idx] in subckts:
            return idx
    return None


def infer_formal_supply_roles(subckts):
    known = {}

    for name, subckt in subckts.items():
        roles = {}
        for idx, pin in enumerate(subckt.pins):
            supply = canonical_supply(pin)
            if supply is not None:
                roles[idx] = supply
        if roles:
            known[name] = roles

    changed = True
    while changed:
        changed = False
        for name, subckt in subckts.items():
            roles = known.setdefault(name, {})
            formal_index = {pin: idx for idx, pin in enumerate(subckt.pins)}
            inferred = {}

            for _, _, stmt_lines in iter_instance_stmts(subckt.body_lines):
                tokens = flatten_instance(stmt_lines)
                cell_idx = find_cell_index(tokens, subckts)
                if cell_idx is None:
                    continue
                child_name = tokens[cell_idx]
                child_roles = known.get(child_name, {})
                if not child_roles:
                    continue

                conn_count = cell_idx - 1
                child_pin_count = len(subckts[child_name].pins)
                if conn_count < child_pin_count:
                    continue

                for child_pin_idx, supply in child_roles.items():
                    conn_idx = 1 + child_pin_idx
                    actual = tokens[conn_idx]
                    parent_pin_idx = formal_index.get(actual)
                    if parent_pin_idx is None:
                        continue
                    inferred.setdefault(parent_pin_idx, set()).add(supply)

            for pin_idx, supplies in inferred.items():
                if len(supplies) != 1 or pin_idx in roles:
                    continue
                roles[pin_idx] = next(iter(supplies))
                changed = True

    return known


def rewrite_instance(
    stmt_lines,
    subckts,
    current_formal_roles,
    current_pins,
    known_roles,
):
    tokens = flatten_instance(stmt_lines)
    if not tokens or not tokens[0].startswith("X"):
        return stmt_lines

    cell_idx = find_cell_index(tokens, subckts)
    if cell_idx is None:
        return stmt_lines

    child_name = tokens[cell_idx]
    child_roles = known_roles.get(child_name, {})
    child_pins = subckts[child_name].pins
    conn_count = cell_idx - 1
    if conn_count < len(child_pins):
        return stmt_lines

    current_formal_index = {pin: idx for idx, pin in enumerate(current_pins)}
    changed = False

    for child_pin_idx, supply in child_roles.items():
        conn_idx = 1 + child_pin_idx
        actual = tokens[conn_idx]
        if actual == supply:
            continue

        current_formal_idx = current_formal_index.get(actual)
        if current_formal_idx is not None:
            if current_formal_roles.get(current_formal_idx) != supply:
                continue

        tokens[conn_idx] = supply
        changed = True

    if not changed:
        return stmt_lines
    return [" ".join(tokens)]


def rewrite_netlist(text):
    lines = text.splitlines()
    subckts = parse_subckts(lines)
    known_roles = infer_formal_supply_roles(subckts)

    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.startswith(".SUBCKT "):
            out.append(line)
            i += 1
            continue

        tokens = line.split()
        name = tokens[1]
        subckt = subckts[name]
        current_formal_roles = known_roles.get(name, {})
        out.extend(subckt.header_lines)
        body = subckt.body_lines
        j = 0
        while j < len(body):
            if not body[j].startswith("X"):
                out.append(body[j])
                j += 1
                continue
            k = j + 1
            while k < len(body) and body[k].startswith("+"):
                k += 1
            out.extend(
                rewrite_instance(
                    body[j:k],
                    subckts,
                    current_formal_roles,
                    subckt.pins,
                    known_roles,
                )
            )
            j = k

        out.append(subckt.end_line)
        i += len(subckt.header_lines) + len(subckt.body_lines) + 1

    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    text = args.input.read_text()
    args.output.write_text(rewrite_netlist(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
