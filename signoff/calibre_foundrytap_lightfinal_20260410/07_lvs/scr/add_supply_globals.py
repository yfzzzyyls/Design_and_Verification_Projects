#!/usr/bin/env python3
"""Prepend a global supply declaration to a SPICE netlist."""

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--globals",
        nargs="+",
        default=["VDD", "VSS"],
        help="Global nets to prepend",
    )
    args = parser.parse_args()

    prefix = ".GLOBAL " + " ".join(args.globals) + "\n"
    body = args.input.read_text()
    if body.startswith(prefix):
        args.output.write_text(body)
    else:
        args.output.write_text(prefix + body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
