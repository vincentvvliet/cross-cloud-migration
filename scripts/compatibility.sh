#!/usr/bin/env bash
set -euo pipefail

echo "=== Running main pipeline ==="
python generator/main.py

echo "=== Running Quint verification ==="
quint run quint/generated/system.qnt --invariants SystemCorrect # --verbosity 3

# TODO: run multiple permutations
# TODO: handle violations

echo "=== Done ==="
