from parse_config import load_config, load_compat_config
from invariants import INVARIANTS, satisfies
from load_systems import import_systems
from generate_invariants import generate_invariants_quint
from generate_system import generate_system_qnt

import argparse


def generate(caps_source, caps_target):
    systems_db, _, _ = import_systems()

    # --- Invariants from SOURCE ---
    active = [
        inv for inv in INVARIANTS if satisfies(caps_source["systems"], inv.requires)
    ]

    participating_systems_source = [
        s["type"] for s in caps_source["systems"].values()
    ] + [caps_source["composition"]["name"]]

    imports = [
        systems_db[s]["import"] for s in systems_db if s in participating_systems_source
    ]

    quint = generate_invariants_quint(active, imports)

    with open("quint/generated/generated_invariants.qnt", "w") as f:
        f.write(quint)

    print(
        f"Generated {len(active)} invariants { '(from SOURCE)' if (caps_source != caps_target) else '' }"
    )

    # --- System from TARGET ---
    generate_system_qnt(caps_target, systems_db, "quint/generated/system.qnt")

    print(
        f"Generated system.qnt { '(from TARGET)' if (caps_source != caps_target) else '' }"
    )


def main():
    parser = argparse.ArgumentParser(description="Run Quint generation pipeline")
    parser.add_argument(
        "--compat",
        action="store_true",
        help="Run in compatibility mode (source invariants vs target system)",
    )
    parser.add_argument(
        "--compat-file",
        default="config/compat.yaml",
        help="Path to compatibility config file",
    )

    args = parser.parse_args()

    if args.compat:
        print("=== Running in COMPATIBILITY MODE ===")
        caps_source, caps_target = load_compat_config(args.compat_file)

        print(
            "SOURCE:",
            [s["type"] for s in caps_source["systems"].values()],
        )
        print(
            "TARGET:",
            [s["type"] for s in caps_target["systems"].values()],
        )

        generate(caps_source, caps_target)

    else:
        print("=== Running in NORMAL MODE ===")
        caps = load_config()

        generate(caps, caps)


if __name__ == "__main__":
    main()
