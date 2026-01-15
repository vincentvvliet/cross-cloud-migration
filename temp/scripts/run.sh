#!/usr/bin/env bash
set -euo pipefail

echo "=== Generating invariants from YAML ==="
cd generator
python main.py
cd ..

echo "=== Running Quint verification ==="
quint run quint/system.qnt

echo "=== Done ==="
