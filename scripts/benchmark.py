#!/usr/bin/env python3
"""DEPRECATED (ADR-0050): agentmemory has been removed.

See token_usage.py for current metrics.

Usage:
    python3 scripts/benchmark.py
"""

from __future__ import annotations

import sys


def main() -> None:
    print(
        "DEPRECATED (ADR-0050): This benchmark script relied on agentmemory, "
        "which has been removed. See token_usage.py for current metrics.",
        file=sys.stderr,
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
