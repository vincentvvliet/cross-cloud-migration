import json
import subprocess
from pathlib import Path
import yaml

CONFIG_ROOT = Path("config")
RESULTS_PATH = Path(
    "experiments/compatibility-experiment/results/compatibility_results.json"
)


KV_SYSTEMS = ["DynamoDB", "Redis", "Cassandra"]
QUEUE_SYSTEMS = ["Kafka", "RabbitMQ", "SQS"]


def write_compat_config(source_kv, source_q, target_kv, target_q):
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

    path = CONFIG_ROOT / "compat.yaml"
    with open(path, "w") as f:
        yaml.dump(compat, f)

    return path


def run_single_experiment():
    try:
        # Run generator in compat mode
        gen = subprocess.run(
            ["python", "generator/main.py", "--compat"],
            capture_output=True,
            text=True,
        )

        if gen.returncode != 0:
            return {
                "status": "error",
                "violations": False,
                "error": gen.stderr,
            }

        # Run Quint
        quint = subprocess.run(
            [
                "quint",
                "run",
                "quint/generated/system.qnt",
                "--invariants",
                "SystemCorrect",
            ],
            capture_output=True,
            text=True,
        )

        output = quint.stdout + quint.stderr

        # --- Detect result ---
        if quint.returncode != 0:
            # Quint returns non-zero on invariant violation
            return {
                "status": "fail",
                "violations": True,
                "error": None,
                "raw_output": output,
            }

        return {
            "status": "pass",
            "violations": False,
            "error": None,
            "raw_output": output,
        }

    except Exception as e:
        return {
            "status": "crash",
            "violations": False,
            "error": str(e),
        }


def main():
    RESULTS_PATH.parent.mkdir(exist_ok=True)

    results = []

    total = len(KV_SYSTEMS) * len(QUEUE_SYSTEMS) ** 2 * len(KV_SYSTEMS)

    counter = 0

    for source_kv in KV_SYSTEMS:
        for source_q in QUEUE_SYSTEMS:
            for target_kv in KV_SYSTEMS:
                for target_q in QUEUE_SYSTEMS:

                    counter += 1
                    print(
                        f"[{counter}] SOURCE({source_kv}, {source_q}) → TARGET({target_kv}, {target_q})"
                    )

                    write_compat_config(source_kv, source_q, target_kv, target_q)

                    result = run_single_experiment()

                    results.append(
                        {
                            "source": {"kv": source_kv, "queue": source_q},
                            "target": {"kv": target_kv, "queue": target_q},
                            **result,
                        }
                    )

    with open(RESULTS_PATH, "w") as f:
        json.dump({"experiments": results}, f, indent=2)

    print(f"\nSaved results to {RESULTS_PATH}")


if __name__ == "__main__":
    main()
