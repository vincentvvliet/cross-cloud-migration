#!/usr/bin/env bash
set -euo pipefail

echo "=== Running Quint verification ==="
quint run trace-parsing/redis.qnt --invariants kv_invariants --out-itf trace-parsing/traces/trace.itf.json --max-samples 1 --max-steps 1000

echo "=== Trace output saved to trace.itf.json ==="

echo "=== Parsing trace output ==="
python trace-parsing/trace_parsing.py

echo "=== Done ==="
