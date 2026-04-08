from parse_config import load_config, load_compat_config
from invariants import INVARIANTS, satisfies
from load_systems import import_systems
from generate_invariants import generate_invariants_quint
from generate_system import generate_system_qnt

import os


def generate(caps_source, caps_target):
    systems_db, _, _ = import_systems()

    # Invariants from SOURCE
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

    print(f"Generated {len(active)} invariants (from SOURCE)")

    # System from TARGET
    generate_system_qnt(caps_target, systems_db, "quint/generated/system.qnt")

    print(f"Generated system.qnt (from TARGET)")


def main():
    compat_mode = os.path.exists("config/compat.yaml")

    if compat_mode:
        print("=== Running in COMPATIBILITY MODE ===")
        caps_source, caps_target = load_compat_config()

        print("SOURCE:", [s["type"] for s in caps_source["systems"].values()])
        print("TARGET:", [s["type"] for s in caps_target["systems"].values()])

        generate(caps_source, caps_target)

    else:
        print("=== Running in NORMAL MODE ===")
        caps = load_config()

        generate(caps, caps)


if __name__ == "__main__":
    main()
