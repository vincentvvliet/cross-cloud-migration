#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-normal}

echo "=== Running main pipeline ==="

if [ "$MODE" = "compat" ]; then
    python generator/main.py --compat
else
    python generator/main.py
fi

echo "=== Running Quint verification ==="
quint run quint/generated/system.qnt --invariants SystemCorrect

echo "=== Done ==="