#!/usr/bin/env bash
set -euo pipefail

echo "=== Generating invariants from YAML ==="
python generator/main.py

echo "=== Running Quint verification ==="
quint run quint/generated/system.qnt

echo "=== Done ==="
