import json
import subprocess
from pathlib import Path
import yaml
import shutil
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed

from load_systems import import_systems

CONFIG_ROOT = Path("config")
RESULTS_DIR = Path("experiments/compatibility-experiment/results/")
RESULTS_DIR.mkdir(exist_ok=True)

_, QUEUE_SYSTEMS, KV_SYSTEMS = import_systems()

# Filter Base Systems
QUEUE_SYSTEMS = [q for q in QUEUE_SYSTEMS if q != "BaseQueue"]
KV_SYSTEMS = [k for k in KV_SYSTEMS if k != "BaseKV"]

FIXED_QUEUE = "BaseQueue"
FIXED_KV = "BaseKV"

MAX_WORKERS = 4


# -----------------------------
# ISOLATION
# -----------------------------
def create_isolated_env(run_id):
    base = Path(f"/tmp/quint_exp_{run_id}")
    base.mkdir(parents=True, exist_ok=True)

    shutil.copytree("generator", base / "generator")
    shutil.copytree("quint", base / "quint")
    shutil.copytree("config", base / "config")

    return base


def write_compat_config(base, source_kv, source_q, target_kv, target_q):
    compat = {
        "source": {
            "systems": {"kv": source_kv, "queue": source_q},
            "composition": {"name": "KVQueue"},
        },
        "target": {
            "systems": {"kv": target_kv, "queue": target_q},
            "composition": {"name": "KVQueue"},
        },
    }

    path = base / "config" / "compat.yaml"
    with open(path, "w") as f:
        yaml.dump(compat, f)


# -----------------------------
# RUN SINGLE
# -----------------------------
def run_single(params):
    source_kv, source_q, target_kv, target_q = params
    run_id = str(uuid.uuid4())[:8]

    try:
        base = create_isolated_env(run_id)

        write_compat_config(base, source_kv, source_q, target_kv, target_q)

        gen = subprocess.run(
            ["python", "generator/main.py", "--compat"],
            cwd=base,
            capture_output=True,
            text=True,
        )

        if gen.returncode != 0:
            return build_result(
                source_kv, source_q, target_kv, target_q, "error", False, gen.stderr
            )

        quint = subprocess.run(
            [
                "quint",
                "run",
                "quint/generated/system.qnt",
                "--invariants",
                "SystemCorrect",
            ],
            cwd=base,
            capture_output=True,
            text=True,
        )

        if quint.returncode != 0:
            return build_result(source_kv, source_q, target_kv, target_q, "fail", True)

        return build_result(source_kv, source_q, target_kv, target_q, "pass", False)

    except Exception as e:
        return build_result(
            source_kv, source_q, target_kv, target_q, "crash", False, str(e)
        )

    finally:
        try:
            shutil.rmtree(base)
        except:
            pass


def build_result(
    source_kv, source_q, target_kv, target_q, status, violations, error=None
):
    return {
        "source": {"kv": source_kv, "queue": source_q},
        "target": {"kv": target_kv, "queue": target_q},
        "status": status,
        "violations": violations,
        "error": error,
    }


# -----------------------------
# EXPERIMENT BUILDERS
# -----------------------------
def build_kv_tasks():
    tasks = []
    for s_kv in KV_SYSTEMS:
        for t_kv in KV_SYSTEMS:
            if s_kv == t_kv:
                # Skip same-to-same
                continue
            tasks.append((s_kv, FIXED_QUEUE, t_kv, FIXED_QUEUE))
    return tasks


def build_queue_tasks():
    tasks = []
    for s_q in QUEUE_SYSTEMS:
        for t_q in QUEUE_SYSTEMS:
            if s_q == t_q:
                # Skip same-to-same
                continue
            tasks.append((FIXED_KV, s_q, FIXED_KV, t_q))
    return tasks


# -----------------------------
# EXECUTION
# -----------------------------
def run_tasks(tasks, label):
    results = []

    with ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(run_single, t): t for t in tasks}

        for i, future in enumerate(as_completed(futures), 1):
            result = future.result()
            print(f"[{label}] {i}/{len(tasks)} → {result['status']}")
            results.append(result)

    return results


# -----------------------------
# MAIN
# -----------------------------
def main():
    print("=== KV COMPATIBILITY ===")
    kv_results = run_tasks(build_kv_tasks(), "KV")

    with open(RESULTS_DIR / "kv_results.json", "w") as f:
        json.dump({"experiments": kv_results}, f, indent=2)

    print("\n=== QUEUE COMPATIBILITY ===")
    queue_results = run_tasks(build_queue_tasks(), "QUEUE")

    with open(RESULTS_DIR / "queue_results.json", "w") as f:
        json.dump({"experiments": queue_results}, f, indent=2)

    print("\nSaved results:")
    print(" - experiments/compatibility-experiment/results/kv_results.json")
    print(" - experiments/compatibility-experiment/results/queue_results.json")


if __name__ == "__main__":
    main()
