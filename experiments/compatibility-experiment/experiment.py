import json
import subprocess
from pathlib import Path
import yaml
import shutil
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed
from load_systems import import_systems

CONFIG_ROOT = Path("config")
RESULTS_PATH = Path(
    "experiments/compatibility-experiment/results/compatibility_results.json"
)

KV_SYSTEMS = ["DynamoDB", "Redis", "Cassandra"]
QUEUE_SYSTEMS = ["Kafka", "RabbitMQ", "SQS"]

_, QUEUE_SYSTEMS_1, KV_SYSTEMS_1 = import_systems()
print(QUEUE_SYSTEMS_1)
print(KV_SYSTEMS_1)

MAX_WORKERS = 4  # adjust based on CPU


def create_isolated_env(run_id):
    base = Path(f"/tmp/quint_exp_{run_id}")
    base.mkdir(parents=True, exist_ok=True)

    # Copy necessary folders
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


def run_single_experiment(params):
    source_kv, source_q, target_kv, target_q = params
    run_id = str(uuid.uuid4())[:8]

    try:
        base = create_isolated_env(run_id)

        write_compat_config(base, source_kv, source_q, target_kv, target_q)

        # --- Run generator ---
        gen = subprocess.run(
            ["python", "generator/main.py", "--compat"],
            cwd=base,
            capture_output=True,
            text=True,
        )

        if gen.returncode != 0:
            return build_result(
                source_kv,
                source_q,
                target_kv,
                target_q,
                "error",
                False,
                gen.stderr,
            )

        # --- Run Quint ---
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

        output = quint.stdout + quint.stderr

        if quint.returncode != 0:
            return build_result(
                source_kv,
                source_q,
                target_kv,
                target_q,
                "fail",
                True,
                None,
                output,
            )

        return build_result(
            source_kv,
            source_q,
            target_kv,
            target_q,
            "pass",
            False,
            None,
            output,
        )

    except Exception as e:
        return build_result(
            source_kv,
            source_q,
            target_kv,
            target_q,
            "crash",
            False,
            str(e),
        )

    finally:
        # Cleanup
        try:
            shutil.rmtree(base)
        except:
            pass


def build_result(
    source_kv,
    source_q,
    target_kv,
    target_q,
    status,
    violations,
    error=None,
    output=None,
):
    return {
        "source": {"kv": source_kv, "queue": source_q},
        "target": {"kv": target_kv, "queue": target_q},
        "status": status,
        "violations": violations,
        "error": error,
        "raw_output": output,
    }


def main():
    RESULTS_PATH.parent.mkdir(exist_ok=True)

    tasks = [
        (s_kv, s_q, t_kv, t_q)
        for s_kv in KV_SYSTEMS
        for s_q in QUEUE_SYSTEMS
        for t_kv in KV_SYSTEMS
        for t_q in QUEUE_SYSTEMS
    ]

    results = []

    with ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(run_single_experiment, t): t for t in tasks}

        for i, future in enumerate(as_completed(futures), 1):
            result = future.result()
            print(f"[{i}/{len(tasks)}] {result['status']}")

            results.append(result)

    with open(RESULTS_PATH, "w") as f:
        json.dump({"experiments": results}, f, indent=2)

    print(f"\nSaved results to {RESULTS_PATH}")


if __name__ == "__main__":
    main()
