# cross-cloud-migration

Current workflow:
- Update system.yaml
- Re-run generator: `python generator/main.py`
- Run quint: `quint run quint/system.qnt --invariants SystemCorrect`